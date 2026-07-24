import 'package:dvor_chatbot/src/jobs/referral_broadcast_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('sends referral broadcast on Wednesday 10:00', () async {
    final now = DateTime.utc(2030, 6, 26, 7, 0); // Wednesday 10:00 MSK
    final sender = FakeSender();
    final job = ReferralBroadcastJob(
      sender: sender,
      templates: const MessageTemplates(botUsername: 'dvor_chatbot'),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.chatId, -1001234567890);
    expect(sender.messages.single.parseMode, 'HTML');
    expect(sender.messages.single.text, contains('Приведи друга'));
    expect(sender.messages.single.text, contains('Реферальная программа'));
    expect(sender.messages.single.text, contains('https://t.me/dvor_chatbot?start=book'));
  });

  test('does not send referral broadcast outside Wednesday 10:00', () async {
    final now = DateTime.utc(2030, 6, 25, 7, 0); // Tuesday 10:00 MSK
    final sender = FakeSender();
    final job = ReferralBroadcastJob(
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, isEmpty);
  });

  test('does not send duplicate referral broadcasts in one day', () async {
    var now = DateTime.utc(2030, 6, 26, 7, 0);
    final sender = FakeSender();
    final job = ReferralBroadcastJob(
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();
    await job.run();
    now = DateTime.utc(2030, 6, 26, 7, 1);
    await job.run();

    expect(sender.messages, hasLength(1));
  });
}
