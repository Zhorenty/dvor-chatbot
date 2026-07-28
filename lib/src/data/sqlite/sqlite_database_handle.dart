import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Shared SQLite connection for booking/onboarding/subscription repositories.
///
/// Opens one [Database] with WAL, foreign keys, and busy timeout so concurrent
/// writers from jobs and handlers cooperate on a single file.
final class SqliteDatabaseHandle {
  SqliteDatabaseHandle._(this._db, {required this.path, required this.ownsConnection});

  factory SqliteDatabaseHandle.open(
    String path, {
    int busyTimeoutMs = 5000,
  }) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(path);
    db.execute('PRAGMA busy_timeout=$busyTimeoutMs;');
    try {
      db.execute('PRAGMA journal_mode=WAL;');
    } on Object {
      // Concurrent openers may briefly lock while WAL is enabled.
    }
    db.execute('PRAGMA foreign_keys=ON;');
    return SqliteDatabaseHandle._(db, path: path, ownsConnection: true);
  }

  /// Wraps an already-open database without disposing it on [close].
  factory SqliteDatabaseHandle.fromDatabase(
    Database db, {
    required String path,
  }) {
    return SqliteDatabaseHandle._(db, path: path, ownsConnection: false);
  }

  final Database _db;
  final String path;
  final bool ownsConnection;
  bool _closed = false;

  Database get database {
    if (_closed) {
      throw StateError('SqliteDatabaseHandle is closed.');
    }
    return _db;
  }

  void ensureJobDedupeSchema() {
    database.execute('''
      CREATE TABLE IF NOT EXISTS job_dedupe_log (
        dedupe_key TEXT PRIMARY KEY,
        sent_at TEXT NOT NULL
      );
    ''');
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    if (ownsConnection) {
      _db.dispose();
    }
  }
}
