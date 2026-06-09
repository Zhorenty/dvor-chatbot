import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';

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
}
