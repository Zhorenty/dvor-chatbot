import 'dart:convert';

import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/retry.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:http/http.dart' as http;

final class TelegramClient implements MessageSender {
  static const int _maxTelegramMessageLength = 4096;

  TelegramClient({
    required String token,
    http.Client? httpClient,
  })  : _baseUri = Uri.parse('https://api.telegram.org/bot$token'),
        _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Uri _methodUri(String method) => _baseUri.replace(path: '${_baseUri.path}/$method');

  Future<Map<String, dynamic>> _post(
    String method, {
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await retry(
      () => _httpClient
          .post(
            _methodUri(method),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout),
      shouldRetry: (error) => error is! TelegramApiException,
    );

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw TelegramApiException(
        'Telegram API returned non-JSON response',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      final description = payload['description']?.toString() ?? 'HTTP error';
      throw TelegramApiException(description, statusCode: response.statusCode);
    }

    if (payload['ok'] != true) {
      final description = payload['description']?.toString() ?? 'Telegram response is not ok';
      throw TelegramApiException(description, statusCode: response.statusCode);
    }

    return payload;
  }

  Future<List<Map<String, dynamic>>> getUpdates({
    required int offset,
    required int timeoutSeconds,
    Set<String> allowedUpdates = const {'message'},
  }) async {
    final requestTimeout = Duration(seconds: timeoutSeconds + 10);
    final payload = await _post(
      'getUpdates',
      body: <String, Object?>{
        'offset': offset,
        'limit': 100,
        'timeout': timeoutSeconds,
        'allowed_updates': allowedUpdates.toList(growable: false),
      },
      timeout: requestTimeout,
    );

    final rawResult = payload['result'];
    if (rawResult is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawResult
        .whereType<Map<Object?, Object?>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<String?> getBotUsername() async {
    final payload = await _post('getMe', body: const <String, Object?>{});
    final result = payload['result'];
    if (result is! Map) {
      return null;
    }
    return result['username']?.toString();
  }

  Future<void> deleteWebhook({bool dropPendingUpdates = false}) async {
    final payload = await _post(
      'deleteWebhook',
      body: <String, Object?>{
        'drop_pending_updates': dropPendingUpdates,
      },
    );
    final result = payload['result'];
    if (result != true) {
      throw const TelegramApiException('Telegram did not confirm webhook deletion');
    }
  }

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  }) async {
    final chunks = _splitMessageText(text);
    var lastMessageId = 0;
    for (var index = 0; index < chunks.length; index++) {
      final isLastChunk = index == chunks.length - 1;
      lastMessageId = await _sendMessageChunk(
        chatId,
        chunks[index],
        disableNotification: disableNotification,
        disableWebPagePreview: disableWebPagePreview,
        replyMarkup: isLastChunk ? replyMarkup : null,
        parseMode: parseMode,
      );
    }
    return lastMessageId;
  }

  Future<int> _sendMessageChunk(
    int chatId,
    String text, {
    required bool disableNotification,
    required bool disableWebPagePreview,
    required Map<String, Object?>? replyMarkup,
    required String? parseMode,
  }) async {
    final body = <String, Object?>{
      'chat_id': chatId,
      'text': text,
      'disable_notification': disableNotification,
      'disable_web_page_preview': disableWebPagePreview,
    };
    if (replyMarkup != null) {
      body['reply_markup'] = replyMarkup;
    }
    if (parseMode != null) {
      body['parse_mode'] = parseMode;
    }

    final payload = await _post(
      'sendMessage',
      body: body,
    );

    final result = payload['result'];
    if (result is! Map || result['message_id'] is! int) {
      throw const TelegramApiException('Telegram did not return message_id');
    }

    return result['message_id'] as int;
  }

  List<String> _splitMessageText(String text) {
    return _splitBySeparators(
      text,
      separators: const <String>['\n\n', '\n'],
      maxLength: _maxTelegramMessageLength,
    );
  }

  List<String> _splitBySeparators(
    String text, {
    required List<String> separators,
    required int maxLength,
  }) {
    if (_textLength(text) <= maxLength) {
      return <String>[text];
    }
    if (separators.isEmpty) {
      return _hardSplit(text, maxLength);
    }

    final separator = separators.first;
    final nextSeparators = separators.sublist(1);
    final segments = text.split(separator);
    if (segments.length == 1) {
      return _splitBySeparators(
        text,
        separators: nextSeparators,
        maxLength: maxLength,
      );
    }

    final chunks = <String>[];
    var current = '';
    for (final segment in segments) {
      final candidate = current.isEmpty ? segment : '$current$separator$segment';
      if (_textLength(candidate) <= maxLength) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) {
        chunks.add(current);
      }
      if (_textLength(segment) <= maxLength) {
        current = segment;
        continue;
      }
      chunks.addAll(
        _splitBySeparators(
          segment,
          separators: nextSeparators,
          maxLength: maxLength,
        ),
      );
      current = '';
    }
    if (current.isNotEmpty) {
      chunks.add(current);
    }

    return chunks.isEmpty ? _hardSplit(text, maxLength) : chunks;
  }

  List<String> _hardSplit(String text, int maxLength) {
    final codePoints = text.runes.toList(growable: false);
    final chunks = <String>[];
    for (var index = 0; index < codePoints.length; index += maxLength) {
      final end = (index + maxLength < codePoints.length) ? index + maxLength : codePoints.length;
      chunks.add(String.fromCharCodes(codePoints.sublist(index, end)));
    }
    return chunks.isEmpty ? <String>[text] : chunks;
  }

  int _textLength(String text) => text.runes.length;

  @override
  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  }) async {
    final payload = await _post(
      'copyMessage',
      body: <String, Object?>{
        'chat_id': chatId,
        'from_chat_id': fromChatId,
        'message_id': messageId,
        'disable_notification': disableNotification,
      },
    );

    final result = payload['result'];
    if (result is! Map || result['message_id'] is! int) {
      throw const TelegramApiException('Telegram did not return message_id');
    }

    return result['message_id'] as int;
  }

  @override
  Future<void> deleteMessage(
    int chatId, {
    required int messageId,
  }) async {
    final payload = await _post(
      'deleteMessage',
      body: <String, Object?>{
        'chat_id': chatId,
        'message_id': messageId,
      },
    );
    final result = payload['result'];
    if (result != true) {
      throw const TelegramApiException('Telegram did not confirm message deletion');
    }
  }

  @override
  Future<void> banChatMember(
    int chatId, {
    required int userId,
    bool revokeMessages = true,
  }) async {
    final payload = await _post(
      'banChatMember',
      body: <String, Object?>{
        'chat_id': chatId,
        'user_id': userId,
        'revoke_messages': revokeMessages,
      },
    );
    final result = payload['result'];
    if (result != true) {
      throw const TelegramApiException('Telegram did not confirm chat member ban');
    }
  }

  @override
  Future<void> pinMessage(
    int chatId, {
    required int messageId,
    bool disableNotification = true,
  }) async {
    final payload = await _post(
      'pinChatMessage',
      body: <String, Object?>{
        'chat_id': chatId,
        'message_id': messageId,
        'disable_notification': disableNotification,
      },
    );
    final result = payload['result'];
    if (result != true) {
      throw const TelegramApiException('Telegram did not confirm message pin');
    }
  }

  @override
  Future<void> answerCallbackQuery(
    String callbackQueryId, {
    String? text,
    bool showAlert = false,
  }) async {
    final payload = await _post(
      'answerCallbackQuery',
      body: <String, Object?>{
        'callback_query_id': callbackQueryId,
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        'show_alert': showAlert,
      },
    );
    final result = payload['result'];
    if (result != true) {
      throw const TelegramApiException('Telegram did not confirm callback answer');
    }
  }

  void close() {
    _httpClient.close();
  }
}
