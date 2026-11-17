import 'dart:io';

import 'package:dvor_chatbot/src/application/boxing_card_ledger.dart';
import 'package:dvor_chatbot/src/data/sqlite_subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/private_handlers_harness.dart';

void main() {
  group('ledger usedOffset', () {
    test('offset reduces remaining and is clamped at zero', () {
      expect(
        BoxingCardLedger.remainingGroupSlots(plan: BoxingCardPlan.udar, used: 1, usedOffset: 4),
        3,
      );
      expect(
        BoxingCardLedger.remainingGroupSlots(plan: BoxingCardPlan.baza, used: 3, usedOffset: 5),
        0,
      );
    });
  });

  group('SqliteSubscriptionRepository manual grant', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dvor-manual-sub-');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('grants active card, refuses duplicate, updates offset', () async {
      final now = DateTime(2030, 7, 1, 12);
      final repo = SqliteSubscriptionRepository(dbPath: '${tmpDir.path}/b.sqlite');
      await repo.init();

      final granted = await repo.grantManually(
        userId: 55,
        userUsername: '@boxer',
        plan: BoxingCardPlan.udar,
        activatedAt: now,
        days: 30,
        usedOffset: 5,
      );
      expect(granted.outcome, GrantSubscriptionOutcome.granted);
      expect(granted.request!.userUsername, 'boxer');
      expect(granted.request!.usedOffset, 5);

      final membership = await repo.getMembership(55, now: now.add(const Duration(days: 1)));
      expect(membership.level, MembershipLevel.boxingCard);
      expect(membership.plan, BoxingCardPlan.udar);
      expect(membership.usedOffset, 5);

      final again = await repo.grantManually(
        userId: 55,
        plan: BoxingCardPlan.baza,
        activatedAt: now,
        days: 30,
      );
      expect(again.outcome, GrantSubscriptionOutcome.alreadyActive);

      final updated = await repo.setUsedOffset(
        requestId: granted.request!.id,
        usedOffset: 2,
        updatedAt: now,
      );
      expect(updated!.usedOffset, 2);
      await repo.close();
    });
  });

  group('admin commands', () {
    final admin = 9100;

    test('/grant_subscription grants and notifies user', () async {
      final repo = FakeSubscriptionRepository();
      final h = PrivateHandlersHarness(
        adminUserIds: <int>{admin},
        subscriptionRepository: repo,
        nowProvider: () => DateTime(2030, 7, 1, 12),
      );
      await h.handleText(chatId: admin, userId: admin, text: '/grant_subscription 777 baza 2 14');
      expect(repo.grantCalls, hasLength(1));
      expect(repo.grantCalls.single.userId, 777);
      expect(repo.grantCalls.single.plan, BoxingCardPlan.baza);
      expect(repo.grantCalls.single.days, 14);
      expect(repo.grantCalls.single.usedOffset, 2); // quota 4 - remaining 2
      expect(h.messagesTo(777), isNotEmpty);
      expect(h.messagesTo(admin).last.text, contains('Абонемент выдан'));
    });

    test('/grant_subscription defaults to full quota', () async {
      final repo = FakeSubscriptionRepository();
      final h = PrivateHandlersHarness(adminUserIds: <int>{admin}, subscriptionRepository: repo);
      await h.handleText(chatId: admin, userId: admin, text: '/grant_subscription 777 udar');
      expect(repo.grantCalls.single.usedOffset, 0);
      expect(repo.grantCalls.single.days, 30);
    });

    test('/grant_subscription rejects bad input and non-admin', () async {
      final repo = FakeSubscriptionRepository();
      final h = PrivateHandlersHarness(adminUserIds: <int>{admin}, subscriptionRepository: repo);
      await h.handleText(chatId: admin, userId: admin, text: '/grant_subscription 777 baza 9');
      await h.handleText(chatId: 5, userId: 5, text: '/grant_subscription 777 baza');
      expect(repo.grantCalls, isEmpty);
    });

    test('/set_subscription_left sets offset from desired remaining', () async {
      final repo = FakeSubscriptionRepository();
      final now = DateTime(2030, 7, 1, 12);
      repo.requestsById[41] = SubscriptionRequest(
        id: 41,
        userId: 321,
        userUsername: null,
        status: SubscriptionRequestStatus.active,
        plan: BoxingCardPlan.udar,
        createdAt: now,
        updatedAt: now,
        activeFrom: now,
        activeUntil: now.add(const Duration(days: 30)),
      );
      final h = PrivateHandlersHarness(
        adminUserIds: <int>{admin},
        subscriptionRepository: repo,
        nowProvider: () => now,
      );
      await h.handleText(chatId: admin, userId: admin, text: '/set_subscription_left 41 3');
      expect(repo.setOffsetCalls.single.requestId, 41);
      expect(repo.setOffsetCalls.single.usedOffset, 5); // 8 - 0 used - 3 left
      expect(h.messagesTo(321), isNotEmpty);
    });
  });
}
