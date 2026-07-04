import 'dart:convert';

import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('sendMessage splits oversized schedule text by full blocks', () async {
    final sendMessageBodies = <Map<String, Object?>>[];
    final client = TelegramClient(
      token: 'token',
      httpClient: MockClient((request) async {
        final method = request.url.pathSegments.last;
        if (method != 'sendMessage') {
          throw StateError('Unexpected method: $method');
        }
        final body = Map<String, Object?>.from(jsonDecode(request.body) as Map<String, dynamic>);
        sendMessageBodies.add(body);
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'result': <String, Object?>{
              'message_id': sendMessageBodies.length,
            },
          }),
          200,
        );
      }),
    );

    final header = 'Выбери мероприятие для записи 👇';
    final entry1 = _trainingEntry(1, 'A');
    final entry2 = _trainingEntry(2, 'B');
    final entry3 = _trainingEntry(3, 'C');
    final text = <String>[header, entry1, entry2, entry3].join('\n\n');

    final messageId = await client.sendMessage(
      42,
      text,
      parseMode: 'HTML',
      replyMarkup: const <String, Object?>{
        'keyboard': <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': 'Кнопка'},
          ],
        ],
      },
    );

    expect(sendMessageBodies, hasLength(2));
    expect(sendMessageBodies[0]['text'], allOf(contains(entry1), contains(entry2)));
    expect(sendMessageBodies[0]['text'], isNot(contains(entry3)));
    expect(sendMessageBodies[1]['text'], contains(entry3));
    expect(sendMessageBodies[0]['reply_markup'], isNull);
    expect(sendMessageBodies[1]['reply_markup'], isNotNull);
    expect(sendMessageBodies[0]['parse_mode'], equals('HTML'));
    expect(sendMessageBodies[1]['parse_mode'], equals('HTML'));
    expect(messageId, equals(2));

    client.close();
  });

  test('sendMessage hard-splits text without separators', () async {
    final sendMessageBodies = <Map<String, Object?>>[];
    final client = TelegramClient(
      token: 'token',
      httpClient: MockClient((request) async {
        final method = request.url.pathSegments.last;
        if (method != 'sendMessage') {
          throw StateError('Unexpected method: $method');
        }
        final body = Map<String, Object?>.from(jsonDecode(request.body) as Map<String, dynamic>);
        sendMessageBodies.add(body);
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'result': <String, Object?>{
              'message_id': sendMessageBodies.length,
            },
          }),
          200,
        );
      }),
    );

    final messageId = await client.sendMessage(
      42,
      'x' * 9000,
    );

    expect(sendMessageBodies, hasLength(3));
    for (final body in sendMessageBodies) {
      expect((body['text'] as String).runes.length, lessThanOrEqualTo(4096));
    }
    expect(messageId, equals(3));

    client.close();
  });
}

String _trainingEntry(int index, String marker) {
  return '$index. Тренировка $index\n'
      '🕒 01.07.2026 19:00\n'
      '📍 Локация $index\n'
      '👥 до 24\n'
      '${marker * 1500}';
}
