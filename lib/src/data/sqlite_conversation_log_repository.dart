import 'dart:io';

import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/conversation_log_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteConversationLogRepository implements ConversationLogRepository {
  static const int _previewMaxLength = 400;

  SqliteConversationLogRepository({
    String? dbPath,
    SqliteDatabaseHandle? databaseHandle,
    DateTime Function()? nowProvider,
  })  : _dbPath = dbPath ?? databaseHandle?.path,
        _externalHandle = databaseHandle,
        _nowProvider = nowProvider ?? DateTime.now {
    if (_dbPath == null) {
      throw ArgumentError('Either dbPath or databaseHandle is required.');
    }
  }

  final String? _dbPath;
  final SqliteDatabaseHandle? _externalHandle;
  final DateTime Function() _nowProvider;
  SqliteDatabaseHandle? _ownedHandle;
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('SqliteConversationLogRepository is not initialized.');
    }
    return db;
  }

  @override
  Future<void> init() async {
    final external = _externalHandle;
    if (external != null) {
      _db = external.database;
    } else {
      final path = _dbPath!;
      File(path).parent.createSync(recursive: true);
      final handle = SqliteDatabaseHandle.open(path);
      _ownedHandle = handle;
      _db = handle.database;
    }
    final db = _database;
    db.execute('''
      CREATE TABLE IF NOT EXISTS telegram_users (
        user_id INTEGER PRIMARY KEY,
        username TEXT,
        updated_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_telegram_users_username
      ON telegram_users (username COLLATE NOCASE);
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS conversation_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        occurred_at TEXT NOT NULL,
        direction TEXT NOT NULL,
        peer_user_id INTEGER NOT NULL,
        peer_username TEXT,
        chat_id INTEGER NOT NULL,
        telegram_message_id INTEGER,
        content_type TEXT NOT NULL,
        text_preview TEXT
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_conversation_log_occurred_at
      ON conversation_log (occurred_at DESC);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_conversation_log_peer_user_id
      ON conversation_log (peer_user_id, occurred_at DESC);
    ''');
  }

  @override
  Future<void> close() async {
    _ownedHandle?.close();
    _ownedHandle = null;
    _db = null;
  }

  @override
  Future<void> upsertTelegramUser({
    required int userId,
    String? username,
  }) async {
    if (userId <= 0) {
      return;
    }
    final normalized = normalizeTelegramUsername(username);
    final nowIso = _nowProvider().toUtc().toIso8601String();
    _database.execute(
      '''
      INSERT INTO telegram_users (user_id, username, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        username = COALESCE(excluded.username, telegram_users.username),
        updated_at = excluded.updated_at;
      ''',
      <Object?>[userId, normalized, nowIso],
    );
  }

  @override
  Future<void> append({
    required ConversationDirection direction,
    required int peerUserId,
    String? peerUsername,
    required int chatId,
    int? telegramMessageId,
    required ConversationContentType contentType,
    String? textPreview,
  }) async {
    if (peerUserId <= 0 || chatId <= 0) {
      return;
    }
    final normalized = normalizeTelegramUsername(peerUsername);
    if (normalized != null) {
      await upsertTelegramUser(userId: peerUserId, username: normalized);
    } else {
      await upsertTelegramUser(userId: peerUserId);
    }
    final nowIso = _nowProvider().toUtc().toIso8601String();
    _database.execute(
      '''
      INSERT INTO conversation_log (
        occurred_at,
        direction,
        peer_user_id,
        peer_username,
        chat_id,
        telegram_message_id,
        content_type,
        text_preview
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      <Object?>[
        nowIso,
        direction.name,
        peerUserId,
        normalized,
        chatId,
        telegramMessageId,
        contentType.name,
        _truncatePreview(textPreview),
      ],
    );
  }

  @override
  Future<List<ConversationLogEntry>> recentActions({
    int limit = 40,
    Set<int> excludePeerIds = const <int>{},
  }) async {
    final safeLimit = limit < 1 ? 1 : (limit > 200 ? 200 : limit);
    final excluded = excludePeerIds.where((id) => id > 0).toList(growable: false);
    ResultSet rows;
    if (excluded.isEmpty) {
      rows = _database.select(
        '''
        SELECT *
        FROM conversation_log
        ORDER BY occurred_at DESC, id DESC
        LIMIT ?;
        ''',
        <Object?>[safeLimit],
      );
    } else {
      final placeholders = List.filled(excluded.length, '?').join(', ');
      rows = _database.select(
        '''
        SELECT *
        FROM conversation_log
        WHERE peer_user_id NOT IN ($placeholders)
        ORDER BY occurred_at DESC, id DESC
        LIMIT ?;
        ''',
        <Object?>[...excluded, safeLimit],
      );
    }
    return rows.map(_mapRow).toList(growable: false);
  }

  @override
  Future<List<ConversationLogEntry>> dialogForUserId(
    int userId, {
    int limit = 50,
  }) async {
    if (userId <= 0) {
      return const <ConversationLogEntry>[];
    }
    final safeLimit = limit < 1 ? 1 : (limit > 200 ? 200 : limit);
    final rows = _database.select(
      '''
      SELECT *
      FROM conversation_log
      WHERE peer_user_id = ?
      ORDER BY occurred_at DESC, id DESC
      LIMIT ?;
      ''',
      <Object?>[userId, safeLimit],
    );
    final entries = rows.map(_mapRow).toList();
    return entries.reversed.toList(growable: false);
  }

  @override
  Future<int?> resolveUserIdByUsername(String username) async {
    final normalized = normalizeTelegramUsername(username);
    if (normalized == null) {
      return null;
    }
    final fromDirectory = _database.select(
      '''
      SELECT user_id
      FROM telegram_users
      WHERE username = ? COLLATE NOCASE
      ORDER BY updated_at DESC
      LIMIT 1;
      ''',
      <Object?>[normalized],
    );
    if (fromDirectory.isNotEmpty) {
      return fromDirectory.first['user_id'] as int;
    }
    final fromLog = _database.select(
      '''
      SELECT peer_user_id
      FROM conversation_log
      WHERE peer_username = ? COLLATE NOCASE
      ORDER BY occurred_at DESC, id DESC
      LIMIT 1;
      ''',
      <Object?>[normalized],
    );
    if (fromLog.isEmpty) {
      return null;
    }
    return fromLog.first['peer_user_id'] as int;
  }

  ConversationLogEntry _mapRow(Row row) {
    return ConversationLogEntry(
      id: row['id'] as int,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
      direction: ConversationDirection.values.byName(row['direction'] as String),
      peerUserId: row['peer_user_id'] as int,
      peerUsername: row['peer_username'] as String?,
      chatId: row['chat_id'] as int,
      telegramMessageId: row['telegram_message_id'] as int?,
      contentType: ConversationContentType.values.byName(row['content_type'] as String),
      textPreview: row['text_preview'] as String?,
    );
  }

  String? _truncatePreview(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final plain = trimmed
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .trim();
    if (plain.isEmpty) {
      return null;
    }
    if (plain.runes.length <= _previewMaxLength) {
      return plain;
    }
    return '${String.fromCharCodes(plain.runes.take(_previewMaxLength))}…';
  }
}
