import 'package:dvor_chatbot/src/application/loyalty_credit_dm.dart';
import 'package:dvor_chatbot/src/data/conversation_log_repository.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:l/l.dart';

/// One-shot: delete previously sent вершинки credit/expiry DMs after a quiet remigration.
final class LoyaltyCreditDmCleanupJob {
  const LoyaltyCreditDmCleanupJob({
    required ConversationLogRepository conversationLogRepository,
    required MessageSender sender,
    JobDedupeRepository? jobDedupeRepository,
  })  : _conversationLogRepository = conversationLogRepository,
        _sender = sender,
        _jobDedupeRepository = jobDedupeRepository;

  static const String dedupeKey = 'loyalty_credit_dm_cleanup_v1';

  final ConversationLogRepository _conversationLogRepository;
  final MessageSender _sender;
  final JobDedupeRepository? _jobDedupeRepository;

  Future<void> run() async {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null && !dedupe.tryClaim(dedupeKey)) {
      return;
    }
    var completed = false;
    try {
      final entries = await _conversationLogRepository.listOutboundWithTelegramId();
      for (final entry in entries) {
        final messageId = entry.telegramMessageId;
        if (messageId == null || !LoyaltyCreditDm.matches(entry.textPreview)) {
          continue;
        }
        try {
          await _sender.deleteMessage(entry.chatId, messageId: messageId);
        } on TelegramApiException catch (error, stackTrace) {
          if (_canBeConsideredDeleted(error)) {
            continue;
          }
          l.w(
            'Failed to delete loyalty credit DM ${entry.id} '
            'for user ${entry.peerUserId}: $error',
            stackTrace,
          );
        } on Object catch (error, stackTrace) {
          l.w(
            'Unexpected loyalty credit DM cleanup error for user '
            '${entry.peerUserId}: $error',
            stackTrace,
          );
        }
      }
      completed = true;
    } on Object catch (error, stackTrace) {
      l.w('Loyalty credit DM cleanup job failed: $error', stackTrace);
    } finally {
      if (!completed) {
        dedupe?.release(dedupeKey);
      }
    }
  }

  bool _canBeConsideredDeleted(TelegramApiException error) {
    if (error.statusCode == 400) {
      final normalized = error.message.toLowerCase();
      return normalized.contains('message to delete not found') ||
          normalized.contains('message can\'t be deleted');
    }
    return false;
  }
}
