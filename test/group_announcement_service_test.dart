import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  const chatId = -1001234567890;

  test('publishes when announcement slot is empty', () async {
    final sender = FakeSender();
    final service = GroupAnnouncementService(sender: sender);

    final sent = await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.referralBroadcast,
      text: 'referral',
      parseMode: 'HTML',
    );

    expect(sent, isTrue);
    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.text, 'referral');
    expect(sender.deletedMessages, isEmpty);
  });

  test('replaces when new announcement has equal or higher priority', () async {
    final sender = FakeSender();
    final service = GroupAnnouncementService(sender: sender);

    await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.lowSpots,
      text: 'low',
    );

    final sent = await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.scheduleBroadcast,
      text: 'schedule',
    );

    expect(sent, isTrue);
    expect(sender.messages, hasLength(2));
    expect(sender.messages.last.text, 'schedule');
    expect(sender.deletedMessages, hasLength(1));
    expect(sender.deletedMessages.single.messageId, 1);
  });

  test('skips when new announcement has lower priority', () async {
    final sender = FakeSender();
    final service = GroupAnnouncementService(sender: sender);

    await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.trainingDayPromo,
      text: 'promo',
    );

    final sent = await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.lowSpots,
      text: 'low',
    );

    expect(sent, isFalse);
    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.text, 'promo');
    expect(sender.deletedMessages, isEmpty);
  });

  test('allows lower priority after slot TTL and deletes previous message', () async {
    var now = DateTime.utc(2030, 6, 22, 10, 0);
    final sender = FakeSender();
    final service = GroupAnnouncementService(
      sender: sender,
      slotTtl: const Duration(hours: 12),
      nowProvider: () => now,
    );

    await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.trainingDayPromo,
      text: 'promo',
    );
    expect(sender.messages, hasLength(1));

    now = now.add(const Duration(hours: 12));
    final sent = await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.referralBroadcast,
      text: 'referral',
    );

    expect(sent, isTrue);
    expect(sender.messages, hasLength(2));
    expect(sender.messages.last.text, 'referral');
    expect(sender.deletedMessages, hasLength(1));
    expect(sender.deletedMessages.single.messageId, 1);
  });

  test('replaces equal priority announcement', () async {
    final sender = FakeSender();
    final service = GroupAnnouncementService(sender: sender);

    await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.lowSpots,
      text: 'first',
    );
    final sent = await service.publish(
      chatId: chatId,
      type: GroupAnnouncementType.lowSpots,
      text: 'second',
    );

    expect(sent, isTrue);
    expect(sender.messages.map((m) => m.text), <String>['first', 'second']);
    expect(sender.deletedMessages, hasLength(1));
  });
}
