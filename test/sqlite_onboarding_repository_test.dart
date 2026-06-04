import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteOnboardingRepository', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dvor-onboarding-test-');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('grants starter bonus only after timely start and consumes once', () async {
      final repository = SqliteOnboardingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();
      final joinedAt = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await repository.registerGroupWelcome(
        userId: 3001,
        groupChatId: -1001,
        welcomeMessageId: 15,
        joinedAt: joinedAt,
      );
      await repository.markStartedAndGetPendingWelcome(
        3001,
        startedAt: joinedAt.add(const Duration(hours: 2)),
      );

      expect(await repository.hasStarterBonusAvailable(3001), isTrue);
      expect(
        await repository.consumeStarterBonus(
          3001,
          consumedAt: joinedAt.add(const Duration(hours: 2, minutes: 1)),
        ),
        isTrue,
      );
      expect(await repository.hasStarterBonusAvailable(3001), isFalse);
      expect(
        await repository.consumeStarterBonus(
          3001,
          consumedAt: joinedAt.add(const Duration(hours: 2, minutes: 2)),
        ),
        isFalse,
      );

      await repository.close();
    });

    test('does not grant starter bonus when start is later than 24 hours', () async {
      final repository = SqliteOnboardingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();
      final joinedAt = DateTime.now().toUtc().subtract(const Duration(hours: 26));
      await repository.registerGroupWelcome(
        userId: 4001,
        groupChatId: -1001,
        welcomeMessageId: 16,
        joinedAt: joinedAt,
      );
      await repository.markStartedAndGetPendingWelcome(
        4001,
        startedAt: joinedAt.add(const Duration(hours: 25)),
      );

      expect(await repository.hasStarterBonusAvailable(4001), isFalse);
      expect(
        await repository.consumeStarterBonus(
          4001,
          consumedAt: joinedAt.add(const Duration(hours: 25, minutes: 5)),
        ),
        isFalse,
      );

      await repository.close();
    });

    test('expires starter bonus after 7 days from start', () async {
      final repository = SqliteOnboardingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();
      final now = DateTime.now().toUtc();
      final joinedAt = now.subtract(const Duration(days: 8, hours: 2));
      await repository.registerGroupWelcome(
        userId: 4501,
        groupChatId: -1001,
        welcomeMessageId: 116,
        joinedAt: joinedAt,
      );
      await repository.markStartedAndGetPendingWelcome(
        4501,
        startedAt: joinedAt.add(const Duration(hours: 2)),
      );

      expect(await repository.hasStarterBonusAvailable(4501), isFalse);
      expect(
        await repository.consumeStarterBonus(
          4501,
          consumedAt: now,
        ),
        isFalse,
      );

      await repository.close();
    });

    test('finds expiring starter bonuses and marks reminder sent once', () async {
      final repository = SqliteOnboardingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();
      final now = DateTime.now().toUtc();
      final joinedAt = now.subtract(const Duration(days: 6, hours: 2));
      final startedAt = joinedAt.add(const Duration(hours: 2));
      await repository.registerGroupWelcome(
        userId: 4601,
        groupChatId: -1001,
        welcomeMessageId: 117,
        joinedAt: joinedAt,
      );
      await repository.markStartedAndGetPendingWelcome(
        4601,
        startedAt: startedAt,
      );

      final firstBatch = await repository.listStarterBonusExpiringSoon(
        now: now,
        leadTime: const Duration(days: 1),
      );
      expect(firstBatch.map((item) => item.userId), contains(4601));

      await repository.markStarterBonusReminderSent(
        4601,
        sentAt: now,
      );
      final secondBatch = await repository.listStarterBonusExpiringSoon(
        now: now,
        leadTime: const Duration(days: 1),
      );
      expect(secondBatch.map((item) => item.userId), isNot(contains(4601)));

      await repository.close();
    });

    test('returns pending welcome for start and for ttl cleanup', () async {
      final repository = SqliteOnboardingRepository(
        dbPath: '${tmpDir.path}/bookings.sqlite',
      );
      await repository.init();
      final joinedAt = DateTime(2030, 6, 1, 10, 0);
      await repository.registerGroupWelcome(
        userId: 5001,
        groupChatId: -1002,
        welcomeMessageId: 77,
        joinedAt: joinedAt,
      );

      final pending = await repository.markStartedAndGetPendingWelcome(
        5001,
        startedAt: joinedAt.add(const Duration(minutes: 1)),
      );
      expect(pending, isNotNull);
      expect(pending!.groupChatId, -1002);
      expect(pending.welcomeMessageId, 77);

      var ready = await repository.listWelcomeMessagesReadyForDelete(
        now: joinedAt.add(const Duration(minutes: 1)),
      );
      expect(ready, hasLength(1));

      await repository.markWelcomeDeleted(
        userId: 5001,
        deletedAt: joinedAt.add(const Duration(minutes: 1)),
      );
      ready = await repository.listWelcomeMessagesReadyForDelete(
        now: joinedAt.add(const Duration(minutes: 2)),
      );
      expect(ready, isEmpty);

      await repository.registerGroupWelcome(
        userId: 5002,
        groupChatId: -1002,
        welcomeMessageId: 88,
        joinedAt: joinedAt,
      );
      ready = await repository.listWelcomeMessagesReadyForDelete(
        now: joinedAt.add(const Duration(minutes: 4)),
      );
      expect(ready.map((item) => item.userId), contains(5002));

      await repository.close();
    });
  });
}
