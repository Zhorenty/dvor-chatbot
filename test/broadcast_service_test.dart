import 'package:dvor_chatbot/src/application/broadcast_service.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('BroadcastService', () {
    test('sends HTML text to all started users', () async {
      final sender = FakeSender();
      final onboarding = FakeOnboardingRepository()
        ..seedUser(userId: 11)
        ..seedUser(userId: 22);
      final service = BroadcastService(
        sender: sender,
        onboardingRepository: onboarding,
      );

      final result = await service.broadcastToUsers(
        const BroadcastContent.text('<b>hello</b>'),
      );

      expect(result.sent, 2);
      expect(result.failed, 0);
      expect(result.total, 2);
      expect(sender.messages.map((item) => item.chatId), containsAll(<int>[11, 22]));
      expect(sender.messages.every((item) => item.parseMode == 'HTML'), isTrue);
      expect(sender.copiedMessages, isEmpty);
    });

    test('copies media messages to users and group', () async {
      final sender = FakeSender();
      final onboarding = FakeOnboardingRepository()..seedUser(userId: 11);
      final service = BroadcastService(
        sender: sender,
        onboardingRepository: onboarding,
        groupChatId: -1001,
      );
      const content = BroadcastContent.media(<BroadcastMessageRef>[
        BroadcastMessageRef(fromChatId: 900, messageId: 1),
        BroadcastMessageRef(fromChatId: 900, messageId: 2),
      ]);

      final usersResult = await service.broadcastToUsers(content);
      final groupSent = await service.broadcastToGroup(content);

      expect(usersResult.sent, 1);
      expect(groupSent, isTrue);
      expect(sender.messages, isEmpty);
      expect(sender.copiedMessages, hasLength(4));
      expect(
        sender.copiedMessages.where((item) => item.toChatId == 11).map((item) => item.messageId),
        <int>[1, 2],
      );
      expect(
        sender.copiedMessages.where((item) => item.toChatId == -1001).map((item) => item.messageId),
        <int>[1, 2],
      );
    });

    test('counts failed deliveries without stopping the broadcast', () async {
      final sender = FakeSender()
        ..sendMessageFailuresByChatId[22] = const TelegramApiException('blocked');
      final onboarding = FakeOnboardingRepository()
        ..seedUser(userId: 11)
        ..seedUser(userId: 22);
      final service = BroadcastService(
        sender: sender,
        onboardingRepository: onboarding,
      );

      final result = await service.broadcastToUsers(
        const BroadcastContent.text('ping'),
      );

      expect(result.sent, 1);
      expect(result.failed, 1);
      expect(result.total, 2);
    });
  });
}
