import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/booking_policy_service.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/jobs/payment_reminder_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('sends expiry notification for overdue pending payments', () async {
    final now = DateTime(2030, 6, 1, 12, 0);
    final bookingRepository = FakeBookingRepository()
      ..expiredPending = <TrainingBooking>[
        fakeBooking(id: 501, userId: 9001),
      ]
      ..pendingForReminder = const <TrainingBooking>[];
    final sender = FakeSender();
    final job = PaymentReminderJob(
      bookingRepository: bookingRepository,
      bookingPolicyService: BookingPolicyService(
        catalogService: ActivityCatalogService(
          scheduleRepository: FakeScheduleRepository(const []),
        ),
      ),
      sender: sender,
      templates: const MessageTemplates(),
      pendingPaymentTtl: const Duration(minutes: 120),
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.chatId, 9001);
    expect(sender.messages.single.text, contains('Время на оплату истекло'));
  });
}
