import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/jobs/subscription_renewal_job.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('SubscriptionRenewalJob', () {
    test('sends 7/3/1 reminders with boxing card copy', () async {
      final sender = FakeSender();
      final until = DateTime(2026, 8, 4, 12);
      final request = SubscriptionRequest(
        id: 11,
        userId: 501,
        userUsername: 'boxer',
        status: SubscriptionRequestStatus.active,
        plan: BoxingCardPlan.baza,
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
        activeFrom: DateTime(2026, 7, 5, 12),
        activeUntil: until,
      );
      final subscriptions = FakeSubscriptionRepository()
        ..renewalReminderTargets = <RenewalReminderTarget>[
          RenewalReminderTarget(request: request, daysBefore: 7),
        ]
        ..membershipLevel = MembershipLevel.boxingCard
        ..membershipPlan = BoxingCardPlan.baza
        ..membershipActiveFrom = request.activeFrom
        ..membershipActiveUntil = until
        ..membershipRequestId = 11;
      final job = SubscriptionRenewalJob(
        subscriptionRepository: subscriptions,
        bookingRepository: FakeBookingRepository(),
        sender: sender,
        templates: const MessageTemplates(),
        nowProvider: () => DateTime(2026, 7, 28, 12),
      );

      await job.run();

      expect(sender.messages, isNotEmpty);
      expect(sender.messages.first.text, contains('Карта до'));
      expect(sender.messages.first.text, contains('Продлить'));
      expect(sender.messages.first.text, isNot(contains('PRO')));
    });

    test('sends expiry copy without PRO', () async {
      final sender = FakeSender();
      final request = SubscriptionRequest(
        id: 12,
        userId: 502,
        userUsername: 'boxer',
        status: SubscriptionRequestStatus.active,
        plan: BoxingCardPlan.udar,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        activeFrom: DateTime(2026, 7, 1, 12),
        activeUntil: DateTime(2026, 7, 31, 12),
      );
      final subscriptions = FakeSubscriptionRepository()
        ..expiredWithoutPromo = <SubscriptionRequest>[request];
      final job = SubscriptionRenewalJob(
        subscriptionRepository: subscriptions,
        sender: sender,
        templates: const MessageTemplates(),
        nowProvider: () => DateTime(2026, 8, 1, 12),
      );

      await job.run();

      expect(sender.messages.single.text, contains('30 дней прошли'));
      expect(sender.messages.single.text, isNot(contains('PRO')));
    });

    test('notifies remaining after boxing card slot starts', () async {
      final sender = FakeSender();
      final startsAt = DateTime(2026, 7, 20, 10);
      final booking = fakeBooking(
        id: 90,
        userId: 503,
        title: 'BOXING DVOR',
        status: BookingStatus.paid,
        paymentNote: MessageFormatters.boxingCardIncludedPaymentNoteMarker,
        startsAt: startsAt,
      );
      final subscriptions = FakeSubscriptionRepository()
        ..membershipLevel = MembershipLevel.boxingCard
        ..membershipPlan = BoxingCardPlan.baza
        ..membershipActiveFrom = DateTime(2026, 7, 1, 12)
        ..membershipActiveUntil = DateTime(2026, 7, 31, 12)
        ..membershipRequestId = 3;
      final bookings = FakeBookingRepository()..queue = [booking];
      final job = SubscriptionRenewalJob(
        subscriptionRepository: subscriptions,
        bookingRepository: bookings,
        sender: sender,
        templates: const MessageTemplates(),
        nowProvider: () => startsAt.add(const Duration(hours: 3)),
        visitNotifyDelay: const Duration(hours: 2),
      );

      await job.run();

      expect(
        sender.messages.any((item) => item.text.contains('Занятие засчитано')),
        isTrue,
      );
    });

    test('reminds about unused individual session', () async {
      final sender = FakeSender();
      final request = SubscriptionRequest(
        id: 14,
        userId: 504,
        userUsername: 'boxer',
        status: SubscriptionRequestStatus.active,
        plan: BoxingCardPlan.baza,
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
        activeFrom: DateTime(2026, 7, 5, 12),
        activeUntil: DateTime(2026, 8, 4, 12),
      );
      final subscriptions = FakeSubscriptionRepository()
        ..individualReminderTargets = <SubscriptionRequest>[request];
      final job = SubscriptionRenewalJob(
        subscriptionRepository: subscriptions,
        sender: sender,
        templates: const MessageTemplates(),
        nowProvider: () => DateTime(2026, 7, 30, 12),
      );

      await job.run();

      expect(sender.messages.single.text, contains('Индивидуальная ещё не закрыта'));
    });
  });
}
