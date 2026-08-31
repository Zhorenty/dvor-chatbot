import 'package:dvor_chatbot/src/domain/loyalty.dart';

abstract interface class LoyaltyRepository {
  Future<void> init();

  Future<void> close();

  Future<void> migrateIfNeeded({required DateTime now});

  Future<LoyaltyAccount> getAccount(int userId);

  Future<List<LoyaltyAccount>> listExpired({
    required DateTime now,
    int limit = 200,
  });

  Future<List<LoyaltyAccount>> listExpiringSoon({
    required DateTime now,
    required Duration leadTime,
    required Duration lifetime,
    int limit = 200,
  });

  Future<List<LoyaltyLedgerEntry>> listRecentLedger(
    int userId, {
    int limit = 4,
  });

  Future<LoyaltyLedgerEntry?> findByIdempotencyKey(String key);

  Future<int> peaksSpentOnBooking(int bookingId);

  Future<int> peaksSpentOnSubscription(int requestId);

  Future<int> peaksSpentOnPendingCard(int userId);

  /// Credits [amount] (> 0). No-op if [idempotencyKey] already exists.
  Future<LoyaltyMutationResult> credit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
    int? inviteeUserId,
  });

  /// Debits [amount] (> 0). Fails closed (applied=false) if balance is insufficient
  /// or the key already exists.
  Future<LoyaltyMutationResult> debit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
  });

  Future<void> touchActivity({
    required int userId,
    required DateTime now,
  });

  Future<LoyaltyPeaksAnalytics> getPeaksAnalytics();
}

final class NoopLoyaltyRepository implements LoyaltyRepository {
  const NoopLoyaltyRepository();

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> migrateIfNeeded({required DateTime now}) async {}

  @override
  Future<LoyaltyAccount> getAccount(int userId) async {
    return LoyaltyAccount(userId: userId, remaining: 0);
  }

  @override
  Future<List<LoyaltyAccount>> listExpired({
    required DateTime now,
    int limit = 200,
  }) async {
    return const <LoyaltyAccount>[];
  }

  @override
  Future<List<LoyaltyAccount>> listExpiringSoon({
    required DateTime now,
    required Duration leadTime,
    required Duration lifetime,
    int limit = 200,
  }) async {
    return const <LoyaltyAccount>[];
  }

  @override
  Future<List<LoyaltyLedgerEntry>> listRecentLedger(
    int userId, {
    int limit = 4,
  }) async {
    return const <LoyaltyLedgerEntry>[];
  }

  @override
  Future<LoyaltyLedgerEntry?> findByIdempotencyKey(String key) async => null;

  @override
  Future<int> peaksSpentOnBooking(int bookingId) async => 0;

  @override
  Future<int> peaksSpentOnSubscription(int requestId) async => 0;

  @override
  Future<int> peaksSpentOnPendingCard(int userId) async => 0;

  @override
  Future<LoyaltyMutationResult> credit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
    int? inviteeUserId,
  }) async {
    return LoyaltyMutationResult(
      applied: false,
      account: LoyaltyAccount(userId: userId, remaining: 0),
      amount: 0,
    );
  }

  @override
  Future<LoyaltyMutationResult> debit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
  }) async {
    return LoyaltyMutationResult(
      applied: false,
      account: LoyaltyAccount(userId: userId, remaining: 0),
      amount: 0,
    );
  }

  @override
  Future<void> touchActivity({
    required int userId,
    required DateTime now,
  }) async {}

  @override
  Future<LoyaltyPeaksAnalytics> getPeaksAnalytics() async {
    return const LoyaltyPeaksAnalytics(
      earnedTotal: 0,
      spentTotal: 0,
      expiredTotal: 0,
      remainingTotal: 0,
    );
  }
}
