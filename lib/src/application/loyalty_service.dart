import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/data/loyalty_repository.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';

final class LoyaltyService {
  LoyaltyService({
    required LoyaltyRepository repository,
    DateTime Function()? nowProvider,
  })  : _repository = repository,
        _nowProvider = nowProvider ?? DateTime.now;

  final LoyaltyRepository _repository;
  final DateTime Function() _nowProvider;

  Future<void> init() => _repository.init();

  Future<void> close() => _repository.close();

  Future<LoyaltyAccount> account(int userId) => _repository.getAccount(userId);

  Future<int> availableBalance(int userId, {DateTime? now}) async {
    final at = now ?? _nowProvider();
    final current = await _repository.getAccount(userId);
    if (current.isExpired(at, lifetime: LoyaltyMath.lifetime)) {
      return 0;
    }
    return current.remaining;
  }

  LoyaltySpendQuote quoteSpend({
    required LoyaltySpendTarget target,
    required int priceRub,
    required int balance,
    int alreadySpent = 0,
  }) {
    return LoyaltyMath.quoteSpend(
      target: target,
      priceRub: priceRub,
      balance: balance,
      alreadySpent: alreadySpent,
    );
  }

  int quoteTrainingEarn(int remainderRub) => LoyaltyMath.trainingEarnPeaks(remainderRub);

  int quoteOutdoorEarn(int paidRub) => LoyaltyMath.outdoorEarnPeaks(paidRub);

  int quoteCardEarn(int paidRub) => LoyaltyMath.boxingCardEarnPeaks(paidRub);

  Future<List<LoyaltyLedgerEntry>> recentLedger(int userId, {int limit = 4}) {
    return _repository.listRecentLedger(userId, limit: limit);
  }

  Future<int> peaksSpentOnBooking(int bookingId) {
    return _repository.peaksSpentOnBooking(bookingId);
  }

  Future<int> peaksSpentOnSubscription(int requestId) {
    return _repository.peaksSpentOnSubscription(requestId);
  }

  Future<int> peaksSpentOnPendingCard(int userId) {
    return _repository.peaksSpentOnPendingCard(userId);
  }

  Future<LoyaltyPeaksAnalytics> peaksAnalytics() => _repository.getPeaksAnalytics();

  Future<List<LoyaltyAccount>> listExpired({DateTime? now, int limit = 200}) {
    return _repository.listExpired(now: now ?? _nowProvider(), limit: limit);
  }

  Future<List<LoyaltyAccount>> listExpiringSoon({DateTime? now, int limit = 200}) {
    return _repository.listExpiringSoon(
      now: now ?? _nowProvider(),
      leadTime: LoyaltyMath.reminderLead,
      lifetime: LoyaltyMath.lifetime,
      limit: limit,
    );
  }

  Future<bool> hasEntry(String idempotencyKey) async {
    return (await _repository.findByIdempotencyKey(idempotencyKey)) != null;
  }

  Future<LoyaltyMutationResult> credit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    DateTime? now,
    int? bookingId,
    int? subscriptionRequestId,
    int? inviteeUserId,
  }) {
    return _repository.credit(
      userId: userId,
      amount: amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      now: now ?? _nowProvider(),
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
      inviteeUserId: inviteeUserId,
    );
  }

  Future<LoyaltyMutationResult> debit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    DateTime? now,
    int? bookingId,
    int? subscriptionRequestId,
  }) async {
    final at = now ?? _nowProvider();
    final current = await _repository.getAccount(userId);
    if (current.isExpired(at, lifetime: LoyaltyMath.lifetime)) {
      return LoyaltyMutationResult(applied: false, account: current, amount: 0);
    }
    return _repository.debit(
      userId: userId,
      amount: amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      now: at,
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
    );
  }

  Future<LoyaltyMutationResult> refund({
    required int userId,
    required int amount,
    required String idempotencyKey,
    DateTime? now,
    int? bookingId,
    int? subscriptionRequestId,
  }) {
    return _repository.credit(
      userId: userId,
      amount: amount,
      reason: LoyaltyLedgerReason.refund,
      idempotencyKey: idempotencyKey,
      now: now ?? _nowProvider(),
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
    );
  }

  Future<void> touchActivity(int userId, {DateTime? now}) {
    return _repository.touchActivity(userId: userId, now: now ?? _nowProvider());
  }

  Future<LoyaltyMutationResult> expireDue(LoyaltyAccount account, {DateTime? now}) async {
    final at = now ?? _nowProvider();
    if (account.remaining <= 0 || !account.isExpired(at, lifetime: LoyaltyMath.lifetime)) {
      return LoyaltyMutationResult(applied: false, account: account, amount: 0);
    }
    final expires = account.expiresAt(lifetime: LoyaltyMath.lifetime) ?? at;
    return _repository.debit(
      userId: account.userId,
      amount: account.remaining,
      reason: LoyaltyLedgerReason.expire,
      idempotencyKey: LoyaltyKeys.expire(account.userId, expires),
      now: at,
    );
  }

  Future<LoyaltyMutationResult> adminGrant({
    required int userId,
    required int amount,
    DateTime? now,
  }) async {
    if (amount <= 0 || amount % LoyaltyMath.unit != 0) {
      return LoyaltyMutationResult(
        applied: false,
        account: await _repository.getAccount(userId),
        amount: 0,
      );
    }
    final at = now ?? _nowProvider();
    return _repository.credit(
      userId: userId,
      amount: amount,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: LoyaltyKeys.adminGrant(userId, at),
      now: at,
    );
  }

  Future<LoyaltyMutationResult> adminDebit({
    required int userId,
    required int amount,
    DateTime? now,
  }) async {
    if (amount <= 0 || amount % LoyaltyMath.unit != 0) {
      return LoyaltyMutationResult(
        applied: false,
        account: await _repository.getAccount(userId),
        amount: 0,
      );
    }
    final at = now ?? _nowProvider();
    return _repository.debit(
      userId: userId,
      amount: amount,
      reason: LoyaltyLedgerReason.adminDebit,
      idempotencyKey: LoyaltyKeys.adminDebit(userId, at),
      now: at,
    );
  }
}
