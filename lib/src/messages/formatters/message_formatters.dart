import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:intl/intl.dart';

final class MessageFormatters {
  const MessageFormatters._();
  static const String starterBonusPaymentNoteMarker = '__starter_bonus__';
  static const String everyFifthBonusPaymentNoteMarker = '__every_fifth_bonus__';

  static String statusLabel(BookingStatus status) {
    return switch (status) {
      BookingStatus.pendingPayment => 'Ожидает оплату',
      BookingStatus.paymentSubmitted => 'Оплата на проверке 👀',
      BookingStatus.paid => 'Оплачено ✅',
      BookingStatus.freeTraining => 'Бесплатная тренировка 🎁',
      BookingStatus.paymentRejected => 'Оплата отклонена ❌',
      BookingStatus.cancelled => 'Отменено',
    };
  }

  static String participantStatusLabel(TrainingBooking booking) {
    return bookingStatusLabel(booking);
  }

  static String bookingStatusLabel(TrainingBooking booking) {
    if (booking.status != BookingStatus.paid) {
      return statusLabel(booking.status);
    }

    if (booking.paymentNote == starterBonusPaymentNoteMarker) {
      return 'Бесплатно: стартовая тренировка 🎁';
    }
    if (booking.paymentNote == everyFifthBonusPaymentNoteMarker) {
      return 'Бесплатно: каждая 5-я тренировка 🎁';
    }
    final price = booking.trainingPrice;
    if (price != null && price <= 0) {
      return 'Бесплатно';
    }
    return statusLabel(booking.status);
  }

  static bool isBonusPaymentNote(String? paymentNote) {
    return paymentNote == starterBonusPaymentNoteMarker ||
        paymentNote == everyFifthBonusPaymentNoteMarker;
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
    if (isOutdoorBooking(booking)) {
      return dateOnlyFormatter.format(booking.startsAt);
    }
    return dateTimeFormatter.format(booking.startsAt);
  }

  static String trainingDateLabel(
    TrainingInfo training,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    if (_isOutdoorCategory(training.category)) {
      return dateOnlyFormatter.format(training.startsAt);
    }
    return dateTimeFormatter.format(training.startsAt);
  }

  static bool isOutdoorBooking(TrainingBooking booking) {
    final trainingKey = booking.trainingKey.toLowerCase();
    if (trainingKey.startsWith('hikes|') || trainingKey.startsWith('trails|')) {
      return true;
    }
    return _isOutdoorBookingTitle(booking.trainingTitle);
  }

  static bool _isOutdoorCategory(ActivityCategory category) {
    return category == ActivityCategory.hikes || category == ActivityCategory.trails;
  }

  static bool _isOutdoorBookingTitle(String title) {
    return title.startsWith('🥾 Поход:') || title.startsWith('🏃 Трейл:');
  }
}
