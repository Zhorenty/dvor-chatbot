import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:sqlite3/sqlite3.dart';

/// Persistent claim/release log so scheduled jobs survive process restarts
/// without double-sending in the same slot.
final class JobDedupeRepository {
  JobDedupeRepository({
    required SqliteDatabaseHandle databaseHandle,
    DateTime Function()? nowProvider,
  })  : _handle = databaseHandle,
        _nowProvider = nowProvider ?? DateTime.now;

  final SqliteDatabaseHandle _handle;
  final DateTime Function() _nowProvider;

  Database get _db => _handle.database;

  void initSchema() {
    _handle.ensureJobDedupeSchema();
  }

  /// Tries to claim [key]. Returns `true` if this caller owns the send.
  bool tryClaim(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final nowIso = _nowProvider().toUtc().toIso8601String();
    try {
      _db.execute('BEGIN IMMEDIATE;');
      final existing = _db.select(
        'SELECT 1 FROM job_dedupe_log WHERE dedupe_key = ? LIMIT 1;',
        <Object?>[normalized],
      );
      if (existing.isNotEmpty) {
        _db.execute('COMMIT;');
        return false;
      }
      _db.execute(
        'INSERT INTO job_dedupe_log (dedupe_key, sent_at) VALUES (?, ?);',
        <Object?>[normalized, nowIso],
      );
      _db.execute('COMMIT;');
      return true;
    } on Object {
      try {
        _db.execute('ROLLBACK;');
      } on Object {
        // ignore rollback failures
      }
      return false;
    }
  }

  void release(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      return;
    }
    _db.execute(
      'DELETE FROM job_dedupe_log WHERE dedupe_key = ?;',
      <Object?>[normalized],
    );
  }

  void cleanupOlderThan(Duration maxAge) {
    final threshold = _nowProvider().toUtc().subtract(maxAge).toIso8601String();
    _db.execute(
      'DELETE FROM job_dedupe_log WHERE sent_at < ?;',
      <Object?>[threshold],
    );
  }
}
