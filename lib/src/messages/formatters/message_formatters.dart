import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:intl/intl.dart';

final class MessageFormatters {
  const MessageFormatters._();
  static const String starterBonusPaymentNoteMarker = '__starter_bonus__';

  static String statusLabel(BookingStatus status) {
    return switch (status) {
      BookingStatus.pendingPayment => 'Ожидает оплату',
      BookingStatus.paymentSubmitted => 'Оплата на проверке 👀',
      BookingStatus.paid => 'Оплачено ✅',
      BookingStatus.paymentRejected => 'Оплата отклонена ❌',
      BookingStatus.cancelled => 'Отменено',
    };
  }

  static String participantStatusLabel(TrainingBooking booking) {
    if (booking.status == BookingStatus.paid &&
        booking.paymentNote == starterBonusPaymentNoteMarker) {
      return 'Бесплатная тренировка 🎁';
    }
    return statusLabel(booking.status);
  }

  static String userTag(TrainingBooking booking) {
    return userTagById(booking.userId, username: booking.userUsername);
  }

  static String userTagById(int userId, {String? username}) {
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      return '@${normalizedUsername.startsWith('@') ? normalizedUsername.substring(1) : normalizedUsername}';
    }
    return 'tg://user?id=$userId';
  }

  static String trainingPriceLabel(int? price) {
    if (price == null || price <= 0) {
      return 'бесплатная';
    }
    return '$price ₽';
  }

  static String outdoorDateLabel(
    DateTime from,
    DateTime to, {
    String pattern = 'dd.MM.yyyy',
    String separator = ' — ',
  }) {
    final formatter = DateFormat(pattern);
    final isOneDay = from.year == to.year && from.month == to.month && from.day == to.day;
    if (isOneDay) {
      return formatter.format(from);
    }
    return '${formatter.format(from)}$separator${formatter.format(to)}';
  }

  static String bookingDateLabel(
    TrainingBooking booking,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    if (_isOutdoorBooking(booking.trainingTitle)) {
      return dateOnlyFormatter.format(booking.startsAt);
    }
    return dateTimeFormatter.format(booking.startsAt);
  }

  static bool _isOutdoorBooking(String title) {
    return title.startsWith('🥾 Поход:') || title.startsWith('🏃 Трейл:');
  }
}
