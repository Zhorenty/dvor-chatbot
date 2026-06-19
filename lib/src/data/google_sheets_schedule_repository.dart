import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:l/l.dart';

final class GoogleSheetsScheduleRepository implements TrainingScheduleRepository {
  GoogleSheetsScheduleRepository({
    required Uri csvUrl,
    int yogaSheetId = 469715453,
    int hikesSheetId = 294119056,
    int trailsSheetId = 1220729038,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration minRefreshInterval = const Duration(minutes: 5),
    http.Client? httpClient,
    DateTime Function()? nowProvider,
  })  : _csvUrl = csvUrl,
        _yogaCsvUrl = _replaceGid(csvUrl, yogaSheetId),
        _hikesCsvUrl = _replaceGid(csvUrl, hikesSheetId),
        _trailsCsvUrl = _replaceGid(csvUrl, trailsSheetId),
        _requestTimeout = requestTimeout,
        _minRefreshInterval = minRefreshInterval,
        _httpClient = httpClient ?? http.Client(),
        _nowProvider = nowProvider ?? DateTime.now;

  final Uri _csvUrl;
  final Uri _yogaCsvUrl;
  final Uri _hikesCsvUrl;
  final Uri _trailsCsvUrl;
  final Duration _requestTimeout;
  final Duration _minRefreshInterval;
  final http.Client _httpClient;
  final DateTime Function() _nowProvider;

  DateTime? _lastRefreshAt;
  List<TrainingInfo> _cached = const <TrainingInfo>[];
  List<TrainingInfo> _cachedYoga = const <TrainingInfo>[];
  List<OutdoorActivityInfo> _cachedOutdoor = const <OutdoorActivityInfo>[];

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) {
    final current = now ?? _nowProvider();
    final items = _cached.where((item) => item.startsAt.isAfter(current)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return items.take(limit).toList(growable: false);
  }

  @override
  List<OutdoorActivityInfo> upcomingOutdoorActivities({DateTime? now, int limit = 8}) {
    final current = now ?? _nowProvider();
    final items = _cachedOutdoor.where((item) => !item.dateTo.isBefore(current)).toList()
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    return items.take(limit).toList(growable: false);
  }

  @override
  List<TrainingInfo> upcomingYoga({DateTime? now, int limit = 5}) {
    final current = now ?? _nowProvider();
    final items = _cachedYoga.where((item) => item.startsAt.isAfter(current)).toList()
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
      final trainingsResponse = await _httpClient.get(_csvUrl).timeout(_requestTimeout);
      if (trainingsResponse.statusCode != 200) {
        l.w('Google Sheets sync failed for trainings: HTTP ${trainingsResponse.statusCode}');
        return false;
      }

      final parsedTrainings = _parseCsv(utf8.decode(trainingsResponse.bodyBytes));
      if (parsedTrainings.isEmpty && _cached.isNotEmpty) {
        l.w('Google Sheets sync returned empty trainings CSV. Keeping previous cache.');
        return false;
      }
      var parsedYoga = _cachedYoga;
      final yogaResponse = await _httpClient.get(_yogaCsvUrl).timeout(_requestTimeout);
      if (yogaResponse.statusCode == 200) {
        parsedYoga = _parseCsv(
          utf8.decode(yogaResponse.bodyBytes),
          category: ActivityCategory.yoga,
        );
      } else {
        l.w('Google Sheets sync skipped yoga: HTTP ${yogaResponse.statusCode}');
      }
      var parsedHikes = _cachedOutdoor
          .where((item) => item.type == OutdoorActivityType.hike)
          .toList(growable: false);
      var parsedTrails = _cachedOutdoor
          .where((item) => item.type == OutdoorActivityType.trail)
          .toList(growable: false);

      final hikesResponse = await _httpClient.get(_hikesCsvUrl).timeout(_requestTimeout);
      if (hikesResponse.statusCode == 200) {
        parsedHikes = _parseOutdoorCsv(
          utf8.decode(hikesResponse.bodyBytes),
          OutdoorActivityType.hike,
        );
      } else {
        l.w('Google Sheets sync skipped hikes: HTTP ${hikesResponse.statusCode}');
      }

      final trailsResponse = await _httpClient.get(_trailsCsvUrl).timeout(_requestTimeout);
      if (trailsResponse.statusCode == 200) {
        parsedTrails = _parseOutdoorCsv(
          utf8.decode(trailsResponse.bodyBytes),
          OutdoorActivityType.trail,
        );
      } else {
        l.w('Google Sheets sync skipped trails: HTTP ${trailsResponse.statusCode}');
      }

      _cached = parsedTrainings;
      _cachedYoga = parsedYoga;
      _cachedOutdoor = <OutdoorActivityInfo>[...parsedHikes, ...parsedTrails];
      _lastRefreshAt = current;
      l.i(
        'Google Sheets sync completed. '
        'Loaded ${parsedTrainings.length} trainings, ${parsedYoga.length} yoga rows '
        'and ${_cachedOutdoor.length} outdoor rows.',
      );
      return true;
    } on TimeoutException catch (error) {
      l.w('Google Sheets sync timeout: $error');
      return false;
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets sync error: $error', stackTrace);
      return false;
    }
  }

  List<TrainingInfo> _parseCsv(
    String body, {
    ActivityCategory category = ActivityCategory.trainings,
  }) {
    final rows = _parseCsvRows(body);
    if (rows.isEmpty) {
      return const <TrainingInfo>[];
    }

    final headers =
        rows.first.map((cell) => _normalizeHeader(cell.toString())).toList(growable: false);
    final titleIndex = headers.indexOf('title');
    final startsAtIndex = headers.indexOf('starts_at');
    final dateIndex = headers.indexOf('date');
    final timeIndex = headers.indexOf('time');
    final locationIndex = headers.indexOf('location');
    final locationUrlIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'location_url',
        'location_link',
        'maps_url',
        'map_url',
      ],
    );
    final priceIndex = headers.indexOf('price');
    final participantsLimitIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'participants_limit',
        'participant_limit',
        'participants',
        'limit',
      ],
    );
    final includeTrainersInParticipantsIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'include_trainers_in_participants',
        'include_coaches_in_participants',
        'count_trainers_as_participants',
        'count_coaches_as_participants',
        'trainers_as_participants',
        'coaches_as_participants',
        'include_trainers',
        'включать_тренеров_в_участников',
        'тренеры_в_участниках',
      ],
    );
    final coachIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'coach',
        'coaches',
        'trainer',
        'trainers',
        'тренер',
        'тренеры',
      ],
    );
    final notesIndex = headers.indexOf('notes');
    final hasStartsAt = startsAtIndex >= 0;
    final hasDateAndTime = dateIndex >= 0 && timeIndex >= 0;
    if (titleIndex < 0 || locationIndex < 0 || (!hasStartsAt && !hasDateAndTime)) {
      throw const FormatException(
        'CSV must contain title, location and either starts_at or date/time columns',
      );
    }

    final items = <TrainingInfo>[];
    for (final row in rows.skip(1)) {
      final title = _cell(row, titleIndex);
      final location = _cell(row, locationIndex);
      if (title.isEmpty || location.isEmpty) {
        continue;
      }

      DateTime? startsAt;
      if (hasStartsAt) {
        final startsAtRaw = _cell(row, startsAtIndex);
        if (startsAtRaw.isNotEmpty) {
          startsAt = _parseDateTime(startsAtRaw);
        }
      }
      if (startsAt == null && hasDateAndTime) {
        startsAt = _parseDateAndTime(_cell(row, dateIndex), _cell(row, timeIndex));
      }
      if (startsAt == null) {
        continue;
      }

      items.add(
        TrainingInfo(
          title: title,
          startsAt: startsAt,
          location: location,
          locationUrl: _optionalCell(row, locationUrlIndex),
          category: category,
          price: _parsePrice(_optionalCell(row, priceIndex)),
          participantsLimit: _parseParticipantsLimit(_optionalCell(row, participantsLimitIndex)),
          includeTrainersInParticipants:
              _parseBoolFlag(_optionalCell(row, includeTrainersInParticipantsIndex)),
          coach: _optionalCell(row, coachIndex),
          notes: _optionalCell(row, notesIndex),
        ),
      );
    }
    return items;
  }

  List<OutdoorActivityInfo> _parseOutdoorCsv(String body, OutdoorActivityType type) {
    final rows = _parseCsvRows(body);
    if (rows.isEmpty) {
      return const <OutdoorActivityInfo>[];
    }

    final headers =
        rows.first.map((cell) => _normalizeHeader(cell.toString())).toList(growable: false);
    final titleIndex = headers.indexOf('title');
    final dateFromIndex = headers.indexOf('date_from');
    final dateToIndex = headers.indexOf('date_to');
    final descriptionIndex = headers.indexOf('description');
    final equipmentIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'equipment',
        'gear',
        'kit',
        'экипировка',
      ],
    );
    final itineraryIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'itinerary',
        'schedule',
        'timeline',
        'program',
        'расписание',
        'тайминг',
        'план',
      ],
    );
    final priceIndex = headers.indexOf('price');
    final participantsLimitIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'participants_limit',
        'participant_limit',
        'participants',
        'limit',
      ],
    );

    if (titleIndex < 0 || dateFromIndex < 0 || descriptionIndex < 0) {
      l.w(
        'Outdoor sheet parsing skipped: '
        'required columns title/date_from/description are missing.',
      );
      return const <OutdoorActivityInfo>[];
    }

    final items = <OutdoorActivityInfo>[];
    for (final row in rows.skip(1)) {
      final title = _cell(row, titleIndex);
      final description = _cell(row, descriptionIndex);
      if (title.isEmpty || description.isEmpty) {
        continue;
      }

      final dateFrom = _parseRangeDateTime(_cell(row, dateFromIndex), isEndOfDay: false);
      if (dateFrom == null) {
        continue;
      }

      final rawDateTo = _optionalCell(row, dateToIndex);
      final dateTo = _parseRangeDateTime(rawDateTo ?? '', isEndOfDay: true) ??
          _parseRangeDateTime(_cell(row, dateFromIndex), isEndOfDay: true);
      if (dateTo == null) {
        continue;
      }

      items.add(
        OutdoorActivityInfo(
          type: type,
          title: title,
          dateFrom: dateFrom,
          dateTo: dateTo,
          description: description,
          equipment: _optionalCell(row, equipmentIndex),
          itinerary: _optionalCell(row, itineraryIndex),
          price: _parsePrice(_optionalCell(row, priceIndex)),
          participantsLimit: _parseParticipantsLimit(_optionalCell(row, participantsLimitIndex)),
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

  DateTime? _parseDateAndTime(String dateRaw, String timeRaw) {
    final dateNormalized = dateRaw.trim();
    final timeNormalized = timeRaw.trim();
    if (dateNormalized.isEmpty || timeNormalized.isEmpty) {
      return null;
    }

    final combined = _parseDateTime('$dateNormalized $timeNormalized');
    if (combined != null) {
      return combined;
    }

    final date = _parseDate(dateNormalized);
    final time = _parseTime(timeNormalized);
    if (date == null || time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute, time.second);
  }

  DateTime? _parseDate(String raw) {
    final dateOnlyFormats = <DateFormat>[
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd.MM.yyyy'),
      DateFormat('d.M.yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('M/d/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
    ];

    for (final format in dateOnlyFormats) {
      try {
        return format.parseStrict(raw);
      } on FormatException {
        // Try next format.
      }
    }

    return null;
  }

  DateTime? _parseRangeDateTime(String raw, {required bool isEndOfDay}) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final parsedDateTime = _parseDateTime(normalized);
    if (parsedDateTime != null) {
      final likelyDateOnly = !RegExp(r'[:T]').hasMatch(normalized);
      if (!likelyDateOnly) {
        return parsedDateTime;
      }
      return isEndOfDay
          ? DateTime(
              parsedDateTime.year,
              parsedDateTime.month,
              parsedDateTime.day,
              23,
              59,
              59,
            )
          : DateTime(parsedDateTime.year, parsedDateTime.month, parsedDateTime.day);
    }

    final dateOnly = _parseDate(normalized);
    if (dateOnly == null) {
      return null;
    }

    return isEndOfDay
        ? DateTime(dateOnly.year, dateOnly.month, dateOnly.day, 23, 59, 59)
        : DateTime(dateOnly.year, dateOnly.month, dateOnly.day);
  }

  DateTime? _parseTime(String raw) {
    final timeFormats = <DateFormat>[
      DateFormat('HH:mm:ss'),
      DateFormat('H:mm:ss'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
      DateFormat('hh:mm a'),
      DateFormat('h:mm a'),
    ];

    for (final format in timeFormats) {
      try {
        return format.parseStrict(raw);
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

  int? _parsePrice(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return null;
    }
    return int.tryParse(digitsOnly);
  }

  int? _parseParticipantsLimit(String? raw) {
    final parsed = _parsePrice(raw);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  bool _parseBoolFlag(String? raw, {bool defaultValue = false}) {
    if (raw == null) {
      return defaultValue;
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return defaultValue;
    }
    if (const <String>{
      '1',
      'true',
      'yes',
      'y',
      'on',
      'да',
      'д',
    }.contains(normalized)) {
      return true;
    }
    if (const <String>{
      '0',
      'false',
      'no',
      'n',
      'off',
      'нет',
      'н',
    }.contains(normalized)) {
      return false;
    }
    return defaultValue;
  }

  int _firstHeaderIndex(List<String> headers, List<String> aliases) {
    for (final alias in aliases) {
      final index = headers.indexOf(alias);
      if (index >= 0) {
        return index;
      }
    }
    return -1;
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  static Uri _replaceGid(Uri source, int gid) {
    final params = <String, String>{...source.queryParameters};
    params['gid'] = '$gid';
    params.putIfAbsent('format', () => 'csv');
    return source.replace(queryParameters: params);
  }
}
