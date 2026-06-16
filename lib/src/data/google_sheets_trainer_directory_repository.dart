import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/data/trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:http/http.dart' as http;
import 'package:l/l.dart';

final class GoogleSheetsTrainerDirectoryRepository implements TrainerDirectoryRepository {
  GoogleSheetsTrainerDirectoryRepository({
    required Uri csvUrl,
    int trainersSheetId = 195037978,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration minRefreshInterval = const Duration(minutes: 5),
    http.Client? httpClient,
    DateTime Function()? nowProvider,
  })  : _csvUrl = _replaceGid(csvUrl, trainersSheetId),
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
  List<TrainerInfo> _cached = const <TrainerInfo>[];

  @override
  List<TrainerInfo> list({int limit = 20}) {
    return _cached.take(limit).toList(growable: false);
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
        l.w('Google Sheets trainers sync failed: HTTP ${response.statusCode}');
        return false;
      }
      _cached = _parseCsv(utf8.decode(response.bodyBytes));
      _lastRefreshAt = current;
      l.i('Google Sheets trainers sync completed. Loaded ${_cached.length} trainers.');
      return true;
    } on TimeoutException catch (error) {
      l.w('Google Sheets trainers sync timeout: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets trainers sync error: $error', stackTrace);
      return false;
    }
  }

  List<TrainerInfo> _parseCsv(String body) {
    final rows = _parseCsvRows(body);
    if (rows.isEmpty) {
      return const <TrainerInfo>[];
    }
    final headers =
        rows.first.map((cell) => _normalizeHeader(cell.toString())).toList(growable: false);

    final nameIndex = _firstExistingHeaderIndex(
      headers,
      const <String>['name', 'trainer_name', 'coach', 'fio', 'имя'],
    );
    final linkIndex = _firstExistingHeaderIndex(
      headers,
      const <String>['link', 'username', 'telegram', 'tg', 'ат', '@', 'ссылка'],
    );
    final descriptionIndex = _firstExistingHeaderIndex(
      headers,
      const <String>['description', 'about', 'bio', 'desc', 'описание'],
    );
    final roleIndex = _firstExistingHeaderIndex(
      headers,
      const <String>['role', 'specialization', 'direction', 'роль', 'направление'],
    );

    if (nameIndex < 0 || linkIndex < 0 || descriptionIndex < 0) {
      throw const FormatException(
        'Trainers CSV must contain name/link/description columns',
      );
    }

    final items = <TrainerInfo>[];
    for (final row in rows.skip(1)) {
      final name = _cell(row, nameIndex);
      final link = _cell(row, linkIndex);
      final description = _cell(row, descriptionIndex);
      final role = _cell(row, roleIndex);
      if (name.isEmpty || link.isEmpty || description.isEmpty) {
        continue;
      }
      items.add(
        TrainerInfo(
          name: name,
          link: _normalizeLink(link),
          description: description,
          role: role,
        ),
      );
    }
    return items;
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

  String _normalizeLink(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return value;
    }
    if (value.startsWith('@') || value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '@$value';
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
