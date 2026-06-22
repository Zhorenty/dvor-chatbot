import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
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
    final bookings = await _bookingRepository.listPaidBookingsInRange(
      fromInclusive: period.startInclusive,
      toExclusive: period.endExclusive,
    );
    var paidBookingsCount = 0;
    var partialPaidBookingsCount = 0;
    var freeBookingsCount = 0;
    var regularFreeBookingsCount = 0;
    var starterFreeBookingsCount = 0;
    var everyFifthFreeBookingsCount = 0;
    var unknownPriceBookingsCount = 0;
    var totalRevenue = 0;
    var partialPaidRevenue = 0;
    final byCategory = <ActivityCategory, _MutableStats>{};
    final byEvent = <String, _MutableStats>{};

    for (final booking in bookings) {
      if (isTrainerBookingWhitelisted(userId: booking.userId, username: booking.userUsername)) {
        continue;
      }
      if (booking.status == BookingStatus.freeTraining) {
        freeBookingsCount++;
        regularFreeBookingsCount++;
        continue;
      }
      final paymentNote = booking.paymentNote;
      final price = booking.trainingPrice;
      if (paymentNote == MessageFormatters.starterBonusPaymentNoteMarker) {
        freeBookingsCount++;
        starterFreeBookingsCount++;
        continue;
      }
      if (paymentNote == MessageFormatters.everyFifthBonusPaymentNoteMarker) {
        freeBookingsCount++;
        everyFifthFreeBookingsCount++;
        continue;
      }
      if (paymentNote == MessageFormatters.proIncludedTrainingPaymentNoteMarker) {
        freeBookingsCount++;
        regularFreeBookingsCount++;
        continue;
      }
      if (price != null && price <= 0) {
        freeBookingsCount++;
        regularFreeBookingsCount++;
        continue;
      }
      if (price == null) {
        unknownPriceBookingsCount++;
        continue;
      }
      final category = _catalogService.categoryForBooking(booking);
      if (booking.status == BookingStatus.partialPaid) {
        final prepayment = (price / 2).ceil();
        partialPaidBookingsCount++;
        partialPaidRevenue += prepayment;
        totalRevenue += prepayment;
        byCategory.putIfAbsent(category, () => _MutableStats()).add(prepayment);
        byEvent.putIfAbsent(booking.trainingTitle, () => _MutableStats()).add(prepayment);
        continue;
      }
      paidBookingsCount++;
      totalRevenue += price;
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
      partialPaidBookingsCount: partialPaidBookingsCount,
      freeBookingsCount: freeBookingsCount,
      regularFreeBookingsCount: regularFreeBookingsCount,
      starterFreeBookingsCount: starterFreeBookingsCount,
      everyFifthFreeBookingsCount: everyFifthFreeBookingsCount,
      unknownPriceBookingsCount: unknownPriceBookingsCount,
      totalRevenue: totalRevenue,
      partialPaidRevenue: partialPaidRevenue,
      averageCheck: paidBookingsCount + partialPaidBookingsCount == 0
          ? 0
          : (totalRevenue / (paidBookingsCount + partialPaidBookingsCount)).round(),
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
