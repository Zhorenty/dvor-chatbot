import 'dart:convert';
import 'dart:io';

import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/miniapp/miniapp_bridge_server.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/private_handlers_harness.dart';

const String _token = 'test-bridge-token-0123456789';

final class _RecordingBackend implements MiniAppBridgeBackend {
  final List<String> calls = <String>[];

  @override
  Future<Map<String, Object?>> schedule() async {
    calls.add('schedule');
    return const <String, Object?>{'events': <Object?>[]};
  }

  @override
  Future<Map<String, Object?>> bookings(int userId) async {
    calls.add('bookings:$userId');
    return const <String, Object?>{'bookings': <Object?>[]};
  }

  @override
  Future<Map<String, Object?>> book({
    required int userId,
    required String? username,
    required String sessionKey,
  }) async {
    calls.add('book:$userId:$username:$sessionKey');
    return const <String, Object?>{'outcome': 'created'};
  }

  @override
  Future<Map<String, Object?>> cancel({required int userId, required int bookingId}) async {
    calls.add('cancel:$userId:$bookingId');
    return const <String, Object?>{'outcome': 'cancelled'};
  }
}

void main() {
  group('MiniAppBridgeServer', () {
    late _RecordingBackend backend;
    late MiniAppBridgeServer server;
    late HttpClient client;

    setUp(() async {
      backend = _RecordingBackend();
      server = MiniAppBridgeServer(backend: backend, token: _token);
      await server.start(port: 0, address: InternetAddress.loopbackIPv4);
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    Future<(int, Map<String, Object?>)> call(
      String method,
      String path, {
      Object? body,
      String? token = _token,
    }) async {
      final request = await client.open(method, '127.0.0.1', server.port!, path);
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.write(body is String ? body : jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return (response.statusCode, jsonDecode(text) as Map<String, Object?>);
    }

    test('rejects requests without the shared token', () async {
      final (status, _) = await call('GET', '/internal/schedule', token: null);
      expect(status, HttpStatus.unauthorized);
      final (wrongStatus, _) = await call('GET', '/internal/schedule', token: 'nope');
      expect(wrongStatus, HttpStatus.unauthorized);
      expect(backend.calls, isEmpty);
    });

    test('routes schedule, bookings, book and cancel', () async {
      expect((await call('GET', '/internal/schedule')).$1, HttpStatus.ok);
      expect((await call('GET', '/internal/users/42/bookings')).$1, HttpStatus.ok);
      final (bookStatus, bookBody) = await call(
        'POST',
        '/internal/bookings',
        body: const {'userId': 42, 'username': 'runner', 'key': 'k1'},
      );
      expect(bookStatus, HttpStatus.ok);
      expect(bookBody['outcome'], 'created');
      expect(
        (await call('POST', '/internal/bookings/7/cancel', body: const {'userId': 42})).$1,
        HttpStatus.ok,
      );
      expect(backend.calls, ['schedule', 'bookings:42', 'book:42:runner:k1', 'cancel:42:7']);
    });

    test('returns 400 on malformed payload and 404 on unknown route', () async {
      expect((await call('POST', '/internal/bookings', body: '{"userId":"x"}')).$1,
          HttpStatus.badRequest);
      expect(
          (await call('POST', '/internal/bookings', body: 'not json')).$1, HttpStatus.badRequest);
      expect((await call('GET', '/internal/nope')).$1, HttpStatus.notFound);
    });
  });

  group('PrivateHandlers Mini App bridge', () {
    final now = DateTime.utc(2026, 10, 20, 9);
    final training = TrainingInfo(
      title: 'Бокс',
      startsAt: DateTime.utc(2026, 10, 21, 16),
      location: 'Площадка',
      price: 700,
      participantsLimit: 1,
      coach: 'Тренер',
    );
    final hike = OutdoorActivityInfo(
      type: OutdoorActivityType.hike,
      title: 'Поход',
      dateFrom: DateTime.utc(2026, 11, 1, 6),
      dateTo: DateTime.utc(2026, 11, 2, 18),
      description: '<b>Маршрут</b> &amp; виды',
      price: 5000,
    );

    test('schedule lists trainings and outdoor events with plain-text details', () async {
      final harness = PrivateHandlersHarness(
        trainings: [training],
        outdoorActivities: [hike],
        nowProvider: () => now,
      );
      final schedule = await harness.handlers.miniAppScheduleWithSeats();
      final events = schedule['events']! as List<Map<String, Object?>>;
      final box = events.firstWhere((event) => event['title'] == 'Бокс');
      expect(box['key'], training.sessionKey);
      // 16:00 club time (UTC+3) is 13:00 UTC.
      expect(box['startsAt'], '2026-10-21T13:00:00.000Z');
      expect(box['category'], 'trainings');
      expect(box['limit'], 1);
      expect(box['taken'], 0);
      final outdoor = events.firstWhere((event) => event['category'] == 'hikes');
      expect(outdoor['description'], 'Маршрут & виды');
      expect(outdoor['endsAt'], isNotNull);
    });

    test('book returns not_found for an unknown event', () async {
      final harness = PrivateHandlersHarness(trainings: [training], nowProvider: () => now);
      final result = await harness.handlers.miniAppBook(
        userId: 5,
        username: 'runner',
        sessionKey: 'missing',
      );
      expect(result['outcome'], 'not_found');
      expect(harness.booking.createCalls, 0);
    });

    test('book returns full without touching the chat when seats are taken', () async {
      final repository = FakeBookingRepository()
        ..userBookings = [
          fakeBooking(id: 1, userId: 5, trainingKey: 'other', status: BookingStatus.paid),
        ]
        ..bookingsByTrainingKey = [
          fakeBooking(id: 2, userId: 9, trainingKey: training.sessionKey),
        ];
      final harness = PrivateHandlersHarness(
        trainings: [training],
        bookingRepository: repository,
        nowProvider: () => now,
      );
      final result = await harness.handlers.miniAppBook(
        userId: 5,
        username: 'runner',
        sessionKey: training.sessionKey,
      );
      expect(result['outcome'], 'full');
      expect(repository.createCalls, 0);
      expect(harness.sender.messages, isEmpty);
    });

    test('book runs the chat booking flow and returns the booking', () async {
      final repository = FakeBookingRepository()
        ..userBookings = [
          fakeBooking(id: 1, userId: 5, trainingKey: 'other', status: BookingStatus.paid),
        ];
      final harness = PrivateHandlersHarness(
        trainings: [training],
        bookingRepository: repository,
        nowProvider: () => now,
      );
      final result = await harness.handlers.miniAppBook(
        userId: 5,
        username: 'runner',
        sessionKey: training.sessionKey,
      );
      expect(result['outcome'], 'created');
      expect(repository.createCalls, 1);
      final booking = result['booking']! as Map<String, Object?>;
      expect(booking['key'], training.sessionKey);
      expect(booking['status'], 'pending_payment');
      expect(harness.sender.messages.map((message) => message.chatId), contains(5));
    });
  });
}
