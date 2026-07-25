enum TrainingFeedbackRating {
  great,
  ok,
  weak,
  skipped,
}

extension TrainingFeedbackRatingX on TrainingFeedbackRating {
  String get storageValue => switch (this) {
        TrainingFeedbackRating.great => 'great',
        TrainingFeedbackRating.ok => 'ok',
        TrainingFeedbackRating.weak => 'weak',
        TrainingFeedbackRating.skipped => 'skipped',
      };

  static TrainingFeedbackRating? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in TrainingFeedbackRating.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

final class TrainingFeedbackRequest {
  const TrainingFeedbackRequest({
    required this.bookingId,
    required this.userId,
    required this.sessionKey,
    required this.trainingTitle,
    required this.sentAt,
  });

  final int bookingId;
  final int userId;
  final String sessionKey;
  final String trainingTitle;
  final DateTime sentAt;
}

final class TrainingFeedbackRecord {
  const TrainingFeedbackRecord({
    required this.id,
    required this.bookingId,
    required this.sessionKey,
    required this.rating,
    required this.submittedAt,
    this.comment,
  });

  final int id;
  final int bookingId;
  final String sessionKey;
  final TrainingFeedbackRating rating;
  final DateTime submittedAt;
  final String? comment;
}
