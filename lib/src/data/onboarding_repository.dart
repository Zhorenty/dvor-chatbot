final class PendingWelcomeMessage {
  const PendingWelcomeMessage({
    required this.userId,
    required this.groupChatId,
    required this.welcomeMessageId,
  });

  final int userId;
  final int groupChatId;
  final int welcomeMessageId;
}

final class StarterBonusReminderTarget {
  const StarterBonusReminderTarget({
    required this.userId,
    required this.expiresAt,
  });

  final int userId;
  final DateTime expiresAt;
}

abstract interface class OnboardingRepository {
  Future<void> init();

  Future<void> close();

  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  });

  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  });

  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  });

  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  });

  Future<bool> hasStarterBonusAvailable(int userId);

  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  });

  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  });

  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  });

  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  });

  Future<int> getEveryFifthLastNotifiedRewards(int userId);

  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  });

  Future<void> registerReferralAttribution({
    required int inviteeUserId,
    required int inviterUserId,
    required DateTime attributedAt,
  });

  /// Returns IDs of all users who have started the bot (sent /start).
  /// Only these users can receive proactive DMs.
  Future<List<int>> getAllStartedUserIds();
}

final class NoopOnboardingRepository implements OnboardingRepository {
  const NoopOnboardingRepository();

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  }) async {}

  @override
  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  }) async {
    return null;
  }

  @override
  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  }) async {
    return const <PendingWelcomeMessage>[];
  }

  @override
  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<bool> hasStarterBonusAvailable(int userId) async {
    return false;
  }

  @override
  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  }) async {
    return false;
  }

  @override
  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  }) async {}

  @override
  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  }) async {
    return const <StarterBonusReminderTarget>[];
  }

  @override
  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  }) async {}

  @override
  Future<int> getEveryFifthLastNotifiedRewards(int userId) async {
    return 0;
  }

  @override
  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<void> registerReferralAttribution({
    required int inviteeUserId,
    required int inviterUserId,
    required DateTime attributedAt,
  }) async {}

  @override
  Future<List<int>> getAllStartedUserIds() async => const <int>[];
}
