import 'package:dvor_chatbot/src/domain/subscription.dart';

abstract interface class SubscriptionRepository {
  Future<void> init();

  Future<void> close();

  Future<SubscriptionMembership> getMembership(
    int userId, {
    required DateTime now,
  });

  Future<SubscriptionUserSnapshot> getUserSnapshot(
    int userId, {
    required DateTime now,
  });

  Future<SubmitSubscriptionRequestResult> submitPaymentRequest({
    required int userId,
    String? userUsername,
    String? note,
    required int paymentProofChatId,
    required int paymentProofMessageId,
    required DateTime requestedAt,
  });

  Future<List<SubscriptionRequest>> listPendingRequests({int limit = 50});

  Future<ReviewSubscriptionRequestResult> reviewPendingRequest({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
  });

  Future<CancelSubscriptionResult> cancelActiveSubscription({
    required int requestId,
    required DateTime cancelledAt,
    String? reason,
    String? comment,
  });

  Future<List<SubscriptionRequest>> listActiveSubscriptions({
    required DateTime now,
    int limit = 100,
  });

  Future<List<SubscriptionRequest>> listSubscriptionsByFilter({
    required SubscriptionListFilter filter,
    required DateTime now,
    int limit = 200,
  });

  Future<List<SubscriptionRequest>> searchSubscriptions(
    String query, {
    required DateTime now,
    int limit = 100,
  });

  Future<ReviewSubscriptionRequestResult> reviewPendingRequestWithReason({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
    String? reason,
    String? comment,
  });

  Future<List<RenewalReminderTarget>> listRenewalReminderTargets({
    required DateTime now,
    int limit = 100,
  });

  Future<void> markRenewalReminderSent({
    required int requestId,
    required int daysBefore,
    required DateTime sentAt,
  });

  Future<List<SubscriptionRequest>> listExpiredWithoutPromo({
    required DateTime now,
    int limit = 100,
  });

  Future<void> markExpiryPromoSent({
    required int requestId,
    required DateTime sentAt,
  });
}

final class NoopSubscriptionRepository implements SubscriptionRepository {
  const NoopSubscriptionRepository();

  @override
  Future<void> close() async {}

  @override
  Future<CancelSubscriptionResult> cancelActiveSubscription({
    required int requestId,
    required DateTime cancelledAt,
    String? reason,
    String? comment,
  }) async {
    return const CancelSubscriptionResult(outcome: CancelSubscriptionOutcome.notFound);
  }

  @override
  Future<void> init() async {}

  @override
  Future<SubscriptionMembership> getMembership(
    int userId, {
    required DateTime now,
  }) async {
    return const SubscriptionMembership(level: MembershipLevel.normal);
  }

  @override
  Future<SubscriptionUserSnapshot> getUserSnapshot(
    int userId, {
    required DateTime now,
  }) async {
    return const SubscriptionUserSnapshot(
      membership: SubscriptionMembership(level: MembershipLevel.normal),
      totalApprovedCount: 0,
    );
  }

  @override
  Future<List<SubscriptionRequest>> listActiveSubscriptions({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<List<SubscriptionRequest>> listSubscriptionsByFilter({
    required SubscriptionListFilter filter,
    required DateTime now,
    int limit = 200,
  }) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<List<SubscriptionRequest>> listPendingRequests({int limit = 50}) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<List<SubscriptionRequest>> searchSubscriptions(
    String query, {
    required DateTime now,
    int limit = 100,
  }) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<ReviewSubscriptionRequestResult> reviewPendingRequest({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
  }) async {
    return const ReviewSubscriptionRequestResult(
      outcome: ReviewSubscriptionRequestOutcome.notFound,
    );
  }

  @override
  Future<ReviewSubscriptionRequestResult> reviewPendingRequestWithReason({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
    String? reason,
    String? comment,
  }) async {
    return const ReviewSubscriptionRequestResult(
      outcome: ReviewSubscriptionRequestOutcome.notFound,
    );
  }

  @override
  Future<SubmitSubscriptionRequestResult> submitPaymentRequest({
    required int userId,
    String? userUsername,
    String? note,
    required int paymentProofChatId,
    required int paymentProofMessageId,
    required DateTime requestedAt,
  }) async {
    return const SubmitSubscriptionRequestResult(
      outcome: SubmitSubscriptionRequestOutcome.created,
    );
  }

  @override
  Future<List<RenewalReminderTarget>> listRenewalReminderTargets({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <RenewalReminderTarget>[];
  }

  @override
  Future<void> markRenewalReminderSent({
    required int requestId,
    required int daysBefore,
    required DateTime sentAt,
  }) async {}

  @override
  Future<List<SubscriptionRequest>> listExpiredWithoutPromo({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<void> markExpiryPromoSent({
    required int requestId,
    required DateTime sentAt,
  }) async {}
}
