import 'dart:io';

import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/pending_payment_expiry_policy.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteBookingRepository implements BookingRepository {
  SqliteBookingRepository({
    required String dbPath,
    Duration pendingPaymentTtl = const Duration(hours: 2),
    DateTime Function()? nowProvider,
  })  : _dbPath = dbPath,
        _pendingPaymentTtl = pendingPaymentTtl,
        _nowProvider = nowProvider ?? DateTime.now;

  final String _dbPath;
  final Duration _pendingPaymentTtl;
  final DateTime Function() _nowProvider;
  final PendingPaymentExpiryPolicy _pendingPaymentExpiryPolicy = const PendingPaymentExpiryPolicy();
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('SqliteBookingRepository is not initialized.');
    }
    return db;
  }

  @override
  Future<void> init() async {
    final file = File(_dbPath);
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(_dbPath);
    _db = db;
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA foreign_keys=ON;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_username TEXT,
        training_key TEXT NOT NULL,
        training_title TEXT NOT NULL,
        starts_at TEXT NOT NULL,
        location TEXT NOT NULL,
        status TEXT NOT NULL,
        payment_note TEXT,
        payment_proof_chat_id INTEGER,
        payment_proof_message_id INTEGER,
        reminder_count INTEGER NOT NULL DEFAULT 0,
        last_reminder_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, training_key)
      );
    ''');
    _addColumnIfMissing(
        db, 'ALTER TABLE bookings ADD COLUMN reminder_count INTEGER NOT NULL DEFAULT 0;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN last_reminder_at TEXT;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN user_username TEXT;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN payment_proof_chat_id INTEGER;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN payment_proof_message_id INTEGER;');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);',
    );
  }

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  @override
  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    String? userUsername,
    required TrainingInfo training,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final key = training.sessionKey;
    final normalizedUsername = _normalizeUsername(userUsername);
    try {
      db.execute(
        '''
        INSERT INTO bookings (
          user_id,
          user_username,
          training_key,
          training_title,
          starts_at,
          location,
          status,
          payment_note,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          userId,
          normalizedUsername,
          key,
          training.title,
          training.startsAt.toUtc().toIso8601String(),
          training.location,
          BookingStatus.pendingPayment.dbValue,
          null,
          nowIso,
          nowIso,
        ],
      );
      final booking = _findBookingByUserAndTraining(userId, key);
      if (booking == null) {
        throw StateError('Inserted booking is missing in database.');
      }
      return BookingCreateResult(booking: booking, created: true);
    } on SqliteException {
      if (normalizedUsername != null) {
        _updateBookingUsernameIfMissing(
          userId: userId,
          trainingKey: key,
          userUsername: normalizedUsername,
        );
      }
      final existing = _findBookingByUserAndTraining(userId, key);
      if (existing == null) {
        rethrow;
      }
      return BookingCreateResult(booking: existing, created: false);
    }
  }

  @override
  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10}) async {
    _expireOverduePendingBookings();
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE user_id = ?
      ORDER BY starts_at ASC
      LIMIT ?;
      ''',
      <Object?>[userId, limit],
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    String? note,
    int? paymentProofChatId,
    int? paymentProofMessageId,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final result = db.select(
      '''
      SELECT id FROM bookings
      WHERE user_id = ? AND status = ?
      ORDER BY starts_at ASC
      LIMIT 1;
      ''',
      <Object?>[userId, BookingStatus.pendingPayment.dbValue],
    );
    if (result.isEmpty) {
      return null;
    }
    final bookingId = result.first['id'] as int;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET status = ?,
          payment_note = ?,
          payment_proof_chat_id = ?,
          payment_proof_message_id = ?,
          updated_at = ?
      WHERE id = ?;
      ''',
      <Object?>[
        BookingStatus.paymentSubmitted.dbValue,
        note?.trim().isEmpty == true ? null : note?.trim(),
        paymentProofChatId,
        paymentProofMessageId,
        nowIso,
        bookingId,
      ],
    );
    return _findBookingById(bookingId);
  }

  @override
  Future<List<TrainingBooking>> listByStatus(
    BookingStatus status, {
    int limit = 20,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE status = ?
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      <Object?>[status.dbValue, limit],
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<List<TrainingBooking>> listByTrainingKeys(
    Set<String> trainingKeys, {
    int limit = 200,
  }) async {
    _expireOverduePendingBookings();
    if (trainingKeys.isEmpty) {
      return const <TrainingBooking>[];
    }
    final db = _database;
    final placeholders = List<String>.filled(trainingKeys.length, '?').join(', ');
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE training_key IN ($placeholders)
        AND status != ?
      ORDER BY starts_at ASC, created_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        ...trainingKeys,
        BookingStatus.cancelled.dbValue,
        limit,
      ],
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<TrainingBooking?> updateStatus(
    int bookingId,
    BookingStatus status, {
    String? paymentNote,
  }) async {
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    if (paymentNote == null) {
      db.execute(
        '''
        UPDATE bookings
        SET status = ?, updated_at = ?
        WHERE id = ?;
        ''',
        <Object?>[status.dbValue, nowIso, bookingId],
      );
    } else {
      db.execute(
        '''
        UPDATE bookings
        SET status = ?, payment_note = ?, updated_at = ?
        WHERE id = ?;
        ''',
        <Object?>[status.dbValue, paymentNote, nowIso, bookingId],
      );
    }
    return _findBookingById(bookingId);
  }

  @override
  Future<List<TrainingBooking>> listPendingPaymentForReminder({
    required DateTime createdBefore,
    required DateTime remindedBefore,
    int limit = 20,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE status = ?
        AND created_at <= ?
        AND (last_reminder_at IS NULL OR last_reminder_at <= ?)
      ORDER BY created_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        BookingStatus.pendingPayment.dbValue,
        createdBefore.toUtc().toIso8601String(),
        remindedBefore.toUtc().toIso8601String(),
        limit,
      ],
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<void> markReminderSent(int bookingId) async {
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET reminder_count = reminder_count + 1,
          last_reminder_at = ?,
          updated_at = ?
      WHERE id = ?;
      ''',
      <Object?>[nowIso, nowIso, bookingId],
    );
  }

  void _expireOverduePendingBookings() {
    final db = _database;
    final cutoff = _nowProvider().toUtc().subtract(_pendingPaymentTtl).toIso8601String();
    final nowIso = _nowProvider().toUtc().toIso8601String();
    _pendingPaymentExpiryPolicy.expire(
      database: db,
      cutoffIsoUtc: cutoff,
      nowIsoUtc: nowIso,
    );
  }

  TrainingBooking? _findBookingByUserAndTraining(int userId, String trainingKey) {
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE user_id = ? AND training_key = ?
      LIMIT 1;
      ''',
      <Object?>[userId, trainingKey],
    );
    if (result.isEmpty) {
      return null;
    }
    return _rowToBooking(result.first);
  }

  TrainingBooking? _findBookingById(int id) {
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE id = ?
      LIMIT 1;
      ''',
      <Object?>[id],
    );
    if (result.isEmpty) {
      return null;
    }
    return _rowToBooking(result.first);
  }

  TrainingBooking _rowToBooking(Row row) {
    return TrainingBooking(
      id: row['id'] as int,
      userId: row['user_id'] as int,
      userUsername: row['user_username'] as String?,
      trainingKey: row['training_key'] as String,
      trainingTitle: row['training_title'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      location: row['location'] as String,
      status: BookingStatus.fromDbValue(row['status'] as String),
      paymentNote: row['payment_note'] as String?,
      paymentProofChatId: row['payment_proof_chat_id'] as int?,
      paymentProofMessageId: row['payment_proof_message_id'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  void _addColumnIfMissing(Database db, String sql) {
    try {
      db.execute(sql);
    } on SqliteException catch (error) {
      if (!error.toString().contains('duplicate column name')) {
        rethrow;
      }
    }
  }

  String? _normalizeUsername(String? username) {
    final trimmed = username?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  void _updateBookingUsernameIfMissing({
    required int userId,
    required String trainingKey,
    required String userUsername,
  }) {
    final db = _database;
    db.execute(
      '''
      UPDATE bookings
      SET user_username = ?
      WHERE user_id = ? AND training_key = ? AND user_username IS NULL;
      ''',
      <Object?>[userUsername, userId, trainingKey],
    );
  }
}
