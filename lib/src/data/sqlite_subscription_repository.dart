import 'dart:io';

import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteSubscriptionRepository implements SubscriptionRepository {
  SqliteSubscriptionRepository({
    required String dbPath,
  }) : _dbPath = dbPath;

  final String _dbPath;
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('SqliteSubscriptionRepository is not initialized.');
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
      CREATE TABLE IF NOT EXISTS subscription_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_username TEXT,
        status TEXT NOT NULL,
        active_from TEXT,
        active_until TEXT,
        payment_note TEXT,
        payment_proof_chat_id INTEGER,
        payment_proof_message_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_requests_user
      ON subscription_requests(user_id);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_requests_status
      ON subscription_requests(status);
    ''');
  }

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  @override
  Future<SubscriptionMembership> getMembership(
    int userId, {
    required DateTime now,
  }) async {
    final row = _findActiveRowForUser(userId, now: now);
    if (row == null) {
      return const SubscriptionMembership(level: MembershipLevel.normal);
    }
    return SubscriptionMembership(
      level: MembershipLevel.pro,
      activeUntil: DateTime.parse(row['active_until'] as String).toLocal(),
    );
  }

  @override
  Future<SubmitSubscriptionRequestResult> submitPaymentRequest({
    required int userId,
    String? userUsername,
    String? note,
    required int paymentProofChatId,
    required int paymentProofMessageId,
    required DateTime requestedAt,
  }) async {
    final db = _database;
    final now = requestedAt.toUtc();
    final activeRow = _findActiveRowForUser(userId, now: requestedAt);
    if (activeRow != null) {
      return SubmitSubscriptionRequestResult(
        outcome: SubmitSubscriptionRequestOutcome.alreadyActive,
        request: _rowToRequest(activeRow),
      );
    }
    final pendingRow = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE user_id = ?
        AND status = ?
      ORDER BY created_at DESC, id DESC
      LIMIT 1;
      ''',
      <Object?>[
        userId,
        SubscriptionRequestStatus.paymentSubmitted.dbValue,
      ],
    );
    if (pendingRow.isNotEmpty) {
      return SubmitSubscriptionRequestResult(
        outcome: SubmitSubscriptionRequestOutcome.alreadyPending,
        request: _rowToRequest(pendingRow.first),
      );
    }

    final normalizedUsername = _normalizeUsername(userUsername);
    db.execute(
      '''
      INSERT INTO subscription_requests (
        user_id,
        user_username,
        status,
        payment_note,
        payment_proof_chat_id,
        payment_proof_message_id,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      <Object?>[
        userId,
        normalizedUsername,
        SubscriptionRequestStatus.paymentSubmitted.dbValue,
        note?.trim().isEmpty == true ? null : note?.trim(),
        paymentProofChatId,
        paymentProofMessageId,
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );
    final inserted = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE id = ?
      LIMIT 1;
      ''',
      <Object?>[db.lastInsertRowId],
    );
    return SubmitSubscriptionRequestResult(
      outcome: SubmitSubscriptionRequestOutcome.created,
      request: inserted.isEmpty ? null : _rowToRequest(inserted.first),
    );
  }

  @override
  Future<List<SubscriptionRequest>> listPendingRequests({int limit = 50}) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE status = ?
      ORDER BY created_at ASC, id ASC
      LIMIT ?;
      ''',
      <Object?>[
        SubscriptionRequestStatus.paymentSubmitted.dbValue,
        limit,
      ],
    );
    return rows.map(_rowToRequest).toList(growable: false);
  }

  @override
  Future<ReviewSubscriptionRequestResult> reviewPendingRequest({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
  }) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE id = ?
      LIMIT 1;
      ''',
      <Object?>[requestId],
    );
    if (rows.isEmpty) {
      return const ReviewSubscriptionRequestResult(
        outcome: ReviewSubscriptionRequestOutcome.notFound,
      );
    }
    final current = _rowToRequest(rows.first);
    if (current.status != SubscriptionRequestStatus.paymentSubmitted) {
      return const ReviewSubscriptionRequestResult(
        outcome: ReviewSubscriptionRequestOutcome.invalidStatus,
      );
    }

    final now = reviewedAt.toUtc();
    if (approve) {
      final currentMembership = await getMembership(current.userId, now: reviewedAt);
      final base = currentMembership.level == MembershipLevel.pro &&
              currentMembership.activeUntil != null &&
              currentMembership.activeUntil!.isAfter(reviewedAt)
          ? currentMembership.activeUntil!
          : reviewedAt;
      final activeUntil = base.add(const Duration(days: 30));
      db.execute(
        '''
        UPDATE subscription_requests
        SET status = ?,
            active_from = ?,
            active_until = ?,
            updated_at = ?
        WHERE id = ?
          AND status = ?;
        ''',
        <Object?>[
          SubscriptionRequestStatus.active.dbValue,
          now.toIso8601String(),
          activeUntil.toUtc().toIso8601String(),
          now.toIso8601String(),
          requestId,
          SubscriptionRequestStatus.paymentSubmitted.dbValue,
        ],
      );
    } else {
      db.execute(
        '''
        UPDATE subscription_requests
        SET status = ?,
            updated_at = ?
        WHERE id = ?
          AND status = ?;
        ''',
        <Object?>[
          SubscriptionRequestStatus.rejected.dbValue,
          now.toIso8601String(),
          requestId,
          SubscriptionRequestStatus.paymentSubmitted.dbValue,
        ],
      );
    }
    if (db.updatedRows == 0) {
      return const ReviewSubscriptionRequestResult(
        outcome: ReviewSubscriptionRequestOutcome.invalidStatus,
      );
    }
    final updatedRows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE id = ?
      LIMIT 1;
      ''',
      <Object?>[requestId],
    );
    return ReviewSubscriptionRequestResult(
      outcome: ReviewSubscriptionRequestOutcome.success,
      request: updatedRows.isEmpty ? null : _rowToRequest(updatedRows.first),
    );
  }

  @override
  Future<List<SubscriptionRequest>> listActiveSubscriptions({
    required DateTime now,
    int limit = 100,
  }) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE status = ?
        AND active_until IS NOT NULL
        AND active_until > ?
      ORDER BY active_until ASC, id ASC
      LIMIT ?;
      ''',
      <Object?>[
        SubscriptionRequestStatus.active.dbValue,
        now.toUtc().toIso8601String(),
        limit,
      ],
    );
    return rows.map(_rowToRequest).toList(growable: false);
  }

  Row? _findActiveRowForUser(
    int userId, {
    required DateTime now,
  }) {
    final db = _database;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE user_id = ?
        AND status = ?
        AND active_until IS NOT NULL
        AND active_until > ?
      ORDER BY active_until DESC, id DESC
      LIMIT 1;
      ''',
      <Object?>[
        userId,
        SubscriptionRequestStatus.active.dbValue,
        now.toUtc().toIso8601String(),
      ],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  SubscriptionRequest _rowToRequest(Row row) {
    return SubscriptionRequest(
      id: row['id'] as int,
      userId: row['user_id'] as int,
      userUsername: row['user_username'] as String?,
      status: SubscriptionRequestStatus.fromDbValue(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      activeFrom: row['active_from'] == null
          ? null
          : DateTime.parse(row['active_from'] as String).toLocal(),
      activeUntil: row['active_until'] == null
          ? null
          : DateTime.parse(row['active_until'] as String).toLocal(),
      paymentNote: row['payment_note'] as String?,
      paymentProofChatId: row['payment_proof_chat_id'] as int?,
      paymentProofMessageId: row['payment_proof_message_id'] as int?,
    );
  }

  String? _normalizeUsername(String? username) {
    final trimmed = username?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }
}
