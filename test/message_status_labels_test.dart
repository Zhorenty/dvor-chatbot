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

      expect(MessageFormatters.bookingStatusLabel(regularFree), 'Бесплатно');
      expect(
        MessageFormatters.bookingStatusLabel(starterFree),
        'Бесплатно: стартовая тренировка 🎁',
      );
      expect(
        MessageFormatters.bookingStatusLabel(everyFifthFree),
        'Бесплатно: каждая 5-я тренировка 🎁',
      );
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
    expect(text, contains('Статус: Бесплатно'));
  });
}
