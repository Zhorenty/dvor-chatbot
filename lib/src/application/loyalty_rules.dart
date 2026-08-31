import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_participant.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';

/// Qualification for earning вершинки. Spend rules live in [LoyaltyMath].
abstract final class LoyaltyRules {
  static const List<String> excludedTrainingPaymentNotes = <String>[
    MessageFormatters.starterBonusPaymentNoteMarker,
    MessageFormatters.everyFifthBonusPaymentNoteMarker,
    MessageFormatters.referralBonusPaymentNoteMarker,
    MessageFormatters.proIncludedTrainingPaymentNoteMarker,
    MessageFormatters.boxingCardIncludedPaymentNoteMarker,
    MessageFormatters.boxingCardLateCancelPaymentNoteMarker,
    MessageFormatters.dvorTeamFreePaymentNoteMarker,
    MessageFormatters.loyaltyPeaksPaymentNoteMarker,
  ];

  static bool isExcludedTrainingPaymentNote(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return false;
    }
    return excludedTrainingPaymentNotes.contains(paymentNote);
  }

  static bool isTrainerStaffBooking(TrainingBooking booking) {
    if (booking.participantType == BookingParticipantType.guest) {
      return false;
    }
    final participantUserId = booking.participantUserId ?? booking.userId;
    final participantUsername = booking.participantUsername ?? booking.userUsername;
    return isTrainerBookingWhitelisted(
      userId: participantUserId,
      username: participantUsername,
    );
  }

  static bool isSelfBooking(TrainingBooking booking) {
    return booking.participantType == BookingParticipantType.self;
  }

  static bool canEarnTraining({
    required TrainingBooking booking,
    required DateTime now,
    required int peaksSpent,
  }) {
    if (!isSelfBooking(booking)) {
      return false;
    }
    if (booking.status != BookingStatus.paid) {
      return false;
    }
    if (!booking.startsAt.isBefore(now)) {
      return false;
    }
    if (isExcludedTrainingPaymentNote(booking.paymentNote)) {
      return false;
    }
    if (isTrainerStaffBooking(booking)) {
      return false;
    }
    final remainder = LoyaltyMath.remainderRub(
      priceRub: booking.trainingPrice ?? 0,
      peaksSpent: peaksSpent,
    );
    return remainder > 0;
  }

  static bool canEarnOutdoor({
    required TrainingBooking booking,
    required DateTime now,
    required DateTime eventEndedAt,
    required int peaksSpent,
  }) {
    if (!isSelfBooking(booking)) {
      return false;
    }
    if (booking.status != BookingStatus.paid && booking.status != BookingStatus.partialPaid) {
      return false;
    }
    if (eventEndedAt.isAfter(now)) {
      return false;
    }
    if (isExcludedTrainingPaymentNote(booking.paymentNote)) {
      return false;
    }
    return outdoorPaidRub(booking: booking, peaksSpent: peaksSpent) > 0;
  }

  static int outdoorPaidRub({
    required TrainingBooking booking,
    required int peaksSpent,
  }) {
    final price = booking.trainingPrice ?? 0;
    if (price <= 0) {
      return 0;
    }
    final remainder = LoyaltyMath.remainderRub(priceRub: price, peaksSpent: peaksSpent);
    if (booking.status == BookingStatus.partialPaid) {
      final prepay = MessageFormatters.outdoorPrepaymentAmount(
        price,
        prepayPercent: booking.trainingPrepayPercent,
      );
      final cash = prepay - (peaksSpent ~/ LoyaltyMath.peaksPerRub);
      if (cash <= 0) {
        return 0;
      }
      return cash > remainder ? remainder : cash;
    }
    return remainder;
  }

  static bool qualifiesReferralInviteeTraining({
    required TrainingBooking booking,
    required DateTime now,
    required int peaksSpent,
    required ActivityCategory category,
  }) {
    if (category != ActivityCategory.trainings) {
      return false;
    }
    if (!canEarnTraining(booking: booking, now: now, peaksSpent: peaksSpent)) {
      return false;
    }
    // 100% вершинками: remainder 0 — already excluded by canEarnTraining.
    return true;
  }

  static bool canSpendOnSlot({
    required bool promoRestricted,
    required bool isFree,
    required bool isStaffOrTeam,
  }) {
    if (promoRestricted || isFree || isStaffOrTeam) {
      return false;
    }
    return true;
  }
}
