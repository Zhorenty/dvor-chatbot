import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/config/trainer_booking_whitelist.dart';
import 'package:dvor_chatbot/src/data/dvor_team_repository.dart';
import 'package:http/http.dart' as http;
import 'package:l/l.dart';

final class GoogleSheetsDvorTeamRepository implements DvorTeamRepository {
  GoogleSheetsDvorTeamRepository({
    required Uri csvUrl,
    int dvorTeamSheetId = 2001400867,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration minRefreshInterval = const Duration(minutes: 5),
    http.Client? httpClient,
    DateTime Function()? nowProvider,
  })  : _csvUrl = _replaceGid(csvUrl, dvorTeamSheetId),
        _requestTimeout = requestTimeout,
        _minRefreshInterval = minRefreshInterval,
        _httpClient = httpClient ?? http.Client(),
        _nowProvider = nowProvider ?? DateTime.now;

  final Uri _csvUrl;
  final Duration _requestTimeout;
  final Duration _minRefreshInterval;
  final http.Client _httpClient;
  final DateTime Function() _nowProvider;

  DateTime? _lastRefreshAt;
  Set<String> _cachedUsernames = const <String>{};

  @override
  Set<String> usernames() => Set<String>.unmodifiable(_cachedUsernames);

  @override
  bool containsUsername(String? username) {
    final normalized = normalizeTelegramUsername(username);
    if (normalized == null) {
      return false;
    }
    return _cachedUsernames.contains(normalized);
  }

  @override
  Future<bool> refresh({bool force = false}) async {
    final current = _nowProvider();
    if (!force &&
        _lastRefreshAt != null &&
        current.difference(_lastRefreshAt!) < _minRefreshInterval) {
      return true;
    }

    try {
      final response = await _httpClient.get(_csvUrl).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        l.w('Google Sheets dvor team sync failed: HTTP ${response.statusCode}');
        return false;
      }
      _cachedUsernames = _parseCsv(utf8.decode(response.bodyBytes));
      _lastRefreshAt = current;
      l.i('Google Sheets dvor team sync completed. Loaded ${_cachedUsernames.length} usernames.');
      return true;
    } on TimeoutException catch (error) {
      l.w('Google Sheets dvor team sync timeout: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets dvor team sync error: $error', stackTrace);
      return false;
    }
  }

  Set<String> _parseCsv(String body) {
    final rows = _parseCsvRows(body);
    if (rows.isEmpty) {
      return const <String>{};
    }
    final headers =
        rows.first.map((cell) => _normalizeHeader(cell.toString())).toList(growable: false);

    final usernameIndex = _firstExistingHeaderIndex(
      headers,
      const <String>[
        'username',
        'user_name',
        'telegram',
        'tg',
        'link',
        'ат',
        '@',
        'юзернейм',
        'username_telegram',
      ],
    );

    if (usernameIndex < 0) {
      throw const FormatException(
        'Dvor team CSV must contain a username column',
      );
    }

    final usernames = <String>{};
    for (final row in rows.skip(1)) {
      final raw = _cell(row, usernameIndex);
      final normalized = normalizeTelegramUsername(raw);
      if (normalized != null) {
        usernames.add(normalized);
      }
    }
    return usernames;
  }

  int _firstExistingHeaderIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexOf(_normalizeHeader(candidate));
      if (index >= 0) {
        return index;
      }
    }
    return -1;
  }

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].toString().trim();
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_').replaceAll('ё', 'е');
  }

  List<List<String>> _parseCsvRows(String source) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;
    var index = 0;

    void finishCell() {
      currentRow.add(currentCell.toString());
      currentCell.clear();
    }

    void finishRow() {
      finishCell();
      if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
      currentRow.clear();
    }

    while (index < source.length) {
      final char = source[index];
      if (char == '"') {
        final nextIndex = index + 1;
        if (inQuotes && nextIndex < source.length && source[nextIndex] == '"') {
          currentCell.write('"');
          index = nextIndex;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        finishCell();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && index + 1 < source.length && source[index + 1] == '\n') {
          index += 1;
        }
        finishRow();
      } else {
        currentCell.write(char);
      }
      index += 1;
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      finishRow();
    }
    return rows;
  }

  static Uri _replaceGid(Uri source, int gid) {
    final params = <String, String>{...source.queryParameters};
    params['gid'] = '$gid';
    params.putIfAbsent('format', () => 'csv');
    return source.replace(queryParameters: params);
  }
}
