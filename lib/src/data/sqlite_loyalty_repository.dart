import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_rules.dart';
import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/loyalty_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteLoyaltyRepository implements LoyaltyRepository {
  SqliteLoyaltyRepository({
    required SqliteDatabaseHandle databaseHandle,
    DateTime Function()? nowProvider,
  })  : _handle = databaseHandle,
        _nowProvider = nowProvider ?? DateTime.now;

  static const String _metaMigrationKey = 'migration_v1';
  static const String _metaMigrationV2Key = 'migration_v2';

  final SqliteDatabaseHandle _handle;
  final DateTime Function() _nowProvider;

  Database get _db => _handle.database;

  @override
  Future<void> init() async {
    final db = _db;
    db.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_accounts (
        user_id INTEGER PRIMARY KEY,
        remaining INTEGER NOT NULL DEFAULT 0 CHECK (remaining >= 0),
        last_loyalty_activity_at TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        reason TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        booking_id INTEGER,
        subscription_request_id INTEGER,
        invitee_user_id INTEGER
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_ledger_user '
      'ON loyalty_ledger(user_id, created_at DESC);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_ledger_booking '
      'ON loyalty_ledger(booking_id);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_accounts_activity '
      'ON loyalty_accounts(last_loyalty_activity_at);',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await migrateIfNeeded(now: _nowProvider());
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> migrateIfNeeded({required DateTime now}) async {
    final at = now.toUtc();
    await _runVersionedMigration(
      metaKey: _metaMigrationKey,
      nowUtc: at,
      body: _runMigrationV1,
    );
    await _runVersionedMigration(
      metaKey: _metaMigrationV2Key,
      nowUtc: at,
      body: _runMigrationV2,
    );
  }

  Future<void> _runVersionedMigration({
    required String metaKey,
    required DateTime nowUtc,
    required void Function(Database db, DateTime nowUtc) body,
  }) async {
    final db = _db;
    final existing = db.select(
      'SELECT value FROM loyalty_meta WHERE key = ? LIMIT 1;',
      <Object?>[metaKey],
    );
    if (existing.isNotEmpty) {
      return;
    }
    db.execute('BEGIN IMMEDIATE;');
    var shouldCommit = false;
    try {
      body(db, nowUtc);
      db.execute(
        'INSERT INTO loyalty_meta (key, value) VALUES (?, ?);',
        <Object?>[metaKey, nowUtc.toIso8601String()],
      );
      shouldCommit = true;
    } finally {
      db.execute(shouldCommit ? 'COMMIT;' : 'ROLLBACK;');
    }
  }

  void _runMigrationV1(Database db, DateTime nowUtc) {
    final nowIso = nowUtc.toIso8601String();
    Set<int> startedIds = <int>{};
    try {
      startedIds = db
          .select(
            'SELECT user_id FROM onboarding_users WHERE started_at IS NOT NULL;',
          )
          .map((row) => row['user_id'] as int)
          .toSet();
    } on SqliteException {
      startedIds = <int>{};
    }
    for (final userId in startedIds) {
      _insertCreditUnlocked(
        db,
        userId: userId,
        amount: LoyaltyMath.startBonusPeaks,
        reason: LoyaltyLedgerReason.start,
        key: LoyaltyKeys.start(userId),
        nowIso: nowIso,
      );
    }

    final trainingsSql = "(training_key LIKE 'trainings|%' OR "
        "(training_key NOT LIKE 'hikes|%' "
        "AND training_key NOT LIKE 'trails|%' "
        "AND training_title NOT LIKE '🥾 Поход:%' AND training_title NOT LIKE '🏃 Трейл:%'))";
    final excludedNotes = LoyaltyRules.excludedTrainingPaymentNotes
        .where((note) => note != MessageFormatters.loyaltyPeaksPaymentNoteMarker)
        .toList(growable: false);
    final excludedPlaceholders = List<String>.filled(excludedNotes.length, '?').join(', ');
    ResultSet qualifiedRows;
    try {
      qualifiedRows = db.select(
        '''
        SELECT *
        FROM bookings
        WHERE COALESCE(participant_type, 'self') = 'self'
          AND status = ?
          AND starts_at < ?
          AND ($trainingsSql)
          AND (training_price IS NULL OR training_price > 0)
          AND (payment_note IS NULL OR payment_note NOT IN ($excludedPlaceholders));
        ''',
        <Object?>[
          BookingStatus.paid.dbValue,
          nowIso,
          ...excludedNotes,
        ],
      );
    } on SqliteException {
      return;
    }
    for (final row in qualifiedRows) {
      final userId = row['user_id'] as int;
      final username = row['user_username'] as String?;
      if (isTrainerBookingWhitelisted(userId: userId, username: username)) {
        continue;
      }
      final bookingId = row['id'] as int;
      final price = row['training_price'] as int?;
      final amount = price == null || price <= 0
          ? LoyaltyMath.missingTrainingPriceEarnPeaks
          : LoyaltyMath.trainingEarnPeaks(price);
      _insertCreditUnlocked(
        db,
        userId: userId,
        amount: amount,
        reason: LoyaltyLedgerReason.training,
        key: LoyaltyKeys.training(bookingId),
        nowIso: nowIso,
        bookingId: bookingId,
      );
    }

    final usedFifthRows = db.select(
      '''
      SELECT *
      FROM bookings
      WHERE COALESCE(participant_type, 'self') = 'self'
        AND status = ?
        AND starts_at < ?
        AND ($trainingsSql)
        AND payment_note = ?;
      ''',
      <Object?>[
        BookingStatus.paid.dbValue,
        nowIso,
        MessageFormatters.everyFifthBonusPaymentNoteMarker,
      ],
    );
    for (final row in usedFifthRows) {
      final userId = row['user_id'] as int;
      final bookingId = row['id'] as int;
      final price = row['training_price'] as int?;
      final wanted = price == null || price <= 0
          ? LoyaltyMath.missingEveryFifthDebitPeaks
          : price * LoyaltyMath.peaksPerRub;
      final remaining = _remainingUnlocked(db, userId);
      final amount = remaining < wanted ? remaining : wanted;
      if (amount <= 0) {
        continue;
      }
      _insertDebitUnlocked(
        db,
        userId: userId,
        amount: amount,
        reason: LoyaltyLedgerReason.migration,
        key: LoyaltyKeys.migrationEveryFifth(bookingId),
        nowIso: nowIso,
        bookingId: bookingId,
      );
    }

    ResultSet attributions;
    try {
      attributions = db.select(
        '''
        SELECT invitee_user_id, inviter_user_id
        FROM referral_attributions
        ORDER BY attributed_at ASC, invitee_user_id ASC;
        ''',
      );
    } on SqliteException {
      attributions = db.select('SELECT 1 AS invitee_user_id WHERE 0;');
    }
    for (final row in attributions) {
      final inviteeId = row['invitee_user_id'] as int;
      final inviterId = row['inviter_user_id'] as int;
      final qualified = db.select(
        '''
        SELECT 1
        FROM bookings
        WHERE user_id = ?
          AND COALESCE(participant_type, 'self') = 'self'
          AND status = ?
          AND starts_at < ?
          AND training_price > 0
          AND ($trainingsSql)
          AND (payment_note IS NULL OR payment_note NOT IN ($excludedPlaceholders))
        LIMIT 1;
        ''',
        <Object?>[
          inviteeId,
          BookingStatus.paid.dbValue,
          nowIso,
          ...excludedNotes,
        ],
      );
      if (qualified.isEmpty) {
        continue;
      }
      _insertCreditUnlocked(
        db,
        userId: inviterId,
        amount: LoyaltyMath.referralPeaks,
        reason: LoyaltyLedgerReason.referral,
        key: LoyaltyKeys.referral(inviteeId),
        nowIso: nowIso,
        inviteeUserId: inviteeId,
      );
    }

    final usedReferralRows = db.select(
      '''
      SELECT id, user_id
      FROM bookings
      WHERE status = ?
        AND payment_note = ?;
      ''',
      <Object?>[
        BookingStatus.paid.dbValue,
        MessageFormatters.referralBonusPaymentNoteMarker,
      ],
    );
    for (final row in usedReferralRows) {
      final userId = row['user_id'] as int;
      final bookingId = row['id'] as int;
      final remaining = _remainingUnlocked(db, userId);
      final amount = remaining < LoyaltyMath.referralPeaks ? remaining : LoyaltyMath.referralPeaks;
      if (amount <= 0) {
        continue;
      }
      _insertDebitUnlocked(
        db,
        userId: userId,
        amount: amount,
        reason: LoyaltyLedgerReason.migration,
        key: 'migration:$bookingId+referral_used',
        nowIso: nowIso,
        bookingId: bookingId,
      );
    }

    db.execute(
      '''
      UPDATE loyalty_accounts
      SET last_loyalty_activity_at = ?
      WHERE user_id IN (SELECT DISTINCT user_id FROM loyalty_ledger);
      ''',
      <Object?>[nowIso],
    );
  }

  void _runMigrationV2(Database db, DateTime nowUtc) {
    final nowIso = nowUtc.toIso8601String();
    _convertUnusedEveryFifth(db, nowUtc: nowUtc, nowIso: nowIso);
    _convertUnusedStarterBonus(db, nowUtc: nowUtc, nowIso: nowIso);
    db.execute(
      '''
      UPDATE loyalty_accounts
      SET last_loyalty_activity_at = ?
      WHERE user_id IN (SELECT DISTINCT user_id FROM loyalty_ledger);
      ''',
      <Object?>[nowIso],
    );
  }

  void _convertUnusedEveryFifth(
    Database db, {
    required DateTime nowUtc,
    required String nowIso,
  }) {
    final trainingsSql = _trainingsCategorySql;
    final excludedNotes = _excludedTrainingNotesForMigration;
    final excludedPlaceholders = List<String>.filled(excludedNotes.length, '?').join(', ');
    ResultSet qualifiedRows;
    ResultSet usedRows;
    try {
      qualifiedRows = db.select(
        '''
        SELECT user_id, user_username, COUNT(*) AS total
        FROM bookings
        WHERE COALESCE(participant_type, 'self') = 'self'
          AND status = ?
          AND starts_at < ?
          AND ($trainingsSql)
          AND (training_price IS NULL OR training_price > 0)
          AND (payment_note IS NULL OR payment_note NOT IN ($excludedPlaceholders))
        GROUP BY user_id;
        ''',
        <Object?>[
          BookingStatus.paid.dbValue,
          nowIso,
          ...excludedNotes,
        ],
      );
      usedRows = db.select(
        '''
        SELECT user_id, COUNT(*) AS total
        FROM bookings
        WHERE COALESCE(participant_type, 'self') = 'self'
          AND status = ?
          AND starts_at < ?
          AND ($trainingsSql)
          AND payment_note = ?
        GROUP BY user_id;
        ''',
        <Object?>[
          BookingStatus.paid.dbValue,
          nowIso,
          MessageFormatters.everyFifthBonusPaymentNoteMarker,
        ],
      );
    } on SqliteException {
      return;
    }
    final usedByUser = <int, int>{};
    for (final row in usedRows) {
      usedByUser[row['user_id'] as int] = (row['total'] as int?) ?? 0;
    }
    for (final row in qualifiedRows) {
      final userId = row['user_id'] as int;
      final username = row['user_username'] as String?;
      if (isTrainerBookingWhitelisted(userId: userId, username: username)) {
        continue;
      }
      final qualified = (row['total'] as int?) ?? 0;
      final unused = LoyaltyMath.unusedEveryFifthRewards(
        qualifiedTrainingsCount: qualified,
        usedRewardsCount: usedByUser[userId] ?? 0,
      );
      final amount = LoyaltyMath.unusedEveryFifthPeaks(unused);
      if (amount <= 0) {
        continue;
      }
      _insertCreditUnlocked(
        db,
        userId: userId,
        amount: amount,
        reason: LoyaltyLedgerReason.migration,
        key: LoyaltyKeys.migrationEveryFifthUnused(userId),
        nowIso: nowIso,
      );
    }
  }

  void _convertUnusedStarterBonus(
    Database db, {
    required DateTime nowUtc,
    required String nowIso,
  }) {
    ResultSet rows;
    try {
      rows = db.select(
        '''
        SELECT user_id, started_at, last_joined_at, welcome_sent_at, entry_type
        FROM onboarding_users
        WHERE started_at IS NOT NULL
          AND starter_bonus_consumed_at IS NULL;
        ''',
      );
    } on SqliteException {
      return;
    }
    for (final row in rows) {
      if (!_starterBonusAvailableAt(row, nowUtc: nowUtc)) {
        continue;
      }
      final userId = row['user_id'] as int;
      _insertCreditUnlocked(
        db,
        userId: userId,
        amount: LoyaltyMath.starterConversionPeaks,
        reason: LoyaltyLedgerReason.migration,
        key: LoyaltyKeys.migrationStarter(userId),
        nowIso: nowIso,
      );
      db.execute(
        '''
        UPDATE onboarding_users
        SET starter_bonus_consumed_at = ?
        WHERE user_id = ?
          AND starter_bonus_consumed_at IS NULL;
        ''',
        <Object?>[nowIso, userId],
      );
    }
  }

  bool _starterBonusAvailableAt(Row row, {required DateTime nowUtc}) {
    final startedAtRaw = row['started_at'] as String?;
    final joinedAtRaw = row['last_joined_at'] as String?;
    if (startedAtRaw == null || joinedAtRaw == null) {
      return false;
    }
    final startedAt = DateTime.parse(startedAtRaw).toUtc();
    final joinedAt = DateTime.parse(joinedAtRaw).toUtc();
    if (startedAt.isAtSameMomentAs(joinedAt) && row['welcome_sent_at'] == null) {
      final entry = OnboardingEntryTypeX.tryParse(row['entry_type'] as String?);
      if (entry == OnboardingEntryType.cold) {
        return false;
      }
    }
    final eligibleUntil = joinedAt.add(const Duration(hours: 24));
    if (startedAt.isBefore(joinedAt) || startedAt.isAfter(eligibleUntil)) {
      return false;
    }
    final expiresAt = startedAt.add(const Duration(days: 7));
    return !nowUtc.isAfter(expiresAt);
  }

  String get _trainingsCategorySql => "(training_key LIKE 'trainings|%' OR "
      "(training_key NOT LIKE 'hikes|%' "
      "AND training_key NOT LIKE 'trails|%' "
      "AND training_title NOT LIKE '🥾 Поход:%' AND training_title NOT LIKE '🏃 Трейл:%'))";

  List<String> get _excludedTrainingNotesForMigration => LoyaltyRules.excludedTrainingPaymentNotes
      .where((note) => note != MessageFormatters.loyaltyPeaksPaymentNoteMarker)
      .toList(growable: false);

  int _remainingUnlocked(Database db, int userId) {
    final rows = db.select(
      'SELECT remaining FROM loyalty_accounts WHERE user_id = ? LIMIT 1;',
      <Object?>[userId],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return (rows.first['remaining'] as int?) ?? 0;
  }

  void _insertCreditUnlocked(
    Database db, {
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String key,
    required String nowIso,
    int? bookingId,
    int? inviteeUserId,
  }) {
    if (amount <= 0) {
      return;
    }
    final existing = db.select(
      'SELECT 1 FROM loyalty_ledger WHERE idempotency_key = ? LIMIT 1;',
      <Object?>[key],
    );
    if (existing.isNotEmpty) {
      return;
    }
    db.execute(
      '''
      INSERT INTO loyalty_ledger (
        user_id, amount, reason, idempotency_key, created_at,
        booking_id, invitee_user_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?);
      ''',
      <Object?>[userId, amount, reason.dbValue, key, nowIso, bookingId, inviteeUserId],
    );
    db.execute(
      '''
      INSERT INTO loyalty_accounts (user_id, remaining, last_loyalty_activity_at)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        remaining = remaining + excluded.remaining,
        last_loyalty_activity_at = excluded.last_loyalty_activity_at;
      ''',
      <Object?>[userId, amount, nowIso],
    );
  }

  void _insertDebitUnlocked(
    Database db, {
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String key,
    required String nowIso,
    int? bookingId,
  }) {
    if (amount <= 0) {
      return;
    }
    final existing = db.select(
      'SELECT 1 FROM loyalty_ledger WHERE idempotency_key = ? LIMIT 1;',
      <Object?>[key],
    );
    if (existing.isNotEmpty) {
      return;
    }
    db.execute(
      '''
      INSERT INTO loyalty_ledger (
        user_id, amount, reason, idempotency_key, created_at, booking_id
      ) VALUES (?, ?, ?, ?, ?, ?);
      ''',
      <Object?>[userId, -amount, reason.dbValue, key, nowIso, bookingId],
    );
    db.execute(
      '''
      UPDATE loyalty_accounts
      SET remaining = remaining - ?,
          last_loyalty_activity_at = ?
      WHERE user_id = ?;
      ''',
      <Object?>[amount, nowIso, userId],
    );
  }

  @override
  Future<LoyaltyAccount> getAccount(int userId) async {
    final rows = _db.select(
      'SELECT * FROM loyalty_accounts WHERE user_id = ? LIMIT 1;',
      <Object?>[userId],
    );
    if (rows.isEmpty) {
      return LoyaltyAccount(userId: userId, remaining: 0);
    }
    return _rowToAccount(rows.first);
  }

  @override
  Future<List<LoyaltyAccount>> listExpired({
    required DateTime now,
    int limit = 200,
  }) async {
    final cutoffIso = now.toUtc().subtract(LoyaltyMath.lifetime).toIso8601String();
    final rows = _db.select(
      '''
      SELECT * FROM loyalty_accounts
      WHERE remaining > 0
        AND last_loyalty_activity_at IS NOT NULL
        AND last_loyalty_activity_at <= ?
      ORDER BY last_loyalty_activity_at ASC
      LIMIT ?;
      ''',
      <Object?>[cutoffIso, limit],
    );
    return rows.map(_rowToAccount).toList(growable: false);
  }

  @override
  Future<List<LoyaltyAccount>> listExpiringSoon({
    required DateTime now,
    required Duration leadTime,
    required Duration lifetime,
    int limit = 200,
  }) async {
    final expiredCutoffIso = now.toUtc().subtract(lifetime).toIso8601String();
    final enteredWindowIso = now.toUtc().subtract(lifetime - leadTime).toIso8601String();
    final rows = _db.select(
      '''
      SELECT * FROM loyalty_accounts
      WHERE remaining > 0
        AND last_loyalty_activity_at IS NOT NULL
        AND last_loyalty_activity_at <= ?
        AND last_loyalty_activity_at > ?
      ORDER BY last_loyalty_activity_at ASC
      LIMIT ?;
      ''',
      <Object?>[enteredWindowIso, expiredCutoffIso, limit],
    );
    return rows.map(_rowToAccount).toList(growable: false);
  }

  @override
  Future<List<LoyaltyLedgerEntry>> listRecentLedger(
    int userId, {
    int limit = 4,
  }) async {
    final rows = _db.select(
      '''
      SELECT * FROM loyalty_ledger
      WHERE user_id = ?
      ORDER BY created_at DESC, id DESC
      LIMIT ?;
      ''',
      <Object?>[userId, limit],
    );
    return rows.map(_rowToLedger).toList(growable: false);
  }

  @override
  Future<LoyaltyLedgerEntry?> findByIdempotencyKey(String key) async {
    final rows = _db.select(
      'SELECT * FROM loyalty_ledger WHERE idempotency_key = ? LIMIT 1;',
      <Object?>[key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _rowToLedger(rows.first);
  }

  @override
  Future<int> peaksSpentOnBooking(int bookingId) async {
    return _netSpend(
      '''
      SELECT COALESCE(SUM(CASE
        WHEN reason = 'spend' THEN -amount
        WHEN reason = 'refund' THEN -amount
        ELSE 0
      END), 0) AS total
      FROM loyalty_ledger
      WHERE booking_id = ?;
      ''',
      <Object?>[bookingId],
    );
  }

  @override
  Future<int> peaksSpentOnSubscription(int requestId) async {
    return _netSpend(
      '''
      SELECT COALESCE(SUM(CASE
        WHEN reason = 'spend' THEN -amount
        WHEN reason = 'refund' THEN -amount
        ELSE 0
      END), 0) AS total
      FROM loyalty_ledger
      WHERE subscription_request_id = ?;
      ''',
      <Object?>[requestId],
    );
  }

  @override
  Future<int> peaksSpentOnPendingCard(int userId) async {
    final spend = await findByIdempotencyKey(LoyaltyKeys.pendingCardSpend(userId));
    if (spend == null) {
      return 0;
    }
    final refund = await findByIdempotencyKey(LoyaltyKeys.pendingCardRefund(userId));
    final amount = -spend.amount - (refund?.amount ?? 0);
    return amount < 0 ? 0 : amount;
  }

  int _netSpend(String sql, List<Object?> args) {
    final rows = _db.select(sql, args);
    if (rows.isEmpty) {
      return 0;
    }
    final total = (rows.first['total'] as int?) ?? 0;
    return total < 0 ? 0 : total;
  }

  @override
  Future<LoyaltyMutationResult> credit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
    int? inviteeUserId,
  }) async {
    if (amount <= 0) {
      return LoyaltyMutationResult(
        applied: false,
        account: await getAccount(userId),
        amount: 0,
      );
    }
    return _mutate(
      userId: userId,
      signedAmount: amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      now: now,
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
      inviteeUserId: inviteeUserId,
    );
  }

  @override
  Future<LoyaltyMutationResult> debit({
    required int userId,
    required int amount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
  }) async {
    if (amount <= 0) {
      return LoyaltyMutationResult(
        applied: false,
        account: await getAccount(userId),
        amount: 0,
      );
    }
    return _mutate(
      userId: userId,
      signedAmount: -amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      now: now,
      bookingId: bookingId,
      subscriptionRequestId: subscriptionRequestId,
    );
  }

  Future<LoyaltyMutationResult> _mutate({
    required int userId,
    required int signedAmount,
    required LoyaltyLedgerReason reason,
    required String idempotencyKey,
    required DateTime now,
    int? bookingId,
    int? subscriptionRequestId,
    int? inviteeUserId,
  }) async {
    final db = _db;
    final nowIso = now.toUtc().toIso8601String();
    db.execute('BEGIN IMMEDIATE;');
    var shouldCommit = false;
    try {
      final existing = db.select(
        'SELECT * FROM loyalty_ledger WHERE idempotency_key = ? LIMIT 1;',
        <Object?>[idempotencyKey],
      );
      if (existing.isNotEmpty) {
        shouldCommit = true;
        final account = _accountUnlocked(db, userId);
        return LoyaltyMutationResult(
          applied: false,
          account: account,
          amount: 0,
          entry: _rowToLedger(existing.first),
        );
      }
      final current = _accountUnlocked(db, userId);
      final nextRemaining = current.remaining + signedAmount;
      if (nextRemaining < 0) {
        shouldCommit = true;
        return LoyaltyMutationResult(
          applied: false,
          account: current,
          amount: 0,
        );
      }
      db.execute(
        '''
        INSERT INTO loyalty_ledger (
          user_id, amount, reason, idempotency_key, created_at,
          booking_id, subscription_request_id, invitee_user_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          userId,
          signedAmount,
          reason.dbValue,
          idempotencyKey,
          nowIso,
          bookingId,
          subscriptionRequestId,
          inviteeUserId,
        ],
      );
      final entryId = db.lastInsertRowId;
      db.execute(
        '''
        INSERT INTO loyalty_accounts (user_id, remaining, last_loyalty_activity_at)
        VALUES (?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
          remaining = excluded.remaining,
          last_loyalty_activity_at = excluded.last_loyalty_activity_at;
        ''',
        <Object?>[userId, nextRemaining, nowIso],
      );
      shouldCommit = true;
      final entry = LoyaltyLedgerEntry(
        id: entryId,
        userId: userId,
        amount: signedAmount,
        reason: reason,
        idempotencyKey: idempotencyKey,
        createdAt: now.toUtc(),
        bookingId: bookingId,
        subscriptionRequestId: subscriptionRequestId,
        inviteeUserId: inviteeUserId,
      );
      return LoyaltyMutationResult(
        applied: true,
        account: LoyaltyAccount(
          userId: userId,
          remaining: nextRemaining,
          lastLoyaltyActivityAt: now.toUtc(),
        ),
        amount: signedAmount.abs(),
        entry: entry,
      );
    } finally {
      db.execute(shouldCommit ? 'COMMIT;' : 'ROLLBACK;');
    }
  }

  LoyaltyAccount _accountUnlocked(Database db, int userId) {
    final rows = db.select(
      'SELECT * FROM loyalty_accounts WHERE user_id = ? LIMIT 1;',
      <Object?>[userId],
    );
    if (rows.isEmpty) {
      return LoyaltyAccount(userId: userId, remaining: 0);
    }
    return _rowToAccount(rows.first);
  }

  @override
  Future<void> touchActivity({
    required int userId,
    required DateTime now,
  }) async {
    final nowIso = now.toUtc().toIso8601String();
    _db.execute(
      '''
      INSERT INTO loyalty_accounts (user_id, remaining, last_loyalty_activity_at)
      VALUES (?, 0, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        last_loyalty_activity_at = excluded.last_loyalty_activity_at;
      ''',
      <Object?>[userId, nowIso],
    );
  }

  @override
  Future<LoyaltyPeaksAnalytics> getPeaksAnalytics() async {
    int sum(String sql) {
      final rows = _db.select(sql);
      if (rows.isEmpty) {
        return 0;
      }
      return (rows.first['total'] as int?) ?? 0;
    }

    final earned = sum(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM loyalty_ledger
      WHERE amount > 0 AND reason NOT IN ('refund');
      ''',
    );
    final spent = sum(
      '''
      SELECT COALESCE(SUM(-amount), 0) AS total
      FROM loyalty_ledger
      WHERE reason IN ('spend', 'admin_debit');
      ''',
    );
    final expired = sum(
      '''
      SELECT COALESCE(SUM(-amount), 0) AS total
      FROM loyalty_ledger
      WHERE reason = 'expire';
      ''',
    );
    final remaining = sum(
      'SELECT COALESCE(SUM(remaining), 0) AS total FROM loyalty_accounts;',
    );
    return LoyaltyPeaksAnalytics(
      earnedTotal: earned,
      spentTotal: spent,
      expiredTotal: expired,
      remainingTotal: remaining,
    );
  }

  LoyaltyAccount _rowToAccount(Row row) {
    final lastRaw = row['last_loyalty_activity_at'] as String?;
    return LoyaltyAccount(
      userId: row['user_id'] as int,
      remaining: (row['remaining'] as int?) ?? 0,
      lastLoyaltyActivityAt: lastRaw == null ? null : DateTime.parse(lastRaw).toUtc(),
    );
  }

  LoyaltyLedgerEntry _rowToLedger(Row row) {
    return LoyaltyLedgerEntry(
      id: row['id'] as int,
      userId: row['user_id'] as int,
      amount: row['amount'] as int,
      reason: LoyaltyLedgerReason.fromDbValue(row['reason'] as String),
      idempotencyKey: row['idempotency_key'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      bookingId: row['booking_id'] as int?,
      subscriptionRequestId: row['subscription_request_id'] as int?,
      inviteeUserId: row['invitee_user_id'] as int?,
    );
  }
}
