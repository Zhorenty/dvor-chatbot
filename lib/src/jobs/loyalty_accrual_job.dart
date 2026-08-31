import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_rules.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:l/l.dart';

final class LoyaltyAccrualJob {
  const LoyaltyAccrualJob({
    required LoyaltyService loyaltyService,
    required BookingRepository bookingRepository,
    required OnboardingRepository onboardingRepository,
    ActivityCatalogService? catalogService,
    DateTime Function()? nowProvider,
    this.lookback = const Duration(days: 3),
  })  : _loyaltyService = loyaltyService,
        _bookingRepository = bookingRepository,
        _onboardingRepository = onboardingRepository,
        _catalogService = catalogService,
        _nowProvider = nowProvider ?? DateTime.now;

  final LoyaltyService _loyaltyService;
  final BookingRepository _bookingRepository;
  final OnboardingRepository _onboardingRepository;
  final ActivityCatalogService? _catalogService;
  final DateTime Function() _nowProvider;
  final Duration lookback;

  Future<void> run() async {
    final now = _nowProvider();
    try {
      await _accrueVisits(now);
      await _accrueReferrals(now);
    } on Object catch (error, stackTrace) {
      l.w('Loyalty accrual job failed: $error', stackTrace);
    }
  }

  Future<void> _accrueVisits(DateTime now) async {
    final from = now.subtract(lookback);
    final bookings = await _bookingRepository.listSelfPaidBookingsStartedBetween(
      startsFromInclusive: from,
      startsToInclusive: now,
      limit: 2000,
    );
    for (final booking in bookings) {
      try {
        await _accrueBooking(booking, now);
      } on Object catch (error, stackTrace) {
        l.w('Failed loyalty accrual for booking ${booking.id}: $error', stackTrace);
      }
    }
  }

  Future<void> _accrueBooking(TrainingBooking booking, DateTime now) async {
    final category = _catalogService?.categoryForBooking(booking) ?? ActivityCategory.trainings;
    final peaksSpent = await _loyaltyService.peaksSpentOnBooking(booking.id);
    if (category == ActivityCategory.trainings) {
      if (!LoyaltyRules.canEarnTraining(
        booking: booking,
        now: now,
        peaksSpent: peaksSpent,
      )) {
        return;
      }
      final remainder = LoyaltyMath.remainderRub(
        priceRub: booking.trainingPrice ?? 0,
        peaksSpent: peaksSpent,
      );
      final amount = _loyaltyService.quoteTrainingEarn(remainder);
      if (amount <= 0) {
        return;
      }
      await _loyaltyService.credit(
        userId: booking.userId,
        amount: amount,
        reason: LoyaltyLedgerReason.training,
        idempotencyKey: LoyaltyKeys.training(booking.id),
        now: now,
        bookingId: booking.id,
      );
      return;
    }
    if (category != ActivityCategory.hikes && category != ActivityCategory.trails) {
      return;
    }
    final info = _catalogService?.trainingInfoForBooking(booking);
    final endedAt = info?.endsAt ?? booking.startsAt;
    if (!LoyaltyRules.canEarnOutdoor(
      booking: booking,
      now: now,
      eventEndedAt: endedAt,
      peaksSpent: peaksSpent,
    )) {
      return;
    }
    final paidRub = LoyaltyRules.outdoorPaidRub(booking: booking, peaksSpent: peaksSpent);
    final amount = _loyaltyService.quoteOutdoorEarn(paidRub);
    if (amount <= 0) {
      return;
    }
    final reason =
        category == ActivityCategory.hikes ? LoyaltyLedgerReason.hike : LoyaltyLedgerReason.trail;
    final key = category == ActivityCategory.hikes
        ? LoyaltyKeys.hike(booking.id)
        : LoyaltyKeys.trail(booking.id);
    await _loyaltyService.credit(
      userId: booking.userId,
      amount: amount,
      reason: reason,
      idempotencyKey: key,
      now: now,
      bookingId: booking.id,
    );
  }

  Future<void> _accrueReferrals(DateTime now) async {
    final from = now.subtract(lookback);
    final attributions = await _onboardingRepository.listReferralAttributions();
    for (final attribution in attributions) {
      try {
        if (await _loyaltyService.hasEntry(LoyaltyKeys.referral(attribution.inviteeUserId))) {
          continue;
        }
        final bookings = await _bookingRepository.listUserBookings(
          attribution.inviteeUserId,
          limit: 200,
        );
        var qualifies = false;
        for (final booking in bookings) {
          if (booking.startsAt.isBefore(from) || booking.startsAt.isAfter(now)) {
            continue;
          }
          final category =
              _catalogService?.categoryForBooking(booking) ?? ActivityCategory.trainings;
          final peaksSpent = await _loyaltyService.peaksSpentOnBooking(booking.id);
          if (LoyaltyRules.qualifiesReferralInviteeTraining(
            booking: booking,
            now: now,
            peaksSpent: peaksSpent,
            category: category,
          )) {
            qualifies = true;
            break;
          }
        }
        if (!qualifies) {
          continue;
        }
        await _loyaltyService.credit(
          userId: attribution.inviterUserId,
          amount: LoyaltyMath.referralPeaks,
          reason: LoyaltyLedgerReason.referral,
          idempotencyKey: LoyaltyKeys.referral(attribution.inviteeUserId),
          now: now,
          inviteeUserId: attribution.inviteeUserId,
        );
      } on Object catch (error, stackTrace) {
        l.w(
          'Failed loyalty referral accrual for invitee ${attribution.inviteeUserId}: $error',
          stackTrace,
        );
      }
    }
  }
}
