import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/boxing_title.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';

/// Quota, 24h transfer/cancel, and period window for DVOR BOXING CARD.
final class BoxingCardLedger {
  const BoxingCardLedger._();

  static const Duration periodDuration = Duration(days: 30);
  static const Duration transferCutoff = Duration(hours: 24);

  static DateTime periodStart(SubscriptionMembership membership, {required DateTime now}) {
    final activeFrom = membership.activeFrom;
    if (activeFrom != null) {
      return activeFrom;
    }
    final activeUntil = membership.activeUntil;
    if (activeUntil != null) {
      return activeUntil.subtract(periodDuration);
    }
    return now;
  }

  static DateTime? periodEnd(SubscriptionMembership membership) => membership.activeUntil;

  static bool isActiveBoxingCard(SubscriptionMembership membership, {required DateTime now}) {
    if (membership.level != MembershipLevel.boxingCard || membership.plan == null) {
      return false;
    }
    final until = membership.activeUntil;
    if (until == null) {
      return false;
    }
    return until.isAfter(now);
  }

  static int usedGroupSlots({
    required List<TrainingBooking> bookings,
    required int userId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return bookings.where((booking) {
      if (booking.userId != userId) {
        return false;
      }
      if (!isBoxingTrainingTitle(booking.trainingTitle)) {
        return false;
      }
      if (booking.startsAt.isBefore(periodStart) || !booking.startsAt.isBefore(periodEnd)) {
        return false;
      }
      if (MessageFormatters.isBoxingCardLateCancelPaymentNote(booking.paymentNote)) {
        return true;
      }
      return booking.status == BookingStatus.paid &&
          MessageFormatters.isBoxingCardIncludedPaymentNote(booking.paymentNote);
    }).length;
  }

  static int remainingGroupSlots({
    required BoxingCardPlan plan,
    required int used,
  }) {
    final remaining = plan.groupQuota - used;
    return remaining < 0 ? 0 : remaining;
  }

  static bool burnsSlotOnCancel(TrainingBooking booking, {required DateTime now}) {
    return booking.startsAt.difference(now) < transferCutoff;
  }

  static bool canReschedule(TrainingBooking booking, {required DateTime now}) {
    return !booking.startsAt.isBefore(now) && booking.startsAt.difference(now) >= transferCutoff;
  }

  static bool isAllowedRescheduleTarget(TrainingInfo training) {
    return isBoxingTrainingTitle(training.title);
  }

  static bool trainingStartsInsidePeriod({
    required TrainingInfo training,
    required SubscriptionMembership membership,
  }) {
    final until = membership.activeUntil;
    if (until == null) {
      return false;
    }
    final from = membership.activeFrom ?? until.subtract(periodDuration);
    return !training.startsAt.isBefore(from) && training.startsAt.isBefore(until);
  }
}
