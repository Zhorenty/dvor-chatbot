import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('builds weekly summary with revenue, free and unknown price', () async {
    final period = EconomicSummaryPeriod(
      type: EconomicReportType.weekly,
      startInclusive: DateTime(2026, 6, 1),
      endExclusive: DateTime(2026, 6, 8),
    );
    final bookingRepository = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 1,
          trainingKey: 'trainings|1',
          title: 'Функционал',
          status: BookingStatus.paid,
          trainingPrice: 700,
          updatedAt: DateTime(2026, 6, 2, 10),
        ),
        fakeBooking(
          id: 2,
          trainingKey: 'hikes|2',
          title: '🥾 Поход: Архыз',
          status: BookingStatus.paid,
          trainingPrice: 2500,
          updatedAt: DateTime(2026, 6, 4, 10),
        ),
        fakeBooking(
          id: 3,
          trainingKey: 'trainings|3',
          title: 'Бонус',
          status: BookingStatus.paid,
          trainingPrice: 700,
          paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
          updatedAt: DateTime(2026, 6, 5, 12),
        ),
        fakeBooking(
          id: 4,
          trainingKey: 'trainings|4',
          title: 'Без цены',
          status: BookingStatus.paid,
          trainingPrice: null,
          updatedAt: DateTime(2026, 6, 6, 12),
        ),
        fakeBooking(
          id: 5,
          trainingKey: 'trainings|5',
          title: 'Админская бесплатная',
          status: BookingStatus.freeTraining,
          trainingPrice: 900,
          updatedAt: DateTime(2026, 6, 6, 13),
        ),
      ];
    final scheduleRepository = FakeScheduleRepository(const []);
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
    );

    final summary = await service.buildSummary(period);

    expect(summary.totalRevenue, 3200);
    expect(summary.paidBookingsCount, 2);
    expect(summary.partialPaidBookingsCount, 0);
    expect(summary.partialPaidRevenue, 0);
    expect(summary.freeBookingsCount, 2);
    expect(summary.regularFreeBookingsCount, 1);
    expect(summary.starterFreeBookingsCount, 0);
    expect(summary.everyFifthFreeBookingsCount, 1);
    expect(summary.unknownPriceBookingsCount, 1);
    expect(summary.averageCheck, 1600);
    expect(summary.byCategory, hasLength(2));
    expect(summary.byEvent.first.eventTitle, '🥾 Поход: Архыз');
    expect(summary.byEvent.first.revenue, 2500);
  });

  test('handles bonus markers, non-positive prices and keeps top-5 events', () async {
    final period = EconomicSummaryPeriod(
      type: EconomicReportType.monthly,
      startInclusive: DateTime(2026, 6, 1),
      endExclusive: DateTime(2026, 7, 1),
    );
    final bookingRepository = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 11,
          trainingKey: 'trainings|11',
          title: 'Платная A',
          status: BookingStatus.paid,
          trainingPrice: 2100,
          updatedAt: DateTime(2026, 6, 2, 10),
        ),
        fakeBooking(
          id: 12,
          trainingKey: 'trainings|12',
          title: 'Платная B',
          status: BookingStatus.paid,
          trainingPrice: 1800,
          updatedAt: DateTime(2026, 6, 3, 10),
        ),
        fakeBooking(
          id: 13,
          trainingKey: 'hikes|13',
          title: '🥾 Поход C',
          status: BookingStatus.paid,
          trainingPrice: 3500,
          updatedAt: DateTime(2026, 6, 4, 10),
        ),
        fakeBooking(
          id: 14,
          trainingKey: 'trainings|14',
          title: 'Платная D',
          status: BookingStatus.paid,
          trainingPrice: 1500,
          updatedAt: DateTime(2026, 6, 5, 10),
        ),
        fakeBooking(
          id: 15,
          trainingKey: 'trainings|15',
          title: 'Платная E',
          status: BookingStatus.paid,
          trainingPrice: 1200,
          updatedAt: DateTime(2026, 6, 6, 10),
        ),
        fakeBooking(
          id: 16,
          trainingKey: 'trainings|16',
          title: 'Платная F',
          status: BookingStatus.paid,
          trainingPrice: 900,
          updatedAt: DateTime(2026, 6, 7, 10),
        ),
        fakeBooking(
          id: 17,
          trainingKey: 'trainings|17',
          title: 'Стартовый бонус',
          status: BookingStatus.paid,
          trainingPrice: 700,
          paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
          updatedAt: DateTime(2026, 6, 8, 10),
        ),
        fakeBooking(
          id: 18,
          trainingKey: 'trainings|18',
          title: 'Нулевая цена',
          status: BookingStatus.paid,
          trainingPrice: 0,
          updatedAt: DateTime(2026, 6, 9, 10),
        ),
        fakeBooking(
          id: 19,
          trainingKey: 'trainings|19',
          title: 'Отрицательная цена',
          status: BookingStatus.paid,
          trainingPrice: -100,
          updatedAt: DateTime(2026, 6, 10, 10),
        ),
        fakeBooking(
          id: 20,
          trainingKey: 'trainings|20',
          title: 'Включено в PRO',
          status: BookingStatus.paid,
          trainingPrice: 1500,
          paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
          updatedAt: DateTime(2026, 6, 11, 10),
        ),
      ];
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(
        scheduleRepository: FakeScheduleRepository(const []),
      ),
    );

    final summary = await service.buildSummary(period);

    expect(summary.totalRevenue, 11000);
    expect(summary.paidBookingsCount, 6);
    expect(summary.partialPaidBookingsCount, 0);
    expect(summary.partialPaidRevenue, 0);
    expect(summary.freeBookingsCount, 4);
    expect(summary.starterFreeBookingsCount, 1);
    expect(summary.regularFreeBookingsCount, 3);
    expect(summary.everyFifthFreeBookingsCount, 0);
    expect(summary.unknownPriceBookingsCount, 0);
    expect(summary.averageCheck, 1833);
    expect(summary.byEvent, hasLength(5));
    expect(summary.byEvent.first.eventTitle, '🥾 Поход C');
  });

  test('excludes trainer bookings from all economic summary counters', () async {
    final period = EconomicSummaryPeriod(
      type: EconomicReportType.weekly,
      startInclusive: DateTime(2026, 6, 1),
      endExclusive: DateTime(2026, 6, 8),
    );
    final bookingRepository = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 21,
          trainingKey: 'trainings|21',
          title: 'Обычная платная',
          status: BookingStatus.paid,
          trainingPrice: 1200,
          updatedAt: DateTime(2026, 6, 3, 10),
        ),
        fakeBooking(
          id: 22,
          userId: 999001,
          userUsername: '@whatshapped',
          trainingKey: 'hikes|22',
          title: '🥾 Поход тренера',
          status: BookingStatus.paid,
          trainingPrice: 3500,
          updatedAt: DateTime(2026, 6, 4, 10),
        ),
        fakeBooking(
          id: 23,
          userId: 999002,
          userUsername: '@k_morozzovaa',
          trainingKey: 'trainings|23',
          title: 'Бесплатная тренера',
          status: BookingStatus.freeTraining,
          trainingPrice: 0,
          updatedAt: DateTime(2026, 6, 5, 10),
        ),
        fakeBooking(
          id: 24,
          userId: 999003,
          userUsername: '@nudden',
          trainingKey: 'trainings|24',
          title: 'Без цены тренера',
          status: BookingStatus.paid,
          trainingPrice: null,
          updatedAt: DateTime(2026, 6, 6, 10),
        ),
      ];
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(
        scheduleRepository: FakeScheduleRepository(const []),
      ),
    );

    final summary = await service.buildSummary(period);

    expect(summary.totalRevenue, 1200);
    expect(summary.paidBookingsCount, 1);
    expect(summary.partialPaidBookingsCount, 0);
    expect(summary.partialPaidRevenue, 0);
    expect(summary.freeBookingsCount, 0);
    expect(summary.regularFreeBookingsCount, 0);
    expect(summary.starterFreeBookingsCount, 0);
    expect(summary.everyFifthFreeBookingsCount, 0);
    expect(summary.unknownPriceBookingsCount, 0);
    expect(summary.byEvent, hasLength(1));
    expect(summary.byEvent.single.eventTitle, 'Обычная платная');
  });

  test('counts partial payments as prepayments and includes them into revenue', () async {
    final period = EconomicSummaryPeriod(
      type: EconomicReportType.weekly,
      startInclusive: DateTime(2026, 6, 1),
      endExclusive: DateTime(2026, 6, 8),
    );
    final bookingRepository = FakeBookingRepository()
      ..queue = <TrainingBooking>[
        fakeBooking(
          id: 31,
          trainingKey: 'hikes|31',
          title: '🥾 Поход: Предоплата',
          status: BookingStatus.partialPaid,
          trainingPrice: 2500,
          updatedAt: DateTime(2026, 6, 2, 10),
        ),
        fakeBooking(
          id: 32,
          trainingKey: 'hikes|32',
          title: '🥾 Поход: Полная оплата',
          status: BookingStatus.paid,
          trainingPrice: 2500,
          updatedAt: DateTime(2026, 6, 3, 10),
        ),
      ];
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(
        scheduleRepository: FakeScheduleRepository(const []),
      ),
    );

    final summary = await service.buildSummary(period);

    expect(summary.totalRevenue, 3750);
    expect(summary.paidBookingsCount, 1);
    expect(summary.partialPaidBookingsCount, 1);
    expect(summary.partialPaidRevenue, 1250);
    expect(summary.averageCheck, 1875);
    expect(summary.byEvent, hasLength(2));
    expect(
      summary.byEvent.firstWhere((item) => item.eventTitle == '🥾 Поход: Полная оплата').revenue,
      2500,
    );
    expect(
      summary.byEvent.firstWhere((item) => item.eventTitle == '🥾 Поход: Предоплата').revenue,
      1250,
    );
  });
}
