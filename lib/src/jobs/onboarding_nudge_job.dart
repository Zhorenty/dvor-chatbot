import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/onboarding_service.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class OnboardingNudgeJob {
  const OnboardingNudgeJob({
    required OnboardingRepository onboardingRepository,
    required OnboardingService onboardingService,
    required MessageSender sender,
    required MessageTemplates templates,
    ActivityCatalogService? catalogService,
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _onboardingService = onboardingService,
        _sender = sender,
        _templates = templates,
        _catalogService = catalogService,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final OnboardingService _onboardingService;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final ActivityCatalogService? _catalogService;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    if (!_onboardingService.dripEnabled) {
      return;
    }
    final now = _nowProvider();
    try {
      final candidates = await _onboardingRepository.listOnboardingNudgeCandidates(
        now: now,
        limit: 100,
      );
      for (final candidate in candidates) {
        try {
          final decision = await _onboardingService.nextNudge(candidate, now);
          if (decision == null) {
            continue;
          }
          if (decision.kind == OnboardingNudgeKind.day1Schedule) {
            await _onboardingService.applyDefaultTrackIfNeeded(candidate.userId);
          }
          final quizIncomplete = decision.kind == OnboardingNudgeKind.quizReminder30m ||
              decision.kind == OnboardingNudgeKind.quizReminder2h ||
              decision.kind == OnboardingNudgeKind.quizHelp6h;
          final text = switch (decision.kind) {
            OnboardingNudgeKind.quizReminder30m ||
            OnboardingNudgeKind.quizReminder2h =>
              _templates.onboardingNudgeQuizReminder(),
            OnboardingNudgeKind.quizHelp6h => _templates.onboardingNeedHelp(),
            OnboardingNudgeKind.day1Schedule ||
            OnboardingNudgeKind.day2Book =>
              _templates.onboardingNudgePrimaryCta(nearest: _nearestSlot(candidate)),
            OnboardingNudgeKind.day5Alt => _templates.onboardingNudgeDay5Alt(),
            OnboardingNudgeKind.day7Book => _templates.onboardingNudgeDay7(),
          };
          await _sender.sendMessage(
            candidate.userId,
            text,
            replyMarkup: _templates.onboardingNudgeKeyboard(quizIncomplete: quizIncomplete),
          );
          await _onboardingRepository.recordNudgeSent(
            userId: candidate.userId,
            nudgeKey: decision.nudgeKey,
            sentAt: now,
            phase: candidate.phase,
            step: candidate.step,
          );
        } on Object catch (error, stackTrace) {
          l.w(
            'Failed onboarding nudge for user ${candidate.userId}: $error',
            stackTrace,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Onboarding nudge job failed: $error', stackTrace);
    }
  }

  TrainingInfo? _nearestSlot(OnboardingNudgeCandidate candidate) {
    final catalog = _catalogService;
    if (catalog == null) {
      return null;
    }
    final items = catalog.bookableItems(candidate.preferredBookingCategory, limit: 1);
    if (items.isEmpty) {
      return null;
    }
    return items.first;
  }
}
