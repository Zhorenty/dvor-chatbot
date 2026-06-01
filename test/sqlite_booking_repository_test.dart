import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
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
        training: training,
      );
      final second = await repository.createPendingBooking(
        userId: 1001,
        training: training,
      );

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(first.booking.id, second.booking.id);

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
  });
}
