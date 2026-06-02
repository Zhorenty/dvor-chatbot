abstract interface class MessageSender {
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  });

  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  });

  Future<void> deleteMessage(
    int chatId, {
    required int messageId,
  });
}
