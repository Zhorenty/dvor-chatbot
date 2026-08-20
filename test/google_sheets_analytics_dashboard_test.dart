import 'package:dvor_chatbot/src/data/google_sheets_analytics_dashboard.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/admin_analytics.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsAnalyticsDashboard', () {
    test('builds KPI cards, sections, banding and at least one chart', () {
      final dashboard = GoogleSheetsAnalyticsDashboard.build(
        bookings: _bookings(),
        loyalty: _loyalty(),
        subscriptions: _subscriptions(),
        currentWeek: _economy(title: 'Силовая'),
        currentMonth: _economy(title: 'Поход'),
      );

      expect(dashboard.sheetTitle, 'АНАЛИТИКА');
      expect(dashboard.obsoleteSheetTitles, isEmpty);
      expect(dashboard.rows.first.first, 'DVOR · Аналитика');
      expect(
        dashboard.rows.first.last.toString(),
        contains('Срез 18.08.2026'),
      );
      expect(dashboard.rows[1].first.toString(), contains('руками не править'));
      expect(
        dashboard.rows.any((row) => row.contains('Бронирования')),
        isTrue,
      );
      expect(
        dashboard.rows.any((row) => row.contains('Бонусы и рефералы')),
        isTrue,
      );
      expect(dashboard.rows.any((row) => row.contains('Абонементы')), isTrue);
      expect(dashboard.rows.any((row) => row.contains('Экономика')), isTrue);
      expect(
        dashboard.rows.any(
          (row) => row.any((cell) => cell.toString().contains('Текущая неделя')),
        ),
        isTrue,
      );
      expect(
        dashboard.rows.any(
          (row) => row.any((cell) => cell.toString().contains('Текущий месяц')),
        ),
        isTrue,
      );
      expect(dashboard.charts, isNotEmpty);
      expect(
        dashboard.charts.map((chart) => chart.title),
        contains('7 / 30 дней: создано и подтверждено'),
      );
      expect(dashboard.bandedTables, isNotEmpty);
    });
  });
}

BookingAnalytics _bookings() {
  return BookingAnalytics(
    generatedAt: DateTime.utc(2026, 8, 18, 9),
    totalBookings: 40,
    statusCounts: const <String, int>{
      'paid': 20,
      'pending_payment': 8,
      'cancelled': 4,
    },
    createdLast7Days: 6,
    createdLast30Days: 18,
    confirmedLast7Days: 4,
    confirmedLast30Days: 12,
    cancelledLast7Days: 1,
    cancelledLast30Days: 3,
    pendingPaymentCount: 8,
    paymentSubmittedCount: 2,
    upcomingConfirmedCount: 5,
    pastConfirmedCount: 15,
    confirmedByCategory: const <String, int>{
      'trainings': 16,
      'hikes': 3,
    },
    createdWithOutcomeLast30Days: 15,
    confirmedAmongOutcomeLast30Days: 12,
    promoCodeBookingsCount: 3,
    uniqueUsersWithConfirmed: 11,
  );
}

LoyaltyAnalytics _loyalty() {
  return LoyaltyAnalytics(
    generatedAt: DateTime.utc(2026, 8, 18, 9),
    starterBonusAvailable: 4,
    starterBonusConsumed: 7,
    referralAttributionsTotal: 9,
    referralAttributionsLast30Days: 2,
    freeByStarterCount: 7,
    freeByReferralCount: 3,
    freeByEveryFifthCount: 2,
  );
}

SubscriptionAnalytics _subscriptions() {
  return SubscriptionAnalytics(
    generatedAt: DateTime.utc(2026, 8, 18, 9),
    activeCount: 5,
    expiringSoonCount: 1,
    pendingCount: 2,
    cancelledOrRejectedCount: 3,
    approvedTotal: 8,
  );
}

EconomicSummary _economy({required String title}) {
  return EconomicSummary(
    period: EconomicSummaryPeriod(
      type: EconomicReportType.weekly,
      startInclusive: DateTime(2026, 8, 17),
      endExclusive: DateTime(2026, 8, 19),
    ),
    paidBookingsCount: 4,
    partialPaidBookingsCount: 1,
    freeBookingsCount: 2,
    regularFreeBookingsCount: 1,
    starterFreeBookingsCount: 1,
    everyFifthFreeBookingsCount: 0,
    unknownPriceBookingsCount: 0,
    totalRevenue: 4200,
    partialPaidRevenue: 700,
    averageCheck: 840,
    byCategory: const <EconomicSummaryByCategory>[
      EconomicSummaryByCategory(
        category: ActivityCategory.trainings,
        bookingsCount: 3,
        revenue: 2100,
      ),
      EconomicSummaryByCategory(
        category: ActivityCategory.hikes,
        bookingsCount: 2,
        revenue: 2100,
      ),
    ],
    byEvent: <EconomicSummaryByEvent>[
      EconomicSummaryByEvent(eventTitle: title, bookingsCount: 3, revenue: 2100),
    ],
  );
}
