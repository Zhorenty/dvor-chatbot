import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';

final class PaymentReviewService {
  const PaymentReviewService({
    required BookingRepository bookingRepository,
    required ActivityCatalogService catalogService,
  })  : _bookingRepository = bookingRepository,
        _catalogService = catalogService;

  final BookingRepository _bookingRepository;
  final ActivityCatalogService _catalogService;

  Future<List<TrainingBooking>> queueByCategory(ActivityCategory category) async {
    final queue = await _bookingRepository.listByStatus(BookingStatus.paymentSubmitted);
    return queue
        .where((booking) => _catalogService.categoryForBooking(booking) == category)
        .toList(growable: false);
  }
}
