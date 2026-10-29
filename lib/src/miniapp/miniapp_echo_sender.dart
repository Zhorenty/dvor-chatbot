import 'dart:async';

import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/rich_message.dart';

/// Texts the bot sent to one chat while a Mini App action ran.
final class MiniAppCapture {
  MiniAppCapture(this.chatId);

  final int chatId;
  final List<String> texts = <String>[];

  static final Object _zoneKey = Object();

  static MiniAppCapture? get current => Zone.current[_zoneKey] as MiniAppCapture?;

  /// Runs [action] and records every text the bot sends to [chatId] meanwhile,
  /// so the app can show the same answer the chat gets.
  static Future<(T, List<String>)> run<T>(int chatId, Future<T> Function() action) async {
    final capture = MiniAppCapture(chatId);
    final result = await runZoned(action, zoneValues: {_zoneKey: capture});
    return (result, List<String>.unmodifiable(capture.texts));
  }
}

/// Decorator that copies outbound texts into the active [MiniAppCapture].
/// Outside a capture zone it only forwards.
final class MiniAppEchoSender implements MessageSender {
  MiniAppEchoSender(this._inner);

  final MessageSender _inner;

  void _record(int chatId, String text) {
    final capture = MiniAppCapture.current;
    if (capture != null && capture.chatId == chatId) {
      capture.texts.add(text);
    }
  }

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = true,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  }) {
    _record(chatId, text);
    return _inner.sendMessage(
      chatId,
      text,
      disableNotification: disableNotification,
      disableWebPagePreview: disableWebPagePreview,
      replyMarkup: replyMarkup,
      parseMode: parseMode,
    );
  }

  @override
  Future<int> sendRichMessage(
    int chatId,
    InputRichMessage richMessage, {
    bool disableNotification = true,
    bool disableWebPagePreview = true,
    Map<String, Object?>? replyMarkup,
  }) {
    _record(chatId, richMessage.html);
    return _inner.sendRichMessage(
      chatId,
      richMessage,
      disableNotification: disableNotification,
      disableWebPagePreview: disableWebPagePreview,
      replyMarkup: replyMarkup,
    );
  }

  @override
  Future<void> editRichMessage(
    int chatId, {
    required int messageId,
    required InputRichMessage richMessage,
    Map<String, Object?>? replyMarkup,
  }) {
    _record(chatId, richMessage.html);
    return _inner.editRichMessage(
      chatId,
      messageId: messageId,
      richMessage: richMessage,
      replyMarkup: replyMarkup,
    );
  }

  @override
  Future<int> sendVideo(
    int chatId, {
    required String video,
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  }) {
    return _inner.sendVideo(
      chatId,
      video: video,
      disableNotification: disableNotification,
      replyMarkup: replyMarkup,
    );
  }

  @override
  Future<int> sendVideoNote(
    int chatId, {
    required String videoNote,
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  }) {
    return _inner.sendVideoNote(
      chatId,
      videoNote: videoNote,
      disableNotification: disableNotification,
      replyMarkup: replyMarkup,
    );
  }

  @override
  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  }) {
    return _inner.copyMessage(
      chatId,
      fromChatId: fromChatId,
      messageId: messageId,
      disableNotification: disableNotification,
    );
  }

  @override
  Future<void> deleteMessage(int chatId, {required int messageId}) {
    return _inner.deleteMessage(chatId, messageId: messageId);
  }

  @override
  Future<void> banChatMember(int chatId, {required int userId, bool revokeMessages = true}) {
    return _inner.banChatMember(chatId, userId: userId, revokeMessages: revokeMessages);
  }

  @override
  Future<void> pinMessage(int chatId, {required int messageId, bool disableNotification = true}) {
    return _inner.pinMessage(
      chatId,
      messageId: messageId,
      disableNotification: disableNotification,
    );
  }

  @override
  Future<void> answerCallbackQuery(String callbackQueryId, {String? text, bool showAlert = false}) {
    return _inner.answerCallbackQuery(callbackQueryId, text: text, showAlert: showAlert);
  }

  @override
  Future<void> editMessageReplyMarkup(
    int chatId, {
    required int messageId,
    Map<String, Object?>? replyMarkup,
  }) {
    return _inner.editMessageReplyMarkup(
      chatId,
      messageId: messageId,
      replyMarkup: replyMarkup,
    );
  }
}
