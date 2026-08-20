import 'dart:async';
import 'dart:convert';

import 'package:dvor_chatbot/src/data/google_sheets_value_parser.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:http/http.dart' as http;
import 'package:l/l.dart';

final class GoogleSheetsScheduleRepository implements TrainingScheduleRepository {
  GoogleSheetsScheduleRepository({
    required Uri csvUrl,
    int hikesSheetId = 294119056,
    int trailsSheetId = 1220729038,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration minRefreshInterval = const Duration(minutes: 5),
    http.Client? httpClient,
    DateTime Function()? nowProvider,
  })  : _csvUrl = csvUrl,
        _hikesCsvUrl = _replaceGid(csvUrl, hikesSheetId),
        _trailsCsvUrl = _replaceGid(csvUrl, trailsSheetId),
        _requestTimeout = requestTimeout,
        _minRefreshInterval = minRefreshInterval,
        _httpClient = httpClient ?? http.Client(),
        _nowProvider = nowProvider ?? DateTime.now;

  final Uri _csvUrl;
  final Uri _hikesCsvUrl;
  final Uri _trailsCsvUrl;
  final Duration _requestTimeout;
  final Duration _minRefreshInterval;
  final http.Client _httpClient;
  final DateTime Function() _nowProvider;

  DateTime? _lastRefreshAt;
  List<TrainingInfo> _cached = const <TrainingInfo>[];
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
      _cachedOutdoor = <OutdoorActivityInfo>[...parsedHikes, ...parsedTrails];
      _lastRefreshAt = current;
      l.i(
        'Google Sheets sync completed. '
        'Loaded ${parsedTrainings.length} trainings '
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
    final titleIndex = _firstHeaderIndex(headers, const <String>['title', 'название']);
    final startsAtIndex = headers.indexOf('starts_at');
    final dateIndex = GoogleSheetsValueParser.firstHeaderIndex(headers, const <String>[
      'date',
      'дата',
    ]);
    final timeIndex = GoogleSheetsValueParser.firstHeaderIndex(headers, const <String>[
      'time',
      'время',
    ]);
    final locationIndex = GoogleSheetsValueParser.firstHeaderIndex(
      headers,
      const <String>['location', 'место', 'where', 'place'],
    );
    final locationUrlIndex = GoogleSheetsValueParser.firstHeaderIndex(
      headers,
      const <String>[
        'location_url',
        'location_link',
        'maps_url',
        'map_url',
        'карта',
      ],
    );
    final priceIndex = GoogleSheetsValueParser.firstHeaderIndex(headers, const <String>[
      'price',
      'цена',
    ]);
    final participantsLimitIndex = GoogleSheetsValueParser.firstHeaderIndex(
      headers,
      const <String>[
        'participants_limit',
        'participant_limit',
        'participants',
        'limit',
        'лимит',
      ],
    );
    final includeTrainersInParticipantsIndex = GoogleSheetsValueParser.firstHeaderIndex(
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
        'тренеры_в_лимите',
      ],
    );
    final coachIndex = GoogleSheetsValueParser.firstHeaderIndex(
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
    final notesIndex = GoogleSheetsValueParser.firstHeaderIndex(
      headers,
      const <String>['notes', 'заметки', 'примечание'],
    );
    final promoRestrictedIndex = GoogleSheetsValueParser.firstHeaderIndex(
      headers,
      const <String>[
        'promo_restricted',
        'no_promo',
        'restrict_promo',
        'without_promo',
        'без_промокода',
        'без_скидок',
      ],
    );
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
          promoRestricted: _parseBoolFlag(_optionalCell(row, promoRestrictedIndex)),
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
    final titleIndex = _firstHeaderIndex(headers, const <String>['title', 'название']);
    final dateFromIndex = _firstHeaderIndex(
      headers,
      const <String>['date_from', 'дата_с', 'дата_начала'],
    );
    final dateToIndex = _firstHeaderIndex(
      headers,
      const <String>['date_to', 'дата_по', 'дата_окончания'],
    );
    final locationIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'location',
        'where',
        'place',
        'место',
        'где',
      ],
    );
    final descriptionIndex = _firstHeaderIndex(
      headers,
      const <String>['description', 'описание'],
    );
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
    final priceIndex = _firstHeaderIndex(headers, const <String>['price', 'цена']);
    final prepayPercentIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'prepay_percent',
        'prepayment_percent',
        'prepaid_percent',
        'prepay',
        'предоплата',
        'процент_предоплаты',
      ],
    );
    final participantsLimitIndex = _firstHeaderIndex(
      headers,
      const <String>[
        'participants_limit',
        'participant_limit',
        'participants',
        'limit',
        'лимит',
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
      final location = _optionalCell(row, locationIndex)?.trim();

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
          location: location == null || location.isEmpty ? null : location,
          equipment: _optionalCell(row, equipmentIndex),
          itinerary: _optionalCell(row, itineraryIndex),
          price: _parsePrice(_optionalCell(row, priceIndex)),
          prepayPercent: _parsePrepayPercent(_optionalCell(row, prepayPercentIndex)),
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

  DateTime? _parseDateTime(String raw) => GoogleSheetsValueParser.parseDateTime(raw);

  DateTime? _parseDateAndTime(String dateRaw, String timeRaw) {
    return GoogleSheetsValueParser.parseDateAndTime(dateRaw, timeRaw);
  }

  DateTime? _parseRangeDateTime(String raw, {required bool isEndOfDay}) {
    return GoogleSheetsValueParser.parseRangeDateTime(raw, isEndOfDay: isEndOfDay);
  }

  String _cell(List<dynamic> row, int index) {
    return GoogleSheetsValueParser.cell(List<Object?>.from(row), index);
  }

  String? _optionalCell(List<dynamic> row, int index) {
    return GoogleSheetsValueParser.optionalCell(List<Object?>.from(row), index);
  }

  int? _parsePrice(String? raw) => GoogleSheetsValueParser.parsePrice(raw);

  int? _parseParticipantsLimit(String? raw) {
    return GoogleSheetsValueParser.parseParticipantsLimit(raw);
  }

  int _parsePrepayPercent(String? raw) => GoogleSheetsValueParser.parsePrepayPercent(raw);

  bool _parseBoolFlag(String? raw, {bool defaultValue = false}) {
    return GoogleSheetsValueParser.parseBoolFlag(raw, defaultValue: defaultValue);
  }

  int _firstHeaderIndex(List<String> headers, List<String> aliases) {
    return GoogleSheetsValueParser.firstHeaderIndex(headers, aliases);
  }

  String _normalizeHeader(String value) => GoogleSheetsValueParser.normalizeHeader(value);

  static Uri _replaceGid(Uri source, int gid) {
    final params = <String, String>{...source.queryParameters};
    params['gid'] = '$gid';
    params.putIfAbsent('format', () => 'csv');
    return source.replace(queryParameters: params);
  }
}
