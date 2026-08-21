import 'dart:io';

import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_participant.dart';
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
        nowProvider: () => DateTime(2030, 7, 1, 12),
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

    test('snapshots training map url onto created booking', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime(2030, 7, 1, 12),
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 1002,
        training: TrainingInfo(
          title: 'Morning run',
          startsAt: DateTime(2030, 8, 22, 8, 30),
          location: 'Surf Coffee x Riverside',
          locationUrl: 'https://yandex.ru/maps/org/surf_coffee/123',
        ),
      );

      expect(created.created, isTrue);
      expect(created.booking.location, 'Surf Coffee x Riverside');
      expect(created.booking.locationUrl, 'https://yandex.ru/maps/org/surf_coffee/123');

      await repository.close();
    });

    test('refreshes username on repeated booking for same user and training', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Username refresh',
        startsAt: DateTime(2030, 6, 10, 20),
        location: 'Gym A',
      );

      final first = await repository.createPendingBooking(
        userId: 1009,
        userUsername: '@old_name',
        training: training,
      );
      final second = await repository.createPendingBooking(
        userId: 1009,
        userUsername: '@new_name',
        training: training,
      );

      expect(first.booking.id, second.booking.id);
      expect(second.created, isFalse);
      expect(second.booking.userUsername, 'new_name');

      await repository.close();
    });

    test('throws when participants limit is reached for another user', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Limited session',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        participantsLimit: 1,
      );

      await repository.createPendingBooking(
        userId: 1001,
        userUsername: '@runner_1001',
        training: training,
      );

      expect(
        () => repository.createPendingBooking(
          userId: 1002,
          userUsername: '@runner_1002',
          training: training,
        ),
        throwsA(isA<BookingParticipantsLimitExceededException>()),
      );

      await repository.close();
    });

    test('does not count whitelisted trainers in participants limit by default', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Limited session',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        participantsLimit: 1,
      );

      await repository.createPendingBooking(
        userId: 99001,
        userUsername: '@whatshapped',
        training: training,
      );

      final second = await repository.createPendingBooking(
        userId: 1002,
        userUsername: '@runner_1002',
        training: training,
      );

      expect(second.created, isTrue);

      await repository.close();
    });

    test('counts whitelisted trainers in participants limit when enabled', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Limited session',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        participantsLimit: 1,
        includeTrainersInParticipants: true,
      );

      await repository.createPendingBooking(
        userId: 99001,
        userUsername: '@zhorenty',
        training: training,
      );

      expect(
        () => repository.createPendingBooking(
          userId: 1002,
          userUsername: '@runner_1002',
          training: training,
        ),
        throwsA(isA<BookingParticipantsLimitExceededException>()),
      );

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

    test('prioritizes active bookings over archived records in user list', () async {
      final now = DateTime(2030, 6, 15, 12, 0);
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => now,
      );
      await repository.init();

      for (var i = 0; i < 12; i++) {
        final archived = await repository.createPendingBooking(
          userId: 4110,
          training: TrainingInfo(
            title: 'Archived #$i',
            startsAt: now.subtract(Duration(days: 30 - i)),
            location: 'Old track',
          ),
        );
        await repository.updateStatus(archived.booking.id, BookingStatus.cancelled);
      }

      final upcoming = await repository.createPendingBooking(
        userId: 4110,
        training: TrainingInfo(
          title: 'Upcoming payment target',
          startsAt: now.add(const Duration(days: 4)),
          location: 'New track',
        ),
      );

      final listed = await repository.listUserBookings(4110, limit: 10);

      expect(listed, hasLength(10));
      expect(listed.first.id, upcoming.booking.id);
      expect(listed.first.status, BookingStatus.pendingPayment);
      expect(listed.where((item) => item.id == upcoming.booking.id), hasLength(1));

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

    test('does not fall back to another pending booking when pinned id is stale', () async {
      // In-memory flow may hold a cancelled activeBooking.id while another
      // pending booking exists. Attaching the receipt to the wrong event is worse
      // than asking the user to pick again.
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final stale = await repository.createPendingBooking(
        userId: 3301,
        training: TrainingInfo(
          title: 'Stale booking',
          startsAt: DateTime(2030, 7, 1, 10),
          location: 'Track A',
        ),
      );
      await repository.updateStatus(stale.booking.id, BookingStatus.cancelled);

      final active = await repository.createPendingBooking(
        userId: 3301,
        training: TrainingInfo(
          title: 'Active booking',
          startsAt: DateTime(2030, 7, 2, 10),
          location: 'Track B',
        ),
      );

      final submitted = await repository.submitPaymentForLatestPending(
        3301,
        bookingId: stale.booking.id,
        note: 'proof',
      );

      expect(submitted, isNull);
      final listed = await repository.listUserBookings(3301, limit: 10);
      expect(
        listed.firstWhere((b) => b.id == active.booking.id).status,
        BookingStatus.pendingPayment,
      );

      await repository.close();
    });

    test('does not submit payment for partial paid booking id', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 2122,
        training: TrainingInfo(
          title: 'Trail top-up',
          startsAt: DateTime(2030, 6, 20, 8),
          location: 'Mountain',
        ),
      );
      await repository.updateStatus(created.booking.id, BookingStatus.partialPaid);

      final submitted = await repository.submitPaymentForLatestPending(
        2122,
        bookingId: created.booking.id,
        note: 'final payment proof',
      );

      expect(submitted, isNull);

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
        remindedBefore: now.add(const Duration(days: 1)),
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

    test('blocks reschedule from free-priced booking to paid training', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final initial = await repository.createPendingBooking(
        userId: 5005,
        training: TrainingInfo(
          title: 'Open class',
          startsAt: DateTime(2030, 6, 16, 18),
          location: 'Gym C',
          price: 0,
        ),
      );
      await repository.updateStatus(initial.booking.id, BookingStatus.paid);

      final result = await repository.rescheduleBooking(
        userId: 5005,
        bookingId: initial.booking.id,
        training: TrainingInfo(
          title: 'Paid class',
          startsAt: DateTime(2030, 6, 20, 18),
          location: 'Gym D',
          price: 2200,
        ),
      );

      expect(result.outcome, BookingRescheduleOutcome.conflict);

      await repository.close();
    });

    test('blocks reschedule from paid booking to free training', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final initial = await repository.createPendingBooking(
        userId: 5006,
        training: TrainingInfo(
          title: 'Paid class',
          startsAt: DateTime(2030, 6, 16, 18),
          location: 'Gym E',
          price: 2200,
        ),
      );
      await repository.updateStatus(initial.booking.id, BookingStatus.paid);

      final result = await repository.rescheduleBooking(
        userId: 5006,
        bookingId: initial.booking.id,
        training: TrainingInfo(
          title: 'Open class',
          startsAt: DateTime(2030, 6, 20, 18),
          location: 'Gym F',
          price: 0,
        ),
      );

      expect(result.outcome, BookingRescheduleOutcome.conflict);

      await repository.close();
    });

    test('blocks reschedule between paid trainings with different price', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final initial = await repository.createPendingBooking(
        userId: 5007,
        training: TrainingInfo(
          title: 'Paid class',
          startsAt: DateTime(2030, 6, 16, 18),
          location: 'Gym E',
          price: 2200,
        ),
      );
      await repository.updateStatus(initial.booking.id, BookingStatus.paid);

      final result = await repository.rescheduleBooking(
        userId: 5007,
        bookingId: initial.booking.id,
        training: TrainingInfo(
          title: 'Another paid class',
          startsAt: DateTime(2030, 6, 20, 18),
          location: 'Gym F',
          price: 2800,
        ),
      );

      expect(result.outcome, BookingRescheduleOutcome.conflict);

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

    test('keeps paymentRejected status and allows proof resubmit', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 5210,
        training: TrainingInfo(
          title: 'Reject then resubmit',
          startsAt: DateTime(2030, 6, 19, 19),
          location: 'Gym',
        ),
      );
      await repository.submitPaymentForLatestPending(5210, bookingId: created.booking.id);
      final rejected = await repository.reviewSubmittedPayment(
        bookingId: created.booking.id,
        status: BookingStatus.paymentRejected,
      );
      expect(rejected.outcome, PaymentReviewOutcome.success);
      expect(rejected.booking, isNotNull);
      expect(rejected.booking!.status, BookingStatus.paymentRejected);

      final resubmitted = await repository.submitPaymentForLatestPending(
        5210,
        bookingId: created.booking.id,
        note: 'new proof',
      );
      expect(resubmitted, isNotNull);
      expect(resubmitted!.status, BookingStatus.paymentSubmitted);
      expect(resubmitted.paymentNote, 'new proof');

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
            price: 1200,
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
          price: 1200,
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

    test('excludes free trainings from every-fifth reward progress', () async {
      final now = DateTime(2030, 6, 20, 12);
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => now,
      );
      await repository.init();

      final paid = await repository.createPendingBooking(
        userId: 5102,
        training: TrainingInfo(
          title: 'Paid session',
          startsAt: DateTime(2030, 6, 10, 18),
          location: 'Gym A',
          price: 1200,
        ),
      );
      await repository.updateStatus(paid.booking.id, BookingStatus.paid);

      final freeByPrice = await repository.createPendingBooking(
        userId: 5102,
        training: TrainingInfo(
          title: 'Free by price',
          startsAt: DateTime(2030, 6, 11, 18),
          location: 'Gym A',
          price: 0,
        ),
      );
      await repository.updateStatus(freeByPrice.booking.id, BookingStatus.paid);

      final starterBonus = await repository.createPendingBooking(
        userId: 5102,
        training: TrainingInfo(
          title: 'Starter bonus',
          startsAt: DateTime(2030, 6, 12, 18),
          location: 'Gym A',
          price: 1200,
        ),
      );
      await repository.updateStatus(
        starterBonus.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
      );

      final referralBonus = await repository.createPendingBooking(
        userId: 5102,
        training: TrainingInfo(
          title: 'Referral bonus',
          startsAt: DateTime(2030, 6, 13, 18),
          location: 'Gym A',
          price: 1200,
        ),
      );
      await repository.updateStatus(
        referralBonus.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.referralBonusPaymentNoteMarker,
      );

      final proIncluded = await repository.createPendingBooking(
        userId: 5102,
        training: TrainingInfo(
          title: 'PRO included',
          startsAt: DateTime(2030, 6, 14, 18),
          location: 'Gym A',
          price: 1200,
        ),
      );
      await repository.updateStatus(
        proIncluded.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
      );

      final progress = await repository.getEveryFifthRewardProgress(5102, now: now);
      expect(progress.qualifiedTrainingsCount, 1);
      expect(progress.usedRewardsCount, 0);
      expect(progress.availableRewardsCount, 0);

      await repository.close();
    });

    test('builds referral reward progress from successful invited users', () async {
      final now = DateTime(2030, 6, 20, 12);
      final dbPath = '${tmpDir.path}/bookings.sqlite';
      final repository = SqliteBookingRepository(
        dbPath: dbPath,
        nowProvider: () => now,
      );
      final onboardingRepository = SqliteOnboardingRepository(dbPath: dbPath);
      await repository.init();
      await onboardingRepository.init();

      await onboardingRepository.registerReferralAttribution(
        inviteeUserId: 6202,
        inviterUserId: 6201,
        attributedAt: now.subtract(const Duration(days: 10)),
      );
      await onboardingRepository.registerReferralAttribution(
        inviteeUserId: 6203,
        inviterUserId: 6201,
        attributedAt: now.subtract(const Duration(days: 9)),
      );

      final inviteeCompleted = await repository.createPendingBooking(
        userId: 6202,
        training: TrainingInfo(
          title: 'Invitee completed',
          startsAt: DateTime(2030, 6, 10, 18),
          location: 'Gym A',
          price: 1200,
        ),
      );
      await repository.updateStatus(inviteeCompleted.booking.id, BookingStatus.paid);

      final inviterUsed = await repository.createPendingBooking(
        userId: 6201,
        training: TrainingInfo(
          title: 'Inviter bonus usage',
          startsAt: DateTime(2030, 6, 12, 18),
          location: 'Gym A',
        ),
      );
      await repository.updateStatus(
        inviterUsed.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.referralBonusPaymentNoteMarker,
      );

      final progress = await repository.getReferralRewardProgress(6201, now: now);
      expect(progress.qualifiedReferralsCount, 1);
      expect(progress.usedRewardsCount, 1);
      expect(progress.availableRewardsCount, 0);

      await onboardingRepository.close();
      await repository.close();
    });

    test('does not count free or bonus invitee trainings for referral progress', () async {
      final now = DateTime(2030, 6, 20, 12);
      final dbPath = '${tmpDir.path}/bookings.sqlite';
      final repository = SqliteBookingRepository(
        dbPath: dbPath,
        nowProvider: () => now,
      );
      final onboardingRepository = SqliteOnboardingRepository(dbPath: dbPath);
      await repository.init();
      await onboardingRepository.init();

      await onboardingRepository.registerReferralAttribution(
        inviteeUserId: 6302,
        inviterUserId: 6301,
        attributedAt: now.subtract(const Duration(days: 10)),
      );
      await onboardingRepository.registerReferralAttribution(
        inviteeUserId: 6303,
        inviterUserId: 6301,
        attributedAt: now.subtract(const Duration(days: 10)),
      );

      final freeInvitee = await repository.createPendingBooking(
        userId: 6302,
        training: TrainingInfo(
          title: 'Invitee free by price',
          startsAt: DateTime(2030, 6, 10, 18),
          location: 'Gym A',
          price: 0,
        ),
      );
      await repository.updateStatus(freeInvitee.booking.id, BookingStatus.paid);

      final bonusInvitee = await repository.createPendingBooking(
        userId: 6303,
        training: TrainingInfo(
          title: 'Invitee bonus',
          startsAt: DateTime(2030, 6, 11, 18),
          location: 'Gym A',
          price: 1200,
        ),
      );
      await repository.updateStatus(
        bonusInvitee.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
      );

      final progress = await repository.getReferralRewardProgress(6301, now: now);
      expect(progress.qualifiedReferralsCount, 0);
      expect(progress.availableRewardsCount, 0);

      await onboardingRepository.close();
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

    test('admin username edit reassigns booking owner and frees old user slot', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final targetTraining = TrainingInfo(
        title: 'Shared event',
        startsAt: DateTime(2030, 7, 1, 19),
        location: 'Gym A',
      );
      final warmupTraining = TrainingInfo(
        title: 'Warmup',
        startsAt: DateTime(2030, 7, 2, 19),
        location: 'Gym A',
      );
      final source = await repository.createPendingBooking(
        userId: 7101,
        userUsername: 'user_a',
        training: targetTraining,
      );
      await repository.createPendingBooking(
        userId: 7102,
        userUsername: 'user_b',
        training: warmupTraining,
      );

      final updated = await repository.adminUpdateBooking(
        bookingId: source.booking.id,
        userUsername: 'user_b',
      );

      expect(updated, isNotNull);
      expect(updated!.userId, 7102);
      expect(updated.userUsername, 'user_b');

      final retryBySource = await repository.createPendingBooking(
        userId: 7101,
        userUsername: 'user_a',
        training: targetTraining,
      );
      expect(retryBySource.created, isTrue);
      expect(retryBySource.booking.id, isNot(source.booking.id));

      final retryByTarget = await repository.createPendingBooking(
        userId: 7102,
        userUsername: 'user_b',
        training: targetTraining,
      );
      expect(retryByTarget.created, isFalse);
      expect(retryByTarget.booking.id, updated.id);

      await repository.close();
    });

    test('admin create by username links booking to known real user', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final knownUserWarmup = TrainingInfo(
        title: 'Known user warmup',
        startsAt: DateTime(2030, 7, 5, 19),
        location: 'Gym B',
      );
      final adminTargetTraining = TrainingInfo(
        title: 'Known user target',
        startsAt: DateTime(2030, 7, 6, 19),
        location: 'Gym B',
      );
      await repository.createPendingBooking(
        userId: 7201,
        userUsername: 'known_runner',
        training: knownUserWarmup,
      );

      final created = await repository.adminCreateBooking(
        userUsername: 'known_runner',
        training: adminTargetTraining,
        status: BookingStatus.pendingPayment,
      );

      expect(created.userId, 7201);
      final byKnownUser = await repository.listUserBookings(7201, limit: 20);
      expect(byKnownUser.any((item) => item.id == created.id), isTrue);

      final duplicate = await repository.createPendingBooking(
        userId: 7201,
        userUsername: 'known_runner',
        training: adminTargetTraining,
      );
      expect(duplicate.created, isFalse);
      expect(duplicate.booking.id, created.id);

      await repository.close();
    });

    test('adopts synthetic admin booking when real user books same training', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Synthetic prebooking',
        startsAt: DateTime(2030, 7, 7, 19),
        location: 'Gym C',
      );
      final adminCreated = await repository.adminCreateBooking(
        userUsername: 'legacy_user',
        training: training,
        status: BookingStatus.pendingPayment,
      );
      expect(adminCreated.userId, lessThan(0));

      final userAttempt = await repository.createPendingBooking(
        userId: 7301,
        userUsername: 'legacy_user',
        training: training,
      );
      expect(userAttempt.created, isFalse);
      expect(userAttempt.booking.id, adminCreated.id);
      expect(userAttempt.booking.userId, 7301);
      expect(userAttempt.booking.userUsername, 'legacy_user');

      final userBookings = await repository.listUserBookings(7301, limit: 20);
      expect(userBookings.any((item) => item.id == adminCreated.id), isTrue);

      await repository.close();
    });

    test('admin update rejects free status for paid training', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.adminCreateBooking(
        userUsername: 'status_guard',
        training: TrainingInfo(
          title: 'Admin edit base',
          startsAt: DateTime(2030, 7, 2, 19),
          location: 'Gym A',
          price: 0,
        ),
        status: BookingStatus.freeTraining,
      );

      expect(
        () => repository.adminUpdateBooking(
          bookingId: created.id,
          training: TrainingInfo(
            title: 'Admin edit paid',
            startsAt: DateTime(2030, 7, 3, 19),
            location: 'Gym B',
            price: 2600,
          ),
        ),
        throwsA(isA<BookingConflictException>()),
      );

      await repository.close();
    });

    test('admin restore resets pending-payment lifecycle fields', () async {
      var now = DateTime(2030, 7, 2, 10, 0);
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => now,
      );
      await repository.init();

      final created = await repository.createPendingBooking(
        userId: 9101,
        userUsername: 'restore_case',
        training: TrainingInfo(
          title: 'Restore flow',
          startsAt: DateTime(2030, 7, 20, 19),
          location: 'Gym Restore',
        ),
      );
      final submitted = await repository.submitPaymentForLatestPending(
        9101,
        bookingId: created.booking.id,
        note: 'paid screenshot',
      );
      expect(submitted, isNotNull);
      await repository.updateStatus(created.booking.id, BookingStatus.cancelled);

      now = DateTime(2030, 7, 2, 15, 0);
      final restored = await repository.adminUpdateBooking(
        bookingId: created.booking.id,
        status: BookingStatus.pendingPayment,
      );
      expect(restored, isNotNull);
      expect(restored!.status, BookingStatus.pendingPayment);
      expect(restored.paymentNote, isNull);

      final userBookings = await repository.listUserBookings(9101, limit: 10);
      final restoredFromList = userBookings.firstWhere((item) => item.id == created.booking.id);
      expect(restoredFromList.status, BookingStatus.pendingPayment);

      await repository.close();
    });

    test(
        'stores training price, includes free-training and partial-paid statuses in summary range and marks report once',
        () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime(2030, 7, 1, 12),
      );
      await repository.init();
      final created = await repository.createPendingBooking(
        userId: 6001,
        training: TrainingInfo(
          title: 'Price check',
          startsAt: DateTime(2030, 7, 1, 19),
          location: 'Gym',
          price: 1700,
        ),
      );
      await repository.updateStatus(created.booking.id, BookingStatus.paid);
      final freeCreated = await repository.createPendingBooking(
        userId: 6002,
        training: TrainingInfo(
          title: 'Price check free',
          startsAt: DateTime(2030, 7, 2, 19),
          location: 'Gym',
          price: 1700,
        ),
      );
      await repository.updateStatus(freeCreated.booking.id, BookingStatus.freeTraining);
      final partialCreated = await repository.createPendingBooking(
        userId: 6003,
        training: TrainingInfo(
          title: 'Price check partial',
          startsAt: DateTime(2030, 7, 3, 19),
          location: 'Gym',
          price: 1700,
        ),
      );
      await repository.updateStatus(partialCreated.booking.id, BookingStatus.partialPaid);

      final paid = await repository.listPaidBookingsInRange(
        fromInclusive: DateTime(2030, 6, 1),
        toExclusive: DateTime(2030, 8, 1),
      );
      expect(paid, hasLength(3));
      expect(paid.any((item) => item.status == BookingStatus.paid), isTrue);
      expect(paid.any((item) => item.status == BookingStatus.freeTraining), isTrue);
      expect(paid.any((item) => item.status == BookingStatus.partialPaid), isTrue);
      expect(paid.firstWhere((item) => item.status == BookingStatus.paid).trainingPrice, 1700);

      final firstMark = await repository.tryMarkEconomicReportSent(
        reportType: 'weekly',
        periodStart: DateTime(2030, 6, 24),
        periodEnd: DateTime(2030, 7, 1),
        sentAt: DateTime(2030, 7, 1, 9),
      );
      final duplicateMark = await repository.tryMarkEconomicReportSent(
        reportType: 'weekly',
        periodStart: DateTime(2030, 6, 24),
        periodEnd: DateTime(2030, 7, 1),
        sentAt: DateTime(2030, 7, 1, 10),
      );
      expect(firstMark, isTrue);
      expect(duplicateMark, isFalse);

      await repository.rollbackEconomicReportSent(
        reportType: 'weekly',
        periodStart: DateTime(2030, 6, 24),
        periodEnd: DateTime(2030, 7, 1),
      );
      final markAfterRollback = await repository.tryMarkEconomicReportSent(
        reportType: 'weekly',
        periodStart: DateTime(2030, 6, 24),
        periodEnd: DateTime(2030, 7, 1),
        sentAt: DateTime(2030, 7, 1, 11),
      );
      expect(markAfterRollback, isTrue);

      await repository.close();
    });

    test('admin can set freeTraining status on paid activity (status-only update)', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.adminCreateBooking(
        userUsername: 'trainer_free',
        training: TrainingInfo(
          title: 'Paid training',
          startsAt: DateTime(2030, 8, 1, 19),
          location: 'Hall A',
          price: 1800,
        ),
        status: BookingStatus.pendingPayment,
      );

      final updated = await repository.adminUpdateBooking(
        bookingId: created.id,
        status: BookingStatus.freeTraining,
      );

      expect(updated, isNotNull);
      expect(updated!.status, BookingStatus.freeTraining);
      expect(updated.trainingPrice, 1800);

      await repository.close();
    });

    test('admin update blocks moving freeTraining booking to paid activity', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final created = await repository.adminCreateBooking(
        userUsername: 'trainer_move',
        training: TrainingInfo(
          title: 'Free activity',
          startsAt: DateTime(2030, 8, 2, 19),
          location: 'Outdoors',
          price: 0,
        ),
        status: BookingStatus.freeTraining,
      );

      expect(
        () => repository.adminUpdateBooking(
          bookingId: created.id,
          training: TrainingInfo(
            title: 'Paid event',
            startsAt: DateTime(2030, 8, 3, 19),
            location: 'Hall B',
            price: 2600,
          ),
        ),
        throwsA(isA<BookingConflictException>()),
      );

      await repository.close();
    });

    test('applyPromoCode discounts price and keeps status for partial discount', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Functional',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        price: 1500,
      );
      final created = await repository.createPendingBooking(
        userId: 2001,
        training: training,
      );

      final updated = await repository.applyPromoCode(
        bookingId: created.booking.id,
        code: 'SUMMER50',
        discountPercent: 50,
        discountedPrice: 750,
      );

      expect(updated, isNotNull);
      expect(updated!.trainingPrice, 750);
      expect(updated.promoCode, 'SUMMER50');
      expect(updated.promoDiscountPercent, 50);
      expect(updated.status, BookingStatus.pendingPayment);

      await repository.close();
    });

    test('applyPromoCode marks booking as paid for full discount', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Functional',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        price: 1500,
      );
      final created = await repository.createPendingBooking(
        userId: 2002,
        training: training,
      );

      final updated = await repository.applyPromoCode(
        bookingId: created.booking.id,
        code: 'FREEDAY',
        discountPercent: 100,
        discountedPrice: 0,
      );

      expect(updated, isNotNull);
      expect(updated!.trainingPrice, 0);
      expect(updated.promoCode, 'FREEDAY');
      expect(updated.promoDiscountPercent, 100);
      expect(updated.status, BookingStatus.paid);

      await repository.close();
    });

    test('creates managed booking group for friend and guest with shared payment group', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime(2030, 7, 1, 12),
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Functional',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        price: 1500,
        participantsLimit: 10,
      );

      final group = await repository.createPendingBookingGroup(
        managerUserId: 3001,
        managerUsername: 'organizer',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.telegram(username: 'friend_one'),
          BookingParticipantDraft.guest(name: 'Бабушка Мария'),
        ],
      );

      expect(group.bookings, hasLength(2));
      expect(group.totalPrice, 3000);
      expect(group.bookings.every((b) => b.paymentGroupId == group.paymentGroupId), isTrue);
      expect(group.bookings.every((b) => b.managerUserId == 3001), isTrue);
      expect(group.bookings[0].participantType, BookingParticipantType.telegram);
      expect(group.bookings[1].participantType, BookingParticipantType.guest);

      final listed = await repository.listUserBookings(3001);
      expect(listed.where((b) => b.paymentGroupId == group.paymentGroupId), hasLength(2));

      final submitted = await repository.submitPaymentForLatestPending(
        3001,
        bookingId: group.bookings.first.id,
        note: 'group pay',
      );
      expect(submitted, isNotNull);
      final afterSubmit = await repository.listBookingsByPaymentGroup(group.paymentGroupId);
      expect(
        afterSubmit.every((b) => b.status == BookingStatus.paymentSubmitted),
        isTrue,
      );

      final reviewed = await repository.reviewSubmittedPayment(
        bookingId: group.bookings.first.id,
        status: BookingStatus.paid,
      );
      expect(reviewed.outcome, PaymentReviewOutcome.success);
      final afterReview = await repository.listBookingsByPaymentGroup(group.paymentGroupId);
      expect(afterReview.every((b) => b.status == BookingStatus.paid), isTrue);

      await repository.close();
    });

    test('rejects duplicate friend in managed booking group', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Functional',
        startsAt: DateTime(2030, 6, 10, 19),
        location: 'Gym A',
        price: 1500,
      );

      await repository.createPendingBooking(
        userId: 4002,
        userUsername: 'already_booked',
        training: training,
      );

      expect(
        () => repository.createPendingBookingGroup(
          managerUserId: 4001,
          managerUsername: 'organizer',
          training: training,
          participants: const <BookingParticipantDraft>[
            BookingParticipantDraft.telegram(username: 'already_booked'),
          ],
        ),
        throwsA(isA<BookingParticipantConflictException>()),
      );

      await repository.close();
    });

    test('allows manager self-booking after creating friend seats on same event', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime(2030, 7, 1, 12),
      );
      await repository.init();

      final training = TrainingInfo(
        title: '🥾 Поход: Архыз',
        startsAt: DateTime(2030, 8, 8),
        location: 'Архыз',
        category: ActivityCategory.hikes,
        price: 4700,
        participantsLimit: 20,
        includeTrainersInParticipants: true,
      );

      final group = await repository.createPendingBookingGroup(
        managerUserId: 5101,
        managerUsername: 'katya',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.telegram(username: 'nikita_medvedev'),
          BookingParticipantDraft.guest(name: 'Третий Человек'),
        ],
      );
      expect(group.bookings, hasLength(2));

      final selfBooking = await repository.createPendingBooking(
        userId: 5101,
        userUsername: 'katya',
        training: training,
      );
      expect(selfBooking.created, isTrue);
      expect(selfBooking.booking.participantType, BookingParticipantType.self);
      expect(selfBooking.booking.id, isNot(group.bookings.first.id));

      final listed = await repository.listUserBookings(5101, limit: 20);
      expect(listed.where((b) => b.trainingKey == training.sessionKey), hasLength(3));

      await repository.close();
    });

    test('allows status-only admin update for sibling party bookings', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime(2030, 7, 1, 12),
      );
      await repository.init();

      final training = TrainingInfo(
        title: '🥾 Поход: Архыз',
        startsAt: DateTime(2030, 8, 8),
        location: 'Архыз',
        category: ActivityCategory.hikes,
        price: 4700,
        includeTrainersInParticipants: true,
      );
      final group = await repository.createPendingBookingGroup(
        managerUserId: 5201,
        managerUsername: 'katya',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.guest(name: 'Никита Медведев'),
          BookingParticipantDraft.guest(name: 'Третий Человек'),
        ],
      );

      final updated = await repository.adminUpdateBooking(
        bookingId: group.bookings.last.id,
        status: BookingStatus.partialPaid,
      );
      expect(updated, isNotNull);
      expect(updated!.status, BookingStatus.partialPaid);
      expect(group.bookings.first.status, BookingStatus.pendingPayment);

      final found = await repository.adminSearchBookingsByUsername('Третий Человек');
      expect(found.map((b) => b.id), contains(group.bookings.last.id));

      await repository.close();
    });

    test('reactivated booking gets a fresh payment TTL window', () async {
      var now = DateTime.utc(2030, 6, 1, 12);
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => now,
        pendingPaymentTtl: const Duration(minutes: 30),
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Trail',
        startsAt: DateTime(2030, 7, 1, 10),
        location: 'Forest',
        price: 2000,
      );
      final first = await repository.createPendingBooking(
        userId: 6101,
        userUsername: 'runner',
        training: training,
      );
      final originalCreatedAt = first.booking.createdAt;

      now = now.add(const Duration(minutes: 31));
      final expired = await repository.expirePendingPaymentBookings(
        createdBefore: now,
        limit: 10,
      );
      expect(expired.map((b) => b.id), contains(first.booking.id));

      now = now.add(const Duration(minutes: 5));
      final second = await repository.createPendingBooking(
        userId: 6101,
        userUsername: 'runner',
        training: training,
      );
      expect(second.created, isTrue);
      expect(second.booking.id, first.booking.id);
      expect(second.booking.createdAt.isAfter(originalCreatedAt), isTrue);

      now = now.add(const Duration(minutes: 10));
      final stillAlive = await repository.expirePendingPaymentBookings(
        createdBefore: now.subtract(const Duration(minutes: 30)),
        limit: 10,
      );
      expect(stillAlive, isEmpty);

      await repository.close();
    });

    test('cancels and expires whole payment group together', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime.utc(2030, 6, 1, 12),
        pendingPaymentTtl: const Duration(minutes: 30),
      );
      await repository.init();

      final training = TrainingInfo(
        title: '🥾 Поход: Группа',
        startsAt: DateTime(2030, 8, 1),
        location: 'Горы',
        category: ActivityCategory.hikes,
        price: 4000,
      );
      final group = await repository.createPendingBookingGroup(
        managerUserId: 6201,
        managerUsername: 'manager',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.telegram(username: 'friend_alpha'),
          BookingParticipantDraft.guest(name: 'Гость Один'),
        ],
      );

      final cancelled = await repository.cancelBooking(
        userId: 6201,
        bookingId: group.bookings.first.id,
      );
      expect(cancelled.outcome, BookingActionOutcome.success);
      final afterCancel = await repository.listBookingsByPaymentGroup(group.paymentGroupId);
      expect(afterCancel.every((b) => b.status == BookingStatus.cancelled), isTrue);

      final group2 = await repository.createPendingBookingGroup(
        managerUserId: 6201,
        managerUsername: 'manager',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.telegram(username: 'friend_alpha'),
          BookingParticipantDraft.guest(name: 'Гость Один'),
        ],
      );
      expect(group2.bookings, hasLength(2));

      final expired = await repository.expirePendingPaymentBookings(
        createdBefore: DateTime.utc(2030, 6, 1, 13),
        limit: 20,
      );
      expect(expired, isNotEmpty);
      final afterExpire = await repository.listBookingsByPaymentGroup(group2.paymentGroupId);
      expect(afterExpire.every((b) => b.status == BookingStatus.cancelled), isTrue);

      await repository.close();
    });

    test('rebinds managed telegram friend when the real user books later', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
        nowProvider: () => DateTime.utc(2030, 6, 1, 12),
      );
      await repository.init();

      final training = TrainingInfo(
        title: '🥾 Поход: Ребинд',
        startsAt: DateTime(2030, 8, 1),
        location: 'Горы',
        category: ActivityCategory.hikes,
        price: 4000,
      );
      final group = await repository.createPendingBookingGroup(
        managerUserId: 6301,
        managerUsername: 'manager',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.telegram(username: 'real_friend'),
        ],
      );
      final managedId = group.bookings.single.id;

      final rebound = await repository.createPendingBooking(
        userId: 6399,
        userUsername: 'real_friend',
        training: training,
      );
      expect(rebound.created, isFalse);
      expect(rebound.booking.id, managedId);
      expect(rebound.booking.userId, 6399);
      expect(rebound.booking.participantType, BookingParticipantType.self);
      expect(rebound.booking.managerUserId, 6399);

      await repository.close();
    });

    test('trainer manager party seats still consume participant capacity', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Limited',
        startsAt: DateTime(2030, 7, 1, 19),
        location: 'Hall',
        price: 1000,
        participantsLimit: 2,
        includeTrainersInParticipants: false,
      );

      // Whitelisted trainer username from trainer_booking_whitelist.dart.
      await repository.createPendingBookingGroup(
        managerUserId: 6401,
        managerUsername: 'k_morozzovaa',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.guest(name: 'Друг 1'),
          BookingParticipantDraft.guest(name: 'Друг 2'),
        ],
      );

      expect(
        () => repository.createPendingBooking(
          userId: 6402,
          userUsername: 'regular',
          training: training,
        ),
        throwsA(isA<BookingParticipantsLimitExceededException>()),
      );

      await repository.close();
    });

    test('admin username edit keeps managed guest seat ownership', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final training = TrainingInfo(
        title: 'Managed edit',
        startsAt: DateTime(2030, 7, 1, 19),
        location: 'Hall',
        price: 1000,
      );
      final group = await repository.createPendingBookingGroup(
        managerUserId: 6501,
        managerUsername: 'manager',
        training: training,
        participants: const <BookingParticipantDraft>[
          BookingParticipantDraft.guest(name: 'Старое Имя'),
        ],
      );

      final updated = await repository.adminUpdateBooking(
        bookingId: group.bookings.single.id,
        userUsername: 'Новое Имя',
      );
      expect(updated, isNotNull);
      expect(updated!.managerUserId, 6501);
      expect(updated.userId, 6501);
      expect(updated.participantType, BookingParticipantType.guest);
      expect(updated.participantName, 'Новое Имя');

      await repository.close();
    });

    test('does not attach pinned payment proof to a different pending booking', () async {
      final repository = SqliteBookingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final outdoor = TrainingInfo(
        title: '🥾 Поход: A',
        startsAt: DateTime(2030, 8, 1),
        location: 'A',
        category: ActivityCategory.hikes,
        price: 4000,
      );
      final training = TrainingInfo(
        title: 'Training B',
        startsAt: DateTime(2030, 8, 2, 19),
        location: 'Hall',
        price: 1500,
      );
      final outdoorBooking = await repository.createPendingBooking(
        userId: 6601,
        userUsername: 'payer',
        training: outdoor,
      );
      final other = await repository.createPendingBooking(
        userId: 6601,
        userUsername: 'payer',
        training: training,
      );
      await repository.updateStatus(outdoorBooking.booking.id, BookingStatus.cancelled);

      final submitted = await repository.submitPaymentForLatestPending(
        6601,
        bookingId: outdoorBooking.booking.id,
        note: 'proof for outdoor',
      );
      expect(submitted, isNull);
      final stillPending = await repository.listUserBookings(6601, limit: 10);
      expect(
        stillPending.firstWhere((b) => b.id == other.booking.id).status,
        BookingStatus.pendingPayment,
      );

      await repository.close();
    });
  });
}
