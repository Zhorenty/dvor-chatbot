import 'dart:io';

import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteBookingRepository', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dvor-sqlite-test-');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('creates and deduplicates booking by user and training', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Functional',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
      );

      final first = await repository.createPendingBooking(
        userId: 1001,
        userUsername: '@runner_1001',
        training: training,
      );
      final second = await repository.createPendingBooking(
        userId: 1001,
        training: training,
      );

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(first.booking.id, second.booking.id);
      expect(first.booking.userUsername, 'runner_1001');
      expect(second.booking.userUsername, 'runner_1001');

      await repository.close();
    });

    test('lists bookings by training keys without cancelled and rejected records', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final firstTraining = TrainingInfo(
        title: 'Functional',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
      );
      final secondTraining = TrainingInfo(
        title: 'Cardio',
        startsAt: DateTime(2030, 6, 11, 19),
        location: 'Gym B',
      );

      final first = await repository.createPendingBooking(
        userId: 4001,
        userUsername: 'first_user',
        training: firstTraining,
      );
      final second = await repository.createPendingBooking(
        userId: 4002,
        userUsername: 'second_user',
        training: secondTraining,
      );
      await repository.updateStatus(first.booking.id, BookingStatus.cancelled);
      await repository.updateStatus(second.booking.id, BookingStatus.paymentRejected);

      final result = await repository.listByTrainingKeys(
        <String>{firstTraining.sessionKey, secondTraining.sessionKey},
      );

      expect(result, isEmpty);

      await repository.close();
    });

    test('reactivates cancelled booking on repeat booking attempt', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Free session',
        startsAt: DateTime(2030, 6, 12, 19),
        location: 'Gym A',
        price: 0,
      );

      final first = await repository.createPendingBooking(
        userId: 4101,
        userUsername: 'runner_rebook',
        training: training,
      );
      await repository.updateStatus(first.booking.id, BookingStatus.cancelled);

      final second = await repository.createPendingBooking(
        userId: 4101,
        userUsername: 'runner_rebook',
        training: training,
      );

      expect(second.created, isTrue);
      expect(second.booking.id, first.booking.id);
      expect(second.booking.status, BookingStatus.pendingPayment);

      await repository.close();
    });

    test('submits payment and lists queue by status', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      await repository.createPendingBooking(
        userId: 2001,
        training: TrainingInfo(
          title: 'Cardio',
          startsAt: DateTime(2030, 6, 11, 18),
          location: 'Stadium B',
        ),
      );

      final submitted = await repository.submitPaymentForLatestPending(
        2001,
        note: 'transfer done',
      );

      expect(submitted, isNotNull);
      expect(submitted!.status, BookingStatus.paymentSubmitted);

      final queue = await repository.listByStatus(BookingStatus.paymentSubmitted);
      expect(queue, hasLength(1));
      expect(queue.single.id, submitted.id);

      await repository.close();
    });

    test('submits payment for exact pending booking id only', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final first = await repository.createPendingBooking(
        userId: 2111,
        training: TrainingInfo(
          title: 'First pending',
          startsAt: DateTime(2030, 6, 11, 18),
          location: 'Stadium B',
        ),
      );
      final second = await repository.createPendingBooking(
        userId: 2111,
        training: TrainingInfo(
          title: 'Second pending',
          startsAt: DateTime(2030, 6, 12, 18),
          location: 'Stadium C',
        ),
      );

      final submitted = await repository.submitPaymentForLatestPending(
        2111,
        bookingId: second.booking.id,
        note: 'proof for second',
      );
      expect(submitted, isNotNull);
      expect(submitted!.id, second.booking.id);
      expect(submitted.status, BookingStatus.paymentSubmitted);

      final rejected = await repository.submitPaymentForLatestPending(
        2111,
        bookingId: first.booking.id,
      );
      expect(rejected, isNotNull);
      expect(rejected!.id, first.booking.id);

      final noMatch = await repository.submitPaymentForLatestPending(
        2111,
        bookingId: 999999,
      );
      expect(noMatch, isNull);

      await repository.close();
    });

    test('returns pending bookings for reminder and marks reminder sent', () async {
      final now = DateTime(2030, 6, 1, 12, 0);
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => now,
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 3001,
        training: TrainingInfo(
          title: 'Strength',
          startsAt: DateTime(2030, 6, 12, 18),
          location: 'Gym C',
        ),
      );

      final reminders = await repository.listPendingPaymentForReminder(
        createdBefore: now.add(const Duration(minutes: 1)),
        remindedBefore: now.add(const Duration(minutes: 1)),
      );
      expect(reminders, hasLength(1));
      expect(reminders.single.id, created.booking.id);

      await repository.markReminderSent(created.booking.id);

      final afterMark = await repository.listPendingPaymentForReminder(
        createdBefore: now.add(const Duration(minutes: 1)),
        remindedBefore: now.subtract(const Duration(minutes: 1)),
      );
      expect(afterMark, isEmpty);

      await repository.close();
    });

    test('reschedules user booking and preserves payment status', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final initial = await repository.createPendingBooking(
        userId: 5001,
        training: TrainingInfo(
          title: 'Initial session',
          startsAt: DateTime(2030, 6, 12, 18),
          location: 'Gym A',
        ),
      );
      await repository.updateStatus(initial.booking.id, BookingStatus.paid);

      final result = await repository.rescheduleBooking(
        userId: 5001,
        bookingId: initial.booking.id,
        training: TrainingInfo(
          title: 'Moved session',
          startsAt: DateTime(2030, 6, 15, 18),
          location: 'Gym B',
        ),
      );

      expect(result.outcome, BookingRescheduleOutcome.success);
      expect(result.booking, isNotNull);
      expect(result.booking!.id, initial.booking.id);
      expect(result.booking!.trainingTitle, 'Moved session');
      expect(result.booking!.location, 'Gym B');
      expect(result.booking!.status, BookingStatus.paid);

      await repository.close();
    });

    test('reviews payment only from submitted status', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 5201,
        training: TrainingInfo(
          title: 'Review target',
          startsAt: DateTime(2030, 6, 18, 19),
          location: 'Gym',
        ),
      );
      final invalidBefore = await repository.reviewSubmittedPayment(
        bookingId: created.booking.id,
        status: BookingStatus.paid,
      );
      expect(invalidBefore.outcome, PaymentReviewOutcome.invalidStatus);

      await repository.submitPaymentForLatestPending(5201, bookingId: created.booking.id);
      final approved = await repository.reviewSubmittedPayment(
        bookingId: created.booking.id,
        status: BookingStatus.paid,
      );
      expect(approved.outcome, PaymentReviewOutcome.success);
      expect(approved.booking, isNotNull);
      expect(approved.booking!.status, BookingStatus.paid);

      final invalidAfter = await repository.reviewSubmittedPayment(
        bookingId: created.booking.id,
        status: BookingStatus.paymentRejected,
      );
      expect(invalidAfter.outcome, PaymentReviewOutcome.invalidStatus);

      await repository.close();
    });

    test('returns conflict when rescheduling to already booked slot', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final first = await repository.createPendingBooking(
        userId: 5002,
        training: TrainingInfo(
          title: 'Session A',
          startsAt: DateTime(2030, 6, 12, 18),
          location: 'Gym A',
        ),
      );
      final second = await repository.createPendingBooking(
        userId: 5002,
        training: TrainingInfo(
          title: 'Session B',
          startsAt: DateTime(2030, 6, 13, 18),
          location: 'Gym B',
        ),
      );

      final result = await repository.rescheduleBooking(
        userId: 5002,
        bookingId: first.booking.id,
        training: TrainingInfo(
          title: second.booking.trainingTitle,
          startsAt: second.booking.startsAt,
          location: second.booking.location,
        ),
      );

      expect(result.outcome, BookingRescheduleOutcome.conflict);

      await repository.close();
    });

    test('cancels only booking owner records', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 5003,
        training: TrainingInfo(
          title: 'Cancelable',
          startsAt: DateTime(2030, 6, 20, 18),
          location: 'Gym',
        ),
      );

      final denied = await repository.cancelBooking(
        userId: 5004,
        bookingId: created.booking.id,
      );
      expect(denied.outcome, BookingActionOutcome.notFound);

      final success = await repository.cancelBooking(
        userId: 5003,
        bookingId: created.booking.id,
      );
      expect(success.outcome, BookingActionOutcome.success);
      expect(success.booking?.status, BookingStatus.cancelled);

      await repository.close();
    });

    test('builds every-fifth reward progress from paid past trainings', () async {
      final now = DateTime(2030, 6, 20, 12);
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => now,
      );
      await repository.init();
      for (var i = 0; i < 4; i++) {
        final created = await repository.createPendingBooking(
          userId: 5101,
          training: TrainingInfo(
            title: 'Session $i',
            startsAt: DateTime(2030, 6, 10 + i, 18),
            location: 'Gym A',
          ),
        );
        await repository.updateStatus(created.booking.id, BookingStatus.paid);
      }
      final freeCreated = await repository.createPendingBooking(
        userId: 5101,
        training: TrainingInfo(
          title: 'Free reward',
          startsAt: DateTime(2030, 6, 15, 18),
          location: 'Gym A',
        ),
      );
      await repository.updateStatus(
        freeCreated.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
      );

      final progress = await repository.getEveryFifthRewardProgress(5101, now: now);
      expect(progress.qualifiedTrainingsCount, 4);
      expect(progress.usedRewardsCount, 1);
      expect(progress.earnedRewardsCount, 1);
      expect(progress.availableRewardsCount, 0);

      await repository.close();
    });

    test('creates independent admin bookings for different usernames', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Admin shared event',
        startsAt: DateTime(2030, 6, 30, 19),
        location: 'Gym A',
      );
      final first = await repository.adminCreateBooking(
        userUsername: 'alpha_user',
        training: training,
        status: BookingStatus.pendingPayment,
      );
      final second = await repository.adminCreateBooking(
        userUsername: 'beta_user',
        training: training,
        status: BookingStatus.pendingPayment,
      );

      expect(first.id, isNot(second.id));
      final bookings = await repository.adminListBookings(
        category: training.category,
        archived: false,
        limit: 50,
      );
      expect(
        bookings.where((item) => item.trainingKey == training.sessionKey).length,
        2,
      );

      await repository.close();
    });
  });
}
