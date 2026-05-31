import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:l/l.dart';

final class GoogleSheetsScheduleRepository implements TrainingScheduleRepository {
  GoogleSheetsScheduleRepository({
    required Uri csvUrl,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration minRefreshInterval = const Duration(minutes: 5),
    http.Client? httpClient,
    DateTime Function()? nowProvider,
  })  : _csvUrl = csvUrl,
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
  List<TrainingInfo> _cached = const <TrainingInfo>[];

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) {
    final current = now ?? _nowProvider();
    final items = _cached.where((item) => item.startsAt.isAfter(current)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return items.take(limit).toList(growable: false);
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
        l.w('Google Sheets sync failed: HTTP ${response.statusCode}');
        return false;
      }

      final parsed = _parseCsv(utf8.decode(response.bodyBytes));
      _cached = parsed;
      _lastRefreshAt = current;
      l.i('Google Sheets sync completed. Loaded ${parsed.length} schedule rows.');
      return true;
    } on TimeoutException catch (error) {
      l.w('Google Sheets sync timeout: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets sync error: $error', stackTrace);
      return false;
    }
  }

  List<TrainingInfo> _parseCsv(String body) {
    final rows = _parseCsvRows(body);
    if (rows.isEmpty) {
      return const <TrainingInfo>[];
    }

    final headers =
        rows.first.map((cell) => _normalizeHeader(cell.toString())).toList(growable: false);
    final titleIndex = headers.indexOf('title');
    final startsAtIndex = headers.indexOf('starts_at');
    final locationIndex = headers.indexOf('location');
    final coachIndex = headers.indexOf('coach');
    final notesIndex = headers.indexOf('notes');
    if (titleIndex < 0 || startsAtIndex < 0 || locationIndex < 0) {
      throw const FormatException('CSV must contain title, starts_at, location columns');
    }

    final items = <TrainingInfo>[];
    for (final row in rows.skip(1)) {
      final title = _cell(row, titleIndex);
      final startsAtRaw = _cell(row, startsAtIndex);
      final location = _cell(row, locationIndex);
      if (title.isEmpty || startsAtRaw.isEmpty || location.isEmpty) {
        continue;
      }

      final startsAt = _parseDateTime(startsAtRaw);
      if (startsAt == null) {
        continue;
      }

      items.add(
        TrainingInfo(
          title: title,
          startsAt: startsAt,
          location: location,
          coach: _optionalCell(row, coachIndex),
          notes: _optionalCell(row, notesIndex),
        ),
      );
    }
    return items;
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

  DateTime? _parseDateTime(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final isoDate = DateTime.tryParse(normalized);
    if (isoDate != null) {
      return isoDate.isUtc ? isoDate.toLocal() : isoDate;
    }

    final localFormats = <DateFormat>[
      DateFormat('dd.MM.yyyy HH:mm:ss'),
      DateFormat('dd.MM.yyyy H:mm:ss'),
      DateFormat('dd.MM.yyyy HH:mm'),
      DateFormat('dd.MM.yyyy H:mm'),
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd H:mm:ss'),
      DateFormat('yyyy-MM-dd HH:mm'),
      DateFormat('yyyy-MM-dd H:mm'),
    ];
    for (final format in localFormats) {
      try {
        return format.parseStrict(normalized);
      } on FormatException {
        // Try next format.
      }
    }
    return null;
  }

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].toString().trim();
  }

  String? _optionalCell(List<dynamic> row, int index) {
    final value = _cell(row, index);
    return value.isEmpty ? null : value;
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }
}
