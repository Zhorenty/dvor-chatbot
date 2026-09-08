import 'package:dvor_chatbot/src/telegram/rich_message.dart';

abstract interface class MessageSender {
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = true,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  });

  /// Structured screen via Bot API `sendRichMessage`. Implementations must fall back
  /// to [sendMessage] with [InputRichMessage.fallbackHtml] when rich is unavailable.
  Future<int> sendRichMessage(
    int chatId,
    InputRichMessage richMessage, {
    bool disableNotification = true,
    bool disableWebPagePreview = true,
    Map<String, Object?>? replyMarkup,
  });

  /// Edit a previously sent rich message (`editMessageText` + `rich_message`).
  Future<void> editRichMessage(
    int chatId, {
    required int messageId,
    required InputRichMessage richMessage,
    Map<String, Object?>? replyMarkup,
  });

  Future<int> sendVideo(
    int chatId, {
    required String video,
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  });

  Future<int> sendVideoNote(
    int chatId, {
    required String videoNote,
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

  Future<void> editMessageReplyMarkup(
    int chatId, {
    required int messageId,
    Map<String, Object?>? replyMarkup,
  });
}

/// Sends a structured screen via [MessageSender.sendRichMessage], or classic HTML when [transactional].
Future<int> sendBotScreen(
  MessageSender sender,
  int chatId,
  InputRichMessage message, {
  bool transactional = false,
  bool disableNotification = true,
  bool disableWebPagePreview = true,
  Map<String, Object?>? replyMarkup,
}) {
  if (transactional) {
    return sender.sendMessage(
      chatId,
      message.fallbackHtml,
      disableNotification: disableNotification,
      disableWebPagePreview: disableWebPagePreview,
      replyMarkup: replyMarkup ?? message.fallbackInlineKeyboard(),
      parseMode: 'HTML',
    );
  }
  return sender.sendRichMessage(
    chatId,
    message,
    disableNotification: disableNotification,
    disableWebPagePreview: disableWebPagePreview,
    replyMarkup: replyMarkup,
  );
}

/// Convenience wrapper: send [html] as a rich screen with classic HTML fallback.
Future<int> sendBotHtml(
  MessageSender sender,
  int chatId,
  String html, {
  bool transactional = false,
  bool disableNotification = true,
  bool disableWebPagePreview = true,
  Map<String, Object?>? replyMarkup,
}) {
  return sendBotScreen(
    sender,
    chatId,
    InputRichMessage(html: html),
    transactional: transactional,
    disableNotification: disableNotification,
    disableWebPagePreview: disableWebPagePreview,
    replyMarkup: replyMarkup,
  );
}
