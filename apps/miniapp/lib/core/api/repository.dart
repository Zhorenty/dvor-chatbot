import 'dart:convert';

import 'package:dvor_miniapp/core/api/models.dart';
import 'package:http/http.dart' as http;

/// Data access for the Mini App. [ApiRepository] talks to the Go API;
/// [DemoRepository] backs local previews outside Telegram.
abstract interface class DvorRepository {
  Future<Me> me();

  Future<List<ClubEvent>> events();

  Future<List<Booking>> bookings();

  Future<ActionResult> book(String key);

  Future<ActionResult> cancel(int bookingId);

  Future<List<AdminPayment>> adminPayments();

  Future<void> reviewPayment(int bookingId, PaymentDecision decision);

  /// Bot copies the receipt photo into the admin's chat.
  Future<void> sendProof(int bookingId);

  Future<List<AdminSession>> adminSessions();

  Future<Roster> roster(String key);

  Future<AdminParticipant> markAttendance(int bookingId, Attendance attendance);
}

class ApiRepository implements DvorRepository {
  ApiRepository({required String initData, http.Client? client, String baseUrl = '/api/v1'})
    : _initData = initData,
      _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  final String _initData;
  final http.Client _client;
  final String _baseUrl;

  static const Duration _readTimeout = Duration(seconds: 15);
  static const Duration _writeTimeout = Duration(seconds: 35);

  Map<String, String> get _headers => {
    'Authorization': 'tma $_initData',
    'Content-Type': 'application/json',
  };

  @override
  Future<Me> me() async => Me.fromJson(await _get('/me'));

  @override
  Future<List<ClubEvent>> events() async {
    final json = await _get('/events');
    final raw = (json['events'] as List<Object?>?) ?? const [];
    final events = raw.whereType<Map<String, Object?>>().map(ClubEvent.fromJson).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return events;
  }

  @override
  Future<List<Booking>> bookings() async {
    final json = await _get('/bookings');
    final raw = (json['bookings'] as List<Object?>?) ?? const [];
    return raw.whereType<Map<String, Object?>>().map(Booking.fromJson).toList();
  }

  @override
  Future<ActionResult> book(String key) async =>
      ActionResult.fromJson(await _post('/bookings', {'key': key}));

  @override
  Future<ActionResult> cancel(int bookingId) async =>
      ActionResult.fromJson(await _post('/bookings/$bookingId/cancel', const {}));

  @override
  Future<List<AdminPayment>> adminPayments() async {
    final json = await _get('/admin/payments');
    final raw = (json['payments'] as List<Object?>?) ?? const [];
    return raw.whereType<Map<String, Object?>>().map(AdminPayment.fromJson).toList();
  }

  @override
  Future<void> reviewPayment(int bookingId, PaymentDecision decision) async {
    await _post('/admin/payments/$bookingId/review', {'decision': decision.wire});
  }

  @override
  Future<void> sendProof(int bookingId) async {
    await _post('/admin/payments/$bookingId/proof', const {});
  }

  @override
  Future<List<AdminSession>> adminSessions() async {
    final json = await _get('/admin/sessions');
    final raw = (json['sessions'] as List<Object?>?) ?? const [];
    return raw.whereType<Map<String, Object?>>().map(AdminSession.fromJson).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<Roster> roster(String key) async {
    final json = await _get('/admin/sessions/participants?key=${Uri.encodeQueryComponent(key)}');
    final raw = (json['participants'] as List<Object?>?) ?? const [];
    return Roster(
      session: AdminSession.fromJson(json['session']! as Map<String, Object?>),
      participants: raw.whereType<Map<String, Object?>>().map(AdminParticipant.fromJson).toList(),
    );
  }

  @override
  Future<AdminParticipant> markAttendance(int bookingId, Attendance attendance) async {
    final json = await _post('/admin/bookings/$bookingId/attendance', {
      'attendance': attendance.wire,
    });
    return AdminParticipant.fromJson(json['participant']! as Map<String, Object?>);
  }

  Future<Map<String, Object?>> _get(String path) async {
    final response = await _guard(
      () => _client.get(Uri.parse('$_baseUrl$path'), headers: _headers).timeout(_readTimeout),
    );
    return _decode(response);
  }

  Future<Map<String, Object?>> _post(String path, Map<String, Object?> body) async {
    final response = await _guard(
      () => _client
          .post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body))
          .timeout(_writeTimeout),
    );
    return _decode(response);
  }

  Future<http.Response> _guard(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on Exception {
      throw const ApiException('network', 'Нет связи. Проверь интернет и попробуй ещё раз.');
    }
  }

  Map<String, Object?> _decode(http.Response response) {
    Map<String, Object?> json;
    try {
      json = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>?) ?? const {};
    } on FormatException {
      json = const {};
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    final error = json['error'];
    if (error is Map<String, Object?>) {
      throw ApiException(
        (error['code'] as String?) ?? 'error',
        (error['message'] as String?) ?? 'Что-то пошло не так.',
      );
    }
    throw const ApiException('error', 'Что-то пошло не так. Попробуй ещё раз.');
  }
}
