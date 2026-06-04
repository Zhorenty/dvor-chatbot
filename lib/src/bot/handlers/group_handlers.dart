import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class GroupHandlers {
  GroupHandlers({
    required MessageSender sender,
    OnboardingRepository onboardingRepository = const NoopOnboardingRepository(),
    required MessageTemplates templates,
    required int? targetChatId,
    DateTime Function()? nowProvider,
  })  : _sender = sender,
        _onboardingRepository = onboardingRepository,
        _templates = templates,
        _targetChatId = targetChatId,
        _nowProvider = nowProvider ?? DateTime.now;

  final MessageSender _sender;
  final OnboardingRepository _onboardingRepository;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final DateTime Function() _nowProvider;

  Future<bool> handle(Map<String, dynamic> message) async {
    final chat = message['chat'];
    if (chat is! Map) {
      return false;
    }
    final chatType = chat['type']?.toString();
    if (chatType != 'group' && chatType != 'supergroup') {
      return false;
    }

    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    if (_targetChatId != null && _targetChatId != chatId) {
      return false;
    }

    final newMembers = message['new_chat_members'];
    if (newMembers is! List) {
      return false;
    }

    for (final item in newMembers.whereType<Map<Object?, Object?>>()) {
      final user = Map<String, dynamic>.from(item);
      if (user['is_bot'] == true) {
        continue;
      }
      final userId = user['id'];
      if (userId is! int) {
        continue;
      }

      try {
        final welcomeMessageId = await _sender.sendMessage(
          chatId,
          _templates.groupWelcome(
            username: user['username']?.toString(),
            userId: userId,
            firstName: user['first_name']?.toString(),
          ),
          disableNotification: true,
          parseMode: 'HTML',
        );
        final joinedAt = _extractJoinedAt(message) ?? _nowProvider();
        await _onboardingRepository.registerGroupWelcome(
          userId: userId,
          groupChatId: chatId,
          welcomeMessageId: welcomeMessageId,
          joinedAt: joinedAt,
        );
      } on Object catch (error) {
        l.w('Failed to process welcome for user $userId: $error');
      }
    }

    return true;
  }

  DateTime? _extractJoinedAt(Map<String, dynamic> message) {
    final rawDate = message['date'];
    if (rawDate is! int) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(rawDate * 1000, isUtc: true).toLocal();
  }
}
