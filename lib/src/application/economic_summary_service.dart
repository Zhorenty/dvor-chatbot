import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';

final class EconomicSummaryService {
  const EconomicSummaryService({
    required BookingRepository bookingRepository,
    required ActivityCatalogService catalogService,
  })  : _bookingRepository = bookingRepository,
        _catalogService = catalogService;

  final BookingRepository _bookingRepository;
  final ActivityCatalogService _catalogService;

  EconomicSummaryPeriod latestCompletedWeeklyPeriod(DateTime now) {
    final currentWeekStart = _weekStart(now);
    return EconomicSummaryPeriod(
      type: EconomicReportType.weekly,
      startInclusive: currentWeekStart.subtract(const Duration(days: 7)),
      endExclusive: currentWeekStart,
    );
  }

  EconomicSummaryPeriod currentWeeklyPeriod(DateTime now) {
    final currentWeekStart = _weekStart(now);
    return EconomicSummaryPeriod(
      type: EconomicReportType.weekly,
      startInclusive: currentWeekStart,
      endExclusive: now.toLocal(),
    );
  }

  EconomicSummaryPeriod latestCompletedMonthlyPeriod(DateTime now) {
    final localNow = now.toLocal();
    final currentMonthStart = DateTime(localNow.year, localNow.month, 1);
    final previousMonthStart = DateTime(
      currentMonthStart.year,
      currentMonthStart.month - 1,
      1,
    );
    return EconomicSummaryPeriod(
      type: EconomicReportType.monthly,
      startInclusive: previousMonthStart,
      endExclusive: currentMonthStart,
    );
  }

  EconomicSummaryPeriod currentMonthlyPeriod(DateTime now) {
    final localNow = now.toLocal();
    final currentMonthStart = DateTime(localNow.year, localNow.month, 1);
    return EconomicSummaryPeriod(
      type: EconomicReportType.monthly,
      startInclusive: currentMonthStart,
      endExclusive: localNow,
    );
  }

  Future<EconomicSummary> buildSummary(EconomicSummaryPeriod period) async {
    final paid = await _bookingRepository.listPaidBookingsInRange(
      fromInclusive: period.startInclusive,
      toExclusive: period.endExclusive,
    );
    var paidBookingsCount = 0;
    var freeBookingsCount = 0;
    var unknownPriceBookingsCount = 0;
    var totalRevenue = 0;
    final byCategory = <ActivityCategory, _MutableStats>{};
    final byEvent = <String, _MutableStats>{};

    for (final booking in paid) {
      final isBonus = MessageFormatters.isBonusPaymentNote(booking.paymentNote);
      final price = booking.trainingPrice;
      if (isBonus || (price != null && price <= 0)) {
        freeBookingsCount++;
        continue;
      }
      if (price == null) {
        unknownPriceBookingsCount++;
        continue;
      }
      paidBookingsCount++;
      totalRevenue += price;
      final category = _catalogService.categoryForBooking(booking);
      byCategory.putIfAbsent(category, () => _MutableStats()).add(price);
      byEvent.putIfAbsent(booking.trainingTitle, () => _MutableStats()).add(price);
    }

    final categorySummary = byCategory.entries
        .map(
          (entry) => EconomicSummaryByCategory(
            category: entry.key,
            bookingsCount: entry.value.bookings,
            revenue: entry.value.revenue,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.revenue.compareTo(left.revenue));
    final eventSummary = byEvent.entries
        .map(
          (entry) => EconomicSummaryByEvent(
            eventTitle: entry.key,
            bookingsCount: entry.value.bookings,
            revenue: entry.value.revenue,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.revenue.compareTo(left.revenue));

    return EconomicSummary(
      period: period,
      paidBookingsCount: paidBookingsCount,
      freeBookingsCount: freeBookingsCount,
      unknownPriceBookingsCount: unknownPriceBookingsCount,
      totalRevenue: totalRevenue,
      averageCheck: paidBookingsCount == 0 ? 0 : (totalRevenue / paidBookingsCount).round(),
      byCategory: categorySummary,
      byEvent: eventSummary.take(5).toList(growable: false),
    );
  }

  DateTime _weekStart(DateTime now) {
    final localNow = now.toLocal();
    return DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    ).subtract(Duration(days: localNow.weekday - DateTime.monday));
  }
}

final class _MutableStats {
  int bookings = 0;
  int revenue = 0;

  void add(int amount) {
    bookings++;
    revenue += amount;
  }
}
