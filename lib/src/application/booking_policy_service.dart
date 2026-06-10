import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

enum ReschedulePaymentTypeViolation {
  freeToPaid,
  paidToFree,
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

  final ActivityCatalogService _catalogService;

  ActivityCategory categoryForBooking(TrainingBooking booking) {
    return _catalogService.categoryForBooking(booking);
  }

  bool isOutdoorCategory(ActivityCategory category) {
    return category == ActivityCategory.hikes || category == ActivityCategory.trails;
  }

  bool canReschedule(TrainingBooking booking) {
    return categoryForBooking(booking) == ActivityCategory.trainings;
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
  }

  bool canCancel(TrainingBooking booking, {required DateTime now}) {
    final category = categoryForBooking(booking);
    if (!isOutdoorCategory(category)) {
      return false;
    }
    return booking.startsAt.difference(now) >= const Duration(days: 7);
  }

  bool shouldShowOutdoorPaymentTypeChoice(TrainingBooking booking) {
    return isOutdoorCategory(categoryForBooking(booking));
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
}
