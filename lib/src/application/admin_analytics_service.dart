import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/admin_analytics.dart';

final class AdminAnalyticsService {
  const AdminAnalyticsService({
    required BookingRepository bookingRepository,
    required OnboardingRepository onboardingRepository,
    required SubscriptionRepository subscriptionRepository,
  })  : _bookingRepository = bookingRepository,
        _onboardingRepository = onboardingRepository,
        _subscriptionRepository = subscriptionRepository;

  final BookingRepository _bookingRepository;
  final OnboardingRepository _onboardingRepository;
  final SubscriptionRepository _subscriptionRepository;

  Future<BookingAnalytics> buildBookingAnalytics({required DateTime now}) {
    return _bookingRepository.getBookingAnalytics(now: now);
  }

  Future<LoyaltyAnalytics> buildLoyaltyAnalytics({required DateTime now}) async {
    final starter = await _onboardingRepository.getStarterBonusAnalytics();
    final usage = await _bookingRepository.getLoyaltyBonusUsageAnalytics(now: now);
    return LoyaltyAnalytics(
      generatedAt: now.toUtc(),
      starterBonusAvailable: starter.availableCount,
      starterBonusConsumed: starter.consumedCount,
      referralAttributionsTotal: usage.referralAttributionsTotal,
      referralAttributionsLast30Days: usage.referralAttributionsLast30Days,
      freeByStarterCount: usage.freeByStarterCount,
      freeByReferralCount: usage.freeByReferralCount,
      freeByEveryFifthCount: usage.freeByEveryFifthCount,
    );
  }

  Future<SubscriptionAnalytics> buildSubscriptionAnalytics({required DateTime now}) {
    return _subscriptionRepository.getSubscriptionAnalytics(now: now);
  }
}
