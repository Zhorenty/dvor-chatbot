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
    return _dedupePaymentGroups(queue)
        .where((booking) => _catalogService.categoryForBooking(booking) == category)
        .toList(growable: false);
  }

  Future<PaymentQueueCounters> queueCounters() async {
    final queue = await _bookingRepository.listByStatus(
      BookingStatus.paymentSubmitted,
      limit: _queueFetchLimit,
    );
    final deduped = _dedupePaymentGroups(queue);
    var trainings = 0;
    var yoga = 0;
    var hikes = 0;
    var trails = 0;
    for (final booking in deduped) {
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
      total: deduped.length,
      trainings: trainings,
      yoga: yoga,
      hikes: hikes,
      trails: trails,
    );
  }

  List<TrainingBooking> _dedupePaymentGroups(List<TrainingBooking> queue) {
    final seenGroups = <String>{};
    final result = <TrainingBooking>[];
    for (final booking in queue) {
      final groupId = booking.paymentGroupId?.trim();
      if (groupId != null && groupId.isNotEmpty) {
        if (!seenGroups.add(groupId)) {
          continue;
        }
      }
      result.add(booking);
    }
    return result;
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
