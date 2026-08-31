import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/data/loyalty_repository.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';

final class InMemoryLoyaltyRepository implements LoyaltyRepository {
  InMemoryLoyaltyRepository({DateTime Function()? nowProvider})
      : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() _nowProvider;
  final Map<int, LoyaltyAccount> _accounts = <int, LoyaltyAccount>{};
  final List<LoyaltyLedgerEntry> _ledger = <LoyaltyLedgerEntry>[];
  int _nextId = 1;
  bool migrated = false;

  Map<int, LoyaltyAccount> get accounts => _accounts;

  List<LoyaltyLedgerEntry> get ledger => _ledger;

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> migrateIfNeeded({required DateTime now}) async {
    migrated = true;
  }

  @override
  Future<LoyaltyAccount> getAccount(int userId) async {
    return _accounts[userId] ?? LoyaltyAccount(userId: userId, remaining: 0);
  }

  @override
  Future<List<LoyaltyAccount>> listExpired({
    required DateTime now,
    int limit = 200,
  }) async {
    final cutoff = now.subtract(LoyaltyMath.lifetime);
    final result = _accounts.values
        .where(
          (account) =>
              account.remaining > 0 &&
              account.lastLoyaltyActivityAt != null &&
              !account.lastLoyaltyActivityAt!.isAfter(cutoff),
        )
        .take(limit)
        .toList(growable: false);
    return result;
  }

  @override
  Future<List<LoyaltyAccount>> listExpiringSoon({
    required DateTime now,
    required Duration leadTime,
    required Duration lifetime,
    int limit = 200,
  }) async {
    final expiredCutoff = now.subtract(lifetime);
    // last+lifetime - lead <= now < last+lifetime
    // last <= now - (lifetime - lead)  AND last > now - lifetime
    final enteredWindow = now.subtract(lifetime - leadTime);
    final result = _accounts.values
        .where((account) {
          if (account.remaining <= 0) {
            return false;
          }
          final last = account.lastLoyaltyActivityAt;
          if (last == null) {
            return false;
          }
          return !last.isAfter(enteredWindow) && last.isAfter(expiredCutoff);
        })
        .take(limit)
        .toList(growable: false);
    return result;
  }

  @override
  Future<List<LoyaltyLedgerEntry>> listRecentLedger(
    int userId, {
    int limit = 4,
  }) async {
    final items = _ledger.where((entry) => entry.userId == userId && entry.amount != 0).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.length <= limit) {
      return items;
    }
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<LoyaltyLedgerEntry?> findByIdempotencyKey(String key) async {
    for (final entry in _ledger) {
      if (entry.idempotencyKey == key) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<int> peaksSpentOnBooking(int bookingId) async {
    var spent = 0;
    for (final entry in _ledger) {
      if (entry.bookingId != bookingId) {
        continue;
      }
      if (entry.reason == LoyaltyLedgerReason.spend) {
        spent += -entry.amount;
      }
      if (entry.reason == LoyaltyLedgerReason.refund) {
        spent -= entry.amount;
      }
    }
    return spent < 0 ? 0 : spent;
  }

  @override
  Future<int> peaksSpentOnSubscription(int requestId) async {
    var spent = 0;
    for (final entry in _ledger) {
      if (entry.subscriptionRequestId != requestId) {
        continue;
      }
      if (entry.reason == LoyaltyLedgerReason.spend) {
        spent += -entry.amount;
      }
      if (entry.reason == LoyaltyLedgerReason.refund) {
        spent -= entry.amount;
      }
    }
    return spent < 0 ? 0 : spent;
  }

  @override
  Future<int> peaksSpentOnPendingCard(int userId) async {
    final spend = await findByIdempotencyKey(LoyaltyKeys.pendingCardSpend(userId));
    if (spend == null) {
      return 0;
    }
    final refund = await findByIdempotencyKey(LoyaltyKeys.pendingCardRefund(userId));
    final amount = -spend.amount - (refund?.amount ?? 0);
    return amount < 0 ? 0 : amount;
  }

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
    final existing = await findByIdempotencyKey(idempotencyKey);
    if (existing != null) {
      return LoyaltyMutationResult(
        applied: false,
        account: await getAccount(userId),
        amount: 0,
        entry: existing,
      );
    }
    if (amount <= 0) {
      return LoyaltyMutationResult(
        applied: false,
        account: await getAccount(userId),
        amount: 0,
      );
    }
    final current = await getAccount(userId);
    final entry = LoyaltyLedgerEntry(
      id: _nextId++,
      userId: userId,
      amount: amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
      inviteeUserId: inviteeUserId,
    );
    _ledger.add(entry);
    final updated = LoyaltyAccount(
      userId: userId,
      remaining: current.remaining + amount,
      lastLoyaltyActivityAt: now,
    );
    _accounts[userId] = updated;
    return LoyaltyMutationResult(
      applied: true,
      account: updated,
      amount: amount,
      entry: entry,
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
    final existing = await findByIdempotencyKey(idempotencyKey);
    if (existing != null) {
      return LoyaltyMutationResult(
        applied: false,
        account: await getAccount(userId),
        amount: 0,
        entry: existing,
      );
    }
    final current = await getAccount(userId);
    if (amount <= 0 || current.remaining < amount) {
      return LoyaltyMutationResult(
        applied: false,
        account: current,
        amount: 0,
      );
    }
    final entry = LoyaltyLedgerEntry(
      id: _nextId++,
      userId: userId,
      amount: -amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
    );
    _ledger.add(entry);
    final updated = LoyaltyAccount(
      userId: userId,
      remaining: current.remaining - amount,
      lastLoyaltyActivityAt: now,
    );
    _accounts[userId] = updated;
    return LoyaltyMutationResult(
      applied: true,
      account: updated,
      amount: amount,
      entry: entry,
    );
  }

  @override
  Future<void> touchActivity({
    required int userId,
    required DateTime now,
  }) async {
    final current = await getAccount(userId);
    _accounts[userId] = LoyaltyAccount(
      userId: userId,
      remaining: current.remaining,
      lastLoyaltyActivityAt: now,
    );
  }

  @override
  Future<LoyaltyPeaksAnalytics> getPeaksAnalytics() async {
    var earned = 0;
    var spent = 0;
    var expired = 0;
    for (final entry in _ledger) {
      switch (entry.reason) {
        case LoyaltyLedgerReason.spend:
        case LoyaltyLedgerReason.adminDebit:
          spent += -entry.amount;
        case LoyaltyLedgerReason.expire:
          expired += -entry.amount;
        case LoyaltyLedgerReason.refund:
          break;
        default:
          if (entry.amount > 0) {
            earned += entry.amount;
          }
      }
    }
    var remaining = 0;
    for (final account in _accounts.values) {
      remaining += account.remaining;
    }
    return LoyaltyPeaksAnalytics(
      earnedTotal: earned,
      spentTotal: spent,
      expiredTotal: expired,
      remainingTotal: remaining,
    );
  }

  DateTime now() => _nowProvider();
}
