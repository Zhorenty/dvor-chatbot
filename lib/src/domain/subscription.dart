enum SubscriptionRequestStatus {
  paymentSubmitted('payment_submitted'),
  active('active'),
  cancelled('cancelled'),
  rejected('rejected');

  const SubscriptionRequestStatus(this.dbValue);

  final String dbValue;

  static SubscriptionRequestStatus fromDbValue(String value) {
    return SubscriptionRequestStatus.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown subscription status'),
    );
  }
}

enum BoxingCardPlan {
  baza('baza'),
  udar('udar');

  const BoxingCardPlan(this.dbValue);

  final String dbValue;

  int get groupQuota => switch (this) {
        BoxingCardPlan.baza => 4,
        BoxingCardPlan.udar => 8,
      };

  int get individualQuota => 1;

  int get priceRub => switch (this) {
        BoxingCardPlan.baza => 3500,
        BoxingCardPlan.udar => 4700,
      };

  String get displayName => switch (this) {
        BoxingCardPlan.baza => 'БАЗА',
        BoxingCardPlan.udar => 'УДАР',
      };

  static BoxingCardPlan? tryFromDbValue(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final item in BoxingCardPlan.values) {
      if (item.dbValue == value) {
        return item;
      }
    }
    return null;
  }

  static BoxingCardPlan fromDbValue(String value) {
    final parsed = tryFromDbValue(value);
    if (parsed == null) {
      throw ArgumentError.value(value, 'value', 'Unknown boxing card plan');
    }
    return parsed;
  }
}

final class SubscriptionRequest {
  const SubscriptionRequest({
    required this.id,
    required this.userId,
    required this.userUsername,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
    this.activeFrom,
    this.activeUntil,
    this.paymentNote,
    this.paymentProofChatId,
    this.paymentProofMessageId,
    this.moderationReason,
    this.moderationComment,
    this.renewalReminder7SentAt,
    this.renewalReminder3SentAt,
    this.renewalReminder1SentAt,
    this.expiryPromoSentAt,
    this.individualReminderSentAt,
  });

  final int id;
  final int userId;
  final String? userUsername;
  final SubscriptionRequestStatus status;
  final BoxingCardPlan? plan;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  final String? paymentNote;
  final int? paymentProofChatId;
  final int? paymentProofMessageId;
  final String? moderationReason;
  final String? moderationComment;
  final DateTime? renewalReminder7SentAt;
  final DateTime? renewalReminder3SentAt;
  final DateTime? renewalReminder1SentAt;
  final DateTime? expiryPromoSentAt;
  final DateTime? individualReminderSentAt;
}

enum MembershipLevel { normal, boxingCard }

final class SubscriptionMembership {
  const SubscriptionMembership({
    required this.level,
    this.plan,
    this.activeFrom,
    this.activeUntil,
    this.requestId,
  });

  final MembershipLevel level;
  final BoxingCardPlan? plan;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  final int? requestId;
}

enum SubmitSubscriptionRequestOutcome {
  created,
  alreadyPending,
}

final class SubmitSubscriptionRequestResult {
  const SubmitSubscriptionRequestResult({
    required this.outcome,
    this.request,
  });

  final SubmitSubscriptionRequestOutcome outcome;
  final SubscriptionRequest? request;
}

enum CancelSubscriptionOutcome {
  success,
  notFound,
  invalidStatus,
}

final class CancelSubscriptionResult {
  const CancelSubscriptionResult({
    required this.outcome,
    this.request,
  });

  final CancelSubscriptionOutcome outcome;
  final SubscriptionRequest? request;
}

enum SubscriptionListFilter {
  active,
  expiringSoon,
  pending,
  cancelledOrRejected,
}

final class SubscriptionUserSnapshot {
  const SubscriptionUserSnapshot({
    required this.membership,
    required this.totalApprovedCount,
    this.latestPending,
    this.latestRejectedOrCancelled,
    this.latestActiveRequest,
  });

  final SubscriptionMembership membership;
  final int totalApprovedCount;
  final SubscriptionRequest? latestPending;
  final SubscriptionRequest? latestRejectedOrCancelled;
  final SubscriptionRequest? latestActiveRequest;
}

final class RenewalReminderTarget {
  const RenewalReminderTarget({
    required this.request,
    required this.daysBefore,
  });

  final SubscriptionRequest request;
  final int daysBefore;
}

enum ReviewSubscriptionRequestOutcome {
  success,
  notFound,
  invalidStatus,
}

final class ReviewSubscriptionRequestResult {
  const ReviewSubscriptionRequestResult({
    required this.outcome,
    this.request,
  });

  final ReviewSubscriptionRequestOutcome outcome;
  final SubscriptionRequest? request;
}

enum IndividualSessionRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const IndividualSessionRequestStatus(this.dbValue);

  final String dbValue;

  static IndividualSessionRequestStatus fromDbValue(String value) {
    return IndividualSessionRequestStatus.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown individual session status'),
    );
  }
}

final class IndividualSessionRequest {
  const IndividualSessionRequest({
    required this.id,
    required this.userId,
    required this.userUsername,
    required this.subscriptionRequestId,
    required this.preferredTimes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.moderationComment,
    this.reviewedAt,
  });

  final int id;
  final int userId;
  final String? userUsername;
  final int subscriptionRequestId;
  final String preferredTimes;
  final IndividualSessionRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? moderationComment;
  final DateTime? reviewedAt;
}

enum SubmitIndividualSessionOutcome {
  created,
  alreadyPending,
  quotaUsed,
  noActiveCard,
}

final class SubmitIndividualSessionResult {
  const SubmitIndividualSessionResult({
    required this.outcome,
    this.request,
  });

  final SubmitIndividualSessionOutcome outcome;
  final IndividualSessionRequest? request;
}

enum ReviewIndividualSessionOutcome {
  success,
  notFound,
  invalidStatus,
}

final class ReviewIndividualSessionResult {
  const ReviewIndividualSessionResult({
    required this.outcome,
    this.request,
  });

  final ReviewIndividualSessionOutcome outcome;
  final IndividualSessionRequest? request;
}
