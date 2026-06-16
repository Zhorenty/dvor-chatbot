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
        moderation_reason TEXT,
        moderation_comment TEXT,
        renewal_reminder_7_sent_at TEXT,
        renewal_reminder_3_sent_at TEXT,
        renewal_reminder_1_sent_at TEXT,
        expiry_promo_sent_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    _addColumnIfMissing(
      db,
      'ALTER TABLE subscription_requests ADD COLUMN moderation_reason TEXT;',
    );
    _addColumnIfMissing(
      db,
      'ALTER TABLE subscription_requests ADD COLUMN moderation_comment TEXT;',
    );
    _addColumnIfMissing(
      db,
      'ALTER TABLE subscription_requests ADD COLUMN renewal_reminder_7_sent_at TEXT;',
    );
    _addColumnIfMissing(
      db,
      'ALTER TABLE subscription_requests ADD COLUMN renewal_reminder_3_sent_at TEXT;',
    );
    _addColumnIfMissing(
      db,
      'ALTER TABLE subscription_requests ADD COLUMN renewal_reminder_1_sent_at TEXT;',
    );
    _addColumnIfMissing(
      db,
      'ALTER TABLE subscription_requests ADD COLUMN expiry_promo_sent_at TEXT;',
    );
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_requests_user
      ON subscription_requests(user_id);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_requests_status
      ON subscription_requests(status);
    ''');
    final dedupeTimestamp = DateTime.now().toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE subscription_requests
      SET status = ?,
          updated_at = ?
      WHERE status = ?
        AND id NOT IN (
          SELECT MAX(id)
          FROM subscription_requests
          WHERE status = ?
          GROUP BY user_id
        );
      ''',
      <Object?>[
        SubscriptionRequestStatus.rejected.dbValue,
        dedupeTimestamp,
        SubscriptionRequestStatus.paymentSubmitted.dbValue,
        SubscriptionRequestStatus.paymentSubmitted.dbValue,
      ],
    );
    db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_subscription_pending_unique_user
      ON subscription_requests(user_id)
      WHERE status = 'payment_submitted';
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
  Future<SubscriptionUserSnapshot> getUserSnapshot(
    int userId, {
    required DateTime now,
  }) async {
    final membership = await getMembership(userId, now: now);
    final db = _database;
    final counts = db.select(
      '''
      SELECT
        SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS approved_total
      FROM subscription_requests
      WHERE user_id = ?;
      ''',
      <Object?>[
        SubscriptionRequestStatus.active.dbValue,
        userId,
      ],
    );
    final latestPending = _findLatestByStatuses(
      userId,
      statuses: <SubscriptionRequestStatus>{SubscriptionRequestStatus.paymentSubmitted},
    );
    final latestRejectedOrCancelled = _findLatestByStatuses(
      userId,
      statuses: <SubscriptionRequestStatus>{
        SubscriptionRequestStatus.rejected,
        SubscriptionRequestStatus.cancelled,
      },
    );
    final latestActive = _findLatestByStatuses(
      userId,
      statuses: <SubscriptionRequestStatus>{SubscriptionRequestStatus.active},
    );
    return SubscriptionUserSnapshot(
      membership: membership,
      totalApprovedCount: (counts.first['approved_total'] as int?) ?? 0,
      latestPending: latestPending,
      latestRejectedOrCancelled: latestRejectedOrCancelled,
      latestActiveRequest: latestActive,
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
    db.execute('BEGIN IMMEDIATE TRANSACTION;');
    var shouldCommit = false;
    SubmitSubscriptionRequestResult? result;
    final normalizedUsername = _normalizeUsername(userUsername);
    try {
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
      result = SubmitSubscriptionRequestResult(
        outcome: SubmitSubscriptionRequestOutcome.created,
        request: inserted.isEmpty ? null : _rowToRequest(inserted.first),
      );
      shouldCommit = true;
    } on SqliteException catch (error) {
      if (!_isUniqueConstraintError(error)) {
        rethrow;
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
      result = SubmitSubscriptionRequestResult(
        outcome: SubmitSubscriptionRequestOutcome.alreadyPending,
        request: pendingRow.isEmpty ? null : _rowToRequest(pendingRow.first),
      );
      shouldCommit = true;
    } finally {
      db.execute(shouldCommit ? 'COMMIT;' : 'ROLLBACK;');
    }
    return result;
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
    return reviewPendingRequestWithReason(
      requestId: requestId,
      approve: approve,
      reviewedAt: reviewedAt,
    );
  }

  @override
  Future<ReviewSubscriptionRequestResult> reviewPendingRequestWithReason({
    required int requestId,
    required bool approve,
    required DateTime reviewedAt,
    String? reason,
    String? comment,
  }) async {
    final db = _database;
    db.execute('BEGIN IMMEDIATE TRANSACTION;');
    var shouldCommit = false;
    ReviewSubscriptionRequestResult? result;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE id = ?
      LIMIT 1;
      ''',
      <Object?>[requestId],
    );
    try {
      if (rows.isEmpty) {
        result = const ReviewSubscriptionRequestResult(
          outcome: ReviewSubscriptionRequestOutcome.notFound,
        );
        shouldCommit = true;
      } else {
        final current = _rowToRequest(rows.first);
        if (current.status != SubscriptionRequestStatus.paymentSubmitted) {
          result = const ReviewSubscriptionRequestResult(
            outcome: ReviewSubscriptionRequestOutcome.invalidStatus,
          );
          shouldCommit = true;
        } else {
          final now = reviewedAt.toUtc();
          if (approve) {
            final maxActiveUntilRows = db.select(
              '''
              SELECT MAX(active_until) AS max_active_until
              FROM subscription_requests
              WHERE user_id = ?
                AND status = ?
                AND active_until IS NOT NULL;
              ''',
              <Object?>[
                current.userId,
                SubscriptionRequestStatus.active.dbValue,
              ],
            );
            final maxActiveUntilRaw = maxActiveUntilRows.first['max_active_until'] as String?;
            final maxActiveUntil =
                maxActiveUntilRaw == null ? null : DateTime.parse(maxActiveUntilRaw);
            final baseUtc =
                (maxActiveUntil != null && maxActiveUntil.isAfter(now)) ? maxActiveUntil : now;
            final activeUntil = baseUtc.add(const Duration(days: 30));
            db.execute(
              '''
              UPDATE subscription_requests
              SET status = ?,
                  active_from = ?,
                  active_until = ?,
                  moderation_reason = ?,
                  moderation_comment = ?,
                  updated_at = ?
              WHERE id = ?
                AND status = ?;
              ''',
              <Object?>[
                SubscriptionRequestStatus.active.dbValue,
                now.toIso8601String(),
                activeUntil.toIso8601String(),
                reason?.trim().isEmpty == true ? null : reason?.trim(),
                comment?.trim().isEmpty == true ? null : comment?.trim(),
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
                  moderation_reason = ?,
                  moderation_comment = ?,
                  updated_at = ?
              WHERE id = ?
                AND status = ?;
              ''',
              <Object?>[
                SubscriptionRequestStatus.rejected.dbValue,
                reason?.trim().isEmpty == true ? null : reason?.trim(),
                comment?.trim().isEmpty == true ? null : comment?.trim(),
                now.toIso8601String(),
                requestId,
                SubscriptionRequestStatus.paymentSubmitted.dbValue,
              ],
            );
          }
          if (db.updatedRows == 0) {
            result = const ReviewSubscriptionRequestResult(
              outcome: ReviewSubscriptionRequestOutcome.invalidStatus,
            );
            shouldCommit = true;
          } else {
            final updatedRows = db.select(
              '''
              SELECT * FROM subscription_requests
              WHERE id = ?
              LIMIT 1;
              ''',
              <Object?>[requestId],
            );
            result = ReviewSubscriptionRequestResult(
              outcome: ReviewSubscriptionRequestOutcome.success,
              request: updatedRows.isEmpty ? null : _rowToRequest(updatedRows.first),
            );
            shouldCommit = true;
          }
        }
      }
    } finally {
      db.execute(shouldCommit ? 'COMMIT;' : 'ROLLBACK;');
    }
    return result;
  }

  @override
  Future<CancelSubscriptionResult> cancelActiveSubscription({
    required int requestId,
    required DateTime cancelledAt,
    String? reason,
    String? comment,
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
      return const CancelSubscriptionResult(
        outcome: CancelSubscriptionOutcome.notFound,
      );
    }
    final current = _rowToRequest(rows.first);
    if (current.status != SubscriptionRequestStatus.active) {
      return const CancelSubscriptionResult(
        outcome: CancelSubscriptionOutcome.invalidStatus,
      );
    }
    final now = cancelledAt.toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE subscription_requests
      SET status = ?,
          active_until = ?,
          moderation_reason = ?,
          moderation_comment = ?,
          updated_at = ?
      WHERE id = ?
        AND status = ?;
      ''',
      <Object?>[
        SubscriptionRequestStatus.cancelled.dbValue,
        cancelledAt.toUtc().toIso8601String(),
        reason?.trim().isEmpty == true ? 'admin_cancelled' : reason?.trim(),
        comment?.trim().isEmpty == true ? null : comment?.trim(),
        now,
        requestId,
        SubscriptionRequestStatus.active.dbValue,
      ],
    );
    if (db.updatedRows == 0) {
      return const CancelSubscriptionResult(
        outcome: CancelSubscriptionOutcome.invalidStatus,
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
    return CancelSubscriptionResult(
      outcome: CancelSubscriptionOutcome.success,
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

  @override
  Future<List<SubscriptionRequest>> listSubscriptionsByFilter({
    required SubscriptionListFilter filter,
    required DateTime now,
    int limit = 200,
  }) async {
    final db = _database;
    final nowIso = now.toUtc().toIso8601String();
    final (whereSql, args) = switch (filter) {
      SubscriptionListFilter.active => (
          'status = ? AND active_until IS NOT NULL AND active_until > ?',
          <Object?>[SubscriptionRequestStatus.active.dbValue, nowIso],
        ),
      SubscriptionListFilter.expiringSoon => (
          'status = ? AND active_until IS NOT NULL AND active_until > ? AND active_until <= ?',
          <Object?>[
            SubscriptionRequestStatus.active.dbValue,
            nowIso,
            now.toUtc().add(const Duration(days: 7)).toIso8601String(),
          ],
        ),
      SubscriptionListFilter.pending => (
          'status = ?',
          <Object?>[SubscriptionRequestStatus.paymentSubmitted.dbValue],
        ),
      SubscriptionListFilter.cancelledOrRejected => (
          'status IN (?, ?)',
          <Object?>[
            SubscriptionRequestStatus.cancelled.dbValue,
            SubscriptionRequestStatus.rejected.dbValue,
          ],
        ),
    };
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE $whereSql
      ORDER BY updated_at DESC, id DESC
      LIMIT ?;
      ''',
      <Object?>[...args, limit],
    );
    return rows.map(_rowToRequest).toList(growable: false);
  }

  @override
  Future<List<SubscriptionRequest>> searchSubscriptions(
    String query, {
    required DateTime now,
    int limit = 100,
  }) async {
    final _ = now;
    final db = _database;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <SubscriptionRequest>[];
    }
    final requestId = int.tryParse(normalized);
    final userId = int.tryParse(normalized);
    final username = normalized.startsWith('@') ? normalized.substring(1) : normalized;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE (id = ?)
         OR (user_id = ?)
         OR (user_username LIKE ? COLLATE NOCASE)
      ORDER BY updated_at DESC, id DESC
      LIMIT ?;
      ''',
      <Object?>[
        requestId ?? -1,
        userId ?? -1,
        '%$username%',
        limit,
      ],
    );
    return rows.map(_rowToRequest).toList(growable: false);
  }

  @override
  Future<List<RenewalReminderTarget>> listRenewalReminderTargets({
    required DateTime now,
    int limit = 100,
  }) async {
    final targets = <RenewalReminderTarget>[];
    final buckets = <(int, String?)>[
      (7, 'renewal_reminder_7_sent_at'),
      (3, 'renewal_reminder_3_sent_at'),
      (1, 'renewal_reminder_1_sent_at'),
    ];
    final db = _database;
    final nowIso = now.toUtc().toIso8601String();
    for (final (days, column) in buckets) {
      final untilIso = now.toUtc().add(Duration(days: days)).toIso8601String();
      final rows = db.select(
        '''
        SELECT * FROM subscription_requests
        WHERE status = ?
          AND active_until IS NOT NULL
          AND active_until > ?
          AND active_until <= ?
          AND $column IS NULL
        ORDER BY active_until ASC
        LIMIT ?;
        ''',
        <Object?>[
          SubscriptionRequestStatus.active.dbValue,
          nowIso,
          untilIso,
          limit,
        ],
      );
      for (final row in rows) {
        targets.add(
          RenewalReminderTarget(
            request: _rowToRequest(row),
            daysBefore: days,
          ),
        );
        if (targets.length >= limit) {
          return targets;
        }
      }
    }
    return targets;
  }

  @override
  Future<void> markRenewalReminderSent({
    required int requestId,
    required int daysBefore,
    required DateTime sentAt,
  }) async {
    final db = _database;
    final column = switch (daysBefore) {
      7 => 'renewal_reminder_7_sent_at',
      3 => 'renewal_reminder_3_sent_at',
      _ => 'renewal_reminder_1_sent_at',
    };
    db.execute(
      '''
      UPDATE subscription_requests
      SET $column = ?,
          updated_at = ?
      WHERE id = ?;
      ''',
      <Object?>[
        sentAt.toUtc().toIso8601String(),
        sentAt.toUtc().toIso8601String(),
        requestId,
      ],
    );
  }

  @override
  Future<List<SubscriptionRequest>> listExpiredWithoutPromo({
    required DateTime now,
    int limit = 100,
  }) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE status = ?
        AND active_until IS NOT NULL
        AND active_until <= ?
        AND expiry_promo_sent_at IS NULL
      ORDER BY active_until ASC
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

  @override
  Future<void> markExpiryPromoSent({
    required int requestId,
    required DateTime sentAt,
  }) async {
    final db = _database;
    db.execute(
      '''
      UPDATE subscription_requests
      SET expiry_promo_sent_at = ?,
          updated_at = ?
      WHERE id = ?;
      ''',
      <Object?>[
        sentAt.toUtc().toIso8601String(),
        sentAt.toUtc().toIso8601String(),
        requestId,
      ],
    );
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
      moderationReason: row['moderation_reason'] as String?,
      moderationComment: row['moderation_comment'] as String?,
      renewalReminder7SentAt: _nullableDateTime(row['renewal_reminder_7_sent_at']),
      renewalReminder3SentAt: _nullableDateTime(row['renewal_reminder_3_sent_at']),
      renewalReminder1SentAt: _nullableDateTime(row['renewal_reminder_1_sent_at']),
      expiryPromoSentAt: _nullableDateTime(row['expiry_promo_sent_at']),
    );
  }

  SubscriptionRequest? _findLatestByStatuses(
    int userId, {
    required Set<SubscriptionRequestStatus> statuses,
  }) {
    if (statuses.isEmpty) {
      return null;
    }
    final db = _database;
    final placeholders = List<String>.filled(statuses.length, '?').join(', ');
    final rows = db.select(
      '''
      SELECT * FROM subscription_requests
      WHERE user_id = ?
        AND status IN ($placeholders)
      ORDER BY updated_at DESC, id DESC
      LIMIT 1;
      ''',
      <Object?>[
        userId,
        ...statuses.map((status) => status.dbValue),
      ],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _rowToRequest(rows.first);
  }

  String? _normalizeUsername(String? username) {
    final trimmed = username?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  bool _isUniqueConstraintError(SqliteException error) {
    final message = error.message.toLowerCase();
    return message.contains('unique constraint failed');
  }

  DateTime? _nullableDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String).toLocal();
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
}
