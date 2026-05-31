abstract interface class MessageSender {
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
  });
}
