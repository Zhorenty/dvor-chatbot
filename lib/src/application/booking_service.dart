import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

final class BookingService {
  const BookingService({
    required BookingRepository bookingRepository,
    required ActivityCatalogService catalogService,
  })  : _bookingRepository = bookingRepository,
        _catalogService = catalogService;

  final BookingRepository _bookingRepository;
  final ActivityCatalogService _catalogService;

  List<TrainingInfo> availableForCategory(ActivityCategory category) {
    return _catalogService.bookableItems(category);
  }

  Future<void> markReminderSent(int bookingId) {
    return _bookingRepository.markReminderSent(bookingId);
  }
}
