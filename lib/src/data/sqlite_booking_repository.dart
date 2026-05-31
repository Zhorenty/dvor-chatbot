import 'dart:io';

import 'package:dvor_chatbot/src/data/booking_repository.dart';
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
        training_key TEXT NOT NULL,
        training_title TEXT NOT NULL,
        starts_at TEXT NOT NULL,
        location TEXT NOT NULL,
        status TEXT NOT NULL,
        payment_note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, training_key)
      );
    ''');
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
    required TrainingInfo training,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final key = training.sessionKey;
    try {
      db.execute(
        '''
        INSERT INTO bookings (
          user_id,
          training_key,
          training_title,
          starts_at,
          location,
          status,
          payment_note,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          userId,
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
      SET status = ?, payment_note = ?, updated_at = ?
      WHERE id = ?;
      ''',
      <Object?>[
        BookingStatus.paymentSubmitted.dbValue,
        note?.trim().isEmpty == true ? null : note?.trim(),
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
  Future<TrainingBooking?> updateStatus(
    int bookingId,
    BookingStatus status,
  ) async {
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET status = ?, updated_at = ?
      WHERE id = ?;
      ''',
      <Object?>[status.dbValue, nowIso, bookingId],
    );
    return _findBookingById(bookingId);
  }

  void _expireOverduePendingBookings() {
    final db = _database;
    final cutoff = _nowProvider().toUtc().subtract(_pendingPaymentTtl).toIso8601String();
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET status = ?, updated_at = ?
      WHERE status = ? AND created_at < ?;
      ''',
      <Object?>[
        BookingStatus.cancelled.dbValue,
        nowIso,
        BookingStatus.pendingPayment.dbValue,
        cutoff,
      ],
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
      trainingKey: row['training_key'] as String,
      trainingTitle: row['training_title'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      location: row['location'] as String,
      status: BookingStatus.fromDbValue(row['status'] as String),
      paymentNote: row['payment_note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
