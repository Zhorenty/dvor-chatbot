import 'package:dvor_chatbot/src/application/boxing_card_ledger.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  final periodStart = DateTime(2026, 7, 1, 12);
  final periodEnd = DateTime(2026, 7, 31, 12);

  TrainingInfo boxing({required DateTime startsAt, String title = 'BOXING DVOR'}) {
    return TrainingInfo(
      title: title,
      startsAt: startsAt,
      location: 'Hall',
      price: 1300,
    );
  }

  group('BoxingCardLedger', () {
    test('BAZA counts 4 boxing slots and ignores the 5th', () {
      final bookings = <TrainingBooking>[
        for (var i = 0; i < 4; i++)
          fakeBooking(
            id: i + 1,
            userId: 10,
            title: 'BOXING DVOR',
            status: BookingStatus.paid,
            paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
            startsAt: DateTime(2026, 7, 5 + i, 19),
          ),
      ];
      final used = BoxingCardLedger.usedGroupSlots(
        bookings: bookings,
        userId: 10,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      expect(used, 4);
      expect(
        BoxingCardLedger.remainingGroupSlots(plan: BoxingCardPlan.baza, used: used),
        0,
      );
    });

    test('UDAR remaining hits zero after 8 boxing slots', () {
      final bookings = [
        for (var i = 0; i < 8; i++)
          fakeBooking(
            id: i + 1,
            userId: 11,
            title: 'Бокс',
            status: BookingStatus.paid,
            paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
            startsAt: DateTime(2026, 7, 2 + i, 19),
          ),
      ];
      final used = BoxingCardLedger.usedGroupSlots(
        bookings: bookings,
        userId: 11,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      expect(used, 8);
      expect(
        BoxingCardLedger.remainingGroupSlots(plan: BoxingCardPlan.udar, used: used),
        0,
      );
    });

    test('does not count strength slots', () {
      final bookings = [
        fakeBooking(
          id: 1,
          userId: 12,
          title: 'Силовая',
          status: BookingStatus.paid,
          paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
          startsAt: DateTime(2026, 7, 10, 19),
        ),
      ];
      expect(
        BoxingCardLedger.usedGroupSlots(
          bookings: bookings,
          userId: 12,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        0,
      );
    });

    test('late cancel burns a slot, early cancel does not', () {
      final late = fakeBooking(
        id: 1,
        userId: 13,
        title: 'BOXING DVOR',
        status: BookingStatus.cancelled,
        paymentNote: MessageFormatters.boxingCardLateCancelPaymentNoteMarker,
        startsAt: DateTime(2026, 7, 10, 19),
      );
      final early = fakeBooking(
        id: 2,
        userId: 13,
        title: 'BOXING DVOR',
        status: BookingStatus.cancelled,
        paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
        startsAt: DateTime(2026, 7, 12, 19),
      );
      expect(
        BoxingCardLedger.usedGroupSlots(
          bookings: [late, early],
          userId: 13,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        1,
      );
    });

    test('reschedule same booking does not double-count', () {
      final booking = fakeBooking(
        id: 7,
        userId: 14,
        title: '20.08 BOXING',
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
        startsAt: DateTime(2026, 7, 20, 19),
      );
      expect(
        BoxingCardLedger.usedGroupSlots(
          bookings: [booking],
          userId: 14,
          periodStart: periodStart,
          periodEnd: periodEnd,
        ),
        1,
      );
    });

    test('24h cutoff for reschedule and late cancel', () {
      final startsAt = DateTime(2026, 7, 10, 19);
      final booking = fakeBooking(id: 1, title: 'Бокс', startsAt: startsAt);
      expect(
        BoxingCardLedger.canReschedule(booking, now: startsAt.subtract(const Duration(hours: 24))),
        isTrue,
      );
      expect(
        BoxingCardLedger.canReschedule(
          booking,
          now: startsAt.subtract(const Duration(hours: 23, minutes: 59)),
        ),
        isFalse,
      );
      expect(
        BoxingCardLedger.burnsSlotOnCancel(
          booking,
          now: startsAt.subtract(const Duration(hours: 23)),
        ),
        isTrue,
      );
      expect(
        BoxingCardLedger.burnsSlotOnCancel(
          booking,
          now: startsAt.subtract(const Duration(hours: 25)),
        ),
        isFalse,
      );
    });

    test('reschedule target must be boxing', () {
      expect(BoxingCardLedger.isAllowedRescheduleTarget(boxing(startsAt: DateTime(2026, 7, 11))),
          isTrue);
      expect(
        BoxingCardLedger.isAllowedRescheduleTarget(
          TrainingInfo(title: 'Силовая', startsAt: DateTime(2026, 7, 11), location: 'Hall'),
        ),
        isFalse,
      );
    });
  });
}
