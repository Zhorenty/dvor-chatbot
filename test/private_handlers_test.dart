import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:test/test.dart';

void main() {
  group('PrivateHandlers', () {
    test('handles /start command in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        templates: const MessageTemplates(),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 11, 'type': 'private'},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 11);
      expect(sender.messages.single.text, contains('DVOR'));
    });

    test('handles /trainings command in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тестовая тренировка',
              startsAt: DateTime(2026, 6, 4, 19, 0),
              location: 'Тестовый зал',
            ),
          ],
        ),
        templates: const MessageTemplates(),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 12, 'type': 'private'},
        'text': '/trainings',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Ближайшие тренировки'));
      expect(sender.messages.single.text, contains('Тестовая тренировка'));
    });

    test('ignores non-private chat messages', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        templates: const MessageTemplates(),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': -1001, 'type': 'supergroup'},
        'text': '/start',
      });

      expect(handled, isFalse);
      expect(sender.messages, isEmpty);
    });
  });
}

final class _FakeScheduleRepository implements TrainingScheduleRepository {
  const _FakeScheduleRepository(this._items);

  final List<TrainingInfo> _items;

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) => _items.take(limit).toList();
}

final class _FakeSender implements MessageSender {
  final List<_SentMessage> messages = <_SentMessage>[];

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
  }) async {
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
