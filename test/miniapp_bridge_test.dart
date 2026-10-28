import 'dart:convert';
import 'dart:io';

import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_attendance.dart';
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

  @override
  Future<Map<String, Object?>> adminPayments() async {
    calls.add('adminPayments');
    return const <String, Object?>{'payments': <Object?>[]};
  }

  @override
  Future<Map<String, Object?>> adminReviewPayment({
    required int adminUserId,
    required String? adminUsername,
    required int bookingId,
    required String decision,
  }) async {
    calls.add('review:$adminUserId:$adminUsername:$bookingId:$decision');
    return const <String, Object?>{'outcome': 'reviewed'};
  }

  @override
  Future<Map<String, Object?>> adminSendProof({
    required int adminUserId,
    required int bookingId,
  }) async {
    calls.add('proof:$adminUserId:$bookingId');
    return const <String, Object?>{'outcome': 'sent'};
  }

  @override
  Future<Map<String, Object?>> adminSessions() async {
    calls.add('adminSessions');
    return const <String, Object?>{'sessions': <Object?>[]};
  }

  @override
  Future<Map<String, Object?>> adminParticipants(String sessionKey) async {
    calls.add('participants:$sessionKey');
    return const <String, Object?>{'outcome': 'ok'};
  }

  @override
  Future<Map<String, Object?>> adminMarkAttendance({
    required int adminUserId,
    required int bookingId,
    required String attendance,
  }) async {
    calls.add('attendance:$adminUserId:$bookingId:$attendance');
    return const <String, Object?>{'outcome': 'marked'};
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

    test('routes admin payments, sessions and attendance', () async {
      expect((await call('GET', '/internal/admin/payments')).$1, HttpStatus.ok);
      expect(
        (await call(
          'POST',
          '/internal/admin/payments/9/review',
          body: const {'adminUserId': 1, 'adminUsername': 'boss', 'decision': 'approve'},
        ))
            .$1,
        HttpStatus.ok,
      );
      expect(
        (await call('POST', '/internal/admin/payments/9/proof', body: const {'adminUserId': 1})).$1,
        HttpStatus.ok,
      );
      expect((await call('GET', '/internal/admin/sessions')).$1, HttpStatus.ok);
      final key = Uri.encodeQueryComponent('trainings|2026-10-21T16:00:00.000Z|Бокс|Зал');
      expect((await call('GET', '/internal/admin/participants?key=$key')).$1, HttpStatus.ok);
      expect(
        (await call(
          'POST',
          '/internal/admin/bookings/4/attendance',
          body: const {'adminUserId': 1, 'attendance': 'absent'},
        ))
            .$1,
        HttpStatus.ok,
      );
      expect(backend.calls, [
        'adminPayments',
        'review:1:boss:9:approve',
        'proof:1:9',
        'adminSessions',
        'participants:trainings|2026-10-21T16:00:00.000Z|Бокс|Зал',
        'attendance:1:4:absent',
      ]);
      expect((await call('GET', '/internal/admin/participants')).$1, HttpStatus.badRequest);
      expect(
        (await call('POST', '/internal/admin/payments/9/review', body: const {'adminUserId': 1}))
            .$1,
        HttpStatus.badRequest,
      );
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

  group('PrivateHandlers Mini App admin', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    const adminId = 77;

    test('payments list strips the payment choice marker and keeps the group', () async {
      final repository = FakeBookingRepository()
        ..queue = [
          fakeBooking(
            id: 3,
            userId: 5,
            userUsername: 'runner',
            status: BookingStatus.paymentSubmitted,
            trainingPrice: 6000,
            trainingPrepayPercent: 50,
            paymentNote: '__payment_choice_partial__ перевёл с карты жены',
            paymentProofChatId: 5,
            paymentProofMessageId: 11,
          ),
        ];
      final harness = PrivateHandlersHarness(
        bookingRepository: repository,
        adminUserIds: const {adminId},
        nowProvider: () => now,
      );
      final result = await harness.handlers.miniAppAdminPayments();
      final payment = (result['payments']! as List<Object?>).single! as Map<String, Object?>;
      expect(payment['id'], 3);
      expect(payment['paymentType'], 'partial');
      expect(payment['comment'], 'перевёл с карты жены');
      expect(payment['hasProof'], isTrue);
      expect(payment['total'], 6000);
      expect((payment['organizer']! as Map<String, Object?>)['name'], '@runner');
    });

    test('review is refused for a non-admin and runs the chat review for an admin', () async {
      final repository = FakeBookingRepository();
      final harness = PrivateHandlersHarness(
        bookingRepository: repository,
        adminUserIds: const {adminId},
        adminChatId: -100,
        nowProvider: () => now,
      );
      final refused = await harness.handlers.miniAppAdminReviewPayment(
        adminUserId: 5,
        adminUsername: null,
        bookingId: 3,
        decision: 'approve',
      );
      expect(refused['outcome'], 'forbidden');
      expect(repository.reviewCalls, 0);

      final result = await harness.handlers.miniAppAdminReviewPayment(
        adminUserId: adminId,
        adminUsername: 'boss',
        bookingId: 3,
        decision: 'approve',
      );
      expect(result['outcome'], 'reviewed');
      expect(result['status'], 'paid');
      expect(repository.reviewCalls, 1);
      final recipients = harness.sender.messages.map((message) => message.chatId).toSet();
      // Same notices as the chat button: the payer and the admin chat.
      expect(recipients, containsAll(<int>[1, -100]));
    });

    test('review reports an already reviewed payment', () async {
      final repository = FakeBookingRepository()
        ..paymentReviewResult = const PaymentReviewResult(
          outcome: PaymentReviewOutcome.invalidStatus,
        );
      final harness = PrivateHandlersHarness(
        bookingRepository: repository,
        adminUserIds: const {adminId},
        nowProvider: () => now,
      );
      final result = await harness.handlers.miniAppAdminReviewPayment(
        adminUserId: adminId,
        adminUsername: null,
        bookingId: 3,
        decision: 'reject',
      );
      expect(result['outcome'], 'already_reviewed');
      expect(harness.sender.messages, isEmpty);
    });

    test('proof is copied into the admin chat with the bot', () async {
      final repository = FakeBookingRepository()
        ..queue = [
          fakeBooking(
            id: 3,
            status: BookingStatus.paymentSubmitted,
            paymentProofChatId: 5,
            paymentProofMessageId: 11,
          ),
        ];
      final harness = PrivateHandlersHarness(
        bookingRepository: repository,
        adminUserIds: const {adminId},
        nowProvider: () => now,
      );
      final result = await harness.handlers.miniAppAdminSendProof(
        adminUserId: adminId,
        bookingId: 3,
      );
      expect(result['outcome'], 'sent');
      final copied = harness.sender.copiedMessages.single;
      expect(copied.toChatId, adminId);
      expect(copied.fromChatId, 5);
      expect(copied.messageId, 11);
    });

    test('sessions and roster expose attendance state', () async {
      final past = DateTime.utc(2026, 10, 19, 10);
      final repository = FakeBookingRepository()
        ..bookingsByTrainingKey = [
          fakeBooking(
            id: 1,
            userId: 5,
            userUsername: 'runner',
            status: BookingStatus.paid,
            trainingKey: 'trainings|power',
            title: 'Силовая',
            startsAt: past,
          ),
          fakeBooking(
            id: 2,
            userId: 6,
            status: BookingStatus.paid,
            trainingKey: 'trainings|power',
            title: 'Силовая',
            startsAt: past,
            attendance: BookingAttendance.attended,
          ),
        ];
      final harness = PrivateHandlersHarness(
        bookingRepository: repository,
        adminUserIds: const {adminId},
        nowProvider: () => now,
      );
      final sessions = await harness.handlers.miniAppAdminSessions();
      final session = (sessions['sessions']! as List<Object?>).single! as Map<String, Object?>;
      expect(session['key'], 'trainings|power');
      expect(session['participants'], 2);
      expect(session['unmarked'], 1);
      expect(session['attendanceOpen'], isTrue);

      final roster = await harness.handlers.miniAppAdminParticipants('trainings|power');
      final participants = roster['participants']! as List<Object?>;
      final first = participants.first! as Map<String, Object?>;
      expect(first['name'], '@runner');
      expect(first['canMark'], isTrue);
      expect((participants.last! as Map<String, Object?>)['attendance'], 'attended');
      expect((await harness.handlers.miniAppAdminParticipants('missing'))['outcome'], 'not_found');
    });

    test('attendance uses the chat rules and notifies the participant', () async {
      final repository = FakeBookingRepository()
        ..bookingsByTrainingKey = [
          fakeBooking(
            id: 1,
            userId: 5,
            status: BookingStatus.paid,
            trainingKey: 'trainings|power',
            startsAt: DateTime.utc(2026, 10, 19, 10),
          ),
          fakeBooking(
            id: 2,
            userId: 6,
            status: BookingStatus.paid,
            trainingKey: 'trainings|later',
            startsAt: DateTime.utc(2026, 10, 25, 10),
          ),
        ];
      final harness = PrivateHandlersHarness(
        bookingRepository: repository,
        adminUserIds: const {adminId},
        nowProvider: () => now,
      );
      final early = await harness.handlers.miniAppAdminMarkAttendance(
        adminUserId: adminId,
        bookingId: 2,
        attendance: 'attended',
      );
      expect(early['outcome'], 'not_allowed');
      expect(early['message'], 'Отметить явку можно после старта.');

      final marked = await harness.handlers.miniAppAdminMarkAttendance(
        adminUserId: adminId,
        bookingId: 1,
        attendance: 'attended',
      );
      expect(marked['outcome'], 'marked');
      expect((marked['participant']! as Map<String, Object?>)['attendance'], 'attended');
      expect(harness.sender.messages.map((message) => message.chatId), contains(5));
      expect(harness.sender.messages.map((message) => message.chatId), isNot(contains(adminId)));

      final refused = await harness.handlers.miniAppAdminMarkAttendance(
        adminUserId: 5,
        bookingId: 1,
        attendance: 'absent',
      );
      expect(refused['outcome'], 'forbidden');
    });
  });
}
