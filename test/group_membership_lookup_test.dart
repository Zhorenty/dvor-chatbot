import 'dart:convert';

import 'package:dvor_chatbot/src/application/group_membership_lookup.dart';
import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/telegram/telegram_api_exception.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('isEffectiveGroupMember treats restricted by is_member flag', () {
    expect(isEffectiveGroupMember(status: 'member'), isTrue);
    expect(isEffectiveGroupMember(status: 'restricted', isMemberFlag: true), isTrue);
    expect(isEffectiveGroupMember(status: 'restricted'), isFalse);
    expect(isEffectiveGroupMember(status: 'left'), isFalse);
    expect(isEffectiveGroupMember(status: 'kicked'), isFalse);
  });

  test('lookup treats left status and user-not-found as outside the group', () async {
    final leftClient = TelegramClient(
      token: 'token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'result': <String, Object?>{
              'status': 'left',
              'user': <String, Object?>{'id': 7, 'is_bot': false},
            },
          }),
          200,
        );
      }),
    );
    expect(
      await TelegramGroupMembershipLookup(leftClient).isChatMember(chatId: -1, userId: 7),
      isFalse,
    );
    leftClient.close();

    final missingClient = TelegramClient(
      token: 'token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': false,
            'description': 'Bad Request: user not found',
          }),
          400,
        );
      }),
    );
    expect(
      await TelegramGroupMembershipLookup(missingClient).isChatMember(chatId: -1, userId: 8),
      isFalse,
    );
    missingClient.close();
  });

  test('lookup rethrows unrelated Telegram errors', () async {
    final client = TelegramClient(
      token: 'token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': false,
            'description': 'Forbidden: bot is not a member of the chat',
          }),
          403,
        );
      }),
    );
    expect(
      () => TelegramGroupMembershipLookup(client).isChatMember(chatId: -1, userId: 9),
      throwsA(isA<TelegramApiException>()),
    );
    client.close();
  });
}
