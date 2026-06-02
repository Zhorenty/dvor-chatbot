import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:l/l.dart';

final class WelcomeCleanupJob {
  const WelcomeCleanupJob({
    required OnboardingRepository onboardingRepository,
    required MessageSender sender,
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _sender = sender,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final MessageSender _sender;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    final now = _nowProvider();
    try {
      final items = await _onboardingRepository.listWelcomeMessagesReadyForDelete(now: now);
      for (final item in items) {
        try {
          await _sender.deleteMessage(
            item.groupChatId,
            messageId: item.welcomeMessageId,
          );
          await _onboardingRepository.markWelcomeDeleted(
            userId: item.userId,
            deletedAt: now,
          );
        } on TelegramApiException catch (error, stackTrace) {
          if (_canBeConsideredDeleted(error)) {
            await _onboardingRepository.markWelcomeDeleted(
              userId: item.userId,
              deletedAt: now,
            );
            continue;
          }
          l.w('Failed to delete welcome message for user ${item.userId}: $error', stackTrace);
        } on Object catch (error, stackTrace) {
          l.w('Unexpected welcome cleanup error for user ${item.userId}: $error', stackTrace);
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Welcome cleanup job failed: $error', stackTrace);
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
