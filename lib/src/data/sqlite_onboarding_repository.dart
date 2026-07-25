import 'dart:io';

import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';
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
    for (final sql in <String>[
      'ALTER TABLE onboarding_users ADD COLUMN onboarding_phase TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN onboarding_step TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN quiz_goal TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN quiz_experience TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN selected_track TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN activation_at TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN onboarding_started_at TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN onboarding_completed_at TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN last_nudge_at TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN snooze_until TEXT;',
      'ALTER TABLE onboarding_users ADD COLUMN entry_type TEXT;',
    ]) {
      _addColumnIfMissing(db, sql);
    }
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
    db.execute('''
      CREATE TABLE IF NOT EXISTS onboarding_nudge_log (
        user_id INTEGER NOT NULL,
        nudge_key TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        phase TEXT,
        step TEXT,
        PRIMARY KEY (user_id, nudge_key)
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS training_feedback_requests (
        booking_id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        session_key TEXT NOT NULL,
        training_title TEXT NOT NULL,
        sent_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS training_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id INTEGER NOT NULL UNIQUE,
        session_key TEXT NOT NULL,
        rating TEXT NOT NULL,
        comment TEXT,
        submitted_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    _backfillLegacyUsersOnce(db);
  }

  void _backfillLegacyUsersOnce(Database db) {
    final rows = db.select(
      "SELECT value FROM schema_meta WHERE key = 'onboarding_legacy_backfilled' LIMIT 1;",
    );
    if (rows.isNotEmpty) {
      return;
    }
    db.execute(
      '''
      UPDATE onboarding_users
      SET onboarding_phase = ?,
          entry_type = COALESCE(entry_type, ?)
      WHERE onboarding_phase IS NULL;
      ''',
      <Object?>[
        OnboardingPhase.legacySkipped.storageValue,
        OnboardingEntryType.legacy.storageValue,
      ],
    );
    db.execute(
      '''
      INSERT INTO schema_meta (key, value) VALUES (?, ?);
      ''',
      <Object?>['onboarding_legacy_backfilled', '1'],
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
    await ensureStartedUser(userId, startedAt: startedAt);
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
  Future<OnboardingUserState> ensureStartedUser(
    int userId, {
    required DateTime startedAt,
    OnboardingEntryType? entryType,
  }) async {
    final db = _database;
    final startedAtIso = startedAt.toUtc().toIso8601String();
    final existing = _findOnboardingRow(userId);
    if (existing == null) {
      final resolvedEntry = entryType ?? OnboardingEntryType.cold;
      db.execute(
        '''
        INSERT INTO onboarding_users (
          user_id,
          first_joined_at,
          last_joined_at,
          started_at,
          onboarding_phase,
          onboarding_step,
          onboarding_started_at,
          entry_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          userId,
          startedAtIso,
          startedAtIso,
          startedAtIso,
          OnboardingPhase.phase1Quiz.storageValue,
          OnboardingStep.welcome.storageValue,
          startedAtIso,
          resolvedEntry.storageValue,
        ],
      );
      return (await getOnboardingState(userId))!;
    }

    final phase = OnboardingPhaseX.tryParse(existing['onboarding_phase'] as String?);
    final existingStarted = existing['started_at'] as String?;
    if (existingStarted == null) {
      db.execute(
        '''
        UPDATE onboarding_users
        SET started_at = ?
        WHERE user_id = ?;
        ''',
        <Object?>[startedAtIso, userId],
      );
    }

    if (phase == null) {
      // New row created after legacy backfill (e.g. group welcome before /start).
      final hasJoin = existing['welcome_sent_at'] != null || existing['last_joined_at'] != null;
      final resolvedEntry =
          entryType ?? (hasJoin ? OnboardingEntryType.group : OnboardingEntryType.cold);
      db.execute(
        '''
        UPDATE onboarding_users
        SET onboarding_phase = ?,
            onboarding_step = COALESCE(onboarding_step, ?),
            onboarding_started_at = COALESCE(onboarding_started_at, ?),
            entry_type = COALESCE(entry_type, ?),
            started_at = COALESCE(started_at, ?)
        WHERE user_id = ?;
        ''',
        <Object?>[
          OnboardingPhase.phase1Quiz.storageValue,
          OnboardingStep.welcome.storageValue,
          startedAtIso,
          resolvedEntry.storageValue,
          startedAtIso,
          userId,
        ],
      );
    } else if (phase == OnboardingPhase.legacySkipped) {
      if (existingStarted == null) {
        db.execute(
          '''
          UPDATE onboarding_users
          SET started_at = ?
          WHERE user_id = ?;
          ''',
          <Object?>[startedAtIso, userId],
        );
      }
    } else if (existing['onboarding_started_at'] == null) {
      db.execute(
        '''
        UPDATE onboarding_users
        SET onboarding_started_at = ?,
            started_at = COALESCE(started_at, ?)
        WHERE user_id = ?;
        ''',
        <Object?>[startedAtIso, startedAtIso, userId],
      );
    }

    return (await getOnboardingState(userId))!;
  }

  @override
  Future<OnboardingUserState?> getOnboardingState(int userId) async {
    final row = _findOnboardingRow(userId);
    if (row == null) {
      return null;
    }
    return _mapState(row);
  }

  @override
  Future<void> updateOnboardingProgress({
    required int userId,
    OnboardingPhase? phase,
    OnboardingStep? step,
    OnboardingQuizGoal? quizGoal,
    OnboardingQuizExperience? quizExperience,
    OnboardingTrack? selectedTrack,
    OnboardingEntryType? entryType,
    DateTime? onboardingStartedAt,
    DateTime? snoozeUntil,
    bool clearSnooze = false,
  }) async {
    final db = _database;
    final sets = <String>[];
    final args = <Object?>[];
    if (phase != null) {
      sets.add('onboarding_phase = ?');
      args.add(phase.storageValue);
      if (phase == OnboardingPhase.completed) {
        sets.add('onboarding_completed_at = COALESCE(onboarding_completed_at, ?)');
        args.add(DateTime.now().toUtc().toIso8601String());
      }
    }
    if (step != null) {
      sets.add('onboarding_step = ?');
      args.add(step.storageValue);
    }
    if (quizGoal != null) {
      sets.add('quiz_goal = ?');
      args.add(quizGoal.storageValue);
    }
    if (quizExperience != null) {
      sets.add('quiz_experience = ?');
      args.add(quizExperience.storageValue);
    }
    if (selectedTrack != null) {
      sets.add('selected_track = ?');
      args.add(selectedTrack.storageValue);
    }
    if (entryType != null) {
      sets.add('entry_type = ?');
      args.add(entryType.storageValue);
    }
    if (onboardingStartedAt != null) {
      sets.add('onboarding_started_at = ?');
      args.add(onboardingStartedAt.toUtc().toIso8601String());
    }
    if (clearSnooze) {
      sets.add('snooze_until = NULL');
    } else if (snoozeUntil != null) {
      sets.add('snooze_until = ?');
      args.add(snoozeUntil.toUtc().toIso8601String());
    }
    if (sets.isEmpty) {
      return;
    }
    args.add(userId);
    db.execute(
      'UPDATE onboarding_users SET ${sets.join(', ')} WHERE user_id = ?;',
      args,
    );
  }

  @override
  Future<bool> tryMarkActivation(
    int userId, {
    required DateTime activatedAt,
  }) async {
    final db = _database;
    final state = await getOnboardingState(userId);
    if (state == null || state.isLegacy || state.activationAt != null) {
      return false;
    }
    final activatedAtIso = activatedAt.toUtc().toIso8601String();
    db.execute(
      '''
      UPDATE onboarding_users
      SET activation_at = ?,
          onboarding_phase = ?,
          onboarding_step = ?
      WHERE user_id = ?
        AND activation_at IS NULL
        AND onboarding_phase IS NOT NULL
        AND onboarding_phase != ?;
      ''',
      <Object?>[
        activatedAtIso,
        OnboardingPhase.phase3Integration.storageValue,
        OnboardingStep.ctaBook.storageValue,
        userId,
        OnboardingPhase.legacySkipped.storageValue,
      ],
    );
    return db.updatedRows > 0;
  }

  @override
  Future<bool> hasNudgeBeenSent({
    required int userId,
    required String nudgeKey,
  }) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT 1 FROM onboarding_nudge_log
      WHERE user_id = ? AND nudge_key = ?
      LIMIT 1;
      ''',
      <Object?>[userId, nudgeKey],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> recordNudgeSent({
    required int userId,
    required String nudgeKey,
    required DateTime sentAt,
    OnboardingPhase? phase,
    OnboardingStep? step,
  }) async {
    final db = _database;
    final sentAtIso = sentAt.toUtc().toIso8601String();
    db.execute(
      '''
      INSERT OR IGNORE INTO onboarding_nudge_log (
        user_id, nudge_key, sent_at, phase, step
      ) VALUES (?, ?, ?, ?, ?);
      ''',
      <Object?>[
        userId,
        nudgeKey,
        sentAtIso,
        phase?.storageValue,
        step?.storageValue,
      ],
    );
    db.execute(
      '''
      UPDATE onboarding_users
      SET last_nudge_at = ?
      WHERE user_id = ?;
      ''',
      <Object?>[sentAtIso, userId],
    );
  }

  @override
  Future<List<OnboardingNudgeCandidate>> listOnboardingNudgeCandidates({
    required DateTime now,
    int limit = 100,
  }) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT *
      FROM onboarding_users
      WHERE started_at IS NOT NULL
        AND onboarding_started_at IS NOT NULL
        AND onboarding_phase IS NOT NULL
        AND onboarding_phase NOT IN (?, ?, ?)
      ORDER BY onboarding_started_at ASC
      LIMIT ?;
      ''',
      <Object?>[
        OnboardingPhase.legacySkipped.storageValue,
        OnboardingPhase.completed.storageValue,
        OnboardingPhase.notStarted.storageValue,
        limit,
      ],
    );
    final nowUtc = now.toUtc();
    final result = <OnboardingNudgeCandidate>[];
    for (final row in rows) {
      final state = _mapState(row);
      final started = state.onboardingStartedAt;
      final phase = state.phase;
      if (started == null || phase == null) {
        continue;
      }
      if (state.snoozeUntil != null && state.snoozeUntil!.isAfter(nowUtc)) {
        continue;
      }
      result.add(
        OnboardingNudgeCandidate(
          userId: state.userId,
          phase: phase,
          step: state.step,
          onboardingStartedAt: started,
          quizGoal: state.quizGoal,
          selectedTrack: state.selectedTrack,
          activationAt: state.activationAt,
          lastNudgeAt: state.lastNudgeAt,
          snoozeUntil: state.snoozeUntil,
        ),
      );
    }
    return result;
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

  @override
  Future<List<int>> getAllStartedUserIds() async {
    final db = _database;
    final rows = db.select(
      'SELECT user_id FROM onboarding_users WHERE started_at IS NOT NULL;',
    );
    return rows.map((row) => row['user_id'] as int).toList();
  }

  @override
  Future<bool> hasTrainingFeedbackRequest(int bookingId) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT 1 FROM training_feedback_requests
      WHERE booking_id = ?
      LIMIT 1;
      ''',
      <Object?>[bookingId],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> recordTrainingFeedbackRequest({
    required int bookingId,
    required int userId,
    required String sessionKey,
    required String trainingTitle,
    required DateTime sentAt,
  }) async {
    final db = _database;
    db.execute(
      '''
      INSERT OR IGNORE INTO training_feedback_requests (
        booking_id, user_id, session_key, training_title, sent_at
      ) VALUES (?, ?, ?, ?, ?);
      ''',
      <Object?>[
        bookingId,
        userId,
        sessionKey,
        trainingTitle,
        sentAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> submitTrainingFeedback({
    required int bookingId,
    required String sessionKey,
    required TrainingFeedbackRating rating,
    required DateTime submittedAt,
    String? comment,
  }) async {
    final db = _database;
    db.execute(
      '''
      INSERT INTO training_feedback (
        booking_id, session_key, rating, comment, submitted_at
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(booking_id) DO UPDATE SET
        rating = excluded.rating,
        comment = excluded.comment,
        submitted_at = excluded.submitted_at;
      ''',
      <Object?>[
        bookingId,
        sessionKey,
        rating.storageValue,
        comment,
        submittedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<TrainingFeedbackRequest?> getTrainingFeedbackRequest(int bookingId) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT booking_id, user_id, session_key, training_title, sent_at
      FROM training_feedback_requests
      WHERE booking_id = ?
      LIMIT 1;
      ''',
      <Object?>[bookingId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return TrainingFeedbackRequest(
      bookingId: row['booking_id'] as int,
      userId: row['user_id'] as int,
      sessionKey: row['session_key'] as String,
      trainingTitle: row['training_title'] as String,
      sentAt: DateTime.parse(row['sent_at'] as String).toUtc(),
    );
  }

  @override
  Future<bool> hasTrainingFeedback(int bookingId) async {
    final db = _database;
    final rows = db.select(
      '''
      SELECT 1 FROM training_feedback
      WHERE booking_id = ?
      LIMIT 1;
      ''',
      <Object?>[bookingId],
    );
    return rows.isNotEmpty;
  }

  OnboardingUserState _mapState(Row row) {
    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) {
        return null;
      }
      return DateTime.parse(raw).toUtc();
    }

    return OnboardingUserState(
      userId: row['user_id'] as int,
      phase: OnboardingPhaseX.tryParse(row['onboarding_phase'] as String?),
      step: OnboardingStepX.tryParse(row['onboarding_step'] as String?),
      quizGoal: OnboardingQuizGoalX.tryParse(row['quiz_goal'] as String?),
      quizExperience: OnboardingQuizExperienceX.tryParse(row['quiz_experience'] as String?),
      selectedTrack: OnboardingTrackX.tryParse(row['selected_track'] as String?),
      activationAt: parseDate(row['activation_at']),
      onboardingStartedAt: parseDate(row['onboarding_started_at']),
      onboardingCompletedAt: parseDate(row['onboarding_completed_at']),
      lastNudgeAt: parseDate(row['last_nudge_at']),
      snoozeUntil: parseDate(row['snooze_until']),
      entryType: OnboardingEntryTypeX.tryParse(row['entry_type'] as String?),
      startedAt: parseDate(row['started_at']),
      lastJoinedAt: parseDate(row['last_joined_at']),
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
    // Cold starts use the same timestamp for join placeholders — not eligible.
    if (startedAt.isAtSameMomentAs(joinedAt) && row['welcome_sent_at'] == null) {
      final entry = OnboardingEntryTypeX.tryParse(row['entry_type'] as String?);
      if (entry == OnboardingEntryType.cold) {
        return false;
      }
    }
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
        last_joined_at,
        onboarding_phase,
        entry_type
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id) DO NOTHING;
      ''',
      <Object?>[
        userId,
        nowIso,
        nowIso,
        OnboardingPhase.legacySkipped.storageValue,
        OnboardingEntryType.legacy.storageValue,
      ],
    );
  }
}
