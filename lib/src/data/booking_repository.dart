import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

abstract interface class BookingRepository {
  Future<void> init();

  Future<void> close();

  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    required TrainingInfo training,
  });

  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10});

  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    String? note,
  });

  Future<List<TrainingBooking>> listByStatus(
    BookingStatus status, {
    int limit = 20,
  });

  Future<TrainingBooking?> updateStatus(
    int bookingId,
    BookingStatus status,
  );

  Future<List<TrainingBooking>> listPendingPaymentForReminder({
    required DateTime createdBefore,
    required DateTime remindedBefore,
    int limit = 20,
  });

  Future<void> markReminderSent(int bookingId);
}
