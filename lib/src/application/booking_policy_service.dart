import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';

enum ReschedulePaymentTypeViolation {
  freeToPaid,
  paidToFree,
  priceMismatch,
}

final class ReschedulePaymentTypeViolationException implements Exception {
  const ReschedulePaymentTypeViolationException(this.violation);

  final ReschedulePaymentTypeViolation violation;

  @override
  String toString() {
    return 'ReschedulePaymentTypeViolationException: $violation';
  }
}

final class BookingPolicyService {
  const BookingPolicyService({
    required ActivityCatalogService catalogService,
  }) : _catalogService = catalogService;

  static const Duration paidTrainingCancelLead = Duration(hours: 24);

  final ActivityCatalogService _catalogService;

  ActivityCategory categoryForBooking(TrainingBooking booking) {
    return _catalogService.categoryForBooking(booking);
  }

  bool isOutdoorCategory(ActivityCategory category) {
    return category == ActivityCategory.hikes || category == ActivityCategory.trails;
  }

  bool supportsCancellation(ActivityCategory category) {
    return isOutdoorCategory(category);
  }

  bool supportsCancellationForBooking(TrainingBooking booking) {
    final category = categoryForBooking(booking);
    if (supportsCancellation(category)) {
      return true;
    }
    if (category != ActivityCategory.trainings) {
      return false;
    }
    return _isCancellableFreeTraining(booking) ||
        MessageFormatters.isBoxingCardPaymentNote(booking.paymentNote) ||
        isPeaksRefundTraining(booking);
  }

  bool canReschedule(TrainingBooking booking) {
    final category = categoryForBooking(booking);
    return category == ActivityCategory.trainings;
  }

  void ensureReschedulePaymentTypeAllowed({
    required TrainingBooking booking,
    required TrainingInfo targetTraining,
  }) {
    final bookingIsFree = _isFreeBooking(booking);
    final targetIsFree = _isFreeActivity(targetTraining);
    if (bookingIsFree && !targetIsFree) {
      throw const ReschedulePaymentTypeViolationException(
        ReschedulePaymentTypeViolation.freeToPaid,
      );
    }
    if (!bookingIsFree && targetIsFree) {
      throw const ReschedulePaymentTypeViolationException(
        ReschedulePaymentTypeViolation.paidToFree,
      );
    }
    final bookingPrice = _normalizedBookingPrice(booking);
    final targetPrice = targetTraining.price;
    if (bookingPrice != targetPrice) {
      throw const ReschedulePaymentTypeViolationException(
        ReschedulePaymentTypeViolation.priceMismatch,
      );
    }
  }

  bool canCancel(TrainingBooking booking, {required DateTime now}) {
    if (!supportsCancellationForBooking(booking)) {
      return false;
    }
    final category = categoryForBooking(booking);
    if (isPeaksRefundTraining(booking)) {
      return booking.startsAt.difference(now) >= paidTrainingCancelLead;
    }
    // Free trainings (incl. bonus/promo) can be cancelled at any time.
    if (category == ActivityCategory.trainings && _isCancellableFreeTraining(booking)) {
      return true;
    }
    if (category == ActivityCategory.trainings &&
        MessageFormatters.isBoxingCardPaymentNote(booking.paymentNote)) {
      return !booking.startsAt.isBefore(now);
    }
    if (isOutdoorCategory(category)) {
      return booking.startsAt.difference(now) >= const Duration(days: 7);
    }
    return false;
  }

  /// Paid training (cash or peaks), not a free slot and not a boxing-card burn.
  bool isPeaksRefundTraining(TrainingBooking booking) {
    if (categoryForBooking(booking) != ActivityCategory.trainings) {
      return false;
    }
    if (MessageFormatters.isBoxingCardPaymentNote(booking.paymentNote)) {
      return false;
    }
    if (_isCancellableFreeTraining(booking)) {
      return false;
    }
    return booking.status == BookingStatus.paid && (booking.trainingPrice ?? 0) > 0;
  }

  /// Cash portion of a paid training, converted at 2 ⛰️ = 1 ₽ and rounded up to 10.
  int cashCancelRefundPeaks(TrainingBooking booking, {required int peaksSpent}) {
    if (!isPeaksRefundTraining(booking)) {
      return 0;
    }
    final remainder = LoyaltyMath.remainderRub(
      priceRub: booking.trainingPrice ?? 0,
      peaksSpent: peaksSpent,
    );
    return LoyaltyMath.roundUp(LoyaltyMath.fullPayPeaks(remainder));
  }

  bool shouldShowOutdoorPaymentTypeChoice(TrainingBooking booking) {
    return isOutdoorCategory(categoryForBooking(booking)) &&
        (booking.status == BookingStatus.pendingPayment ||
            booking.status == BookingStatus.paymentRejected);
  }

  bool _isFreeActivity(TrainingInfo training) {
    final price = training.price;
    return price != null && price <= 0;
  }

  bool _isFreeBooking(TrainingBooking booking) {
    if (booking.status == BookingStatus.freeTraining) {
      return true;
    }
    final price = booking.trainingPrice;
    return price != null && price <= 0;
  }

  bool _isCancellableFreeTraining(TrainingBooking booking) {
    return _isFreeBooking(booking) || MessageFormatters.isBonusPaymentNote(booking.paymentNote);
  }

  int? _normalizedBookingPrice(TrainingBooking booking) {
    if (booking.status == BookingStatus.freeTraining) {
      return 0;
    }
    return booking.trainingPrice;
  }
}
