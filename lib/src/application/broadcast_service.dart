import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:l/l.dart';

final class BroadcastResult {
  const BroadcastResult({
    required this.sent,
    required this.failed,
    required this.total,
  });

  final int sent;
  final int failed;
  final int total;
}

/// Reference to a Telegram message that should be copied during broadcast.
final class BroadcastMessageRef {
  const BroadcastMessageRef({
    required this.fromChatId,
    required this.messageId,
  });

  final int fromChatId;
  final int messageId;
}

/// Content for an admin broadcast: either HTML text or media messages to copy.
final class BroadcastContent {
  const BroadcastContent.text(this.htmlText) : sourceMessages = const <BroadcastMessageRef>[];

  const BroadcastContent.media(this.sourceMessages) : htmlText = null;

  final String? htmlText;
  final List<BroadcastMessageRef> sourceMessages;

  bool get hasMedia => sourceMessages.isNotEmpty;
}

final class BroadcastService {
  BroadcastService({
    required MessageSender sender,
    required OnboardingRepository onboardingRepository,
    int? groupChatId,
  })  : _sender = sender,
        _onboardingRepository = onboardingRepository,
        _groupChatId = groupChatId;

  final MessageSender _sender;
  final OnboardingRepository _onboardingRepository;
  final int? _groupChatId;

  /// Sends [content] to all users who have started the bot.
  Future<BroadcastResult> broadcastToUsers(BroadcastContent content) async {
    final userIds = await _onboardingRepository.getAllStartedUserIds();
    var sent = 0;
    var failed = 0;
    for (final userId in userIds) {
      try {
        await _deliver(userId, content);
        sent++;
      } on TelegramApiException catch (error) {
        failed++;
        l.w('Broadcast: failed to send DM to user $userId: $error');
      } on Object catch (error, stackTrace) {
        failed++;
        l.w('Broadcast: unexpected error sending DM to user $userId: $error', stackTrace);
      }
    }
    return BroadcastResult(sent: sent, failed: failed, total: userIds.length);
  }

  /// Sends [content] to the configured group chat.
  /// Returns [true] if sent successfully.
  Future<bool> broadcastToGroup(BroadcastContent content) async {
    final chatId = _groupChatId;
    if (chatId == null) {
      return false;
    }
    try {
      await _deliver(chatId, content);
      return true;
    } on TelegramApiException catch (error) {
      l.w('Broadcast: failed to send message to group $chatId: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Broadcast: unexpected error sending to group $chatId: $error', stackTrace);
      return false;
    }
  }

  /// Sends [content] to all started users and to the configured group chat.
  Future<BroadcastResult> broadcastToUsersAndGroup(BroadcastContent content) async {
    final result = await broadcastToUsers(content);
    await broadcastToGroup(content);
    return result;
  }

  bool get hasGroup => _groupChatId != null;

  Future<void> _deliver(int chatId, BroadcastContent content) async {
    if (content.hasMedia) {
      for (final ref in content.sourceMessages) {
        await _sender.copyMessage(
          chatId,
          fromChatId: ref.fromChatId,
          messageId: ref.messageId,
        );
      }
      return;
    }
    final htmlText = content.htmlText;
    if (htmlText == null || htmlText.isEmpty) {
      throw const TelegramApiException('Broadcast content is empty');
    }
    await _sender.sendMessage(chatId, htmlText, parseMode: 'HTML');
  }
}
