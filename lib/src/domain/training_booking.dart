import 'package:dvor_chatbot/src/domain/booking_participant.dart';
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
    required this.trainingPrice,
    required this.createdAt,
    required this.updatedAt,
    this.paymentNote,
    this.paymentProofChatId,
    this.paymentProofMessageId,
    this.promoCode,
    this.promoDiscountPercent,
    int? managerUserId,
    this.participantType = BookingParticipantType.self,
    int? participantUserId,
    this.participantUsername,
    this.participantName,
    this.paymentGroupId,
  })  : managerUserId = managerUserId ?? userId,
        participantUserId =
            participantUserId ?? (participantType == BookingParticipantType.guest ? null : userId);

  final int id;

  /// Manager / payer identity (legacy column `user_id`).
  final int userId;
  final String? userUsername;
  final String trainingKey;
  final String trainingTitle;
  final DateTime startsAt;
  final String location;
  final BookingStatus status;
  final int? trainingPrice;
  final String? paymentNote;
  final int? paymentProofChatId;
  final int? paymentProofMessageId;
  final String? promoCode;
  final int? promoDiscountPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int managerUserId;
  final BookingParticipantType participantType;
  final int? participantUserId;
  final String? participantUsername;
  final String? participantName;
  final String? paymentGroupId;

  bool get isManagedForOther =>
      participantType != BookingParticipantType.self ||
      (participantUserId != null && participantUserId != managerUserId);

  String get participantDisplayLabel {
    return switch (participantType) {
      BookingParticipantType.guest =>
        (participantName?.trim().isNotEmpty == true) ? participantName!.trim() : 'Гость',
      BookingParticipantType.telegram => _usernameLabel(participantUsername ?? userUsername),
      BookingParticipantType.self => _usernameLabel(userUsername, fallbackUserId: managerUserId),
    };
  }

  static String _usernameLabel(String? username, {int? fallbackUserId}) {
    final normalized = username?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return '@${normalized.startsWith('@') ? normalized.substring(1) : normalized}';
    }
    if (fallbackUserId != null) {
      return 'tg://user?id=$fallbackUserId';
    }
    return 'участник';
  }
}

final class BookingCreateResult {
  const BookingCreateResult({
    required this.booking,
    required this.created,
  });

  final TrainingBooking booking;
  final bool created;
}

final class BookingGroupCreateResult {
  const BookingGroupCreateResult({
    required this.paymentGroupId,
    required this.bookings,
  });

  final String paymentGroupId;
  final List<TrainingBooking> bookings;

  int get totalPrice {
    var sum = 0;
    for (final booking in bookings) {
      sum += booking.trainingPrice ?? 0;
    }
    return sum;
  }
}

enum BookingActionOutcome {
  success,
  notFound,
}

final class BookingActionResult {
  const BookingActionResult({
    required this.outcome,
    this.booking,
  });

  final BookingActionOutcome outcome;
  final TrainingBooking? booking;
}

enum BookingRescheduleOutcome {
  success,
  notFound,
  conflict,
}

final class BookingRescheduleResult {
  const BookingRescheduleResult({
    required this.outcome,
    this.booking,
  });

  final BookingRescheduleOutcome outcome;
  final TrainingBooking? booking;
}
