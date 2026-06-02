import 'dart:convert';

import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:dvor_chatbot/src/telegram/retry.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:http/http.dart' as http;

final class TelegramClient implements MessageSender {
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

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  }) async {
    final body = <String, Object?>{
      'chat_id': chatId,
      'text': text,
      'disable_notification': disableNotification,
    };
    if (replyMarkup != null) {
      body['reply_markup'] = replyMarkup;
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

  void close() {
    _httpClient.close();
  }
}
