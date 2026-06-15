import 'package:dvor_chatbot/src/domain/subscription.dart';

abstract interface class SubscriptionRepository {
  Future<void> init();

  Future<void> close();

  Future<SubscriptionMembership> getMembership(
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

  Future<List<SubscriptionRequest>> listActiveSubscriptions({
    required DateTime now,
    int limit = 100,
  });
}

final class NoopSubscriptionRepository implements SubscriptionRepository {
  const NoopSubscriptionRepository();

  @override
  Future<void> close() async {}

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
  Future<List<SubscriptionRequest>> listActiveSubscriptions({
    required DateTime now,
    int limit = 100,
  }) async {
    return const <SubscriptionRequest>[];
  }

  @override
  Future<List<SubscriptionRequest>> listPendingRequests({int limit = 50}) async {
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
}
