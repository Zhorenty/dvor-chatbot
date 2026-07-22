abstract interface class MessageSender {
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
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

  Future<void> banChatMember(
    int chatId, {
    required int userId,
    bool revokeMessages = true,
  });

  Future<void> pinMessage(
    int chatId, {
    required int messageId,
    bool disableNotification = true,
  });

  Future<void> answerCallbackQuery(
    String callbackQueryId, {
    String? text,
    bool showAlert = false,
  });
}
