import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';

final class PaymentReviewService {
  static const int _queueFetchLimit = 1000;

  const PaymentReviewService({
    required BookingRepository bookingRepository,
    required ActivityCatalogService catalogService,
  })  : _bookingRepository = bookingRepository,
        _catalogService = catalogService;

  final BookingRepository _bookingRepository;
  final ActivityCatalogService _catalogService;

  Future<List<TrainingBooking>> queueByCategory(ActivityCategory category) async {
    final queue = await _bookingRepository.listByStatus(
      BookingStatus.paymentSubmitted,
      limit: _queueFetchLimit,
    );
    return queue
        .where((booking) => _catalogService.categoryForBooking(booking) == category)
        .toList(growable: false);
  }

  Future<PaymentQueueCounters> queueCounters() async {
    final queue = await _bookingRepository.listByStatus(
      BookingStatus.paymentSubmitted,
      limit: _queueFetchLimit,
    );
    var trainings = 0;
    var yoga = 0;
    var hikes = 0;
    var trails = 0;
    for (final booking in queue) {
      switch (_catalogService.categoryForBooking(booking)) {
        case ActivityCategory.trainings:
          trainings++;
        case ActivityCategory.yoga:
          yoga++;
        case ActivityCategory.hikes:
          hikes++;
        case ActivityCategory.trails:
          trails++;
      }
    }
    return PaymentQueueCounters(
      total: queue.length,
      trainings: trainings,
      yoga: yoga,
      hikes: hikes,
      trails: trails,
    );
  }
}

final class PaymentQueueCounters {
  const PaymentQueueCounters({
    required this.total,
    required this.trainings,
    required this.yoga,
    required this.hikes,
    required this.trails,
  });

  final int total;
  final int trainings;
  final int yoga;
  final int hikes;
  final int trails;
}
