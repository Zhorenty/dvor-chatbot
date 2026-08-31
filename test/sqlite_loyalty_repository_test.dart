import 'dart:io';

import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_loyalty_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late SqliteDatabaseHandle handle;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('dvor-loyalty-sqlite-');
    handle = SqliteDatabaseHandle.open('${tmpDir.path}/app.sqlite');
  });

  tearDown(() async {
    handle.close();
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('migration credits /start 1000 and past paid trainings without duplicating live /start',
      () async {
    final now = DateTime.utc(2026, 6, 1, 12);
    final onboarding = SqliteOnboardingRepository(databaseHandle: handle);
    final bookings = SqliteBookingRepository(
      databaseHandle: handle,
      nowProvider: () => now,
    );
    await bookings.init();
    await onboarding.init();
    await onboarding.ensureStartedUser(7, startedAt: DateTime.utc(2026, 1, 1));

    final paid500 = await bookings.createPendingBooking(
      userId: 7,
      training: TrainingInfo(
        title: 'Силовая',
        startsAt: DateTime.utc(2026, 5, 1, 19),
        location: 'Hall',
        price: 500,
      ),
    );
    await bookings.updateStatus(paid500.booking.id, BookingStatus.paid);

    final paid350 = await bookings.createPendingBooking(
      userId: 7,
      training: TrainingInfo(
        title: 'Бокс',
        startsAt: DateTime.utc(2026, 5, 8, 19),
        location: 'Hall',
        price: 350,
      ),
    );
    await bookings.updateStatus(paid350.booking.id, BookingStatus.paid);

    final fifth = await bookings.createPendingBooking(
      userId: 7,
      training: TrainingInfo(
        title: 'Пятая',
        startsAt: DateTime.utc(2026, 5, 15, 19),
        location: 'Hall',
        price: 500,
      ),
    );
    await bookings.updateStatus(
      fifth.booking.id,
      BookingStatus.paid,
      paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
    );

    final loyalty = SqliteLoyaltyRepository(
      databaseHandle: handle,
      nowProvider: () => now,
    );
    await loyalty.init();
    final service = LoyaltyService(repository: loyalty, nowProvider: () => now);

    final account = await service.account(7);
    // 1000 start + 250 + 200 - 1000 used every-fifth = 450
    expect(account.remaining, 450);

    final repeat = await service.credit(
      userId: 7,
      amount: LoyaltyMath.startBonusPeaks,
      reason: LoyaltyLedgerReason.start,
      idempotencyKey: LoyaltyKeys.start(7),
      now: now,
    );
    expect(repeat.applied, isFalse);
    expect((await service.account(7)).remaining, 450);
  });

  test('migration converts unused every-fifth voucher and leftover paid trainings', () async {
    final now = DateTime.utc(2026, 6, 1, 12);
    final onboarding = SqliteOnboardingRepository(databaseHandle: handle);
    final bookings = SqliteBookingRepository(
      databaseHandle: handle,
      nowProvider: () => now,
    );
    await bookings.init();
    await onboarding.init();
    await onboarding.ensureStartedUser(8, startedAt: DateTime.utc(2026, 1, 1));

    for (var i = 0; i < 4; i++) {
      final created = await bookings.createPendingBooking(
        userId: 8,
        training: TrainingInfo(
          title: 'Силовая $i',
          startsAt: DateTime.utc(2026, 4, 1 + i, 19),
          location: 'Hall',
          price: 500,
        ),
      );
      await bookings.updateStatus(created.booking.id, BookingStatus.paid);
    }

    final loyalty = SqliteLoyaltyRepository(
      databaseHandle: handle,
      nowProvider: () => now,
    );
    await loyalty.init();
    final service = LoyaltyService(repository: loyalty, nowProvider: () => now);
    // 1000 /start + 4×250 cashback + 1000 unused 5th
    expect((await service.account(8)).remaining, 3000);
  });

  test('migration converts a still-available starter bonus into peaks and consumes it', () async {
    final now = DateTime.now().toUtc();
    final onboarding = SqliteOnboardingRepository(databaseHandle: handle);
    final bookings = SqliteBookingRepository(
      databaseHandle: handle,
      nowProvider: () => now,
    );
    await bookings.init();
    await onboarding.init();
    await onboarding.ensureStartedUser(
      9,
      startedAt: now.subtract(const Duration(days: 2)),
      entryType: OnboardingEntryType.group,
    );
    expect(await onboarding.hasStarterBonusAvailable(9), isTrue);

    final loyalty = SqliteLoyaltyRepository(
      databaseHandle: handle,
      nowProvider: () => now,
    );
    await loyalty.init();
    final service = LoyaltyService(repository: loyalty, nowProvider: () => now);
    // 1000 /start + 1000 starter conversion
    expect((await service.account(9)).remaining, 2000);
    expect(await onboarding.hasStarterBonusAvailable(9), isFalse);
  });
}
