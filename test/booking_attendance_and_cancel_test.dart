import 'dart:io';

import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/booking_policy_service.dart';
import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/memory_loyalty_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_attendance.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  final catalog = ActivityCatalogService(
    scheduleRepository: FakeScheduleRepository(const <TrainingInfo>[]),
  );
  final policy = BookingPolicyService(catalogService: catalog);

  TrainingInfo trainingAt(DateTime startsAt) {
    return TrainingInfo(
      title: 'Силовая',
      startsAt: startsAt,
      location: 'Зал',
      price: 500,
    );
  }

  test('paid training cancels at 24 hours and refunds cash as peaks', () {
    final startsAt = DateTime.utc(2026, 10, 8, 18);
    final booking = fakeBooking(
      id: 7,
      trainingKey: 'trainings|силовая',
      title: 'Силовая',
      status: BookingStatus.paid,
      trainingPrice: 500,
      startsAt: startsAt,
    );
    expect(policy.isPeaksRefundTraining(booking), isTrue);
    expect(
      policy.canCancel(booking, now: startsAt.subtract(const Duration(hours: 24))),
      isTrue,
    );
    expect(
      policy.canCancel(booking, now: startsAt.subtract(const Duration(hours: 23, minutes: 59))),
      isFalse,
    );
    expect(policy.cashCancelRefundPeaks(booking, peaksSpent: 0), 1000);
    expect(
      policy.cashCancelRefundPeaks(booking, peaksSpent: LoyaltyMath.fullPayPeaks(500)),
      0,
    );
  });

  test('whitelisted members cancel paid trainings until the start', () {
    final startsAt = DateTime.utc(2026, 10, 8, 18);
    TrainingBooking paid(String username) => fakeBooking(
          id: 8,
          userUsername: username,
          trainingKey: 'trainings|box',
          status: BookingStatus.paid,
          trainingPrice: 600,
          startsAt: startsAt,
        );
    final twoHoursBefore = startsAt.subtract(const Duration(hours: 2));
    expect(policy.canCancel(paid('@Zhorenty'), now: twoHoursBefore), isTrue);
    expect(
        policy.canCancel(paid('zhorenty'), now: startsAt.add(const Duration(minutes: 1))), isFalse);
    expect(policy.canCancel(paid('@someone'), now: twoHoursBefore), isFalse);
  });

  test('free, boxing card and outdoor cancel rules stay in place', () {
    final startsAt = DateTime.utc(2026, 10, 8, 18);
    final free = fakeBooking(
      id: 1,
      trainingKey: 'trainings|free',
      status: BookingStatus.freeTraining,
      trainingPrice: 0,
      startsAt: startsAt,
    );
    final card = fakeBooking(
      id: 2,
      trainingKey: 'trainings|box',
      title: 'BOXING',
      status: BookingStatus.paid,
      trainingPrice: 500,
      startsAt: startsAt,
      paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
    );
    final hike = fakeBooking(
      id: 3,
      trainingKey: 'hikes|weekend',
      title: '🥾 Поход: Карелия',
      status: BookingStatus.paid,
      trainingPrice: 2500,
      startsAt: startsAt,
    );
    expect(policy.canCancel(free, now: startsAt.subtract(const Duration(hours: 1))), isTrue);
    expect(policy.isPeaksRefundTraining(card), isFalse);
    expect(policy.canCancel(card, now: startsAt.subtract(const Duration(hours: 1))), isTrue);
    expect(policy.canCancel(card, now: startsAt.add(const Duration(minutes: 1))), isFalse);
    expect(policy.isPeaksRefundTraining(hike), isFalse);
    expect(policy.canCancel(hike, now: startsAt.subtract(const Duration(days: 7))), isTrue);
    expect(policy.canCancel(hike, now: startsAt.subtract(const Duration(days: 6))), isFalse);
  });

  test('multi-day hike and camp prepayment closes 10 days before start', () {
    final startsAt = DateTime.utc(2026, 10, 8, 18);
    final catalog = ActivityCatalogService(
      scheduleRepository: FakeScheduleRepository(
        <TrainingInfo>[
          TrainingInfo(
            title: '🎯 Кэмп: Архыз',
            startsAt: startsAt,
            endsAt: DateTime.utc(2026, 10, 11, 12),
            location: 'Архыз',
            price: 8000,
          ),
        ],
        outdoorItems: <OutdoorActivityInfo>[
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Карелия',
            dateFrom: startsAt,
            dateTo: DateTime.utc(2026, 10, 10, 18),
            description: 'Два дня',
            price: 2500,
          ),
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Один день',
            dateFrom: startsAt,
            dateTo: DateTime.utc(2026, 10, 8, 21),
            description: 'День',
            price: 1500,
          ),
        ],
      ),
    );
    final policy = BookingPolicyService(catalogService: catalog);
    final hike = fakeBooking(
      id: 4,
      trainingKey: 'hikes|karelia',
      title: '🥾 Поход: Карелия',
      status: BookingStatus.paid,
      trainingPrice: 2500,
      startsAt: startsAt,
    );
    final dayHike = fakeBooking(
      id: 5,
      trainingKey: 'hikes|day',
      title: '🥾 Поход: Один день',
      status: BookingStatus.paid,
      trainingPrice: 1500,
      startsAt: startsAt,
    );
    final camp = fakeBooking(
      id: 6,
      trainingKey: 'trails|camp',
      title: '🎯 Кэмп: Архыз',
      status: BookingStatus.paid,
      trainingPrice: 8000,
      startsAt: startsAt,
    );

    expect(policy.isMultiDayOutdoor(hike), isTrue);
    expect(policy.outdoorCancelLead(hike), BookingPolicyService.multiDayOutdoorCancelLead);
    expect(policy.canCancel(hike, now: startsAt.subtract(const Duration(days: 10))), isTrue);
    expect(policy.canCancel(hike, now: startsAt.subtract(const Duration(days: 9))), isFalse);

    expect(policy.isMultiDayOutdoor(dayHike), isFalse);
    expect(policy.canCancel(dayHike, now: startsAt.subtract(const Duration(days: 7))), isTrue);
    expect(policy.canCancel(dayHike, now: startsAt.subtract(const Duration(days: 6))), isFalse);

    expect(policy.isMultiDayOutdoor(camp), isTrue);
    expect(policy.canCancel(camp, now: startsAt.subtract(const Duration(days: 10))), isTrue);
    expect(policy.canCancel(camp, now: startsAt.subtract(const Duration(days: 9))), isFalse);
  });

  test('attendance tops up peaks, absence takes them back, a second mark does not double',
      () async {
    final now = DateTime.utc(2026, 10, 5, 20);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    final booking = fakeBooking(
      id: 15,
      userId: 9,
      trainingKey: 'trainings|15',
      status: BookingStatus.paid,
      trainingPrice: 500,
      startsAt: now.subtract(const Duration(hours: 1)),
      attendance: BookingAttendance.attended,
    );

    final first = await service.syncTrainingPeaks(booking: booking, now: now, isTraining: true);
    expect(first.appliedDelta, 100);
    expect(first.remaining, 100);

    final repeat = await service.syncTrainingPeaks(booking: booking, now: now, isTraining: true);
    expect(repeat.appliedDelta, 0);
    expect((await service.account(9)).remaining, 100);

    final absent = _withAttendance(booking, BookingAttendance.absent);
    final pulled = await service.syncTrainingPeaks(booking: absent, now: now, isTraining: true);
    expect(pulled.appliedDelta, -100);
    expect((await service.account(9)).remaining, 0);

    final back = _withAttendance(booking, BookingAttendance.attended);
    final restored = await service.syncTrainingPeaks(
      booking: back,
      now: now.add(const Duration(seconds: 1)),
      isTraining: true,
    );
    expect(restored.appliedDelta, 100);
    expect((await service.account(9)).remaining, 100);
  });

  test('unmarked training does not earn or reverse an older credit', () async {
    final now = DateTime.utc(2026, 10, 5, 20);
    final repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    final service = LoyaltyService(repository: repository, nowProvider: () => now);
    await service.credit(
      userId: 4,
      amount: 200,
      reason: LoyaltyLedgerReason.training,
      idempotencyKey: 'legacy',
      now: now,
      bookingId: 4,
    );
    final unmarked = fakeBooking(
      id: 4,
      userId: 4,
      trainingKey: 'trainings|4',
      status: BookingStatus.paid,
      trainingPrice: 500,
      startsAt: now.subtract(const Duration(hours: 2)),
    );
    final sync = await service.syncTrainingPeaks(booking: unmarked, now: now, isTraining: true);
    expect(sync.appliedDelta, 0);
    expect((await service.account(4)).remaining, 200);
  });

  test('sqlite keeps the attendance mark', () async {
    final tmpDir = await Directory.systemTemp.createTemp('dvor-attendance-');
    addTearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });
    final now = DateTime.utc(2026, 10, 5, 21);
    final repository = SqliteBookingRepository(
      dbPath: '${tmpDir.path}/bookings.sqlite',
      nowProvider: () => now,
    );
    addTearDown(repository.close);
    await repository.init();
    final created = await repository.createPendingBooking(
      userId: 3,
      userUsername: 'neo',
      training: trainingAt(now.subtract(const Duration(hours: 2))),
    );
    await repository.updateStatus(created.booking.id, BookingStatus.paid);
    final marked = await repository.markAttendance(
      bookingId: created.booking.id,
      attendance: BookingAttendance.attended,
    );
    expect(marked?.attendance, BookingAttendance.attended);
    final loaded = await repository.findBookingById(created.booking.id);
    expect(loaded?.attendance, BookingAttendance.attended);
    final listed = await repository.listBookingsStartedBetween(
      startsFromInclusive: now.subtract(const Duration(days: 7)),
      startsToInclusive: now,
    );
    expect(listed.single.attendance, BookingAttendance.attended);
  });
}

TrainingBooking _withAttendance(TrainingBooking booking, BookingAttendance attendance) {
  return fakeBooking(
    id: booking.id,
    userId: booking.userId,
    trainingKey: booking.trainingKey,
    title: booking.trainingTitle,
    status: booking.status,
    trainingPrice: booking.trainingPrice,
    startsAt: booking.startsAt,
    attendance: attendance,
  );
}
