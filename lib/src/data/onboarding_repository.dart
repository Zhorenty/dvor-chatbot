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
}
