final class FunnelAnalytics {
  const FunnelAnalytics({
    required this.generatedAt,
    required this.startedUsersTotal,
    required this.legacyUsers,
    required this.funnelUsers,
    required this.completedUsers,
    required this.phaseCounts,
    required this.entryTypeCounts,
    required this.quizGoalCounts,
    required this.quizExperienceCounts,
    required this.trackCounts,
    required this.startedLast7Days,
    required this.startedLast30Days,
    required this.activationsTotal,
    required this.activationsLast7Days,
    required this.activationsLast30Days,
    required this.activationRate21Days,
    required this.avgTimeToValueDays,
    required this.snoozeActiveNow,
    required this.nudgeKeyCounts,
    required this.feedbackRequestsSent,
    required this.feedbackResponses,
    required this.feedbackSkipped,
    required this.feedbackRatingCounts,
    required this.feedbackCommentsCount,
    required this.recentFeedbackComments,
    required this.topFeedbackSessions,
  });

  final DateTime generatedAt;
  final int startedUsersTotal;
  final int legacyUsers;
  final int funnelUsers;
  final int completedUsers;
  final Map<String, int> phaseCounts;
  final Map<String, int> entryTypeCounts;
  final Map<String, int> quizGoalCounts;
  final Map<String, int> quizExperienceCounts;
  final Map<String, int> trackCounts;
  final int startedLast7Days;
  final int startedLast30Days;
  final int activationsTotal;
  final int activationsLast7Days;
  final int activationsLast30Days;

  /// Share of funnel users with start in window who activated within 21 days.
  /// `null` when denominator is 0.
  final double? activationRate21Days;

  /// Average days from onboarding start to activation. `null` when no activations.
  final double? avgTimeToValueDays;
  final int snoozeActiveNow;
  final Map<String, int> nudgeKeyCounts;
  final int feedbackRequestsSent;
  final int feedbackResponses;
  final int feedbackSkipped;
  final Map<String, int> feedbackRatingCounts;
  final int feedbackCommentsCount;
  final List<RecentFeedbackComment> recentFeedbackComments;
  final List<FeedbackSessionSummary> topFeedbackSessions;

  int get quizGoalAnsweredCount => _sumCounts(quizGoalCounts);

  int get quizExperienceAnsweredCount => _sumCounts(quizExperienceCounts);

  int get trackChosenCount => _sumCounts(trackCounts);

  /// Share of people who chose a format and then got a first training.
  double? get mapToActivationRate {
    if (trackChosenCount <= 0) {
      return null;
    }
    return activationsTotal / trackChosenCount;
  }

  double? get feedbackResponseRate {
    if (feedbackRequestsSent <= 0) {
      return null;
    }
    return feedbackResponses / feedbackRequestsSent;
  }

  static int _sumCounts(Map<String, int> counts) {
    return counts.values.fold(0, (sum, value) => sum + value);
  }
}

final class RecentFeedbackComment {
  const RecentFeedbackComment({
    required this.trainingTitle,
    required this.rating,
    required this.submittedAt,
    this.comment,
  });

  final String trainingTitle;
  final String rating;
  final DateTime submittedAt;
  final String? comment;
}

final class FeedbackSessionSummary {
  const FeedbackSessionSummary({
    required this.trainingTitle,
    required this.sessionKey,
    required this.responses,
    required this.greatCount,
    required this.okCount,
    required this.weakCount,
  });

  final String trainingTitle;
  final String sessionKey;
  final int responses;
  final int greatCount;
  final int okCount;
  final int weakCount;
}
