import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class StarterBonusReminderJob {
  const StarterBonusReminderJob({
    required OnboardingRepository onboardingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _sender = sender,
        _templates = templates,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    final now = _nowProvider();
    try {
      final targets = await _onboardingRepository.listStarterBonusExpiringSoon(
        now: now,
        leadTime: const Duration(days: 1),
        limit: 100,
      );
      for (final target in targets) {
        try {
          await _sender.sendMessage(
            target.userId,
            _templates.starterBonusExpiryReminder(expiresAt: target.expiresAt),
          );
          await _onboardingRepository.markStarterBonusReminderSent(
            target.userId,
            sentAt: now,
          );
        } on Object catch (error, stackTrace) {
          l.w('Failed to send starter bonus expiry reminder for user ${target.userId}: $error',
              stackTrace);
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Starter bonus reminder job failed: $error', stackTrace);
    }
  }
}
