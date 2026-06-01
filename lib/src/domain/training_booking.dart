import 'package:dvor_chatbot/src/domain/booking_status.dart';

final class TrainingBooking {
  const TrainingBooking({
    required this.id,
    required this.userId,
    required this.userUsername,
    required this.trainingKey,
    required this.trainingTitle,
    required this.startsAt,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paymentNote,
  });

  final int id;
  final int userId;
  final String? userUsername;
  final String trainingKey;
  final String trainingTitle;
  final DateTime startsAt;
  final String location;
  final BookingStatus status;
  final String? paymentNote;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class BookingCreateResult {
  const BookingCreateResult({
    required this.booking,
    required this.created,
  });

  final TrainingBooking booking;
  final bool created;
}
