import 'package:dvor_chatbot/src/domain/activity_category.dart';

enum EconomicReportType { weekly, monthly }

final class EconomicSummaryPeriod {
  const EconomicSummaryPeriod({
    required this.type,
    required this.startInclusive,
    required this.endExclusive,
  });

  final EconomicReportType type;
  final DateTime startInclusive;
  final DateTime endExclusive;
}

final class EconomicSummaryByCategory {
  const EconomicSummaryByCategory({
    required this.category,
    required this.bookingsCount,
    required this.revenue,
  });

  final ActivityCategory category;
  final int bookingsCount;
  final int revenue;
}

final class EconomicSummaryByEvent {
  const EconomicSummaryByEvent({
    required this.eventTitle,
    required this.bookingsCount,
    required this.revenue,
  });

  final String eventTitle;
  final int bookingsCount;
  final int revenue;
}

final class EconomicSummary {
  const EconomicSummary({
    required this.period,
    required this.paidBookingsCount,
    required this.freeBookingsCount,
    required this.regularFreeBookingsCount,
    required this.starterFreeBookingsCount,
    required this.everyFifthFreeBookingsCount,
    required this.unknownPriceBookingsCount,
    required this.totalRevenue,
    required this.averageCheck,
    required this.byCategory,
    required this.byEvent,
  });

  final EconomicSummaryPeriod period;
  final int paidBookingsCount;
  final int freeBookingsCount;
  final int regularFreeBookingsCount;
  final int starterFreeBookingsCount;
  final int everyFifthFreeBookingsCount;
  final int unknownPriceBookingsCount;
  final int totalRevenue;
  final int averageCheck;
  final List<EconomicSummaryByCategory> byCategory;
  final List<EconomicSummaryByEvent> byEvent;
}
