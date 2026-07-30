enum ConversationDirection {
  inbound,
  outbound,
}

enum ConversationContentType {
  text,
  photo,
  document,
  other,
  copy,
}

final class ConversationLogEntry {
  const ConversationLogEntry({
    required this.id,
    required this.occurredAt,
    required this.direction,
    required this.peerUserId,
    required this.chatId,
    required this.contentType,
    this.peerUsername,
    this.telegramMessageId,
    this.textPreview,
  });

  final int id;
  final DateTime occurredAt;
  final ConversationDirection direction;
  final int peerUserId;
  final String? peerUsername;
  final int chatId;
  final int? telegramMessageId;
  final ConversationContentType contentType;
  final String? textPreview;

  bool get canForward => telegramMessageId != null && chatId > 0;
}
