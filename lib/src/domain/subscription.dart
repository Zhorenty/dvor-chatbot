enum SubscriptionRequestStatus {
  paymentSubmitted('payment_submitted'),
  active('active'),
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
  alreadyActive,
}

final class SubmitSubscriptionRequestResult {
  const SubmitSubscriptionRequestResult({
    required this.outcome,
    this.request,
  });

  final SubmitSubscriptionRequestOutcome outcome;
  final SubscriptionRequest? request;
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
