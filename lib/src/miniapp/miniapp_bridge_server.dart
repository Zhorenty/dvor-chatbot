import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:l/l.dart';

/// Bot operations the Mini App API needs. Booking writes stay in the bot so
/// the chat flow, admin notifications and capacity rules are shared.
abstract interface class MiniAppBridgeBackend {
  Future<Map<String, Object?>> schedule();

  Future<Map<String, Object?>> bookings(int userId);

  Future<Map<String, Object?>> book({
    required int userId,
    required String? username,
    required String sessionKey,
  });

  Future<Map<String, Object?>> cancel({
    required int userId,
    required int bookingId,
  });

  Future<Map<String, Object?>> adminPayments();

  Future<Map<String, Object?>> adminReviewPayment({
    required int adminUserId,
    required String? adminUsername,
    required int bookingId,
    required String decision,
  });

  Future<Map<String, Object?>> adminSendProof({
    required int adminUserId,
    required int bookingId,
  });

  Future<Map<String, Object?>> adminSessions();

  Future<Map<String, Object?>> adminParticipants(String sessionKey);

  Future<Map<String, Object?>> adminMarkAttendance({
    required int adminUserId,
    required int bookingId,
    required String attendance,
  });
}

final class PrivateHandlersMiniAppBackend implements MiniAppBridgeBackend {
  const PrivateHandlersMiniAppBackend(this._handlers);

  final PrivateHandlers _handlers;

  @override
  Future<Map<String, Object?>> schedule() => _handlers.miniAppScheduleWithSeats();

  @override
  Future<Map<String, Object?>> bookings(int userId) => _handlers.miniAppBookings(userId);

  @override
  Future<Map<String, Object?>> book({
    required int userId,
    required String? username,
    required String sessionKey,
  }) {
    return _handlers.miniAppBook(userId: userId, username: username, sessionKey: sessionKey);
  }

  @override
  Future<Map<String, Object?>> cancel({required int userId, required int bookingId}) {
    return _handlers.miniAppCancel(userId: userId, bookingId: bookingId);
  }

  @override
  Future<Map<String, Object?>> adminPayments() => _handlers.miniAppAdminPayments();

  @override
  Future<Map<String, Object?>> adminReviewPayment({
    required int adminUserId,
    required String? adminUsername,
    required int bookingId,
    required String decision,
  }) {
    return _handlers.miniAppAdminReviewPayment(
      adminUserId: adminUserId,
      adminUsername: adminUsername,
      bookingId: bookingId,
      decision: decision,
    );
  }

  @override
  Future<Map<String, Object?>> adminSendProof({required int adminUserId, required int bookingId}) {
    return _handlers.miniAppAdminSendProof(adminUserId: adminUserId, bookingId: bookingId);
  }

  @override
  Future<Map<String, Object?>> adminSessions() => _handlers.miniAppAdminSessions();

  @override
  Future<Map<String, Object?>> adminParticipants(String sessionKey) {
    return _handlers.miniAppAdminParticipants(sessionKey);
  }

  @override
  Future<Map<String, Object?>> adminMarkAttendance({
    required int adminUserId,
    required int bookingId,
    required String attendance,
  }) {
    return _handlers.miniAppAdminMarkAttendance(
      adminUserId: adminUserId,
      bookingId: bookingId,
      attendance: attendance,
    );
  }
}

typedef TrackedRunner = Future<T> Function<T>(Future<T> Function() action);

/// Internal HTTP server reachable only from the Docker network (no published
/// port). The Go API authenticates Telegram users and calls it with a shared
/// bearer token; user identity in requests is trusted from the API.
final class MiniAppBridgeServer {
  MiniAppBridgeServer({
    required MiniAppBridgeBackend backend,
    required String token,
    TrackedRunner? runTracked,
  })  : _backend = backend,
        _token = token,
        _runTracked = runTracked;

  final MiniAppBridgeBackend _backend;
  final String _token;
  final TrackedRunner? _runTracked;
  HttpServer? _server;

  static final RegExp _userBookingsPath = RegExp(r'^/internal/users/(\d+)/bookings$');
  static final RegExp _cancelPath = RegExp(r'^/internal/bookings/(\d+)/cancel$');
  static final RegExp _reviewPath = RegExp(r'^/internal/admin/payments/(\d+)/review$');
  static final RegExp _proofPath = RegExp(r'^/internal/admin/payments/(\d+)/proof$');
  static final RegExp _attendancePath = RegExp(r'^/internal/admin/bookings/(\d+)/attendance$');

  int? get port => _server?.port;

  Future<void> start({required int port, InternetAddress? address}) async {
    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    _server = server;
    l.i('Mini App bridge listening on ${server.address.address}:${server.port}');
    unawaited(
      server.forEach(_handle).onError<Object>((error, stackTrace) {
        l.w('Mini App bridge stopped: $error', stackTrace);
      }),
    );
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_isAuthorized(request)) {
        await _write(response, HttpStatus.unauthorized, const {'error': 'unauthorized'});
        return;
      }
      final result = await _track(() => _route(request));
      await _write(response, result.$1, result.$2);
    } on FormatException catch (error) {
      await _write(response, HttpStatus.badRequest, {'error': error.message});
    } on Object catch (error, stackTrace) {
      l.e('Mini App bridge request failed: ${request.method} ${request.uri.path}: $error',
          stackTrace);
      await _write(response, HttpStatus.internalServerError, const {'error': 'internal'});
    }
  }

  Future<(int, Map<String, Object?>)> _route(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    if (method == 'GET' && path == '/internal/health') {
      return (HttpStatus.ok, const <String, Object?>{'ok': true});
    }
    if (method == 'GET' && path == '/internal/schedule') {
      return (HttpStatus.ok, await _backend.schedule());
    }
    final userBookings = _userBookingsPath.firstMatch(path);
    if (method == 'GET' && userBookings != null) {
      return (HttpStatus.ok, await _backend.bookings(int.parse(userBookings.group(1)!)));
    }
    if (method == 'POST' && path == '/internal/bookings') {
      final body = await _readJson(request);
      return (
        HttpStatus.ok,
        await _backend.book(
          userId: _requireInt(body, 'userId'),
          username: body['username'] as String?,
          sessionKey: _requireString(body, 'key'),
        ),
      );
    }
    final cancel = _cancelPath.firstMatch(path);
    if (method == 'POST' && cancel != null) {
      final body = await _readJson(request);
      return (
        HttpStatus.ok,
        await _backend.cancel(
          userId: _requireInt(body, 'userId'),
          bookingId: int.parse(cancel.group(1)!),
        ),
      );
    }
    if (path.startsWith('/internal/admin/')) {
      final admin = await _routeAdmin(request);
      if (admin != null) {
        return admin;
      }
    }
    return (HttpStatus.notFound, const <String, Object?>{'error': 'not_found'});
  }

  /// Admin routes. The API verified admin rights; `adminUserId` is re-checked
  /// by the bot before writes.
  Future<(int, Map<String, Object?>)?> _routeAdmin(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    if (method == 'GET' && path == '/internal/admin/payments') {
      return (HttpStatus.ok, await _backend.adminPayments());
    }
    if (method == 'GET' && path == '/internal/admin/sessions') {
      return (HttpStatus.ok, await _backend.adminSessions());
    }
    if (method == 'GET' && path == '/internal/admin/participants') {
      final key = request.uri.queryParameters['key'] ?? '';
      if (key.isEmpty) {
        throw const FormatException('key must be a non-empty string');
      }
      return (HttpStatus.ok, await _backend.adminParticipants(key));
    }
    if (method != 'POST') {
      return null;
    }
    final review = _reviewPath.firstMatch(path);
    if (review != null) {
      final body = await _readJson(request);
      return (
        HttpStatus.ok,
        await _backend.adminReviewPayment(
          adminUserId: _requireInt(body, 'adminUserId'),
          adminUsername: body['adminUsername'] as String?,
          bookingId: int.parse(review.group(1)!),
          decision: _requireString(body, 'decision'),
        ),
      );
    }
    final proof = _proofPath.firstMatch(path);
    if (proof != null) {
      final body = await _readJson(request);
      return (
        HttpStatus.ok,
        await _backend.adminSendProof(
          adminUserId: _requireInt(body, 'adminUserId'),
          bookingId: int.parse(proof.group(1)!),
        ),
      );
    }
    final attendance = _attendancePath.firstMatch(path);
    if (attendance != null) {
      final body = await _readJson(request);
      return (
        HttpStatus.ok,
        await _backend.adminMarkAttendance(
          adminUserId: _requireInt(body, 'adminUserId'),
          bookingId: int.parse(attendance.group(1)!),
          attendance: _requireString(body, 'attendance'),
        ),
      );
    }
    return null;
  }

  Future<T> _track<T>(Future<T> Function() action) {
    final runTracked = _runTracked;
    return runTracked == null ? action() : runTracked(action);
  }

  bool _isAuthorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const prefix = 'Bearer ';
    if (!header.startsWith(prefix)) {
      return false;
    }
    return _constantTimeEquals(header.substring(prefix.length), _token);
  }

  static bool _constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    var diff = left.length ^ right.length;
    for (var i = 0; i < left.length && i < right.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }

  static Future<Map<String, Object?>> _readJson(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('JSON object expected');
    }
    return decoded;
  }

  static int _requireInt(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is int) {
      return value;
    }
    throw FormatException('$key must be an integer');
  }

  static String _requireString(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('$key must be a non-empty string');
  }

  static Future<void> _write(HttpResponse response, int status, Map<String, Object?> body) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }
}
