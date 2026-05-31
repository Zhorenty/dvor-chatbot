import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:l/l.dart';

final class GroupHandlers {
  const GroupHandlers({
    required MessageSender sender,
    required MessageTemplates templates,
    required int? targetChatId,
    required bool sendGroupFallback,
  })  : _sender = sender,
        _templates = templates,
        _targetChatId = targetChatId,
        _sendGroupFallback = sendGroupFallback;

  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final bool _sendGroupFallback;

  Future<bool> handle(
    Map<String, dynamic> message, {
    required String? botUsername,
  }) async {
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

    final failedDmCount = <int>[];
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
        await _sender.sendMessage(userId, _templates.clubInfoPrivate());
      } on TelegramApiException catch (error) {
        failedDmCount.add(userId);
        l.w('Cannot send DM to user $userId: $error');
      } on Object catch (error) {
        failedDmCount.add(userId);
        l.w('Unknown DM error for user $userId: $error');
      }
    }

    if (failedDmCount.isNotEmpty && _sendGroupFallback) {
      await _sender.sendMessage(
        chatId,
        _templates.groupFallback(botUsername: botUsername),
        disableNotification: true,
      );
    }

    return true;
  }
}
