import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';

final class OnboardingNudgeDecision {
  const OnboardingNudgeDecision({
    required this.nudgeKey,
    required this.kind,
  });

  final String nudgeKey;
  final OnboardingNudgeKind kind;
}

enum OnboardingNudgeKind {
  quizReminder30m,
  quizReminder2h,
  quizHelp6h,
  day1Schedule,
  day2Book,
  day5Alt,
  day7Book,
}

final class OnboardingService {
  const OnboardingService({
    required OnboardingRepository onboardingRepository,
    required bool dripEnabled,
  })  : _onboardingRepository = onboardingRepository,
        _dripEnabled = dripEnabled;

  final OnboardingRepository _onboardingRepository;
  final bool _dripEnabled;

  bool get dripEnabled => _dripEnabled;

  Future<OnboardingUserState> ensureStarted(
    int userId, {
    required DateTime startedAt,
    OnboardingEntryType? entryType,
  }) {
    return _onboardingRepository.ensureStartedUser(
      userId,
      startedAt: startedAt,
      entryType: entryType,
    );
  }

  Future<bool> shouldRunFunnel(int userId) async {
    if (!_dripEnabled) {
      return false;
    }
    final state = await _onboardingRepository.getOnboardingState(userId);
    if (state == null) {
      return true;
    }
    if (state.isLegacy || state.phase == OnboardingPhase.completed) {
      return false;
    }
    return true;
  }

  Future<bool> isInActiveQuiz(int userId) async {
    if (!await shouldRunFunnel(userId)) {
      return false;
    }
    final state = await _onboardingRepository.getOnboardingState(userId);
    final phase = state?.phase;
    return phase == OnboardingPhase.phase1Quiz ||
        phase == OnboardingPhase.phase1Track ||
        phase == OnboardingPhase.phase1Map;
  }

  Future<ActivityCategory> preferredCategory(int userId) async {
    final state = await _onboardingRepository.getOnboardingState(userId);
    return state?.preferredBookingCategory ?? ActivityCategory.trainings;
  }

  Future<void> saveQuizGoal(int userId, OnboardingQuizGoal goal) {
    return _onboardingRepository.updateOnboardingProgress(
      userId: userId,
      phase: OnboardingPhase.phase1Quiz,
      step: OnboardingStep.quizExperience,
      quizGoal: goal,
    );
  }

  Future<void> saveQuizExperience(int userId, OnboardingQuizExperience experience) {
    return _onboardingRepository.updateOnboardingProgress(
      userId: userId,
      phase: OnboardingPhase.phase1Track,
      step: OnboardingStep.trackChoice,
      quizExperience: experience,
    );
  }

  Future<void> saveTrack(int userId, OnboardingTrack track) {
    return _onboardingRepository.updateOnboardingProgress(
      userId: userId,
      phase: OnboardingPhase.phase1Map,
      step: OnboardingStep.mapCta,
      selectedTrack: track,
    );
  }

  Future<void> markMapShown(int userId) {
    return _onboardingRepository.updateOnboardingProgress(
      userId: userId,
      phase: OnboardingPhase.phase2Activation,
      step: OnboardingStep.ctaBook,
    );
  }

  Future<void> applyDefaultTrackIfNeeded(int userId) async {
    final state = await _onboardingRepository.getOnboardingState(userId);
    if (state == null || state.selectedTrack != null) {
      return;
    }
    await _onboardingRepository.updateOnboardingProgress(
      userId: userId,
      phase: OnboardingPhase.phase2Activation,
      step: OnboardingStep.ctaBook,
      selectedTrack: OnboardingTrack.oneOff,
      quizGoal: state.quizGoal ?? OnboardingQuizGoal.unknown,
    );
  }

  Future<void> snooze(int userId, {required DateTime until}) {
    return _onboardingRepository.updateOnboardingProgress(
      userId: userId,
      phase: OnboardingPhase.paused,
      step: OnboardingStep.snoozed,
      snoozeUntil: until,
    );
  }

  Future<bool> tryMarkActivation(int userId, {required DateTime activatedAt}) {
    if (!_dripEnabled) {
      return Future<bool>.value(false);
    }
    return _onboardingRepository.tryMarkActivation(
      userId,
      activatedAt: activatedAt,
    );
  }

  Future<OnboardingNudgeDecision?> nextNudge(
      OnboardingNudgeCandidate candidate, DateTime now) async {
    final nowUtc = now.toUtc();
    final started = candidate.onboardingStartedAt.toUtc();
    final elapsed = nowUtc.difference(started);
    final quizIncomplete = candidate.phase == OnboardingPhase.phase1Quiz ||
        candidate.phase == OnboardingPhase.phase1Track ||
        candidate.phase == OnboardingPhase.phase1Map ||
        candidate.step == OnboardingStep.welcome ||
        candidate.step == OnboardingStep.quizGoal ||
        candidate.step == OnboardingStep.quizExperience ||
        candidate.step == OnboardingStep.trackChoice;

    if (quizIncomplete) {
      final decisions = <(Duration, OnboardingNudgeDecision)>[
        (
          const Duration(minutes: 30),
          const OnboardingNudgeDecision(
            nudgeKey: 'p1_30m',
            kind: OnboardingNudgeKind.quizReminder30m,
          ),
        ),
        (
          const Duration(hours: 2),
          const OnboardingNudgeDecision(
            nudgeKey: 'p1_2h',
            kind: OnboardingNudgeKind.quizReminder2h,
          ),
        ),
        (
          const Duration(hours: 6),
          const OnboardingNudgeDecision(
            nudgeKey: 'p1_6h',
            kind: OnboardingNudgeKind.quizHelp6h,
          ),
        ),
        (
          const Duration(hours: 24),
          const OnboardingNudgeDecision(
            nudgeKey: 'p1_24h',
            kind: OnboardingNudgeKind.day1Schedule,
          ),
        ),
      ];
      for (final (delay, decision) in decisions) {
        if (elapsed < delay) {
          continue;
        }
        if (await _onboardingRepository.hasNudgeBeenSent(
          userId: candidate.userId,
          nudgeKey: decision.nudgeKey,
        )) {
          continue;
        }
        return decision;
      }
      return null;
    }

    if (candidate.activationAt != null) {
      return null;
    }

    if (candidate.lastNudgeAt != null &&
        nowUtc.difference(candidate.lastNudgeAt!.toUtc()) < const Duration(hours: 24)) {
      return null;
    }

    final dayDecisions = <(Duration, OnboardingNudgeDecision)>[
      (
        const Duration(days: 2),
        const OnboardingNudgeDecision(
          nudgeKey: 'p2_d2',
          kind: OnboardingNudgeKind.day2Book,
        ),
      ),
      (
        const Duration(days: 5),
        const OnboardingNudgeDecision(
          nudgeKey: 'p2_d5',
          kind: OnboardingNudgeKind.day5Alt,
        ),
      ),
      (
        const Duration(days: 7),
        const OnboardingNudgeDecision(
          nudgeKey: 'p2_d7',
          kind: OnboardingNudgeKind.day7Book,
        ),
      ),
    ];
    for (final (delay, decision) in dayDecisions) {
      if (elapsed < delay) {
        continue;
      }
      if (await _onboardingRepository.hasNudgeBeenSent(
        userId: candidate.userId,
        nudgeKey: decision.nudgeKey,
      )) {
        continue;
      }
      return decision;
    }
    return null;
  }
}
