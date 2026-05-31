import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:test/test.dart';

void main() {
  group('GroupHandlers', () {
    test('sends DM to each new non-bot member', () async {
      final sender = _FakeSender();
      final handlers = GroupHandlers(
        sender: sender,
        templates: const MessageTemplates(),
        targetChatId: -100123,
        sendGroupFallback: true,
      );

      final handled = await handlers.handle(
        <String, dynamic>{
          'chat': <String, dynamic>{'id': -100123, 'type': 'supergroup'},
          'new_chat_members': <Map<String, Object?>>[
            <String, Object?>{'id': 1001, 'is_bot': false},
            <String, Object?>{'id': 1002, 'is_bot': false},
          ],
        },
        botUsername: 'dvor_test_bot',
      );

      expect(handled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages[0].chatId, 1001);
      expect(sender.messages[1].chatId, 1002);
      expect(
        sender.messages
            .map((m) => m.text)
            .every((text) => text.contains('спортивное объединение DVOR')),
        isTrue,
      );
    });

    test('sends fallback in group when direct message fails', () async {
      final sender = _FakeSender(failingChatIds: <int>{2001});
      final handlers = GroupHandlers(
        sender: sender,
        templates: const MessageTemplates(),
        targetChatId: -100500,
        sendGroupFallback: true,
      );

      final handled = await handlers.handle(
        <String, dynamic>{
          'chat': <String, dynamic>{'id': -100500, 'type': 'supergroup'},
          'new_chat_members': <Map<String, Object?>>[
            <String, Object?>{'id': 2001, 'is_bot': false},
          ],
        },
        botUsername: 'dvor_test_bot',
      );

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, -100500);
      expect(sender.messages.single.text, contains('https://t.me/dvor_test_bot'));
    });

    test('ignores other groups when target chat id is configured', () async {
      final sender = _FakeSender();
      final handlers = GroupHandlers(
        sender: sender,
        templates: const MessageTemplates(),
        targetChatId: -1001,
        sendGroupFallback: true,
      );

      final handled = await handlers.handle(
        <String, dynamic>{
          'chat': <String, dynamic>{'id': -1002, 'type': 'supergroup'},
          'new_chat_members': <Map<String, Object?>>[
            <String, Object?>{'id': 3001, 'is_bot': false},
          ],
        },
        botUsername: 'dvor_test_bot',
      );

      expect(handled, isFalse);
      expect(sender.messages, isEmpty);
    });
  });
}

final class _FakeSender implements MessageSender {
  _FakeSender({Set<int>? failingChatIds}) : _failingChatIds = failingChatIds ?? <int>{};

  final Set<int> _failingChatIds;
  final List<_SentMessage> messages = <_SentMessage>[];

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  }) async {
    if (_failingChatIds.contains(chatId)) {
      throw const TelegramApiException('Forbidden: bot was blocked by the user', statusCode: 403);
    }
    messages.add(
      _SentMessage(
        chatId: chatId,
        text: text,
        disableNotification: disableNotification,
      ),
    );
    return messages.length;
  }
}

final class _SentMessage {
  const _SentMessage({
    required this.chatId,
    required this.text,
    required this.disableNotification,
  });

  final int chatId;
  final String text;
  final bool disableNotification;
}
