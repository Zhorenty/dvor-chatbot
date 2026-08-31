import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/admin_analytics.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';

final class AdminAnalyticsService {
  const AdminAnalyticsService({
    required BookingRepository bookingRepository,
    required OnboardingRepository onboardingRepository,
    required SubscriptionRepository subscriptionRepository,
    LoyaltyService? loyaltyService,
  })  : _bookingRepository = bookingRepository,
        _onboardingRepository = onboardingRepository,
        _subscriptionRepository = subscriptionRepository,
        _loyaltyService = loyaltyService;

  final BookingRepository _bookingRepository;
  final OnboardingRepository _onboardingRepository;
  final SubscriptionRepository _subscriptionRepository;
  final LoyaltyService? _loyaltyService;

  Future<BookingAnalytics> buildBookingAnalytics({required DateTime now}) {
    return _bookingRepository.getBookingAnalytics(now: now);
  }

  Future<LoyaltyAnalytics> buildLoyaltyAnalytics({required DateTime now}) async {
    final starter = await _onboardingRepository.getStarterBonusAnalytics();
    final usage = await _bookingRepository.getLoyaltyBonusUsageAnalytics(now: now);
    final peaks = await _loyaltyService?.peaksAnalytics() ??
        const LoyaltyPeaksAnalytics(
          earnedTotal: 0,
          spentTotal: 0,
          expiredTotal: 0,
          remainingTotal: 0,
        );
    return LoyaltyAnalytics(
      generatedAt: now.toUtc(),
      starterBonusAvailable: starter.availableCount,
      starterBonusConsumed: starter.consumedCount,
      referralAttributionsTotal: usage.referralAttributionsTotal,
      referralAttributionsLast30Days: usage.referralAttributionsLast30Days,
      freeByStarterCount: usage.freeByStarterCount,
      freeByReferralCount: usage.freeByReferralCount,
      freeByEveryFifthCount: usage.freeByEveryFifthCount,
      starterBonusBookedLast30Days: usage.starterBonusBookedLast30Days,
      starterBonusCancelledLast30Days: usage.starterBonusCancelledLast30Days,
      starterBonusBookedLast90Days: usage.starterBonusBookedLast90Days,
      starterBonusCancelledLast90Days: usage.starterBonusCancelledLast90Days,
      starterBonusCancelledByCategoryLast30Days: usage.starterBonusCancelledByCategoryLast30Days,
      peaksEarned: peaks.earnedTotal,
      peaksSpent: peaks.spentTotal,
      peaksExpired: peaks.expiredTotal,
      peaksRemaining: peaks.remainingTotal,
    );
  }

  Future<SubscriptionAnalytics> buildSubscriptionAnalytics({required DateTime now}) {
    return _subscriptionRepository.getSubscriptionAnalytics(now: now);
  }
}
