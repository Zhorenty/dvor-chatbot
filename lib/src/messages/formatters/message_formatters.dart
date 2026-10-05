import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_attendance.dart';
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
  static const String boxingCardIncludedPaymentNoteMarker = '__boxing_card_included__';
  static const String boxingCardLateCancelPaymentNoteMarker = '__boxing_card_late_cancel__';
  static const String dvorTeamFreePaymentNoteMarker = '__dvor_team_free__';
  static const String coachingStaffFreePaymentNoteMarker = '__coaching_staff_free__';
  static const String loyaltyPeaksPaymentNoteMarker = '__loyalty_peaks__';

  static bool isBoxingCardIncludedPaymentNote(String? paymentNote) {
    return paymentNote == boxingCardIncludedPaymentNoteMarker ||
        paymentNote == proIncludedTrainingPaymentNoteMarker;
  }

  static bool isBoxingCardLateCancelPaymentNote(String? paymentNote) {
    return paymentNote == boxingCardLateCancelPaymentNoteMarker;
  }

  static bool isBoxingCardPaymentNote(String? paymentNote) {
    return isBoxingCardIncludedPaymentNote(paymentNote) ||
        isBoxingCardLateCancelPaymentNote(paymentNote);
  }

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
    if (isBoxingCardIncludedPaymentNote(booking.paymentNote)) {
      return 'Включено в бокс-карту 🥊';
    }
    if (isBoxingCardLateCancelPaymentNote(booking.paymentNote)) {
      return 'Слот бокс-карты сгорел 🥊';
    }
    if (booking.paymentNote == dvorTeamFreePaymentNoteMarker) {
      return 'Бесплатно: команда DVOR 🖤';
    }
    if (booking.paymentNote == coachingStaffFreePaymentNoteMarker) {
      return 'Бесплатно: тренерский штаб';
    }
    if (booking.paymentNote == loyaltyPeaksPaymentNoteMarker) {
      return 'Оплачено вершинками ⛰️';
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

  static int? rosterPeaksUserId(TrainingBooking booking) {
    if (booking.participantType == BookingParticipantType.guest) {
      return null;
    }
    final userId = booking.participantUserId ?? booking.userId;
    if (userId <= 0) {
      return null;
    }
    return userId;
  }

  static String participantRosterLine(
    TrainingBooking booking, {
    int? peaksBalance,
    int? peaksSpent,
    int? peaksEarned,
  }) {
    final tag = userTag(booking);
    final status = participantStatusLabel(booking);
    final earned = peaksEarned != null && peaksEarned > 0 ? peaksEarned : 0;
    final showCash = _rosterShowsOutdoorRemainder(booking);
    final attendanceFact = _attendanceFact(booking.attendance);
    if (peaksBalance == null &&
        peaksSpent == null &&
        earned == 0 &&
        !showCash &&
        attendanceFact == null) {
      return '$tag ($status)';
    }

    final head = peaksBalance == null
        ? '$tag ($status)'
        : '$tag ($status, баланс вершинок: $peaksBalance ⛰️)';
    final facts = <String>[];
    if (showCash) {
      final split = outdoorCashAfterPeaks(
        priceRub: booking.trainingPrice ?? 0,
        prepayPercent: booking.trainingPrepayPercent,
        peaksSpent: peaksSpent ?? 0,
      );
      facts.add('предоплата ${_groupedAmount(split.prepayRub)} ₽');
      final spendFact = _rosterSpendFact(peaksSpent);
      if (spendFact != null) {
        facts.add(spendFact);
      }
      facts.add('остаток ${_groupedAmount(split.remainderRub)} ₽');
    } else {
      final spendFact = _rosterSpendFact(peaksSpent);
      if (spendFact != null) {
        facts.add(spendFact);
      }
    }
    if (earned > 0) {
      facts.add('начислено ${_groupedAmount(earned)} ⛰️');
    }
    if (attendanceFact != null) {
      facts.add(attendanceFact);
    }
    if (facts.isEmpty) {
      return head;
    }
    return '$head — ${facts.join(', ')}';
  }

  /// Prepayment stays the transfer. Peaks come off the offline remainder only.
  static ({int prepayRub, int remainderRub}) outdoorCashAfterPeaks({
    required int priceRub,
    required int? prepayPercent,
    required int peaksSpent,
  }) {
    if (priceRub <= 0) {
      return (prepayRub: 0, remainderRub: 0);
    }
    final prepay = outdoorPrepaymentAmount(priceRub, prepayPercent: prepayPercent);
    final grossRemainder = priceRub - prepay;
    final fromPeaks = peaksSpent <= 0 ? 0 : peaksSpent ~/ LoyaltyMath.peaksPerRub;
    final remainder = grossRemainder - fromPeaks;
    return (
      prepayRub: prepay,
      remainderRub: remainder < 0 ? 0 : remainder,
    );
  }

  static bool _rosterShowsOutdoorRemainder(TrainingBooking booking) {
    final price = booking.trainingPrice;
    if (price == null || price <= 0 || !isOutdoorBooking(booking)) {
      return false;
    }
    return switch (booking.status) {
      BookingStatus.pendingPayment ||
      BookingStatus.paymentSubmitted ||
      BookingStatus.partialPaid ||
      BookingStatus.paymentRejected =>
        true,
      BookingStatus.paid || BookingStatus.freeTraining || BookingStatus.cancelled => false,
    };
  }

  static String? _attendanceFact(BookingAttendance? attendance) {
    return switch (attendance) {
      BookingAttendance.attended => 'явка: был',
      BookingAttendance.absent => 'явка: не был',
      null => null,
    };
  }

  static String? _rosterSpendFact(int? peaksSpent) {
    if (peaksSpent == null) {
      return null;
    }
    if (peaksSpent > 0) {
      return 'списано ${_groupedAmount(peaksSpent)} ⛰️';
    }
    return 'без списания';
  }

  static String _groupedAmount(int amount) {
    final negative = amount < 0;
    final digits = (negative ? -amount : amount).toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      if (index > 0 && remaining % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
    }
    if (negative) {
      return '-$buffer';
    }
    return buffer.toString();
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
