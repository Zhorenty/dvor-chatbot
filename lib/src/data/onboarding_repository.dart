import 'package:dvor_chatbot/src/domain/admin_analytics.dart';
import 'package:dvor_chatbot/src/domain/funnel_analytics.dart';
import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';

final class PendingWelcomeMessage {
  const PendingWelcomeMessage({
    required this.userId,
    required this.groupChatId,
    required this.welcomeMessageId,
  });

  final int userId;
  final int groupChatId;
  final int welcomeMessageId;
}

final class StarterBonusReminderTarget {
  const StarterBonusReminderTarget({
    required this.userId,
    required this.expiresAt,
  });

  final int userId;
  final DateTime expiresAt;
}

final class OnboardingNudgeCandidate {
  const OnboardingNudgeCandidate({
    required this.userId,
    required this.phase,
    required this.step,
    required this.onboardingStartedAt,
    this.quizGoal,
    this.selectedTrack,
    this.activationAt,
    this.lastNudgeAt,
    this.snoozeUntil,
  });

  final int userId;
  final OnboardingPhase phase;
  final OnboardingStep? step;
  final DateTime onboardingStartedAt;
  final OnboardingQuizGoal? quizGoal;
  final OnboardingTrack? selectedTrack;
  final DateTime? activationAt;
  final DateTime? lastNudgeAt;
  final DateTime? snoozeUntil;
}

abstract interface class OnboardingRepository {
  Future<void> init();

  Future<void> close();

  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  });

  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  });

  /// Ensures a durable started user row exists (cold DM included).
  Future<OnboardingUserState> ensureStartedUser(
    int userId, {
    required DateTime startedAt,
    OnboardingEntryType? entryType,
  });

  Future<OnboardingUserState?> getOnboardingState(int userId);

  Future<void> updateOnboardingProgress({
    required int userId,
    OnboardingPhase? phase,
    OnboardingStep? step,
    OnboardingQuizGoal? quizGoal,
    OnboardingQuizExperience? quizExperience,
    OnboardingTrack? selectedTrack,
    OnboardingEntryType? entryType,
    DateTime? onboardingStartedAt,
    DateTime? snoozeUntil,
    bool clearSnooze = false,
  });

  /// Marks activation once. Returns true if newly set.
  Future<bool> tryMarkActivation(
    int userId, {
    required DateTime activatedAt,
  });

  Future<bool> hasNudgeBeenSent({
    required int userId,
    required String nudgeKey,
  });

  Future<void> recordNudgeSent({
    required int userId,
    required String nudgeKey,
    required DateTime sentAt,
    OnboardingPhase? phase,
    OnboardingStep? step,
  });

  Future<List<OnboardingNudgeCandidate>> listOnboardingNudgeCandidates({
    required DateTime now,
    int limit = 100,
  });

  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  });

  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  });

  Future<bool> hasStarterBonusAvailable(int userId);

  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  });

  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  });

  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  });

  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  });

  Future<int> getEveryFifthLastNotifiedRewards(int userId);

  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  });

  Future<void> registerReferralAttribution({
    required int inviteeUserId,
    required int inviterUserId,
    required DateTime attributedAt,
  });

  /// Returns IDs of all users who have started the bot (sent /start).
  /// Only these users can receive proactive DMs.
  Future<List<int>> getAllStartedUserIds();

  Future<void> recordGroupMembership({
    required int userId,
    required GroupMembershipStatus status,
    required DateTime at,
  });

  Future<List<GroupInviteNudgeCandidate>> listGroupInviteNudgeCandidates({
    required DateTime now,
    Duration minAgeAfterStart = const Duration(hours: 24),
    int maxNudges = 3,
    int limit = 50,
  });

  Future<void> markGroupInviteNudgeSent({
    required int userId,
    required String nudgeKey,
    required DateTime sentAt,
  });

  Future<bool> hasTrainingFeedbackRequest(int bookingId);

  Future<void> recordTrainingFeedbackRequest({
    required int bookingId,
    required int userId,
    required String sessionKey,
    required String trainingTitle,
    required DateTime sentAt,
  });

  Future<void> submitTrainingFeedback({
    required int bookingId,
    required String sessionKey,
    required TrainingFeedbackRating rating,
    required DateTime submittedAt,
    String? comment,
  });

  Future<TrainingFeedbackRequest?> getTrainingFeedbackRequest(int bookingId);

  Future<bool> hasTrainingFeedback(int bookingId);

  Future<FunnelAnalytics> getFunnelAnalytics({
    required DateTime now,
    int recentCommentsLimit = 10,
    int topSessionsLimit = 8,
  });

  Future<StarterBonusAnalytics> getStarterBonusAnalytics();
}

final class NoopOnboardingRepository implements OnboardingRepository {
  const NoopOnboardingRepository();

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  }) async {}

  @override
  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  }) async {
    return null;
  }

  @override
  Future<OnboardingUserState> ensureStartedUser(
    int userId, {
    required DateTime startedAt,
    OnboardingEntryType? entryType,
  }) async {
    return OnboardingUserState(
      userId: userId,
      phase: OnboardingPhase.legacySkipped,
      startedAt: startedAt,
      entryType: entryType ?? OnboardingEntryType.legacy,
    );
  }

  @override
  Future<OnboardingUserState?> getOnboardingState(int userId) async => null;

  @override
  Future<void> updateOnboardingProgress({
    required int userId,
    OnboardingPhase? phase,
    OnboardingStep? step,
    OnboardingQuizGoal? quizGoal,
    OnboardingQuizExperience? quizExperience,
    OnboardingTrack? selectedTrack,
    OnboardingEntryType? entryType,
    DateTime? onboardingStartedAt,
    DateTime? snoozeUntil,
    bool clearSnooze = false,
  }) async {}

  @override
  Future<bool> tryMarkActivation(
    int userId, {
    required DateTime activatedAt,
  }) async {
    return false;
  }

  @override
  Future<bool> hasNudgeBeenSent({
    required int userId,
    required String nudgeKey,
  }) async {
    return false;
  }

  @override
  Future<void> recordNudgeSent({
    required int userId,
    required String nudgeKey,
    required DateTime sentAt,
    OnboardingPhase? phase,
    OnboardingStep? step,
  }) async {}

  @override
  Future<List<OnboardingNudgeCandidate>> listOnboardingNudgeCandidates({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <OnboardingNudgeCandidate>[];
  }

  @override
  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  }) async {
    return const <PendingWelcomeMessage>[];
  }

  @override
  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<bool> hasStarterBonusAvailable(int userId) async {
    return false;
  }

  @override
  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  }) async {
    return false;
  }

  @override
  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  }) async {}

  @override
  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  }) async {
    return const <StarterBonusReminderTarget>[];
  }

  @override
  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  }) async {}

  @override
  Future<int> getEveryFifthLastNotifiedRewards(int userId) async {
    return 0;
  }

  @override
  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<void> registerReferralAttribution({
    required int inviteeUserId,
    required int inviterUserId,
    required DateTime attributedAt,
  }) async {}

  @override
  Future<List<int>> getAllStartedUserIds() async => const <int>[];

  @override
  Future<void> recordGroupMembership({
    required int userId,
    required GroupMembershipStatus status,
    required DateTime at,
  }) async {}

  @override
  Future<List<GroupInviteNudgeCandidate>> listGroupInviteNudgeCandidates({
    required DateTime now,
    Duration minAgeAfterStart = const Duration(hours: 24),
    int maxNudges = 3,
    int limit = 50,
  }) async {
    return const <GroupInviteNudgeCandidate>[];
  }

  @override
  Future<void> markGroupInviteNudgeSent({
    required int userId,
    required String nudgeKey,
    required DateTime sentAt,
  }) async {}

  @override
  Future<bool> hasTrainingFeedbackRequest(int bookingId) async => false;

  @override
  Future<void> recordTrainingFeedbackRequest({
    required int bookingId,
    required int userId,
    required String sessionKey,
    required String trainingTitle,
    required DateTime sentAt,
  }) async {}

  @override
  Future<void> submitTrainingFeedback({
    required int bookingId,
    required String sessionKey,
    required TrainingFeedbackRating rating,
    required DateTime submittedAt,
    String? comment,
  }) async {}

  @override
  Future<TrainingFeedbackRequest?> getTrainingFeedbackRequest(int bookingId) async {
    return null;
  }

  @override
  Future<bool> hasTrainingFeedback(int bookingId) async => false;

  @override
  Future<FunnelAnalytics> getFunnelAnalytics({
    required DateTime now,
    int recentCommentsLimit = 10,
    int topSessionsLimit = 8,
  }) async {
    return FunnelAnalytics(
      generatedAt: now.toUtc(),
      startedUsersTotal: 0,
      legacyUsers: 0,
      funnelUsers: 0,
      completedUsers: 0,
      phaseCounts: const <String, int>{},
      entryTypeCounts: const <String, int>{},
      quizGoalCounts: const <String, int>{},
      quizExperienceCounts: const <String, int>{},
      trackCounts: const <String, int>{},
      startedLast7Days: 0,
      startedLast30Days: 0,
      activationsTotal: 0,
      activationsLast7Days: 0,
      activationsLast30Days: 0,
      activationRate21Days: null,
      avgTimeToValueDays: null,
      snoozeActiveNow: 0,
      nudgeKeyCounts: const <String, int>{},
      feedbackRequestsSent: 0,
      feedbackResponses: 0,
      feedbackSkipped: 0,
      feedbackRatingCounts: const <String, int>{},
      feedbackCommentsCount: 0,
      recentFeedbackComments: const <RecentFeedbackComment>[],
      topFeedbackSessions: const <FeedbackSessionSummary>[],
    );
  }

  @override
  Future<StarterBonusAnalytics> getStarterBonusAnalytics() async {
    return const StarterBonusAnalytics(availableCount: 0, consumedCount: 0);
  }
}
