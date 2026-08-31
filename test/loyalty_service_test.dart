import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/memory_loyalty_repository.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late InMemoryLoyaltyRepository repository;
  late LoyaltyService service;

  setUp(() {
    now = DateTime.utc(2026, 3, 1, 12);
    repository = InMemoryLoyaltyRepository(nowProvider: () => now);
    service = LoyaltyService(repository: repository, nowProvider: () => now);
  });

  test('first start credits 1000 once; repeat start only extends TTL', () async {
    final first = await service.credit(
      userId: 10,
      amount: LoyaltyMath.startBonusPeaks,
      reason: LoyaltyLedgerReason.start,
      idempotencyKey: LoyaltyKeys.start(10),
      now: now,
    );
    expect(first.applied, isTrue);
    expect(first.account.remaining, 1000);

    now = now.add(const Duration(days: 10));
    final second = await service.credit(
      userId: 10,
      amount: LoyaltyMath.startBonusPeaks,
      reason: LoyaltyLedgerReason.start,
      idempotencyKey: LoyaltyKeys.start(10),
      now: now,
    );
    expect(second.applied, isFalse);
    expect((await service.account(10)).remaining, 1000);

    await service.touchActivity(10, now: now);
    final expires = (await service.account(10)).expiresAt(lifetime: LoyaltyMath.lifetime);
    expect(expires, now.add(LoyaltyMath.lifetime));
  });

  test('expire job is idempotent and burns remaining', () async {
    await service.credit(
      userId: 11,
      amount: 200,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'seed',
      now: now,
    );
    now = now.add(const Duration(days: 45));
    final account = await service.account(11);
    final first = await service.expireDue(account, now: now);
    expect(first.applied, isTrue);
    expect(first.amount, 200);
    expect(first.account.remaining, 0);

    final second = await service.expireDue(await service.account(11), now: now);
    expect(second.applied, isFalse);
    expect((await service.account(11)).remaining, 0);
  });

  test('refund increases balance and is activity', () async {
    await service.credit(
      userId: 12,
      amount: 400,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g',
      now: now,
    );
    await service.debit(
      userId: 12,
      amount: 200,
      reason: LoyaltyLedgerReason.spend,
      idempotencyKey: LoyaltyKeys.spendBooking(5),
      now: now,
      bookingId: 5,
    );
    now = now.add(const Duration(days: 3));
    final refund = await service.refund(
      userId: 12,
      amount: 200,
      idempotencyKey: LoyaltyKeys.refundBooking(5),
      now: now,
      bookingId: 5,
    );
    expect(refund.applied, isTrue);
    expect(refund.account.remaining, 400);
    expect(
      refund.account.expiresAt(lifetime: LoyaltyMath.lifetime),
      now.add(LoyaltyMath.lifetime),
    );
  });

  test('listExpiringSoon matches the 7-day reminder window', () async {
    await service.credit(
      userId: 13,
      amount: 200,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g13',
      now: now,
    );
    now = now.add(const Duration(days: 38));
    final due = await service.listExpiringSoon(now: now);
    expect(due.map((item) => item.userId), contains(13));

    now = now.add(const Duration(days: 1));
    await service.touchActivity(13, now: now);
    final afterTouch = await service.listExpiringSoon(now: now);
    expect(afterTouch.map((item) => item.userId), isNot(contains(13)));
  });

  test('pending card spend refunds restore peaks; card earn is 10% of cash only', () async {
    await service.credit(
      userId: 14,
      amount: 2000,
      reason: LoyaltyLedgerReason.adminGrant,
      idempotencyKey: 'g14',
      now: now,
    );
    await service.debit(
      userId: 14,
      amount: 2000,
      reason: LoyaltyLedgerReason.spend,
      idempotencyKey: LoyaltyKeys.pendingCardSpend(14),
      now: now,
    );
    expect(await service.peaksSpentOnPendingCard(14), 2000);
    now = now.add(const Duration(days: 1));
    final refunded = await service.refund(
      userId: 14,
      amount: 2000,
      idempotencyKey: LoyaltyKeys.pendingCardRefund(14),
      now: now,
    );
    expect(refunded.applied, isTrue);
    expect((await service.account(14)).remaining, 2000);
    expect(service.quoteCardEarn(0), 0);
    expect(service.quoteCardEarn(3500), 700);
    expect(service.quoteCardEarn(2500), 500);
  });
}
