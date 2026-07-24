import 'dart:io';
import 'dart:math';

import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/pending_payment_expiry_policy.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_participant.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteBookingRepository implements BookingRepository {
  static const String _starterBonusPaymentNoteMarker = '__starter_bonus__';
  static const String _everyFifthBonusPaymentNoteMarker = '__every_fifth_bonus__';
  static const String _referralBonusPaymentNoteMarker = '__referral_bonus__';
  static const String _proIncludedTrainingPaymentNoteMarker = '__pro_included_training__';

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
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN promo_code TEXT;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN promo_discount_percent INTEGER;');
    _migrateBookingsParticipantModel(db);
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
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_payment_group_id ON bookings(payment_group_id);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookings_manager_user_id ON bookings(manager_user_id);',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS referral_attributions (
        invitee_user_id INTEGER PRIMARY KEY,
        inviter_user_id INTEGER NOT NULL,
        attributed_at TEXT NOT NULL
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_referral_attributions_inviter '
      'ON referral_attributions(inviter_user_id);',
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
          manager_user_id,
          participant_type,
          participant_user_id,
          participant_username,
          participant_name,
          payment_group_id,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
          userId,
          BookingParticipantType.self.dbValue,
          userId,
          normalizedUsername,
          null,
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
  Future<BookingGroupCreateResult> createPendingBookingGroup({
    required int managerUserId,
    String? managerUsername,
    required TrainingInfo training,
    required List<BookingParticipantDraft> participants,
  }) async {
    _expireOverduePendingBookings();
    if (participants.isEmpty) {
      throw ArgumentError.value(participants, 'participants', 'must not be empty');
    }
    if (participants.length > maxManagedGuestsPerEvent) {
      throw const BookingManagerLimitExceededException(
        'Too many participants for one manager on a single event.',
      );
    }

    final normalizedManagerUsername = _normalizeUsername(managerUsername);
    final key = training.sessionKey;
    final normalizedParticipants = <BookingParticipantDraft>[];
    final seenKeys = <String>{};
    for (final draft in participants) {
      final normalized = _normalizeParticipantDraft(draft);
      final dedupeKey = _participantDedupeKey(normalized, managerUserId: managerUserId);
      if (!seenKeys.add(dedupeKey)) {
        throw BookingParticipantConflictException(
          'Duplicate participant in group: ${normalized.displayLabel}',
        );
      }
      normalizedParticipants.add(normalized);
    }

    final existingManagedGuests = _countActiveManagedGuestBookings(
      managerUserId: managerUserId,
      trainingKey: key,
    );
    if (existingManagedGuests + normalizedParticipants.length > maxManagedGuestsPerEvent) {
      throw const BookingManagerLimitExceededException(
        'Manager participant limit reached for selected training.',
      );
    }

    for (final draft in normalizedParticipants) {
      final conflict = _findActiveParticipantConflict(
        trainingKey: key,
        draft: draft,
        managerUserId: managerUserId,
      );
      if (conflict != null) {
        throw BookingParticipantConflictException(
          'Participant already booked: ${draft.displayLabel}',
        );
      }
    }

    _assertParticipantsLimitAllowsAdditional(
      training,
      additionalCount: normalizedParticipants.length,
      userId: managerUserId,
      userUsername: normalizedManagerUsername,
    );

    final paymentGroupId = _newPaymentGroupId();
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final db = _database;
    final created = <TrainingBooking>[];
    try {
      db.execute('BEGIN IMMEDIATE;');
      for (final draft in normalizedParticipants) {
        final participantUserId = _resolveParticipantUserId(
          draft: draft,
          managerUserId: managerUserId,
        );
        final participantUsername = draft.type == BookingParticipantType.telegram
            ? _normalizeUsername(draft.username)
            : (draft.type == BookingParticipantType.self ? normalizedManagerUsername : null);
        final participantName =
            draft.type == BookingParticipantType.guest ? draft.name?.trim() : null;
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
            manager_user_id,
            participant_type,
            participant_user_id,
            participant_username,
            participant_name,
            payment_group_id,
            created_at,
            updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
          ''',
          <Object?>[
            managerUserId,
            normalizedManagerUsername,
            key,
            training.title,
            training.startsAt.toUtc().toIso8601String(),
            training.location,
            training.price,
            BookingStatus.pendingPayment.dbValue,
            null,
            managerUserId,
            draft.type.dbValue,
            participantUserId,
            participantUsername,
            participantName,
            paymentGroupId,
            nowIso,
            nowIso,
          ],
        );
        final inserted = _findLatestBookingByManagerGroup(
          managerUserId: managerUserId,
          paymentGroupId: paymentGroupId,
          participantType: draft.type,
          participantUserId: participantUserId,
          participantName: participantName,
        );
        if (inserted == null) {
          throw StateError('Inserted group booking is missing in database.');
        }
        created.add(inserted);
      }
      db.execute('COMMIT;');
    } on Object {
      db.execute('ROLLBACK;');
      rethrow;
    }

    return BookingGroupCreateResult(
      paymentGroupId: paymentGroupId,
      bookings: created,
    );
  }

  @override
  Future<List<TrainingBooking>> listBookingsByPaymentGroup(String paymentGroupId) async {
    _expireOverduePendingBookings();
    final normalized = paymentGroupId.trim();
    if (normalized.isEmpty) {
      return const <TrainingBooking>[];
    }
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE payment_group_id = ?
      ORDER BY id ASC;
      ''',
      <Object?>[normalized],
    );
    return result.map(_rowToBooking).toList(growable: false);
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

    // When a specific bookingId is pinned (from the in-memory flow), query it
    // first. If that booking is no longer in a payable status (e.g. cancelled
    // by TTL, or status changed by admin while the user was in the confirmation
    // flow), fall back to any pending booking for this user so that a
    // legitimate payment file is never rejected with a false "no pending
    // booking" error.
    ResultSet result;
    if (bookingId != null) {
      result = db.select(
        '''
        SELECT id FROM bookings
        WHERE id = ? AND user_id = ? AND status IN (?, ?)
        LIMIT 1;
        ''',
        <Object?>[
          bookingId,
          userId,
          BookingStatus.pendingPayment.dbValue,
          BookingStatus.partialPaid.dbValue,
        ],
      );
    } else {
      result = _selectAnyPendingBooking(db, userId);
    }

    // Pinned booking not found in a payable status — try any pending booking.
    if (result.isEmpty && bookingId != null) {
      result = _selectAnyPendingBooking(db, userId);
    }

    if (result.isEmpty) {
      return null;
    }
    final selectedBookingId = result.first['id'] as int;
    final selected = _findBookingById(selectedBookingId);
    if (selected == null) {
      return null;
    }
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final normalizedNote = note?.trim().isEmpty == true ? null : note?.trim();
    final groupId = selected.paymentGroupId?.trim();
    if (groupId != null && groupId.isNotEmpty) {
      db.execute(
        '''
        UPDATE bookings
        SET status = ?,
            payment_note = ?,
            payment_proof_chat_id = ?,
            payment_proof_message_id = ?,
            updated_at = ?
        WHERE payment_group_id = ?
          AND status IN (?, ?);
        ''',
        <Object?>[
          BookingStatus.paymentSubmitted.dbValue,
          normalizedNote,
          paymentProofChatId,
          paymentProofMessageId,
          nowIso,
          groupId,
          BookingStatus.pendingPayment.dbValue,
          BookingStatus.partialPaid.dbValue,
        ],
      );
    } else {
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
          normalizedNote,
          paymentProofChatId,
          paymentProofMessageId,
          nowIso,
          selectedBookingId,
        ],
      );
    }
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
  Future<TrainingBooking?> applyPromoCode({
    required int bookingId,
    required String code,
    required int discountPercent,
    required int discountedPrice,
  }) async {
    final db = _database;
    final nowIso = _nowProvider().toUtc().toIso8601String();
    final columns = <String>[
      'promo_code = ?',
      'promo_discount_percent = ?',
      'training_price = ?',
    ];
    final args = <Object?>[code, discountPercent, discountedPrice];
    if (discountPercent >= 100) {
      columns.add('status = ?');
      args.add(BookingStatus.paid.dbValue);
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
  Future<bool> isPromoCodeUsed(String code, int userId) async {
    final db = _database;
    final normalized = code.trim().toUpperCase();
    final rows = db.select(
      '''
      SELECT 1 FROM bookings
      WHERE UPPER(TRIM(promo_code)) = ?
        AND user_id = ?
        AND status != ?
      LIMIT 1;
      ''',
      <Object?>[normalized, userId, BookingStatus.cancelled.dbValue],
    );
    return rows.isNotEmpty;
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
    final groupId = existing.paymentGroupId?.trim();
    if (groupId != null && groupId.isNotEmpty) {
      db.execute(
        '''
        UPDATE bookings
        SET status = ?, updated_at = ?
        WHERE payment_group_id = ? AND status = ?;
        ''',
        <Object?>[
          status.dbValue,
          nowIso,
          groupId,
          BookingStatus.paymentSubmitted.dbValue,
        ],
      );
    } else {
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
    }
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
    // Kept in signature for backward compatibility; reminders are single-shot now.
    final _ = remindedBefore;
    _expireOverduePendingBookings();
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE status = ?
        AND created_at <= ?
        AND last_reminder_at IS NULL
      ORDER BY created_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        BookingStatus.pendingPayment.dbValue,
        createdBefore.toUtc().toIso8601String(),
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
      WHERE status IN (?, ?, ?)
        AND updated_at >= ?
        AND updated_at < ?
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        BookingStatus.paid.dbValue,
        BookingStatus.freeTraining.dbValue,
        BookingStatus.partialPaid.dbValue,
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
          manager_user_id,
          participant_type,
          participant_user_id,
          participant_username,
          participant_name,
          payment_group_id,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
          effectiveUserId,
          BookingParticipantType.self.dbValue,
          effectiveUserId,
          normalizedUsername,
          null,
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
    // Prevent silently moving a free-training booking onto a paid activity;
    // but allow admin to explicitly grant free status on any existing activity.
    if (training != null &&
        _isFreeStatus(targetStatus) &&
        _isPaidActivityPrice(targetTrainingPrice)) {
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
      columns.add('participant_username = ?');
      args.add(normalizedUsername);
      if (targetUserId != existing.userId) {
        columns.add('user_id = ?');
        args.add(targetUserId);
        columns.add('manager_user_id = ?');
        args.add(targetUserId);
        columns.add('participant_user_id = ?');
        args.add(targetUserId);
        columns.add('participant_type = ?');
        args.add(BookingParticipantType.self.dbValue);
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
      if (status == BookingStatus.pendingPayment &&
          existing.status != BookingStatus.pendingPayment) {
        columns.add('payment_note = ?');
        args.add(null);
        columns.add('payment_proof_chat_id = ?');
        args.add(null);
        columns.add('payment_proof_message_id = ?');
        args.add(null);
        columns.add('reminder_count = ?');
        args.add(0);
        columns.add('last_reminder_at = ?');
        args.add(null);
        columns.add('created_at = ?');
        args.add(nowIso);
      }
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
        AND participant_type = ?
        AND status = ?
        AND starts_at < ?
        AND ($trainingsCondition)
        AND (payment_note IS NULL OR payment_note NOT IN (?, ?));
      ''',
      <Object?>[
        userId,
        BookingParticipantType.self.dbValue,
        BookingStatus.paid.dbValue,
        nowIso,
        _starterBonusPaymentNoteMarker,
        _everyFifthBonusPaymentNoteMarker,
      ],
    );
    final usedResult = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM bookings
      WHERE user_id = ?
        AND participant_type = ?
        AND status = ?
        AND starts_at < ?
        AND ($trainingsCondition)
        AND payment_note = ?;
      ''',
      <Object?>[
        userId,
        BookingParticipantType.self.dbValue,
        BookingStatus.paid.dbValue,
        nowIso,
        _everyFifthBonusPaymentNoteMarker,
      ],
    );
    final qualified = ((qualifiedResult.first['total'] as int?) ?? 0).clamp(0, 1 << 30);
    final used = ((usedResult.first['total'] as int?) ?? 0).clamp(0, 1 << 30);
    return EveryFifthRewardProgress(
      qualifiedTrainingsCount: qualified,
      usedRewardsCount: used,
    );
  }

  @override
  Future<ReferralRewardProgress> getReferralRewardProgress(
    int userId, {
    required DateTime now,
  }) async {
    final db = _database;
    final nowIso = now.toUtc().toIso8601String();
    final trainingsCondition = _categoryConditionSql(ActivityCategory.trainings);
    final qualifiedResult = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM referral_attributions AS refs
      WHERE refs.inviter_user_id = ?
        AND EXISTS (
          SELECT 1
          FROM bookings AS b
          WHERE b.user_id = refs.invitee_user_id
            AND b.participant_type = 'self'
            AND b.status = ?
            AND b.starts_at < ?
            AND b.training_price > 0
            AND ($trainingsCondition)
            AND (b.payment_note IS NULL OR b.payment_note NOT IN (?, ?, ?, ?))
        );
      ''',
      <Object?>[
        userId,
        BookingStatus.paid.dbValue,
        nowIso,
        _starterBonusPaymentNoteMarker,
        _everyFifthBonusPaymentNoteMarker,
        _referralBonusPaymentNoteMarker,
        _proIncludedTrainingPaymentNoteMarker,
      ],
    );
    final usedResult = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM bookings
      WHERE user_id = ?
        AND status = ?
        AND payment_note = ?;
      ''',
      <Object?>[
        userId,
        BookingStatus.paid.dbValue,
        _referralBonusPaymentNoteMarker,
      ],
    );
    final qualified = ((qualifiedResult.first['total'] as int?) ?? 0).clamp(0, 1 << 30);
    final used = ((usedResult.first['total'] as int?) ?? 0).clamp(0, 1 << 30);
    return ReferralRewardProgress(
      qualifiedReferralsCount: qualified,
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

  ResultSet _selectAnyPendingBooking(Database db, int userId) {
    return db.select(
      '''
      SELECT id FROM bookings
      WHERE user_id = ?
        AND status IN (?, ?)
      ORDER BY starts_at ASC,
               CASE status WHEN ? THEN 0 ELSE 1 END ASC
      LIMIT 1;
      ''',
      <Object?>[
        userId,
        BookingStatus.pendingPayment.dbValue,
        BookingStatus.partialPaid.dbValue,
        BookingStatus.partialPaid.dbValue,
      ],
    );
  }

  TrainingBooking? _findBookingByUserAndTraining(int userId, String trainingKey) {
    final db = _database;
    // Prefer the manager's own seat so friend/guest rows under the same
    // manager_user_id do not shadow self bookings.
    final selfResult = db.select(
      '''
      SELECT * FROM bookings
      WHERE training_key = ?
        AND participant_type = ?
        AND (
          participant_user_id = ?
          OR (participant_user_id IS NULL AND user_id = ?)
        )
      LIMIT 1;
      ''',
      <Object?>[
        trainingKey,
        BookingParticipantType.self.dbValue,
        userId,
        userId,
      ],
    );
    if (selfResult.isNotEmpty) {
      return _rowToBooking(selfResult.first);
    }
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE user_id = ? AND training_key = ?
      ORDER BY CASE participant_type WHEN ? THEN 0 ELSE 1 END ASC, id ASC
      LIMIT 1;
      ''',
      <Object?>[userId, trainingKey, BookingParticipantType.self.dbValue],
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
          manager_user_id = ?,
          participant_type = ?,
          participant_user_id = ?,
          participant_username = ?,
          updated_at = ?
      WHERE id = ? AND user_id <= 0;
      ''',
      <Object?>[
        userId,
        userUsername,
        userId,
        BookingParticipantType.self.dbValue,
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
    final userId = row['user_id'] as int;
    final participantType = BookingParticipantType.fromDbValue(
      _optionalStringColumn(row, 'participant_type'),
    );
    return TrainingBooking(
      id: row['id'] as int,
      userId: userId,
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
      promoCode: row['promo_code'] as String?,
      promoDiscountPercent: row['promo_discount_percent'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      managerUserId: (_optionalIntColumn(row, 'manager_user_id') ?? userId),
      participantType: participantType,
      participantUserId: _optionalIntColumn(row, 'participant_user_id'),
      participantUsername: _optionalStringColumn(row, 'participant_username'),
      participantName: _optionalStringColumn(row, 'participant_name'),
      paymentGroupId: _optionalStringColumn(row, 'payment_group_id'),
    );
  }

  int? _optionalIntColumn(Row row, String column) {
    try {
      return row[column] as int?;
    } on ArgumentError {
      return null;
    }
  }

  String? _optionalStringColumn(Row row, String column) {
    try {
      return row[column] as String?;
    } on ArgumentError {
      return null;
    }
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

  void _migrateBookingsParticipantModel(Database db) {
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN manager_user_id INTEGER;');
    _addColumnIfMissing(
        db, "ALTER TABLE bookings ADD COLUMN participant_type TEXT NOT NULL DEFAULT 'self';");
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN participant_user_id INTEGER;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN participant_username TEXT;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN participant_name TEXT;');
    _addColumnIfMissing(db, 'ALTER TABLE bookings ADD COLUMN payment_group_id TEXT;');
    db.execute('''
      UPDATE bookings
      SET manager_user_id = user_id
      WHERE manager_user_id IS NULL;
    ''');
    db.execute('''
      UPDATE bookings
      SET participant_type = 'self'
      WHERE participant_type IS NULL OR TRIM(participant_type) = '';
    ''');
    db.execute('''
      UPDATE bookings
      SET participant_user_id = user_id
      WHERE participant_user_id IS NULL
        AND (participant_type = 'self' OR participant_type = 'telegram');
    ''');
    db.execute('''
      UPDATE bookings
      SET participant_username = user_username
      WHERE participant_username IS NULL
        AND user_username IS NOT NULL
        AND (participant_type = 'self' OR participant_type = 'telegram');
    ''');

    final tableSqlRows = db.select(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'bookings';",
    );
    final tableSql = tableSqlRows.isEmpty ? '' : (tableSqlRows.first['sql'] as String? ?? '');
    final hasLegacyUnique = tableSql.contains('UNIQUE(user_id, training_key)');
    if (!hasLegacyUnique) {
      _ensureParticipantUniqueIndexes(db);
      return;
    }

    db.execute('''
      CREATE TABLE bookings_participant_migrated (
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
        promo_code TEXT,
        promo_discount_percent INTEGER,
        manager_user_id INTEGER NOT NULL,
        participant_type TEXT NOT NULL DEFAULT 'self',
        participant_user_id INTEGER,
        participant_username TEXT,
        participant_name TEXT,
        payment_group_id TEXT
      );
    ''');
    db.execute('''
      INSERT INTO bookings_participant_migrated (
        id, user_id, user_username, training_key, training_title, starts_at, location,
        training_price, status, payment_note, payment_proof_chat_id, payment_proof_message_id,
        reminder_count, last_reminder_at, created_at, updated_at, promo_code, promo_discount_percent,
        manager_user_id, participant_type, participant_user_id, participant_username,
        participant_name, payment_group_id
      )
      SELECT
        id, user_id, user_username, training_key, training_title, starts_at, location,
        training_price, status, payment_note, payment_proof_chat_id, payment_proof_message_id,
        COALESCE(reminder_count, 0), last_reminder_at, created_at, updated_at, promo_code,
        promo_discount_percent,
        COALESCE(manager_user_id, user_id),
        COALESCE(NULLIF(TRIM(participant_type), ''), 'self'),
        COALESCE(participant_user_id, user_id),
        COALESCE(participant_username, user_username),
        participant_name,
        payment_group_id
      FROM bookings;
    ''');
    db.execute('DROP TABLE bookings;');
    db.execute('ALTER TABLE bookings_participant_migrated RENAME TO bookings;');
    _ensureParticipantUniqueIndexes(db);
  }

  void _ensureParticipantUniqueIndexes(Database db) {
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_participant_user_unique
      ON bookings(training_key, participant_user_id)
      WHERE participant_user_id IS NOT NULL;
    ''');
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_guest_participant_unique
      ON bookings(training_key, manager_user_id, participant_name COLLATE NOCASE)
      WHERE participant_type = 'guest' AND participant_name IS NOT NULL;
    ''');
  }

  BookingParticipantDraft _normalizeParticipantDraft(BookingParticipantDraft draft) {
    switch (draft.type) {
      case BookingParticipantType.self:
        return const BookingParticipantDraft.self();
      case BookingParticipantType.telegram:
        final username = _normalizeUsername(draft.username);
        if (username == null) {
          throw ArgumentError.value(draft.username, 'username', 'must not be empty');
        }
        return BookingParticipantDraft.telegram(username: username);
      case BookingParticipantType.guest:
        final name = draft.name?.trim() ?? '';
        if (name.isEmpty || name.length > 40) {
          throw ArgumentError.value(draft.name, 'name', 'must be 1..40 chars');
        }
        return BookingParticipantDraft.guest(name: name);
    }
  }

  String _participantDedupeKey(
    BookingParticipantDraft draft, {
    required int managerUserId,
  }) {
    return switch (draft.type) {
      BookingParticipantType.self => 'self:$managerUserId',
      BookingParticipantType.telegram =>
        'tg:${(_normalizeUsername(draft.username) ?? '').toLowerCase()}',
      BookingParticipantType.guest => 'guest:${(draft.name ?? '').trim().toLowerCase()}',
    };
  }

  int _countActiveManagedGuestBookings({
    required int managerUserId,
    required String trainingKey,
  }) {
    final db = _database;
    final result = db.select(
      '''
      SELECT COUNT(*) AS total
      FROM bookings
      WHERE manager_user_id = ?
        AND training_key = ?
        AND participant_type != ?
        AND status != ?
        AND status != ?;
      ''',
      <Object?>[
        managerUserId,
        trainingKey,
        BookingParticipantType.self.dbValue,
        BookingStatus.cancelled.dbValue,
        BookingStatus.paymentRejected.dbValue,
      ],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  TrainingBooking? _findActiveParticipantConflict({
    required String trainingKey,
    required BookingParticipantDraft draft,
    required int managerUserId,
  }) {
    final db = _database;
    final ResultSet result;
    switch (draft.type) {
      case BookingParticipantType.self:
        result = db.select(
          '''
          SELECT * FROM bookings
          WHERE training_key = ?
            AND participant_type = ?
            AND participant_user_id = ?
            AND status != ?
            AND status != ?
          LIMIT 1;
          ''',
          <Object?>[
            trainingKey,
            BookingParticipantType.self.dbValue,
            managerUserId,
            BookingStatus.cancelled.dbValue,
            BookingStatus.paymentRejected.dbValue,
          ],
        );
      case BookingParticipantType.telegram:
        final username = _normalizeUsername(draft.username);
        if (username == null) {
          throw ArgumentError.value(draft.username, 'username', 'must not be empty');
        }
        final participantUserId = _resolveUserIdByUsername(username);
        result = db.select(
          '''
          SELECT * FROM bookings
          WHERE training_key = ?
            AND status != ?
            AND status != ?
            AND (
              participant_user_id = ?
              OR (
                participant_username = ? COLLATE NOCASE
                AND participant_type = ?
              )
            )
          LIMIT 1;
          ''',
          <Object?>[
            trainingKey,
            BookingStatus.cancelled.dbValue,
            BookingStatus.paymentRejected.dbValue,
            participantUserId,
            username,
            BookingParticipantType.telegram.dbValue,
          ],
        );
      case BookingParticipantType.guest:
        final name = draft.name?.trim() ?? '';
        if (name.isEmpty) {
          throw ArgumentError.value(draft.name, 'name', 'must not be empty');
        }
        result = db.select(
          '''
          SELECT * FROM bookings
          WHERE training_key = ?
            AND manager_user_id = ?
            AND participant_type = ?
            AND participant_name = ? COLLATE NOCASE
            AND status != ?
            AND status != ?
          LIMIT 1;
          ''',
          <Object?>[
            trainingKey,
            managerUserId,
            BookingParticipantType.guest.dbValue,
            name,
            BookingStatus.cancelled.dbValue,
            BookingStatus.paymentRejected.dbValue,
          ],
        );
    }
    if (result.isEmpty) {
      return null;
    }
    return _rowToBooking(result.first);
  }

  int? _resolveParticipantUserId({
    required BookingParticipantDraft draft,
    required int managerUserId,
  }) {
    return switch (draft.type) {
      BookingParticipantType.self => managerUserId,
      BookingParticipantType.telegram =>
        _resolveUserIdByUsername(_normalizeUsername(draft.username) ?? ''),
      BookingParticipantType.guest => null,
    };
  }

  void _assertParticipantsLimitAllowsAdditional(
    TrainingInfo training, {
    required int additionalCount,
    required int userId,
    required String? userUsername,
  }) {
    final participantsLimit = training.participantsLimit;
    if (participantsLimit == null || participantsLimit <= 0 || additionalCount <= 0) {
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
    if (total + additionalCount > participantsLimit) {
      throw const BookingParticipantsLimitExceededException(
        'Participants limit reached for selected training.',
      );
    }
  }

  TrainingBooking? _findLatestBookingByManagerGroup({
    required int managerUserId,
    required String paymentGroupId,
    required BookingParticipantType participantType,
    required int? participantUserId,
    required String? participantName,
  }) {
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE manager_user_id = ?
        AND payment_group_id = ?
        AND participant_type = ?
        AND (
          (? IS NOT NULL AND participant_user_id = ?)
          OR (? IS NOT NULL AND participant_name = ? COLLATE NOCASE)
        )
      ORDER BY id DESC
      LIMIT 1;
      ''',
      <Object?>[
        managerUserId,
        paymentGroupId,
        participantType.dbValue,
        participantUserId,
        participantUserId,
        participantName,
        participantName,
      ],
    );
    if (result.isEmpty) {
      return null;
    }
    return _rowToBooking(result.first);
  }

  String _newPaymentGroupId() {
    final now = _nowProvider().toUtc().microsecondsSinceEpoch;
    final random = Random(now).nextInt(1 << 32).toRadixString(16);
    return 'pg_${now}_$random';
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

  @override
  Future<List<TrainingBooking>> adminSearchBookingsByUsername(
    String username, {
    int limit = 200,
  }) async {
    final normalized = _normalizeUsername(username) ?? username;
    final db = _database;
    final result = db.select(
      '''
      SELECT * FROM bookings
      WHERE user_username = ? COLLATE NOCASE
      ORDER BY starts_at DESC
      LIMIT ?;
      ''',
      <Object?>[normalized, limit],
    );
    return result.map(_rowToBooking).toList();
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
