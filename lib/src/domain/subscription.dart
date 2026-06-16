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

final class SubscriptionRequest {
  const SubscriptionRequest({
    required this.id,
    required this.userId,
    required this.userUsername,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
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
  });

  final int id;
  final int userId;
  final String? userUsername;
  final SubscriptionRequestStatus status;
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
}

enum MembershipLevel { normal, pro }

final class SubscriptionMembership {
  const SubscriptionMembership({
    required this.level,
    this.activeUntil,
  });

  final MembershipLevel level;
  final DateTime? activeUntil;
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
