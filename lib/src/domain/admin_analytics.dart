final class BookingAnalytics {
  const BookingAnalytics({
    required this.generatedAt,
    required this.totalBookings,
    required this.statusCounts,
    required this.createdLast7Days,
    required this.createdLast30Days,
    required this.confirmedLast7Days,
    required this.confirmedLast30Days,
    required this.cancelledLast7Days,
    required this.cancelledLast30Days,
    required this.pendingPaymentCount,
    required this.paymentSubmittedCount,
    required this.upcomingConfirmedCount,
    required this.pastConfirmedCount,
    required this.confirmedByCategory,
    required this.createdWithOutcomeLast30Days,
    required this.confirmedAmongOutcomeLast30Days,
    required this.promoCodeBookingsCount,
    required this.uniqueUsersWithConfirmed,
  });

  final DateTime generatedAt;
  final int totalBookings;
  final Map<String, int> statusCounts;
  final int createdLast7Days;
  final int createdLast30Days;
  final int confirmedLast7Days;
  final int confirmedLast30Days;
  final int cancelledLast7Days;
  final int cancelledLast30Days;
  final int pendingPaymentCount;
  final int paymentSubmittedCount;
  final int upcomingConfirmedCount;
  final int pastConfirmedCount;
  final Map<String, int> confirmedByCategory;
  final int createdWithOutcomeLast30Days;
  final int confirmedAmongOutcomeLast30Days;
  final int promoCodeBookingsCount;
  final int uniqueUsersWithConfirmed;

  /// Share of bookings created in 30d that reached a paid-like status
  /// among those with a terminal-ish outcome (confirmed / cancelled / rejected).
  double? get conversionRate30Days {
    if (createdWithOutcomeLast30Days <= 0) {
      return null;
    }
    return confirmedAmongOutcomeLast30Days / createdWithOutcomeLast30Days;
  }
}

final class LoyaltyBonusUsageAnalytics {
  const LoyaltyBonusUsageAnalytics({
    required this.freeByStarterCount,
    required this.freeByReferralCount,
    required this.freeByEveryFifthCount,
    required this.referralAttributionsTotal,
    required this.referralAttributionsLast30Days,
    this.starterBonusBookedLast30Days = 0,
    this.starterBonusCancelledLast30Days = 0,
    this.starterBonusBookedLast90Days = 0,
    this.starterBonusCancelledLast90Days = 0,
    this.starterBonusCancelledByCategoryLast30Days = const <String, int>{},
  });

  final int freeByStarterCount;
  final int freeByReferralCount;
  final int freeByEveryFifthCount;
  final int referralAttributionsTotal;
  final int referralAttributionsLast30Days;
  final int starterBonusBookedLast30Days;
  final int starterBonusCancelledLast30Days;
  final int starterBonusBookedLast90Days;
  final int starterBonusCancelledLast90Days;
  final Map<String, int> starterBonusCancelledByCategoryLast30Days;

  double? get starterBonusCancelRate30Days {
    if (starterBonusBookedLast30Days <= 0) {
      return null;
    }
    return starterBonusCancelledLast30Days / starterBonusBookedLast30Days;
  }

  double? get starterBonusCancelRate90Days {
    if (starterBonusBookedLast90Days <= 0) {
      return null;
    }
    return starterBonusCancelledLast90Days / starterBonusBookedLast90Days;
  }
}

final class StarterBonusAnalytics {
  const StarterBonusAnalytics({
    required this.availableCount,
    required this.consumedCount,
  });

  final int availableCount;
  final int consumedCount;
}

final class LoyaltyAnalytics {
  const LoyaltyAnalytics({
    required this.generatedAt,
    required this.starterBonusAvailable,
    required this.starterBonusConsumed,
    required this.referralAttributionsTotal,
    required this.referralAttributionsLast30Days,
    required this.freeByStarterCount,
    required this.freeByReferralCount,
    required this.freeByEveryFifthCount,
    this.starterBonusBookedLast30Days = 0,
    this.starterBonusCancelledLast30Days = 0,
    this.starterBonusBookedLast90Days = 0,
    this.starterBonusCancelledLast90Days = 0,
    this.starterBonusCancelledByCategoryLast30Days = const <String, int>{},
  });

  final DateTime generatedAt;
  final int starterBonusAvailable;
  final int starterBonusConsumed;
  final int referralAttributionsTotal;
  final int referralAttributionsLast30Days;
  final int freeByStarterCount;
  final int freeByReferralCount;
  final int freeByEveryFifthCount;
  final int starterBonusBookedLast30Days;
  final int starterBonusCancelledLast30Days;
  final int starterBonusBookedLast90Days;
  final int starterBonusCancelledLast90Days;
  final Map<String, int> starterBonusCancelledByCategoryLast30Days;

  int get freeTrainingsTotal => freeByStarterCount + freeByReferralCount + freeByEveryFifthCount;

  double? get starterBonusCancelRate30Days {
    if (starterBonusBookedLast30Days <= 0) {
      return null;
    }
    return starterBonusCancelledLast30Days / starterBonusBookedLast30Days;
  }

  double? get starterBonusCancelRate90Days {
    if (starterBonusBookedLast90Days <= 0) {
      return null;
    }
    return starterBonusCancelledLast90Days / starterBonusBookedLast90Days;
  }
}

final class SubscriptionAnalytics {
  const SubscriptionAnalytics({
    required this.generatedAt,
    required this.activeCount,
    required this.expiringSoonCount,
    required this.pendingCount,
    required this.cancelledOrRejectedCount,
    required this.approvedTotal,
  });

  final DateTime generatedAt;
  final int activeCount;
  final int expiringSoonCount;
  final int pendingCount;
  final int cancelledOrRejectedCount;
  final int approvedTotal;
}
