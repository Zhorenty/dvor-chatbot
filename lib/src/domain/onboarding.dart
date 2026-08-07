import 'package:dvor_chatbot/src/domain/activity_category.dart';

enum OnboardingPhase {
  notStarted,
  phase1Quiz,
  phase1Track,
  phase1Map,
  phase2Activation,
  phase3Integration,
  phase4Completion,
  completed,
  paused,
  returning,
  legacySkipped,
}

enum OnboardingStep {
  welcome,
  quizGoal,
  quizExperience,
  trackChoice,
  mapCta,
  ctaBook,
  snoozed,
}

enum OnboardingQuizGoal {
  formStrength,
  enduranceRun,
  outdoorHikes,
  unknown,
}

enum OnboardingQuizExperience {
  beginner,
  returning,
  regular,
}

enum OnboardingTrack {
  oneOff,
  outdoor,
  // TODO(subscription): вернуть трек PRO-абонемент в квизе.
  // pro,
}

enum OnboardingEntryType {
  group,
  cold,
  referral,
  returning,
  legacy,
}

extension OnboardingPhaseX on OnboardingPhase {
  String get storageValue => switch (this) {
        OnboardingPhase.notStarted => 'not_started',
        OnboardingPhase.phase1Quiz => 'phase1_quiz',
        OnboardingPhase.phase1Track => 'phase1_track',
        OnboardingPhase.phase1Map => 'phase1_map',
        OnboardingPhase.phase2Activation => 'phase2_activation',
        OnboardingPhase.phase3Integration => 'phase3_integration',
        OnboardingPhase.phase4Completion => 'phase4_completion',
        OnboardingPhase.completed => 'completed',
        OnboardingPhase.paused => 'paused',
        OnboardingPhase.returning => 'returning',
        OnboardingPhase.legacySkipped => 'legacy_skipped',
      };

  static OnboardingPhase? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in OnboardingPhase.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

extension OnboardingStepX on OnboardingStep {
  String get storageValue => switch (this) {
        OnboardingStep.welcome => 'welcome',
        OnboardingStep.quizGoal => 'quiz_goal',
        OnboardingStep.quizExperience => 'quiz_experience',
        OnboardingStep.trackChoice => 'track_choice',
        OnboardingStep.mapCta => 'map_cta',
        OnboardingStep.ctaBook => 'cta_book',
        OnboardingStep.snoozed => 'snoozed',
      };

  static OnboardingStep? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in OnboardingStep.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

extension OnboardingQuizGoalX on OnboardingQuizGoal {
  String get storageValue => switch (this) {
        OnboardingQuizGoal.formStrength => 'form_strength',
        OnboardingQuizGoal.enduranceRun => 'endurance_run',
        OnboardingQuizGoal.outdoorHikes => 'outdoor_hikes',
        OnboardingQuizGoal.unknown => 'unknown',
      };

  static OnboardingQuizGoal? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in OnboardingQuizGoal.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

extension OnboardingQuizExperienceX on OnboardingQuizExperience {
  String get storageValue => switch (this) {
        OnboardingQuizExperience.beginner => 'beginner',
        OnboardingQuizExperience.returning => 'returning',
        OnboardingQuizExperience.regular => 'regular',
      };

  static OnboardingQuizExperience? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in OnboardingQuizExperience.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

extension OnboardingTrackX on OnboardingTrack {
  String get storageValue => switch (this) {
        OnboardingTrack.oneOff => 'one_off',
        OnboardingTrack.outdoor => 'outdoor',
      };

  static OnboardingTrack? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in OnboardingTrack.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

extension OnboardingEntryTypeX on OnboardingEntryType {
  String get storageValue => switch (this) {
        OnboardingEntryType.group => 'group',
        OnboardingEntryType.cold => 'cold',
        OnboardingEntryType.referral => 'referral',
        OnboardingEntryType.returning => 'returning',
        OnboardingEntryType.legacy => 'legacy',
      };

  static OnboardingEntryType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in OnboardingEntryType.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

final class OnboardingUserState {
  const OnboardingUserState({
    required this.userId,
    this.phase,
    this.step,
    this.quizGoal,
    this.quizExperience,
    this.selectedTrack,
    this.activationAt,
    this.onboardingStartedAt,
    this.onboardingCompletedAt,
    this.lastNudgeAt,
    this.snoozeUntil,
    this.entryType,
    this.startedAt,
    this.lastJoinedAt,
  });

  final int userId;
  final OnboardingPhase? phase;
  final OnboardingStep? step;
  final OnboardingQuizGoal? quizGoal;
  final OnboardingQuizExperience? quizExperience;
  final OnboardingTrack? selectedTrack;
  final DateTime? activationAt;
  final DateTime? onboardingStartedAt;
  final DateTime? onboardingCompletedAt;
  final DateTime? lastNudgeAt;
  final DateTime? snoozeUntil;
  final OnboardingEntryType? entryType;
  final DateTime? startedAt;
  final DateTime? lastJoinedAt;

  bool get isLegacy => phase == OnboardingPhase.legacySkipped;

  ActivityCategory get preferredBookingCategory {
    if (selectedTrack == OnboardingTrack.outdoor || quizGoal == OnboardingQuizGoal.outdoorHikes) {
      return ActivityCategory.hikes;
    }
    return ActivityCategory.trainings;
  }
}
