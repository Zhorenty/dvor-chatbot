enum LoyaltyLedgerReason {
  start('start'),
  training('training'),
  feedback('feedback'),
  hike('hike'),
  trail('trail'),
  referral('referral'),
  boxingCard('boxing_card'),
  expire('expire'),
  spend('spend'),
  refund('refund'),
  adminGrant('admin_grant'),
  adminDebit('admin_debit'),
  migration('migration');

  const LoyaltyLedgerReason(this.dbValue);

  final String dbValue;

  static LoyaltyLedgerReason fromDbValue(String value) {
    return LoyaltyLedgerReason.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown loyalty reason'),
    );
  }
}

enum LoyaltySpendTarget {
  training,
  outdoor,
  boxingCard,
}

final class LoyaltyAccount {
  const LoyaltyAccount({
    required this.userId,
    required this.remaining,
    this.lastLoyaltyActivityAt,
  });

  final int userId;
  final int remaining;
  final DateTime? lastLoyaltyActivityAt;

  DateTime? expiresAt({Duration lifetime = const Duration(days: 45)}) {
    final last = lastLoyaltyActivityAt;
    if (last == null) {
      return null;
    }
    return last.add(lifetime);
  }

  bool isExpired(DateTime now, {Duration lifetime = const Duration(days: 45)}) {
    final expires = expiresAt(lifetime: lifetime);
    if (expires == null || remaining <= 0) {
      return false;
    }
    return !expires.isAfter(now);
  }
}

final class LoyaltyLedgerEntry {
  const LoyaltyLedgerEntry({
    required this.id,
    required this.userId,
    required this.amount,
    required this.reason,
    required this.idempotencyKey,
    required this.createdAt,
    this.bookingId,
    this.subscriptionRequestId,
    this.inviteeUserId,
  });

  final int id;
  final int userId;

  /// Signed: credit > 0, debit < 0.
  final int amount;
  final LoyaltyLedgerReason reason;
  final String idempotencyKey;
  final DateTime createdAt;
  final int? bookingId;
  final int? subscriptionRequestId;
  final int? inviteeUserId;
}

final class LoyaltyMutationResult {
  const LoyaltyMutationResult({
    required this.applied,
    required this.account,
    required this.amount,
    this.entry,
  });

  /// False when the idempotency key already existed or the mutation was a no-op.
  final bool applied;
  final LoyaltyAccount account;
  final int amount;
  final LoyaltyLedgerEntry? entry;
}

final class LoyaltySpendQuote {
  const LoyaltySpendQuote({
    required this.peaks,
    required this.remainderRub,
    required this.coversFully,
  });

  final int peaks;
  final int remainderRub;
  final bool coversFully;
}

final class LoyaltyPeaksAnalytics {
  const LoyaltyPeaksAnalytics({
    required this.earnedTotal,
    required this.spentTotal,
    required this.expiredTotal,
    required this.remainingTotal,
  });

  final int earnedTotal;
  final int spentTotal;
  final int expiredTotal;
  final int remainingTotal;
}

final class ReferralAttribution {
  const ReferralAttribution({
    required this.inviteeUserId,
    required this.inviterUserId,
    required this.attributedAt,
  });

  final int inviteeUserId;
  final int inviterUserId;
  final DateTime attributedAt;
}

/// Idempotency keys. Restart must not double-credit or double-burn.
abstract final class LoyaltyKeys {
  static String start(int userId) => '$userId+/start';

  static String training(int bookingId) => '$bookingId+training';

  static String feedback(int bookingId) => '$bookingId+feedback';

  static String hike(int bookingId) => '$bookingId+hike';

  static String trail(int bookingId) => '$bookingId+trail';

  static String spendBooking(int bookingId) => '$bookingId+spend';

  static String refundBooking(int bookingId) => '$bookingId+refund';

  static String referral(int inviteeUserId) => 'referral:$inviteeUserId';

  static String boxingCard(int requestId) => '$requestId+boxing_card';

  static String spendSubscription(int requestId) => '$requestId+spend';

  static String refundSubscription(int requestId) => '$requestId+refund';

  static String expire(int userId, DateTime expiresAtDay) {
    final day = expiresAtDay.toUtc();
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return 'expire:$userId:${day.year}-$mm-$dd';
  }

  static String reminder(int userId, DateTime expiresAtDay) {
    final day = expiresAtDay.toUtc();
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return 'loyalty_reminder:$userId:${day.year}-$mm-$dd';
  }

  static String migrationEveryFifth(int bookingId) => '$bookingId+migration_every_fifth';

  static String migrationEveryFifthUnused(int userId) => 'migration:$userId+every_fifth_unused';

  static String migrationStarter(int userId) => 'migration:$userId+starter';

  static String migrationReferralUnused(int inviterUserId, int index) =>
      'migration:$inviterUserId+referral_unused:$index';

  static String adminGrant(int userId, DateTime at) =>
      'admin_grant:$userId:${at.toUtc().toIso8601String()}';

  static String adminDebit(int userId, DateTime at) =>
      'admin_debit:$userId:${at.toUtc().toIso8601String()}';

  static String pendingCardSpend(int userId) => 'card_pending:$userId+spend';

  static String pendingCardRefund(int userId) => 'card_pending:$userId+refund';
}
