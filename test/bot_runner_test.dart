import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/bot/bot_runner.dart';
import 'package:dvor_chatbot/src/bot/handlers/group_handlers.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/telegram_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('start processes private updates and exits on stop', () async {
    var updatesCalls = 0;
    Set<String> requestedAllowedUpdates = const <String>{};
    late BotRunner runner;
    final httpClient = MockClient((request) async {
      final method = request.url.pathSegments.last;
      if (method == 'getMe') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'result': <String, Object?>{'username': 'dvor_test_bot'},
          }),
          200,
        );
      }
      if (method == 'getUpdates') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final rawAllowedUpdates = body['allowed_updates'];
        if (rawAllowedUpdates is List) {
          requestedAllowedUpdates = rawAllowedUpdates.map((item) => item.toString()).toSet();
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        updatesCalls += 1;
        if (updatesCalls == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'ok': true,
              'result': <Map<String, Object?>>[
                <String, Object?>{
                  'update_id': 1,
                  'message': <String, Object?>{
                    'chat': <String, Object?>{'id': 42, 'type': 'private'},
                    'from': <String, Object?>{'id': 42},
                    'text': '/start',
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{'ok': true, 'result': const <Object?>[]}),
          200,
        );
      }
      if (method == 'deleteWebhook') {
        return http.Response(
          jsonEncode(<String, Object?>{'ok': true, 'result': true}),
          200,
        );
      }
      throw StateError('Unexpected method: $method');
    });

    final sender = FakeSender();
    final scheduleRepository = FakeScheduleRepository(const []);
    final bookingRepository = FakeBookingRepository();
    final onboardingRepository = FakeOnboardingRepository();
    final subscriptionRepository = FakeSubscriptionRepository();
    final templates = const MessageTemplates();
    runner = BotRunner(
      config: const AppConfig(
        botToken: 'token',
        targetChatId: null,
        sendGroupFallback: true,
        pollTimeoutSeconds: 1,
        scheduleSource: ScheduleSource.staticData,
        googleSheetsCsvUrl: null,
        scheduleSyncIntervalSeconds: 30,
        bookingsDbPath: 'data/bookings.sqlite',
        pendingPaymentTtlMinutes: 120,
        adminUserIds: <int>{},
        adminChatId: null,
        logLevel: 'info',
      ),
      client: TelegramClient(
        token: 'token',
        httpClient: httpClient,
      ),
      scheduleRepository: scheduleRepository,
      bookingRepository: bookingRepository,
      onboardingRepository: onboardingRepository,
      subscriptionRepository: subscriptionRepository,
      sender: sender,
      templates: templates,
      privateHandlers: PrivateHandlers(
        sender: sender,
        scheduleRepository: scheduleRepository,
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        templates: templates,
        adminUserIds: const <int>{},
      ),
      groupHandlers: GroupHandlers(
        sender: sender,
        onboardingRepository: onboardingRepository,
        templates: templates,
        targetChatId: null,
      ),
    );

    final startFuture = runner.start();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 120), () => runner.stop()));
    await _waitFor(() => sender.messages.isNotEmpty, timeout: const Duration(seconds: 1));
    await runner.stop();
    await startFuture.timeout(const Duration(seconds: 2));

    expect(scheduleRepository.refreshCalls, greaterThanOrEqualTo(1));
    expect(sender.messages.single.chatId, 42);
    expect(sender.messages.single.text, contains('Добро пожаловать в DVOR'));
    expect(updatesCalls, greaterThanOrEqualTo(1));
    expect(requestedAllowedUpdates, contains('chat_member'));
  });
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timeout while waiting for expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
