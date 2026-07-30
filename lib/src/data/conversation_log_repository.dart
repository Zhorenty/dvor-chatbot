import 'package:dvor_chatbot/src/domain/conversation_log.dart';

abstract interface class ConversationLogRepository {
  Future<void> init();

  Future<void> close();

  Future<void> upsertTelegramUser({
    required int userId,
    String? username,
  });

  Future<void> append({
    required ConversationDirection direction,
    required int peerUserId,
    String? peerUsername,
    required int chatId,
    int? telegramMessageId,
    required ConversationContentType contentType,
    String? textPreview,
  });

  Future<List<ConversationLogEntry>> recentActions({
    int limit = 40,
    Set<int> excludePeerIds = const <int>{},
  });

  Future<List<ConversationLogEntry>> dialogForUserId(
    int userId, {
    int limit = 50,
  });

  Future<int?> resolveUserIdByUsername(String username);
}

final class NoopConversationLogRepository implements ConversationLogRepository {
  const NoopConversationLogRepository();

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> upsertTelegramUser({
    required int userId,
    String? username,
  }) async {}

  @override
  Future<void> append({
    required ConversationDirection direction,
    required int peerUserId,
    String? peerUsername,
    required int chatId,
    int? telegramMessageId,
    required ConversationContentType contentType,
    String? textPreview,
  }) async {}

  @override
  Future<List<ConversationLogEntry>> recentActions({
    int limit = 40,
    Set<int> excludePeerIds = const <int>{},
  }) async {
    return const <ConversationLogEntry>[];
  }

  @override
  Future<List<ConversationLogEntry>> dialogForUserId(
    int userId, {
    int limit = 50,
  }) async {
    return const <ConversationLogEntry>[];
  }

  @override
  Future<int?> resolveUserIdByUsername(String username) async => null;
}
