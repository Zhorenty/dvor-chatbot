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

  /// Sends [htmlText] as an HTML message to all users who have started the bot.
  Future<BroadcastResult> broadcastToUsers(String htmlText) async {
    final userIds = await _onboardingRepository.getAllStartedUserIds();
    var sent = 0;
    var failed = 0;
    for (final userId in userIds) {
      try {
        await _sender.sendMessage(userId, htmlText, parseMode: 'HTML');
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

  /// Sends [htmlText] as an HTML message to the configured group chat.
  /// Returns [true] if sent successfully.
  Future<bool> broadcastToGroup(String htmlText) async {
    final chatId = _groupChatId;
    if (chatId == null) {
      return false;
    }
    try {
      await _sender.sendMessage(chatId, htmlText, parseMode: 'HTML');
      return true;
    } on TelegramApiException catch (error) {
      l.w('Broadcast: failed to send message to group $chatId: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Broadcast: unexpected error sending to group $chatId: $error', stackTrace);
      return false;
    }
  }

  /// Sends [htmlText] to all started users and to the configured group chat.
  Future<BroadcastResult> broadcastToUsersAndGroup(String htmlText) async {
    final result = await broadcastToUsers(htmlText);
    await broadcastToGroup(htmlText);
    return result;
  }

  bool get hasGroup => _groupChatId != null;
}
