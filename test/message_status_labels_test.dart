import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('MessageFormatters.bookingStatusLabel', () {
    test('maps explicit free training status to free label', () {
      final freeTraining = fakeBooking(status: BookingStatus.freeTraining);
      expect(MessageFormatters.bookingStatusLabel(freeTraining), 'Бесплатная тренировка 🎁');
    });

    test('maps free booking variants to distinct labels', () {
      final regularFree = fakeBooking(
        status: BookingStatus.paid,
        trainingPrice: 0,
      );
      final starterFree = fakeBooking(
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
        trainingPrice: 700,
      );
      final everyFifthFree = fakeBooking(
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
        trainingPrice: 700,
      );
      final referralFree = fakeBooking(
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.referralBonusPaymentNoteMarker,
        trainingPrice: 700,
      );
      final coachingStaffFree = fakeBooking(
        userUsername: 'coach',
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.coachingStaffFreePaymentNoteMarker,
        trainingPrice: 700,
      );
      final dvorTeamFree = fakeBooking(
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.dvorTeamFreePaymentNoteMarker,
        trainingPrice: 700,
      );

      expect(MessageFormatters.bookingStatusLabel(regularFree), 'Бесплатно 🎁');
      expect(
        MessageFormatters.bookingStatusLabel(starterFree),
        'Бесплатно: стартовая тренировка 🎁',
      );
      expect(
        MessageFormatters.bookingStatusLabel(everyFifthFree),
        'Бесплатно: каждая 5-я тренировка 🎁',
      );
      expect(
        MessageFormatters.bookingStatusLabel(referralFree),
        'Бесплатно: реферальная тренировка 🎁',
      );
      expect(
        MessageFormatters.bookingStatusLabel(dvorTeamFree),
        'Бесплатно: команда DVOR 🖤',
      );
      expect(
        MessageFormatters.bookingStatusLabel(coachingStaffFree),
        'Бесплатно: тренерский штаб',
      );
      expect(
        MessageFormatters.participantRosterLine(coachingStaffFree, peaksBalance: 1250),
        '@coach (Бесплатно: тренерский штаб, баланс вершинок: 1250 ⛰️)',
      );
      expect(
        MessageFormatters.participantRosterLine(
          coachingStaffFree,
          peaksBalance: 1250,
          peaksSpent: 0,
        ),
        '@coach (Бесплатно: тренерский штаб, баланс вершинок: 1250 ⛰️) — без списания',
      );
    });

    test('shows outdoor prepay and remainder after peaks on the roster', () {
      final hike = fakeBooking(
        userUsername: 'hiker',
        trainingKey: 'hikes|elbrus',
        title: '🥾 Поход: Эльбрус',
        status: BookingStatus.partialPaid,
        trainingPrice: 18000,
        trainingPrepayPercent: 40,
      );

      expect(
        MessageFormatters.outdoorCashAfterPeaks(
          priceRub: 18000,
          prepayPercent: 40,
          peaksSpent: 1000,
        ),
        (prepayRub: 7200, remainderRub: 10300),
      );
      expect(
        MessageFormatters.participantRosterLine(
          hike,
          peaksBalance: 200,
          peaksSpent: 1000,
        ),
        '@hiker (Предоплата внесена 🟡, баланс вершинок: 200 ⛰️) — '
        'предоплата 7 200 ₽, списано 1 000 ⛰️, остаток 10 300 ₽',
      );
    });

    test('separates a boxing accrual from a spend on the roster', () {
      final boxing = fakeBooking(
        userUsername: 'boxer',
        title: 'Бокс',
        status: BookingStatus.paid,
        trainingPrice: 500,
      );

      expect(
        MessageFormatters.participantRosterLine(
          boxing,
          peaksBalance: 200,
          peaksSpent: 0,
          peaksEarned: 200,
        ),
        '@boxer (Оплачено ✅, баланс вершинок: 200 ⛰️) — без списания, начислено 200 ⛰️',
      );
    });

    test('maps promo code full discount booking to promo label', () {
      final promoFree = fakeBooking(
        status: BookingStatus.paid,
        trainingPrice: 0,
        promoCode: 'FREEDAY',
        promoDiscountPercent: 100,
      );

      expect(MessageFormatters.bookingStatusLabel(promoFree), 'Бесплатно: промокод FREEDAY 🎟');
    });

    test('keeps regular paid label for partial promo discount', () {
      final promoPartial = fakeBooking(
        status: BookingStatus.pendingPayment,
        trainingPrice: 750,
        promoCode: 'SUMMER50',
        promoDiscountPercent: 50,
      );

      expect(MessageFormatters.bookingStatusLabel(promoPartial), 'Ожидает оплату ⏳');
    });

    test('keeps paid label when price is unknown', () {
      final paidUnknownPrice = fakeBooking(
        status: BookingStatus.paid,
        trainingPrice: null,
      );

      expect(MessageFormatters.bookingStatusLabel(paidUnknownPrice), 'Оплачено ✅');
    });

    test('maps partial paid status to partial label', () {
      final partialPaid = fakeBooking(status: BookingStatus.partialPaid);
      expect(MessageFormatters.bookingStatusLabel(partialPaid), 'Предоплата внесена 🟡');
    });
  });

  test('myBookings uses booking-aware status labels', () {
    final templates = const MessageTemplates();
    final text = templates.myBookings(
      <TrainingBooking>[
        fakeBooking(
          id: 1,
          status: BookingStatus.paid,
          paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
        ),
        fakeBooking(
          id: 2,
          status: BookingStatus.paid,
          paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
        ),
        fakeBooking(
          id: 3,
          status: BookingStatus.paid,
          trainingPrice: 0,
        ),
      ],
      now: DateTime(2025, 1, 1),
    );

    expect(text, contains('Бесплатно: стартовая тренировка 🎁'));
    expect(text, contains('Бесплатно: каждая 5-я тренировка 🎁'));
    expect(text, contains('Бесплатно 🎁'));
  });
}
