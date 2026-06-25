import 'dart:io';

import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteOnboardingRepository implements OnboardingRepository {
  SqliteOnboardingRepository({
    required String dbPath,
  }) : _dbPath = dbPath;

  final String _dbPath;
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('SqliteOnboardingRepository is not initialized.');
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
      CREATE TABLE IF NOT EXISTS onboarding_users (
        user_id INTEGER PRIMARY KEY,
        first_joined_at TEXT NOT NULL,
        last_joined_at TEXT NOT NULL,
        group_chat_id INTEGER,
        welcome_message_id INTEGER,
        welcome_sent_at TEXT,
        welcome_deleted_at TEXT,
        started_at TEXT,
        starter_bonus_consumed_at TEXT,
        starter_bonus_reminder_sent_at TEXT,
        every_fifth_last_notified_rewards INTEGER NOT NULL DEFAULT 0
      );
    ''');
    _addColumnIfMissing(
      db,
      'ALTER TABLE onboarding_users ADD COLUMN starter_bonus_reminder_sent_at TEXT;',
    );
    _addColumnIfMissing(
      db,
      'ALTER TABLE onboarding_users ADD COLUMN every_fifth_last_notified_rewards INTEGER NOT NULL DEFAULT 0;',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_onboarding_welcome_cleanup '
      'ON onboarding_users(welcome_deleted_at, welcome_sent_at, started_at);',
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
  Future<void> registerGroupWelcome({
    required int userId,
    required int groupChatId,
    required int welcomeMessageId,
    required DateTime joinedAt,
  }) async {
    final db = _database;
    final joinedAtIso = joinedAt.toUtc().toIso8601String();
    db.execute(
      '''
      INSERT INTO onboarding_users (
        user_id,
        first_joined_at,
        last_joined_at,
        group_chat_id,
        welcome_message_id,
        welcome_sent_at,
        welcome_deleted_at,
        started_at
      ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL)
      ON CONFLICT(user_id) DO UPDATE SET
        last_joined_at = excluded.last_joined_at,
        group_chat_id = excluded.group_chat_id,
        welcome_message_id = excluded.welcome_message_id,
        welcome_sent_at = excluded.welcome_sent_at,
        welcome_deleted_at = NULL,
        started_at = NULL;
      ''',
      <Object?>[
        userId,
        joinedAtIso,
        joinedAtIso,
        groupChatId,
        welcomeMessageId,
        joinedAtIso,
      ],
    );
  }

  @override
  Future<PendingWelcomeMessage?> markStartedAndGetPendingWelcome(
    int userId, {
    required DateTime startedAt,
  }) async {
    final db = _database;
    final startedAtIso = startedAt.toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE onboarding_users
      SET started_at = ?
      WHERE user_id = ?;
      ''',
      <Object?>[startedAtIso, userId],
    );
    final row = _findOnboardingRow(userId);
    if (row == null) {
      return null;
    }
    final deletedAt = row['welcome_deleted_at'] as String?;
    if (deletedAt != null) {
      return null;
    }
    final chatId = row['group_chat_id'] as int?;
    final messageId = row['welcome_message_id'] as int?;
    if (chatId == null || messageId == null) {
      return null;
    }
    return PendingWelcomeMessage(
      userId: userId,
      groupChatId: chatId,
      welcomeMessageId: messageId,
    );
  }

  @override
  Future<List<PendingWelcomeMessage>> listWelcomeMessagesReadyForDelete({
    required DateTime now,
    Duration ttl = const Duration(minutes: 3),
    int limit = 100,
  }) async {
    final db = _database;
    final cutoffIso = now.toUtc().subtract(ttl).toIso8601String();
    final rows = db.select(
      '''
      SELECT user_id, group_chat_id, welcome_message_id
      FROM onboarding_users
      WHERE welcome_deleted_at IS NULL
        AND group_chat_id IS NOT NULL
        AND welcome_message_id IS NOT NULL
        AND (
          started_at IS NOT NULL OR welcome_sent_at <= ?
        )
      ORDER BY welcome_sent_at ASC
      LIMIT ?;
      ''',
      <Object?>[cutoffIso, limit],
    );
    return rows
        .map(
          (row) => PendingWelcomeMessage(
            userId: row['user_id'] as int,
            groupChatId: row['group_chat_id'] as int,
            welcomeMessageId: row['welcome_message_id'] as int,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markWelcomeDeleted({
    required int userId,
    required DateTime deletedAt,
  }) async {
    final db = _database;
    db.execute(
      '''
      UPDATE onboarding_users
      SET welcome_deleted_at = ?,
          group_chat_id = NULL,
          welcome_message_id = NULL
      WHERE user_id = ?;
      ''',
      <Object?>[deletedAt.toUtc().toIso8601String(), userId],
    );
  }

  @override
  Future<bool> hasStarterBonusAvailable(int userId) async {
    final row = _findOnboardingRow(userId);
    if (row == null) {
      return false;
    }
    final expiresAt = _starterBonusExpiresAtUtc(row);
    if (expiresAt == null) {
      return false;
    }
    if (DateTime.now().toUtc().isAfter(expiresAt)) {
      return false;
    }
    return row['starter_bonus_consumed_at'] == null;
  }

  @override
  Future<bool> consumeStarterBonus(
    int userId, {
    required DateTime consumedAt,
  }) async {
    final db = _database;
    final row = _findOnboardingRow(userId);
    final expiresAt = row == null ? null : _starterBonusExpiresAtUtc(row);
    if (row == null || expiresAt == null) {
      return false;
    }
    if (row['starter_bonus_consumed_at'] != null) {
      return false;
    }
    if (consumedAt.toUtc().isAfter(expiresAt)) {
      return false;
    }
    db.execute(
      '''
      UPDATE onboarding_users
      SET starter_bonus_consumed_at = ?
      WHERE user_id = ?
        AND starter_bonus_consumed_at IS NULL;
      ''',
      <Object?>[consumedAt.toUtc().toIso8601String(), userId],
    );
    return db.updatedRows > 0;
  }

  @override
  Future<void> rollbackStarterBonusConsumption(
    int userId, {
    required DateTime rollbackAt,
  }) async {
    final db = _database;
    db.execute(
      '''
      UPDATE onboarding_users
      SET starter_bonus_consumed_at = NULL
      WHERE user_id = ?;
      ''',
      <Object?>[userId],
    );
  }

  @override
  Future<List<StarterBonusReminderTarget>> listStarterBonusExpiringSoon({
    required DateTime now,
    Duration leadTime = const Duration(days: 1),
    int limit = 100,
  }) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT user_id, started_at, last_joined_at
      FROM onboarding_users
      WHERE started_at IS NOT NULL
        AND starter_bonus_consumed_at IS NULL
        AND starter_bonus_reminder_sent_at IS NULL
      ORDER BY started_at ASC
      LIMIT ?;
      ''',
      <Object?>[limit * 4],
    );
    final nowUtc = now.toUtc();
    final reminderStartsAt = nowUtc;
    final reminderEndsAt = nowUtc.add(leadTime);
    final targets = <StarterBonusReminderTarget>[];
    for (final row in rows) {
      final expiresAt = _starterBonusExpiresAtUtc(row);
      if (expiresAt == null) {
        continue;
      }
      if (expiresAt.isBefore(reminderStartsAt) || expiresAt.isAfter(reminderEndsAt)) {
        continue;
      }
      targets.add(
        StarterBonusReminderTarget(
          userId: row['user_id'] as int,
          expiresAt: expiresAt.toLocal(),
        ),
      );
      if (targets.length >= limit) {
        break;
      }
    }
    return targets;
  }

  @override
  Future<void> markStarterBonusReminderSent(
    int userId, {
    required DateTime sentAt,
  }) async {
    final db = _database;
    db.execute(
      '''
      UPDATE onboarding_users
      SET starter_bonus_reminder_sent_at = ?
      WHERE user_id = ?;
      ''',
      <Object?>[sentAt.toUtc().toIso8601String(), userId],
    );
  }

  @override
  Future<int> getEveryFifthLastNotifiedRewards(int userId) async {
    final row = _findOnboardingRow(userId);
    if (row == null) {
      return 0;
    }
    return (row['every_fifth_last_notified_rewards'] as int?) ?? 0;
  }

  @override
  Future<void> setEveryFifthLastNotifiedRewards(
    int userId, {
    required int rewardsCount,
    required DateTime updatedAt,
  }) async {
    final db = _database;
    final nowIso = updatedAt.toUtc().toIso8601String();
    _ensureUserRow(userId, nowIso: nowIso);
    db.execute(
      '''
      UPDATE onboarding_users
      SET every_fifth_last_notified_rewards = ?
      WHERE user_id = ?;
      ''',
      <Object?>[rewardsCount, userId],
    );
  }

  @override
  Future<void> registerReferralAttribution({
    required int inviteeUserId,
    required int inviterUserId,
    required DateTime attributedAt,
  }) async {
    if (inviteeUserId <= 0 || inviterUserId <= 0 || inviteeUserId == inviterUserId) {
      return;
    }
    final db = _database;
    db.execute(
      '''
      INSERT OR IGNORE INTO referral_attributions (
        invitee_user_id,
        inviter_user_id,
        attributed_at
      ) VALUES (?, ?, ?);
      ''',
      <Object?>[
        inviteeUserId,
        inviterUserId,
        attributedAt.toUtc().toIso8601String(),
      ],
    );
  }

  Row? _findOnboardingRow(int userId) {
    final db = _database;
    final rows = db.select(
      '''
      SELECT * FROM onboarding_users
      WHERE user_id = ?
      LIMIT 1;
      ''',
      <Object?>[userId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  bool _isStarterBonusEligible(Row row) {
    final startedAtRaw = row['started_at'] as String?;
    final joinedAtRaw = row['last_joined_at'] as String?;
    if (startedAtRaw == null || joinedAtRaw == null) {
      return false;
    }
    final startedAt = DateTime.parse(startedAtRaw).toUtc();
    final joinedAt = DateTime.parse(joinedAtRaw).toUtc();
    final eligibleUntil = joinedAt.add(const Duration(hours: 24));
    return !startedAt.isBefore(joinedAt) && !startedAt.isAfter(eligibleUntil);
  }

  DateTime? _starterBonusExpiresAtUtc(Row row) {
    if (!_isStarterBonusEligible(row)) {
      return null;
    }
    final startedAtRaw = row['started_at'] as String?;
    if (startedAtRaw == null) {
      return null;
    }
    final startedAt = DateTime.parse(startedAtRaw).toUtc();
    return startedAt.add(const Duration(days: 7));
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

  void _ensureUserRow(int userId, {required String nowIso}) {
    final db = _database;
    db.execute(
      '''
      INSERT INTO onboarding_users (
        user_id,
        first_joined_at,
        last_joined_at
      ) VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO NOTHING;
      ''',
      <Object?>[userId, nowIso, nowIso],
    );
  }
}
