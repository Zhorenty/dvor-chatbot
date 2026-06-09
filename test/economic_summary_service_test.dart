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
      ];
    final scheduleRepository = FakeScheduleRepository(const []);
    final service = EconomicSummaryService(
      bookingRepository: bookingRepository,
      catalogService: ActivityCatalogService(scheduleRepository: scheduleRepository),
    );

    final summary = await service.buildSummary(period);

    expect(summary.totalRevenue, 3200);
    expect(summary.paidBookingsCount, 2);
    expect(summary.freeBookingsCount, 1);
    expect(summary.unknownPriceBookingsCount, 1);
    expect(summary.averageCheck, 1600);
    expect(summary.byCategory, hasLength(2));
    expect(summary.byEvent.first.eventTitle, '🥾 Поход: Архыз');
    expect(summary.byEvent.first.revenue, 2500);
  });
}
