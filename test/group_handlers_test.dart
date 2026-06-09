import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:test/test.dart';

void main() {
  group('GroupHandlers', () {
    test('sends DM to each new non-bot member', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository();
      final handlers = GroupHandlers(
        sender: sender,
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        targetChatId: -100123,
      );

      final handled = await handlers.handle(
        <String, dynamic>{
          'date': DateTime(2026, 6, 1, 19, 0).millisecondsSinceEpoch ~/ 1000,
          'chat': <String, dynamic>{'id': -100123, 'type': 'supergroup'},
          'new_chat_members': <Map<String, Object?>>[
            <String, Object?>{'id': 1001, 'is_bot': false, 'username': 'new_runner'},
            <String, Object?>{'id': 1002, 'is_bot': false},
          ],
        },
      );

      expect(handled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages[0].chatId, -100123);
      expect(sender.messages[1].chatId, -100123);
      expect(sender.messages[0].text, contains('Привет, @new_runner!'));
      expect(sender.messages[0].text, contains('подарок за старт'));
      expect(onboarding.records, hasLength(2));
      expect(onboarding.records[0].userId, 1001);
      expect(onboarding.records[0].groupChatId, -100123);
      expect(onboarding.records[0].welcomeMessageId, 1);
    });

    test('skips bot members and does not store welcome for them', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository();
      final handlers = GroupHandlers(
        sender: sender,
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        targetChatId: -100500,
      );

      final handled = await handlers.handle(
        <String, dynamic>{
          'chat': <String, dynamic>{'id': -100500, 'type': 'supergroup'},
          'new_chat_members': <Map<String, Object?>>[
            <String, Object?>{'id': 2001, 'is_bot': true},
          ],
        },
      );

      expect(handled, isTrue);
      expect(sender.messages, isEmpty);
      expect(onboarding.records, isEmpty);
    });

    test('ignores other groups when target chat id is configured', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository();
      final handlers = GroupHandlers(
        sender: sender,
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        targetChatId: -1001,
      );

      final handled = await handlers.handle(
        <String, dynamic>{
          'chat': <String, dynamic>{'id': -1002, 'type': 'supergroup'},
          'new_chat_members': <Map<String, Object?>>[
            <String, Object?>{'id': 3001, 'is_bot': false},
          ],
        },
      );

      expect(handled, isFalse);
      expect(sender.messages, isEmpty);
      expect(onboarding.records, isEmpty);
    });

    test('handles join via chat_member update', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository();
      final handlers = GroupHandlers(
        sender: sender,
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        targetChatId: -100123,
      );

      final handled = await handlers.handleUpdate(
        <String, dynamic>{
          'chat_member': <String, dynamic>{
            'date': DateTime(2026, 6, 1, 19, 0).millisecondsSinceEpoch ~/ 1000,
            'chat': <String, dynamic>{'id': -100123, 'type': 'supergroup'},
            'old_chat_member': <String, dynamic>{
              'status': 'left',
              'user': <String, Object?>{'id': 777, 'is_bot': false},
            },
            'new_chat_member': <String, dynamic>{
              'status': 'member',
              'user': <String, Object?>{'id': 777, 'is_bot': false, 'username': 'joined_via_link'},
            },
          },
        },
      );

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, -100123);
      expect(sender.messages.single.text, contains('Привет, @joined_via_link!'));
      expect(onboarding.records, hasLength(1));
      expect(onboarding.records.single.userId, 777);
    });

    test('ignores non-join chat_member transitions', () async {
      final sender = _FakeSender();
      final onboarding = _FakeOnboardingRepository();
      final handlers = GroupHandlers(
        sender: sender,
        onboardingRepository: onboarding,
        templates: const MessageTemplates(),
        targetChatId: -100123,
      );

      final handled = await handlers.handleUpdate(
        <String, dynamic>{
          'chat_member': <String, dynamic>{
            'chat': <String, dynamic>{'id': -100123, 'type': 'supergroup'},
            'old_chat_member': <String, dynamic>{
              'status': 'member',
              'user': <String, Object?>{'id': 778, 'is_bot': false},
            },
            'new_chat_member': <String, dynamic>{
              'status': 'left',
              'user': <String, Object?>{'id': 778, 'is_bot': false},
            },
          },
        },
      );

      expect(handled, isFalse);
      expect(sender.messages, isEmpty);
      expect(onboarding.records, isEmpty);
    });
  });
}

final class _FakeSender implements MessageSender {
  final List<_SentMessage> messages = <_SentMessage>[];

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
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

  @override
  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  }) async {
    throw UnimplementedError('copyMessage is not used in group handlers tests');
  }

  @override
  Future<void> deleteMessage(
    int chatId, {
    required int messageId,
  }) async {
    throw UnimplementedError('deleteMessage is not used in group handlers tests');
  }

  @override
  Future<void> pinMessage(
    int chatId, {
    required int messageId,
    bool disableNotification = true,
  }) async {
    throw UnimplementedError('pinMessage is not used in group handlers tests');
  }

  @override
  Future<void> answerCallbackQuery(
    String callbackQueryId, {
    String? text,
    bool showAlert = false,
  }) async {
    throw UnimplementedError('answerCallbackQuery is not used in group handlers tests');
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

final class _FakeOnboardingRepository implements OnboardingRepository {
  final List<_WelcomeRecord> records = <_WelcomeRecord>[];

  @override
  Future<void> close() async {}

  @override
  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  }) async {
    return false;
  }

  @override
  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  }) async {}

  @override
  Future<bool> hasStarterBonusAvailable(int userId) async {
    return false;
  }

  @override
  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  }) async {
    return const <StarterBonusReminderTarget>[];
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  }) async {
    return const <PendingWelcomeMessage>[];
  }

  @override
  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  }) async {}

  @override
  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  }) async {
    return null;
  }

  @override
  Future<int> getEveryFifthLastNotifiedRewards(int userId) async {
    return 0;
  }

  @override
  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  }) async {
    records.add(
      _WelcomeRecord(
        userId: userId,
        groupChatId: groupChatId,
        welcomeMessageId: welcomeMessageId,
      ),
    );
  }
}

final class _WelcomeRecord {
  const _WelcomeRecord({
    required this.userId,
    required this.groupChatId,
    required this.welcomeMessageId,
  });

  final int userId;
  final int groupChatId;
  final int welcomeMessageId;
}
