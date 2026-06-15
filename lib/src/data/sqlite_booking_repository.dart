import 'dart:io';

import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/pending_payment_expiry_policy.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
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
        training_price INTEGER,
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
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN training_price INTEGER;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS economic_report_dispatches (
        report_type TEXT NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        PRIMARY KEY (report_type, period_start, period_end)
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
    String? userUsername,
    required TrainingInfo training,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final key = training.sessionKey;
    final normalizedUsername = _normalizeUsername(userUsername);
    final existing = _findBookingByUserAndTraining(userId, key);
    if (existing != null) {
      var bookingForResponse = existing;
      if (normalizedUsername != null) {
        _updateBookingUsername(
          userId: userId,
          trainingKey: key,
          userUsername: normalizedUsername,
        );
        final refreshed = _findBookingByUserAndTraining(userId, key);
        if (refreshed != null) {
          bookingForResponse = refreshed;
        }
      }
      if (bookingForResponse.status == BookingStatus.cancelled ||
          bookingForResponse.status == BookingStatus.paymentRejected) {
        _assertParticipantsLimitNotExceeded(
          training,
          userId: userId,
          userUsername: normalizedUsername,
        );
        final reactivated = await _reactivateBookingAsPendingPayment(
          bookingId: bookingForResponse.id,
          userUsername: normalizedUsername,
        );
        return BookingCreateResult(booking: reactivated, created: true);
      }
      return BookingCreateResult(booking: bookingForResponse, created: false);
    }
    if (normalizedUsername != null) {
      final syntheticByUsername = _findSyntheticBookingByUsernameAndTraining(
        username: normalizedUsername,
        trainingKey: key,
      );
      if (syntheticByUsername != null) {
        final rebound = await _rebindSyntheticBookingToRealUser(
          bookingId: syntheticByUsername.id,
          userId: userId,
          userUsername: normalizedUsername,
        );
        if (rebound.status == BookingStatus.cancelled ||
            rebound.status == BookingStatus.paymentRejected) {
          _assertParticipantsLimitNotExceeded(
            training,
            userId: userId,
            userUsername: normalizedUsername,
          );
          final reactivated = await _reactivateBookingAsPendingPayment(
            bookingId: rebound.id,
            userUsername: normalizedUsername,
          );
          return BookingCreateResult(booking: reactivated, created: true);
        }
        return BookingCreateResult(booking: rebound, created: false);
      }
    }
    _assertParticipantsLimitNotExceeded(
      training,
      userId: userId,
      userUsername: normalizedUsername,
    );
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
          training_price,
          status,
          payment_note,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          userId,
          normalizedUsername,
          key,
          training.title,
          training.startsAt.toUtc().toIso8601String(),
          training.location,
          training.price,
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
        _updateBookingUsername(
          userId: userId,
          trainingKey: key,
          userUsername: normalizedUsername,
        );
      }
      final existing = _findBookingByUserAndTraining(userId, key);
      if (existing == null) {
        rethrow;
      }
      if (existing.status == BookingStatus.cancelled ||
          existing.status == BookingStatus.paymentRejected) {
        _assertParticipantsLimitNotExceeded(
          training,
          userId: userId,
          userUsername: normalizedUsername,
        );
        final reactivated = await _reactivateBookingAsPendingPayment(
          bookingId: existing.id,
          userUsername: normalizedUsername,
        );
        return BookingCreateResult(booking: reactivated, created: true);
      }
      return BookingCreateResult(booking: existing, created: false);
    }
  }

  @override
  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10}) async {
    _expireOverduePendingBookings();
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE user_id = ?
      ORDER BY
        CASE
          WHEN status != ? AND starts_at >= ? THEN 0
          WHEN status != ? THEN 1
          ELSE 2
        END ASC,
        CASE WHEN status != ? AND starts_at >= ? THEN starts_at END ASC,
        CASE WHEN status != ? AND starts_at < ? THEN starts_at END DESC,
        updated_at DESC
      LIMIT ?;
      ''',
      <Object?>[
        userId,
        BookingStatus.cancelled.dbValue,
        nowIso,
        BookingStatus.cancelled.dbValue,
        BookingStatus.cancelled.dbValue,
        nowIso,
        BookingStatus.cancelled.dbValue,
        nowIso,
        limit,
      ],
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<BookingActionResult> cancelBooking({
    required int userId,
    required int bookingId,
  }) async {
    _expireOverduePendingBookings();
    final existing = _findBookingById(bookingId);
    if (existing == null || existing.userId != userId) {
      return const BookingActionResult(outcome: BookingActionOutcome.notFound);
    }
    final updated = await updateStatus(bookingId, BookingStatus.cancelled);
    return BookingActionResult(
      outcome: BookingActionOutcome.success,
      booking: updated,
    );
  }

  @override
  Future<BookingRescheduleResult> rescheduleBooking({
    required int userId,
    required int bookingId,
    required TrainingInfo training,
  }) async {
    _expireOverduePendingBookings();
    final existing = _findBookingById(bookingId);
    if (existing == null || existing.userId != userId) {
      return const BookingRescheduleResult(outcome: BookingRescheduleOutcome.notFound);
    }
    if (_isFreeBooking(existing) && _isPaidActivityPrice(training.price)) {
      return const BookingRescheduleResult(outcome: BookingRescheduleOutcome.conflict);
    }
    if (!_isFreeBooking(existing) && _isFreeActivityPrice(training.price)) {
      return const BookingRescheduleResult(outcome: BookingRescheduleOutcome.conflict);
    }
    if (_normalizedBookingPrice(existing) != training.price) {
      return const BookingRescheduleResult(outcome: BookingRescheduleOutcome.conflict);
    }
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    try {
      db.execute(
        '''
        UPDATE bookings
        SET training_key = ?,
            training_title = ?,
            starts_at = ?,
            location = ?,
            training_price = ?,
            updated_at = ?
        WHERE id = ? AND user_id = ?;
        ''',
        <Object?>[
          training.sessionKey,
          training.title,
          training.startsAt.toUtc().toIso8601String(),
          training.location,
          training.price,
          nowIso,
          bookingId,
          userId,
        ],
      );
    } on SqliteException {
      return const BookingRescheduleResult(outcome: BookingRescheduleOutcome.conflict);
    }
    final updated = _findBookingById(bookingId);
    return BookingRescheduleResult(
      outcome: BookingRescheduleOutcome.success,
      booking: updated,
    );
  }

  @override
  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    int? bookingId,
    String? note,
    int? paymentProofChatId,
    int? paymentProofMessageId,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final result = bookingId == null
        ? db.select(
            '''
            SELECT id FROM bookings
            WHERE user_id = ? AND status = ?
            ORDER BY starts_at ASC
            LIMIT 1;
            ''',
            <Object?>[userId, BookingStatus.pendingPayment.dbValue],
          )
        : db.select(
            '''
            SELECT id FROM bookings
            WHERE id = ? AND user_id = ? AND status = ?
            LIMIT 1;
            ''',
            <Object?>[
              bookingId,
              userId,
              BookingStatus.pendingPayment.dbValue,
            ],
          );
    if (result.isEmpty) {
      return null;
    }
    final selectedBookingId = result.first['id'] as int;
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
        selectedBookingId,
      ],
    );
    return _findBookingById(selectedBookingId);
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
    bool includeCancelled = false,
  }) async {
    _expireOverduePendingBookings();
    if (trainingKeys.isEmpty) {
      return const <TrainingBooking>[];
    }
    final db = _database;
    final placeholders = List<String>.filled(trainingKeys.length, '?').join(', ');
    final cancelledFilterSql = includeCancelled ? '' : 'AND status != ?';
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE training_key IN ($placeholders)
        $cancelledFilterSql
        AND status != ?
      ORDER BY starts_at ASC, created_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        ...trainingKeys,
        if (!includeCancelled) BookingStatus.cancelled.dbValue,
        BookingStatus.paymentRejected.dbValue,
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
  Future<PaymentReviewResult> reviewSubmittedPayment({
    required int bookingId,
    required BookingStatus status,
  }) async {
    final db = _database;
    final existing = _findBookingById(bookingId);
    if (existing == null) {
      return const PaymentReviewResult(outcome: PaymentReviewOutcome.notFound);
    }
    if (existing.status != BookingStatus.paymentSubmitted) {
      return const PaymentReviewResult(outcome: PaymentReviewOutcome.invalidStatus);
    }
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET status = ?, updated_at = ?
      WHERE id = ? AND status = ?;
      ''',
      <Object?>[
        status.dbValue,
        nowIso,
        bookingId,
        BookingStatus.paymentSubmitted.dbValue,
      ],
    );
    if (db.updatedRows == 0) {
      return const PaymentReviewResult(outcome: PaymentReviewOutcome.invalidStatus);
    }
    return PaymentReviewResult(
      outcome: PaymentReviewOutcome.success,
      booking: _findBookingById(bookingId),
    );
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
      WHERE id = ? AND status = ?;
      ''',
      <Object?>[nowIso, nowIso, bookingId, BookingStatus.pendingPayment.dbValue],
    );
  }

  @override
  Future<List<TrainingBooking>> expirePendingPaymentBookings({
    required DateTime createdBefore,
    int limit = 50,
  }) async {
    final db = _database;
    final overdueRows = db.select(
      '''
      SELECT * FROM bookings
      WHERE status = ?
        AND created_at <= ?
      ORDER BY created_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        BookingStatus.pendingPayment.dbValue,
        createdBefore.toUtc().toIso8601String(),
        limit,
      ],
    );
    if (overdueRows.isEmpty) {
      return const <TrainingBooking>[];
    }

    final bookings = overdueRows.map(_rowToBooking).toList(growable: false);
    final ids = bookings.map((booking) => booking.id).toList(growable: false);
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET status = ?, updated_at = ?
      WHERE status = ?
        AND id IN ($placeholders);
      ''',
      <Object?>[
        BookingStatus.cancelled.dbValue,
        nowIso,
        BookingStatus.pendingPayment.dbValue,
        ...ids,
      ],
    );
    return bookings;
  }

  @override
  Future<List<TrainingBooking>> listPaidBookingsInRange({
    required DateTime fromInclusive,
    required DateTime toExclusive,
    int limit = 5000,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE status IN (?, ?)
        AND updated_at >= ?
        AND updated_at < ?
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        BookingStatus.paid.dbValue,
        BookingStatus.freeTraining.dbValue,
        fromInclusive.toUtc().toIso8601String(),
        toExclusive.toUtc().toIso8601String(),
        limit,
      ],
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<bool> tryMarkEconomicReportSent({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime sentAt,
  }) async {
    final db = _database;
    try {
      db.execute(
        '''
        INSERT INTO economic_report_dispatches (
          report_type,
          period_start,
          period_end,
          sent_at
        ) VALUES (?, ?, ?, ?);
        ''',
        <Object?>[
          reportType,
          periodStart.toUtc().toIso8601String(),
          periodEnd.toUtc().toIso8601String(),
          sentAt.toUtc().toIso8601String(),
        ],
      );
      return true;
    } on SqliteException {
      return false;
    }
  }

  @override
  Future<void> rollbackEconomicReportSent({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final db = _database;
    db.execute(
      '''
      DELETE FROM economic_report_dispatches
      WHERE report_type = ?
        AND period_start = ?
        AND period_end = ?;
      ''',
      <Object?>[
        reportType,
        periodStart.toUtc().toIso8601String(),
        periodEnd.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<({int active, int archived})> adminCountBySegment() async {
    _expireOverduePendingBookings();
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final result = db.select(
      '''
      SELECT
        SUM(CASE WHEN starts_at >= ? AND status != ? THEN 1 ELSE 0 END) AS active_count,
        SUM(CASE WHEN starts_at < ? OR status = ? THEN 1 ELSE 0 END) AS archived_count
      FROM bookings;
      ''',
      <Object?>[
        nowIso,
        BookingStatus.cancelled.dbValue,
        nowIso,
        BookingStatus.cancelled.dbValue,
      ],
    );
    final row = result.first;
    return (
      active: (row['active_count'] as int?) ?? 0,
      archived: (row['archived_count'] as int?) ?? 0,
    );
  }

  @override
  Future<List<TrainingBooking>> adminListBookings({
    required ActivityCategory category,
    required bool archived,
    int? limit,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final whereCategory = _categoryConditionSql(category);
    final whereSegment =
        archived ? '(starts_at < ? OR status = ?)' : '(starts_at >= ? AND status != ?)';
    final orderBy = archived ? 'starts_at DESC, updated_at DESC' : 'starts_at ASC, updated_at DESC';
    final whereArgs = <Object?>[
      nowIso,
      BookingStatus.cancelled.dbValue,
    ];
    final limitClause = limit == null ? '' : '\n      LIMIT ?';
    if (limit != null) {
      whereArgs.add(limit);
    }
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE ($whereCategory)
        AND $whereSegment
      ORDER BY $orderBy$limitClause;
      ''',
      whereArgs,
    );
    return result.map(_rowToBooking).toList(growable: false);
  }

  @override
  Future<TrainingBooking> adminCreateBooking({
    int userId = 0,
    required String userUsername,
    required TrainingInfo training,
    required BookingStatus status,
  }) async {
    _expireOverduePendingBookings();
    final db = _database;
    final normalizedUsername = _normalizeUsername(userUsername);
    if (normalizedUsername == null) {
      throw ArgumentError.value(userUsername, 'userUsername', 'username must not be empty');
    }
    final trainingKey = training.sessionKey;
    final effectiveUserId = userId == 0 ? _resolveUserIdByUsername(normalizedUsername) : userId;
    final existingForUsername = _findBookingByUserAndTraining(effectiveUserId, trainingKey);
    if (existingForUsername != null) {
      final updated = await adminUpdateBooking(
        bookingId: existingForUsername.id,
        userUsername: normalizedUsername,
        status: status,
      );
      return updated ?? existingForUsername;
    }

    final nowIso = _nowProvider().toUtc().toIso8601String();
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
          training_price,
          status,
          payment_note,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          effectiveUserId,
          normalizedUsername,
          trainingKey,
          training.title,
          training.startsAt.toUtc().toIso8601String(),
          training.location,
          training.price,
          status.dbValue,
          null,
          nowIso,
          nowIso,
        ],
      );
      final created = _findBookingByUserAndTraining(effectiveUserId, trainingKey);
      if (created == null) {
        throw StateError('Inserted admin booking is missing in database.');
      }
      return created;
    } on SqliteException {
      final existing = _findBookingByUserAndTraining(effectiveUserId, trainingKey);
      if (existing == null) {
        rethrow;
      }
      final updated = await adminUpdateBooking(
        bookingId: existing.id,
        userUsername: normalizedUsername,
        status: status,
      );
      return updated ?? existing;
    }
  }

  @override
  Future<TrainingBooking?> adminUpdateBooking({
    required int bookingId,
    String? userUsername,
    TrainingInfo? training,
    BookingStatus? status,
  }) async {
    final existing = _findBookingById(bookingId);
    if (existing == null) {
      return null;
    }
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final columns = <String>[];
    final args = <Object?>[];
    final normalizedUsername = _normalizeUsername(userUsername);
    if (userUsername != null && normalizedUsername == null) {
      throw ArgumentError.value(userUsername, 'userUsername', 'username must not be empty');
    }
    final targetUserId = normalizedUsername != null
        ? _resolveAdminUpdateTargetUserId(
            existing: existing,
            normalizedUsername: normalizedUsername,
          )
        : existing.userId;
    final targetTrainingKey = training?.sessionKey ?? existing.trainingKey;
    final targetTrainingPrice = training?.price ?? existing.trainingPrice;
    final targetStatus = status ?? existing.status;
    if (_isFreeStatus(targetStatus) && _isPaidActivityPrice(targetTrainingPrice)) {
      throw const BookingConflictException('Free status is not allowed for paid activity.');
    }
    final conflicting = _findBookingByUserAndTraining(targetUserId, targetTrainingKey);
    if (conflicting != null && conflicting.id != bookingId) {
      throw const BookingConflictException(
          'Another booking already exists for this user and event.');
    }
    if (normalizedUsername != null) {
      columns.add('user_username = ?');
      args.add(normalizedUsername);
      if (targetUserId != existing.userId) {
        columns.add('user_id = ?');
        args.add(targetUserId);
      }
    }
    if (training != null) {
      columns.add('training_key = ?');
      args.add(training.sessionKey);
      columns.add('training_title = ?');
      args.add(training.title);
      columns.add('starts_at = ?');
      args.add(training.startsAt.toUtc().toIso8601String());
      columns.add('location = ?');
      args.add(training.location);
      columns.add('training_price = ?');
      args.add(training.price);
    }
    if (status != null) {
      columns.add('status = ?');
      args.add(status.dbValue);
    }
    if (columns.isEmpty) {
      return _findBookingById(bookingId);
    }
    columns.add('updated_at = ?');
    args.add(nowIso);
    args.add(bookingId);
    db.execute(
      '''
      UPDATE bookings
      SET ${columns.join(', ')}
      WHERE id = ?;
      ''',
      args,
    );
    return _findBookingById(bookingId);
  }

  @override
  Future<TrainingBooking?> adminArchiveBooking(int bookingId) async {
    return updateStatus(bookingId, BookingStatus.cancelled);
  }

  @override
  Future<EveryFifthRewardProgress> getEveryFifthRewardProgress(
    int userId, {
    required DateTime now,
  }) async {
    final db = _database;
    final nowIso = now.toUtc().toIso8601String();
    final trainingsCondition = _categoryConditionSql(ActivityCategory.trainings);
    final qualifiedResult = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM bookings
      WHERE user_id = ?
        AND status = ?
        AND starts_at < ?
        AND ($trainingsCondition)
        AND (payment_note IS NULL OR payment_note NOT IN (?, ?));
      ''',
      <Object?>[
        userId,
        BookingStatus.paid.dbValue,
        nowIso,
        '__starter_bonus__',
        '__every_fifth_bonus__',
      ],
    );
    final usedResult = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM bookings
      WHERE user_id = ?
        AND status = ?
        AND starts_at < ?
        AND ($trainingsCondition)
        AND payment_note = ?;
      ''',
      <Object?>[
        userId,
        BookingStatus.paid.dbValue,
        nowIso,
        '__every_fifth_bonus__',
      ],
    );
    final qualified = ((qualifiedResult.first['total'] as int?) ?? 0).clamp(0, 1 << 30);
    final used = ((usedResult.first['total'] as int?) ?? 0).clamp(0, 1 << 30);
    return EveryFifthRewardProgress(
      qualifiedTrainingsCount: qualified,
      usedRewardsCount: used,
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

  TrainingBooking? _findSyntheticBookingByUsernameAndTraining({
    required String username,
    required String trainingKey,
  }) {
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE user_id <= 0
        AND user_username = ? COLLATE NOCASE
        AND training_key = ?
      ORDER BY updated_at DESC, id DESC
      LIMIT 1;
      ''',
      <Object?>[username, trainingKey],
    );
    if (result.isEmpty) {
      return null;
    }
    return _rowToBooking(result.first);
  }

  Future<TrainingBooking> _rebindSyntheticBookingToRealUser({
    required int bookingId,
    required int userId,
    required String userUsername,
  }) async {
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE bookings
      SET user_id = ?,
          user_username = ?,
          updated_at = ?
      WHERE id = ? AND user_id <= 0;
      ''',
      <Object?>[
        userId,
        userUsername,
        nowIso,
        bookingId,
      ],
    );
    final rebound = _findBookingById(bookingId);
    if (rebound == null) {
      throw StateError('Rebound booking is missing in database.');
    }
    return rebound;
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
      trainingPrice: row['training_price'] as int?,
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

  void _updateBookingUsername({
    required int userId,
    required String trainingKey,
    required String userUsername,
  }) {
    final db = _database;
    db.execute(
      '''
      UPDATE bookings
      SET user_username = ?
      WHERE user_id = ?
        AND training_key = ?
        AND (user_username IS NULL OR user_username != ? COLLATE NOCASE);
      ''',
      <Object?>[userUsername, userId, trainingKey, userUsername],
    );
  }

  Future<TrainingBooking> _reactivateBookingAsPendingPayment({
    required int bookingId,
    required String? userUsername,
  }) async {
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final normalizedUsername = _normalizeUsername(userUsername);
    final usernameClause = normalizedUsername == null ? '' : ', user_username = ?';
    final args = <Object?>[
      BookingStatus.pendingPayment.dbValue,
      null,
      null,
      null,
      nowIso,
      if (normalizedUsername != null) normalizedUsername,
      bookingId,
    ];
    db.execute(
      '''
      UPDATE bookings
      SET status = ?,
          payment_note = ?,
          payment_proof_chat_id = ?,
          payment_proof_message_id = ?,
          updated_at = ?
          $usernameClause
      WHERE id = ?;
      ''',
      args,
    );
    final reactivated = _findBookingById(bookingId);
    if (reactivated == null) {
      throw StateError('Reactivated booking is missing in database.');
    }
    return reactivated;
  }

  void _assertParticipantsLimitNotExceeded(
    TrainingInfo training, {
    required int userId,
    required String? userUsername,
  }) {
    final participantsLimit = training.participantsLimit;
    if (participantsLimit == null || participantsLimit <= 0) {
      return;
    }
    final includeTrainers = training.includeTrainersInParticipants;
    if (!includeTrainers && isTrainerBookingWhitelisted(userId: userId, username: userUsername)) {
      return;
    }
    final excludedUserIds = includeTrainers ? const <int>{} : trainerBookingWhitelistUserIds;
    final excludedUsernames = includeTrainers
        ? const <String>{}
        : trainerBookingWhitelistUsernames
            .map(normalizeTelegramUsername)
            .whereType<String>()
            .toSet();
    final exclusionClauses = <String>[];
    final args = <Object?>[
      training.sessionKey,
      BookingStatus.cancelled.dbValue,
      BookingStatus.paymentRejected.dbValue,
    ];
    if (excludedUserIds.isNotEmpty) {
      final placeholders = List<String>.filled(excludedUserIds.length, '?').join(', ');
      exclusionClauses.add('user_id IN ($placeholders)');
      args.addAll(excludedUserIds);
    }
    if (excludedUsernames.isNotEmpty) {
      final placeholders = List<String>.filled(excludedUsernames.length, '?').join(', ');
      exclusionClauses.add('LOWER(user_username) IN ($placeholders)');
      args.addAll(excludedUsernames);
    }
    final excludedSql =
        exclusionClauses.isEmpty ? '' : '\n        AND NOT (${exclusionClauses.join(' OR ')})';
    final db = _database;
    final result = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM bookings
      WHERE training_key = ?
        AND status != ?
        AND status != ?$excludedSql;
      ''',
      args,
    );
    final total = (result.first['total'] as int?) ?? 0;
    if (total >= participantsLimit) {
      throw const BookingParticipantsLimitExceededException(
        'Participants limit reached for selected training.',
      );
    }
  }

  String _categoryConditionSql(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => "(training_key LIKE 'trainings|%' OR "
          "(training_key NOT LIKE 'yoga|%' AND training_key NOT LIKE 'hikes|%' "
          "AND training_key NOT LIKE 'trails|%' "
          "AND training_title NOT LIKE '🧘 Йога:%' "
          "AND training_title NOT LIKE '🥾 Поход:%' AND training_title NOT LIKE '🏃 Трейл:%'))",
      ActivityCategory.yoga => "(training_key LIKE 'yoga|%' OR training_title LIKE '🧘 Йога:%')",
      ActivityCategory.hikes => "(training_key LIKE 'hikes|%' OR training_title LIKE '🥾 Поход:%')",
      ActivityCategory.trails =>
        "(training_key LIKE 'trails|%' OR training_title LIKE '🏃 Трейл:%')",
    };
  }

  int _syntheticUserIdForUsername(String username) {
    var hash = 17;
    for (var i = 0; i < username.length; i++) {
      hash = (hash * 31 + username.codeUnitAt(i)) & 0x7fffffff;
    }
    final value = hash == 0 ? 1 : hash;
    return -value;
  }

  int _resolveAdminUpdateTargetUserId({
    required TrainingBooking existing,
    required String normalizedUsername,
  }) {
    final existingUsername = _normalizeUsername(existing.userUsername)?.toLowerCase();
    final targetUsername = normalizedUsername.toLowerCase();
    if (existingUsername == targetUsername) {
      return existing.userId;
    }
    return _resolveUserIdByUsername(normalizedUsername);
  }

  int _resolveUserIdByUsername(String normalizedUsername) {
    final knownUserId = _findKnownPositiveUserIdByUsername(normalizedUsername);
    if (knownUserId != null) {
      return knownUserId;
    }
    return _syntheticUserIdForUsername(normalizedUsername);
  }

  int? _findKnownPositiveUserIdByUsername(String normalizedUsername) {
    final db = _database;
    final result = db.select(
      '''
      SELECT user_id
      FROM bookings
      WHERE user_id > 0
        AND user_username = ? COLLATE NOCASE
      ORDER BY updated_at DESC, id DESC
      LIMIT 1;
      ''',
      <Object?>[normalizedUsername],
    );
    if (result.isEmpty) {
      return null;
    }
    return result.first['user_id'] as int?;
  }

  bool _isFreeBooking(TrainingBooking booking) {
    if (booking.status == BookingStatus.freeTraining) {
      return true;
    }
    final price = booking.trainingPrice;
    return price != null && price <= 0;
  }

  int? _normalizedBookingPrice(TrainingBooking booking) {
    if (booking.status == BookingStatus.freeTraining) {
      return 0;
    }
    return booking.trainingPrice;
  }

  bool _isFreeStatus(BookingStatus status) {
    return status == BookingStatus.freeTraining;
  }

  bool _isPaidActivityPrice(int? price) {
    return price == null || price > 0;
  }

  bool _isFreeActivityPrice(int? price) {
    return price != null && price <= 0;
  }
}
