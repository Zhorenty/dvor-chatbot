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
      expect(membership.level, MembershipLevel.pro);
      expect(membership.activeUntil, isNotNull);

      await repository.close();
    });
  });
}
