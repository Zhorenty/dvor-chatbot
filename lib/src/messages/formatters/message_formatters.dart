import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_participant.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:intl/intl.dart';

final class MessageFormatters {
  const MessageFormatters._();
  static const String starterBonusPaymentNoteMarker = '__starter_bonus__';
  static const String everyFifthBonusPaymentNoteMarker = '__every_fifth_bonus__';
  static const String referralBonusPaymentNoteMarker = '__referral_bonus__';
  static const String proIncludedTrainingPaymentNoteMarker = '__pro_included_training__';
  static const String dvorTeamFreePaymentNoteMarker = '__dvor_team_free__';

  static String statusLabel(BookingStatus status) {
    return switch (status) {
      BookingStatus.pendingPayment => 'Ожидает оплату ⏳',
      BookingStatus.paymentSubmitted => 'На проверке 🧾',
      BookingStatus.partialPaid => 'Предоплата внесена 🟡',
      BookingStatus.paid => 'Оплачено ✅',
      BookingStatus.freeTraining => 'Бесплатная тренировка 🎁',
      BookingStatus.paymentRejected => 'Оплата отклонена ❌',
      BookingStatus.cancelled => 'Отменено ❌',
    };
  }

  static String participantStatusLabel(TrainingBooking booking) {
    if (booking.status == BookingStatus.cancelled) {
      return 'Отменено ❌';
    }
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
    if (booking.paymentNote == referralBonusPaymentNoteMarker) {
      return 'Бесплатно: реферальная тренировка 🎁';
    }
    if (booking.paymentNote == proIncludedTrainingPaymentNoteMarker) {
      return 'Включено в PRO (из 8 тренировок) 💎';
    }
    if (booking.paymentNote == dvorTeamFreePaymentNoteMarker) {
      return 'Бесплатно: команда DVOR 🖤';
    }
    final price = booking.trainingPrice;
    if (price != null && price <= 0) {
      final promoCode = booking.promoCode;
      if (promoCode != null && promoCode.isNotEmpty) {
        return 'Бесплатно: промокод $promoCode 🎟';
      }
      return 'Бесплатно 🎁';
    }
    return statusLabel(booking.status);
  }

  static bool isBonusPaymentNote(String? paymentNote) {
    return paymentNote == starterBonusPaymentNoteMarker ||
        paymentNote == everyFifthBonusPaymentNoteMarker ||
        paymentNote == referralBonusPaymentNoteMarker;
  }

  static String userTag(TrainingBooking booking) {
    if (booking.participantType == BookingParticipantType.guest) {
      return booking.participantDisplayLabel;
    }
    final participantUsername = booking.participantUsername ?? booking.userUsername;
    final participantUserId = booking.participantUserId ?? booking.userId;
    final tag = userTagById(participantUserId, username: participantUsername);
    if (booking.isManagedForOther &&
        booking.managerUserId != (booking.participantUserId ?? booking.managerUserId)) {
      final managerTag = userTagById(booking.managerUserId, username: booking.userUsername);
      return '$tag (через $managerTag)';
    }
    return tag;
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

  static const int defaultOutdoorPrepayPercent = 50;

  static int resolveOutdoorPrepayPercent(int? percent) {
    if (percent == null || percent < 1 || percent > 100) {
      return defaultOutdoorPrepayPercent;
    }
    return percent;
  }

  static int outdoorPrepaymentAmount(int price, {int? prepayPercent}) {
    final percent = resolveOutdoorPrepayPercent(prepayPercent);
    return (price * percent / 100).ceil();
  }

  static int outdoorRemainderPercent(int? prepayPercent) {
    return 100 - resolveOutdoorPrepayPercent(prepayPercent);
  }

  static String outdoorDateLabel(
    DateTime from,
    DateTime to, {
    String pattern = 'dd.MM.yyyy',
  }) {
    final formatter = DateFormat(pattern);
    final isOneDay = from.year == to.year && from.month == to.month && from.day == to.day;
    if (isOneDay) {
      return formatter.format(from);
    }
    return 'от ${formatter.format(from)} до ${formatter.format(to)}';
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
      final endsAt = training.endsAt;
      if (endsAt != null) {
        return outdoorDateLabel(training.startsAt, endsAt);
      }
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
