import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_rules.dart';
import 'package:dvor_chatbot/src/data/loyalty_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_attendance.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';

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

  /// Spendable balance for each id. Missing and expired accounts are 0.
  Future<Map<int, int>> availableBalances(Iterable<int> userIds, {DateTime? now}) async {
    final at = now ?? _nowProvider();
    final ids = userIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) {
      return const <int, int>{};
    }
    final listed = await _repository.listAccounts(ids);
    final byId = <int, LoyaltyAccount>{
      for (final account in listed) account.userId: account,
    };
    final balances = <int, int>{};
    for (final id in ids) {
      final account = byId[id];
      if (account == null || account.isExpired(at, lifetime: LoyaltyMath.lifetime)) {
        balances[id] = 0;
        continue;
      }
      balances[id] = account.remaining;
    }
    return balances;
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

  Future<int> netTrainingPeaks(int bookingId) {
    return _repository.netTrainingPeaks(bookingId);
  }

  /// Brings training-earn peaks in line with admin attendance.
  ///
  /// Unmarked bookings are left alone so older auto-credits stay put.
  /// Absent bookings are pulled back to zero. Attended bookings are topped up
  /// to the earn quote. A failed debit (balance too small) reports
  /// [TrainingPeaksSync.applied] false while [TrainingPeaksSync.requested] keeps
  /// the intended delta.
  Future<TrainingPeaksSync> syncTrainingPeaks({
    required TrainingBooking booking,
    required DateTime now,
    required bool isTraining,
  }) async {
    final account = await _repository.getAccount(booking.userId);
    if (!isTraining) {
      return TrainingPeaksSync(requested: 0, applied: true, remaining: account.remaining);
    }
    final peaksSpent = await _repository.peaksSpentOnBooking(booking.id);
    final attended = booking.attendance == BookingAttendance.attended;
    final absent = booking.attendance == BookingAttendance.absent;
    final eligible = LoyaltyRules.canEarnTraining(
      booking: booking,
      now: now,
      peaksSpent: peaksSpent,
    );
    if (!attended && !absent) {
      return TrainingPeaksSync(requested: 0, applied: true, remaining: account.remaining);
    }
    final target = eligible
        ? quoteTrainingEarn(
            LoyaltyMath.remainderRub(
              priceRub: booking.trainingPrice ?? 0,
              peaksSpent: peaksSpent,
            ),
          )
        : 0;
    final net = await _repository.netTrainingPeaks(booking.id);
    final delta = target - net;
    if (delta == 0) {
      return TrainingPeaksSync(requested: 0, applied: true, remaining: account.remaining);
    }
    final credit = delta > 0;
    final result = credit
        ? await this.credit(
            userId: booking.userId,
            amount: delta,
            reason: LoyaltyLedgerReason.training,
            idempotencyKey: LoyaltyKeys.attendanceAdjustment(booking.id, now, credit: true),
            now: now,
            bookingId: booking.id,
          )
        : await debit(
            userId: booking.userId,
            amount: -delta,
            reason: LoyaltyLedgerReason.adminDebit,
            idempotencyKey: LoyaltyKeys.attendanceAdjustment(booking.id, now, credit: false),
            now: now,
            bookingId: booking.id,
          );
    return TrainingPeaksSync(
      requested: delta,
      applied: result.applied,
      remaining: result.account.remaining,
    );
  }

  /// One snapshot per id. Bookings with no ledger rows are spent 0, earned 0.
  Future<Map<int, BookingPeaksSnapshot>> peaksByBookings(Iterable<int> bookingIds) async {
    final ids = bookingIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) {
      return const <int, BookingPeaksSnapshot>{};
    }
    final listed = await _repository.peaksByBookings(ids);
    return <int, BookingPeaksSnapshot>{
      for (final id in ids) id: listed[id] ?? const BookingPeaksSnapshot(),
    };
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

final class TrainingPeaksSync {
  const TrainingPeaksSync({
    required this.requested,
    required this.applied,
    required this.remaining,
  });

  /// Signed peaks the attendance mark asked to move. Zero when nothing changed.
  final int requested;

  /// False when the ledger write did not land (for example the balance is too small).
  final bool applied;
  final int remaining;

  int get appliedDelta => applied ? requested : 0;
}
