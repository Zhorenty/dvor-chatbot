import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteSubscriptionRepository', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dvor-subs-test-');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('creates request and activates membership after approval', () async {
      final now = DateTime(2030, 7, 1, 12);
      final repository = SqliteSubscriptionRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final submit = await repository.submitPaymentRequest(
        userId: 101,
        userUsername: 'runner',
        plan: BoxingCardPlan.baza,
        paymentProofChatId: 101,
        paymentProofMessageId: 777,
        requestedAt: now,
      );
      expect(submit.outcome, SubmitSubscriptionRequestOutcome.created);
      expect(submit.request, isNotNull);

      final pending = await repository.listPendingRequests();
      expect(pending, hasLength(1));
      expect(pending.single.id, submit.request!.id);

      final review = await repository.reviewPendingRequest(
        requestId: submit.request!.id,
        approve: true,
        reviewedAt: now.add(const Duration(minutes: 5)),
      );
      expect(review.outcome, ReviewSubscriptionRequestOutcome.success);
      expect(review.request?.status, SubscriptionRequestStatus.active);

      final membership = await repository.getMembership(
        101,
        now: now.add(const Duration(minutes: 10)),
      );
      expect(membership.level, MembershipLevel.boxingCard);
      expect(membership.plan, BoxingCardPlan.baza);
      expect(membership.activeUntil, isNotNull);

      await repository.close();
    });

    test('returns alreadyPending when second request submitted before review', () async {
      final now = DateTime(2030, 7, 1, 12);
      final repository = SqliteSubscriptionRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final first = await repository.submitPaymentRequest(
        userId: 202,
        plan: BoxingCardPlan.udar,
        paymentProofChatId: 202,
        paymentProofMessageId: 1,
        requestedAt: now,
      );
      final second = await repository.submitPaymentRequest(
        userId: 202,
        plan: BoxingCardPlan.baza,
        paymentProofChatId: 202,
        paymentProofMessageId: 2,
        requestedAt: now.add(const Duration(minutes: 1)),
      );

      expect(first.outcome, SubmitSubscriptionRequestOutcome.created);
      expect(second.outcome, SubmitSubscriptionRequestOutcome.alreadyPending);
      expect(second.request?.id, first.request?.id);

      await repository.close();
    });

    test('cancels active subscription by request id', () async {
      final now = DateTime(2030, 7, 1, 12);
      final repository = SqliteSubscriptionRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final submit = await repository.submitPaymentRequest(
        userId: 303,
        plan: BoxingCardPlan.udar,
        paymentProofChatId: 303,
        paymentProofMessageId: 7,
        requestedAt: now,
      );
      await repository.reviewPendingRequest(
        requestId: submit.request!.id,
        approve: true,
        reviewedAt: now.add(const Duration(minutes: 5)),
      );

      final cancel = await repository.cancelActiveSubscription(
        requestId: submit.request!.id,
        cancelledAt: now.add(const Duration(days: 1)),
      );
      expect(cancel.outcome, CancelSubscriptionOutcome.success);
      expect(cancel.request?.status, SubscriptionRequestStatus.cancelled);

      final membership = await repository.getMembership(303, now: now.add(const Duration(days: 2)));
      expect(membership.level, MembershipLevel.normal);

      await repository.close();
    });

    test('activates boxing card for 30 days from approve, not calendar month', () async {
      final now = DateTime.utc(2030, 7, 20, 18, 30);
      final repository = SqliteSubscriptionRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final submit = await repository.submitPaymentRequest(
        userId: 404,
        plan: BoxingCardPlan.baza,
        paymentProofChatId: 404,
        paymentProofMessageId: 3,
        requestedAt: now,
      );
      final reviewedAt = now.add(const Duration(minutes: 10));
      await repository.reviewPendingRequest(
        requestId: submit.request!.id,
        approve: true,
        reviewedAt: reviewedAt,
      );

      final membership = await repository.getMembership(404, now: reviewedAt);
      expect(membership.level, MembershipLevel.boxingCard);
      expect(membership.activeFrom!.toUtc().isAtSameMomentAs(reviewedAt), isTrue);
      expect(
        membership.activeUntil!.toUtc().isAtSameMomentAs(reviewedAt.add(const Duration(days: 30))),
        isTrue,
      );

      await repository.close();
    });

    test('renewal while active starts the next period from current activeUntil', () async {
      final firstApprove = DateTime.utc(2030, 7, 1, 12);
      final repository = SqliteSubscriptionRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();

      final first = await repository.submitPaymentRequest(
        userId: 505,
        plan: BoxingCardPlan.baza,
        paymentProofChatId: 505,
        paymentProofMessageId: 1,
        requestedAt: firstApprove,
      );
      await repository.reviewPendingRequest(
        requestId: first.request!.id,
        approve: true,
        reviewedAt: firstApprove,
      );
      final firstMembership = await repository.getMembership(505, now: firstApprove);
      final firstUntil = firstMembership.activeUntil!.toUtc();

      final renewAt = firstApprove.add(const Duration(days: 10));
      final second = await repository.submitPaymentRequest(
        userId: 505,
        plan: BoxingCardPlan.udar,
        paymentProofChatId: 505,
        paymentProofMessageId: 2,
        requestedAt: renewAt,
      );
      await repository.reviewPendingRequest(
        requestId: second.request!.id,
        approve: true,
        reviewedAt: renewAt,
      );

      final stillCurrent = await repository.getMembership(505, now: renewAt);
      expect(stillCurrent.plan, BoxingCardPlan.baza);
      expect(stillCurrent.activeUntil!.toUtc().isAtSameMomentAs(firstUntil), isTrue);

      final nextPeriod = await repository.getMembership(505, now: firstUntil);
      expect(nextPeriod.plan, BoxingCardPlan.udar);
      expect(nextPeriod.activeFrom!.toUtc().isAtSameMomentAs(firstUntil), isTrue);
      expect(
        nextPeriod.activeUntil!.toUtc().isAtSameMomentAs(firstUntil.add(const Duration(days: 30))),
        isTrue,
      );

      await repository.close();
    });
  });
}
