import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';

typedef NobleUserStats = ({int userId, String? username, int trainingsCount});

final class NoblesListService {
  const NoblesListService({
    required BookingRepository bookingRepository,
    required ActivityCatalogService catalogService,
    DateTime Function()? nowProvider,
  })  : _bookingRepository = bookingRepository,
        _catalogService = catalogService,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final ActivityCatalogService _catalogService;
  final DateTime Function() _nowProvider;

  Future<({List<NobleUserStats> users, int totalTrainings})> buildStats() async {
    final now = _nowProvider();
    final statusBatches = await Future.wait(<Future<List<TrainingBooking>>>[
      _bookingRepository.listByStatus(BookingStatus.pendingPayment, limit: 1000),
      _bookingRepository.listByStatus(BookingStatus.paymentSubmitted, limit: 1000),
      _bookingRepository.listByStatus(BookingStatus.paid, limit: 1000),
      _bookingRepository.listByStatus(BookingStatus.paymentRejected, limit: 1000),
    ]);
    final allBookings = statusBatches.expand((items) => items);
    final aggregated = <int, NobleUserStats>{};
    var totalTrainings = 0;

    for (final booking in allBookings) {
      if (_catalogService.categoryForBooking(booking) != ActivityCategory.trainings) {
        continue;
      }
      if (!booking.startsAt.isBefore(now)) {
        continue;
      }
      totalTrainings += 1;
      final current = aggregated[booking.userId];
      aggregated[booking.userId] = (
        userId: booking.userId,
        username: booking.userUsername ?? current?.username,
        trainingsCount: (current?.trainingsCount ?? 0) + 1,
      );
    }

    final users = aggregated.values.toList(growable: false)
      ..sort(
        (left, right) => right.trainingsCount != left.trainingsCount
            ? right.trainingsCount.compareTo(left.trainingsCount)
            : left.userId.compareTo(right.userId),
      );
    return (users: users, totalTrainings: totalTrainings);
  }
}
