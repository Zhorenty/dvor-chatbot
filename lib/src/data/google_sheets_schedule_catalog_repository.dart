import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_ids.dart';
import 'package:dvor_chatbot/src/data/google_sheets_input_ui.dart';
import 'package:dvor_chatbot/src/data/google_sheets_value_parser.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/data/schedule_catalog_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/schedule_catalog.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/business_timezone.dart';
import 'package:l/l.dart';

final class GoogleSheetsScheduleCatalogRepository implements ScheduleCatalogRepository {
  GoogleSheetsScheduleCatalogRepository({
    required GoogleSheetsSpreadsheetGateway gateway,
  }) : _gateway = gateway;

  final GoogleSheetsSpreadsheetGateway _gateway;

  static const int _maxDataRow = 1 + GoogleSheetsInputUi.extraRows;

  @override
  ScheduleCatalogAvailability get availability => ScheduleCatalogAvailability.ready;

  @override
  Future<List<ScheduleCatalogItem>> listEvents(
    ActivityCategory category, {
    DateTime? now,
    int timezoneOffsetHours = 3,
    bool includePast = false,
  }) async {
    final snapshot = await _readSheet(_specFor(category));
    final items = _parseItems(snapshot, category);
    if (includePast) {
      items.sort((a, b) => a.sortAt.compareTo(b.sortAt));
      return items;
    }
    final current = now ?? DateTime.now();
    final listed = items.where((item) => _isListed(item, current, timezoneOffsetHours)).toList()
      ..sort((a, b) => a.sortAt.compareTo(b.sortAt));
    return listed;
  }

  @override
  Future<ScheduleCatalogItem> create(ScheduleEventDraft draft) async {
    final spec = _specFor(draft.category);
    final snapshot = await _readSheet(spec);
    final emptyRow = _firstEmptyRow(snapshot);
    if (emptyRow == null) {
      throw const ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.noEmptyRows,
        'Нет свободных строк на листе. Добавь строки в таблицу или удали старые события.',
      );
    }
    await _writeDraft(
      snapshot: snapshot,
      row: emptyRow,
      draft: draft,
    );
    final updated = await _readSheet(spec);
    final created =
        _parseItems(updated, draft.category).where((item) => item.sheetRow == emptyRow).firstOrNull;
    if (created == null) {
      throw const ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.invalidValue,
        'Строка записана, но событие не читается. Проверь обязательные поля.',
      );
    }
    return created;
  }

  @override
  Future<ScheduleCatalogItem> update({
    required ScheduleCatalogItem identity,
    required ScheduleEventDraft patch,
  }) async {
    final spec = _specFor(identity.category);
    final snapshot = await _readSheet(spec);
    final current = _findByIdentity(snapshot, identity);
    if (current == null) {
      throw const ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.notFound,
        'Событие не найдено. Обнови список.',
      );
    }
    await _writeDraft(
      snapshot: snapshot,
      row: current.sheetRow,
      draft: patch,
    );
    final updated = await _readSheet(spec);
    final item = _parseItems(updated, identity.category)
        .where((entry) => entry.sheetRow == current.sheetRow)
        .firstOrNull;
    if (item == null) {
      throw const ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.invalidValue,
        'Поле записано, но событие не читается. Проверь обязательные поля.',
      );
    }
    return item;
  }

  @override
  Future<void> delete(ScheduleCatalogItem identity) async {
    final spec = _specFor(identity.category);
    final snapshot = await _readSheet(spec);
    final current = _findByIdentity(snapshot, identity);
    if (current == null) {
      throw const ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.notFound,
        'Событие не найдено. Обнови список.',
      );
    }
    await _deleteRow(snapshot, current.sheetRow);
  }

  @override
  Future<ScheduleRetentionResult> deleteExpired({
    required DateTime now,
    required int timezoneOffsetHours,
  }) async {
    var trainingsDeleted = 0;
    var hikesDeleted = 0;
    var trailsDeleted = 0;
    final requested = <String>[];

    Future<int> purge(ActivityCategory category) async {
      final spec = _specFor(category);
      requested.add(spec.title);
      try {
        final snapshot = await _readSheet(spec);
        final expired = _parseItems(snapshot, category)
            .where((item) => _isExpired(item, now, timezoneOffsetHours))
            .map((item) => item.sheetRow)
            .toList()
          ..sort((a, b) => b.compareTo(a));
        for (final row in expired) {
          await _deleteRow(snapshot, row);
          snapshot.rows.removeAt(row - 1);
        }
        return expired.length;
      } on Object catch (error, stackTrace) {
        l.w('Schedule retention failed for ${spec.title}: $error', stackTrace);
        return 0;
      }
    }

    trainingsDeleted = await purge(ActivityCategory.trainings);
    hikesDeleted = await purge(ActivityCategory.hikes);
    trailsDeleted = await purge(ActivityCategory.trails);
    return ScheduleRetentionResult(
      trainingsDeleted: trainingsDeleted,
      hikesDeleted: hikesDeleted,
      trailsDeleted: trailsDeleted,
      requestedSheetTitles: requested,
    );
  }

  Future<_SheetSnapshot> _readSheet(GoogleSheetsInputSheetSpec spec) async {
    final sheets = await _gateway.describeSheets();
    GoogleSheetsSheetInfo? info;
    for (final sheet in sheets) {
      if (sheet.title == spec.title) {
        info = sheet;
        break;
      }
    }
    if (info == null) {
      throw ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.sheetMissing,
        'Лист «${spec.title}» не найден.',
      );
    }
    final quoted = quoteA1SheetTitle(spec.title);
    final values = await _gateway.getValues('$quoted!A1:Z$_maxDataRow');
    return _SheetSnapshot(spec: spec, sheetId: info.sheetId, rows: values);
  }

  List<ScheduleCatalogItem> _parseItems(_SheetSnapshot snapshot, ActivityCategory category) {
    if (snapshot.rows.isEmpty) {
      return const <ScheduleCatalogItem>[];
    }
    final map = _HeaderMap.from(snapshot);
    final items = <ScheduleCatalogItem>[];
    for (var i = 1; i < snapshot.rows.length; i++) {
      final rowNumber = i + 1;
      if (rowNumber > _maxDataRow) {
        break;
      }
      final row = snapshot.rows[i];
      if (category == ActivityCategory.trainings) {
        final training = _parseTraining(row, map);
        if (training != null) {
          items.add(
            ScheduleCatalogItem(
              sheetRow: rowNumber,
              category: category,
              training: training,
            ),
          );
        }
      } else {
        final outdoor = _parseOutdoor(row, map, category);
        if (outdoor != null) {
          items.add(
            ScheduleCatalogItem(
              sheetRow: rowNumber,
              category: category,
              outdoor: outdoor,
            ),
          );
        }
      }
    }
    return items;
  }

  TrainingInfo? _parseTraining(List<Object?> row, _HeaderMap map) {
    final title = map.cell(row, 'название');
    final location = map.cell(row, 'место');
    final date = map.cell(row, 'дата');
    final time = map.cell(row, 'время');
    if (title.isEmpty || location.isEmpty || date.isEmpty || time.isEmpty) {
      return null;
    }
    final startsAt = GoogleSheetsValueParser.parseDateAndTime(date, time);
    if (startsAt == null) {
      return null;
    }
    return TrainingInfo(
      title: title,
      startsAt: startsAt,
      location: location,
      locationUrl: map.optional(row, 'карта'),
      category: ActivityCategory.trainings,
      price: GoogleSheetsValueParser.parsePrice(map.optional(row, 'цена')),
      participantsLimit: GoogleSheetsValueParser.parseParticipantsLimit(map.optional(row, 'лимит')),
      includeTrainersInParticipants:
          GoogleSheetsValueParser.parseBoolFlag(map.optional(row, 'тренеры_в_лимите')),
      coach: map.optional(row, 'тренер'),
      notes: map.optional(row, 'заметки'),
      promoRestricted: GoogleSheetsValueParser.parseBoolFlag(map.optional(row, 'без_промокода')),
    );
  }

  OutdoorActivityInfo? _parseOutdoor(
    List<Object?> row,
    _HeaderMap map,
    ActivityCategory category,
  ) {
    final title = map.cell(row, 'название');
    final description = map.cell(row, 'описание');
    final dateFromRaw = map.cell(row, 'дата_с');
    if (title.isEmpty || description.isEmpty || dateFromRaw.isEmpty) {
      return null;
    }
    final dateFrom = GoogleSheetsValueParser.parseRangeDateTime(dateFromRaw, isEndOfDay: false);
    if (dateFrom == null) {
      return null;
    }
    final dateToRaw = map.optional(row, 'дата_по');
    final dateTo = GoogleSheetsValueParser.parseRangeDateTime(dateToRaw ?? '', isEndOfDay: true) ??
        GoogleSheetsValueParser.parseRangeDateTime(dateFromRaw, isEndOfDay: true);
    if (dateTo == null) {
      return null;
    }
    return OutdoorActivityInfo(
      type:
          category == ActivityCategory.hikes ? OutdoorActivityType.hike : OutdoorActivityType.trail,
      title: title,
      dateFrom: dateFrom,
      dateTo: dateTo,
      description: description,
      location: map.optional(row, 'место'),
      equipment: map.optional(row, 'экипировка'),
      itinerary: map.optional(row, 'план'),
      price: GoogleSheetsValueParser.parsePrice(map.optional(row, 'цена')),
      prepayPercent: GoogleSheetsValueParser.parsePrepayPercent(map.optional(row, 'предоплата')),
      participantsLimit: GoogleSheetsValueParser.parseParticipantsLimit(map.optional(row, 'лимит')),
    );
  }

  int? _firstEmptyRow(_SheetSnapshot snapshot) {
    final map = _HeaderMap.from(snapshot);
    for (var rowNumber = 2; rowNumber <= _maxDataRow; rowNumber++) {
      final index = rowNumber - 1;
      final row = index < snapshot.rows.length ? snapshot.rows[index] : const <Object?>[];
      if (map.isEmptyDataRow(row)) {
        return rowNumber;
      }
    }
    return null;
  }

  ScheduleCatalogItem? _findByIdentity(_SheetSnapshot snapshot, ScheduleCatalogItem identity) {
    final items = _parseItems(snapshot, identity.category);
    for (final item in items) {
      if (item.sheetRow == identity.sheetRow && item.matchesIdentity(identity)) {
        return item;
      }
    }
    for (final item in items) {
      if (item.matchesIdentity(identity)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _writeDraft({
    required _SheetSnapshot snapshot,
    required int row,
    required ScheduleEventDraft draft,
  }) async {
    final map = _HeaderMap.from(snapshot);
    final quoted = quoteA1SheetTitle(snapshot.spec.title);
    final cells = <MapEntry<int, Object?>>[];

    void put(String header, Object? value, {bool clear = false}) {
      final index = map.indexOfSpecHeader(header);
      if (index == null) {
        return;
      }
      if (map.isStatusIndex(index)) {
        return;
      }
      if (value != null) {
        cells.add(MapEntry<int, Object?>(index, value));
      } else if (clear) {
        cells.add(MapEntry<int, Object?>(index, ''));
      }
    }

    put('название', draft.title);
    put('дата', draft.date);
    put('время', draft.time);
    put('место', draft.location);
    put('карта', draft.locationUrl);
    put('тренер', draft.coach);
    put('цена', draft.price);
    put('лимит', draft.participantsLimit);
    put('заметки', draft.notes);
    put('тренеры_в_лимите', draft.includeTrainersInParticipants);
    put('без_промокода', draft.promoRestricted);
    put('дата_с', draft.dateFrom);
    put('дата_по', draft.dateTo, clear: draft.clearDateTo);
    put('описание', draft.description);
    put('предоплата', draft.prepayPercent, clear: draft.clearPrepay);
    put('экипировка', draft.equipment);
    put('план', draft.itinerary);

    for (final cell in cells) {
      final letter = GoogleSheetsInputUi.columnLetter(cell.key);
      await _gateway.updateValues(
        a1Range: '$quoted!$letter$row',
        rows: <List<Object?>>[
          <Object?>[cell.value],
        ],
        valueInputOption: 'USER_ENTERED',
      );
    }
  }

  Future<void> _deleteRow(_SheetSnapshot snapshot, int sheetRow) async {
    if (sheetRow < 2) {
      throw const ScheduleCatalogFailure(
        ScheduleCatalogErrorCode.invalidValue,
        'Нельзя удалить шапку листа.',
      );
    }
    await _gateway.deleteDimension(
      sheetId: snapshot.sheetId,
      dimension: 'ROWS',
      startIndex: sheetRow - 1,
      endIndex: sheetRow,
    );
  }

  bool _isListed(ScheduleCatalogItem item, DateTime now, int timezoneOffsetHours) {
    final nowLocal = inBusinessTimezone(now, timezoneOffsetHours: timezoneOffsetHours);
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    if (item.training != null) {
      final startLocal = inBusinessTimezone(
        item.training!.startsAt,
        timezoneOffsetHours: timezoneOffsetHours,
      );
      final startDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
      return !startDay.isBefore(today);
    }
    final endLocal = inBusinessTimezone(
      item.outdoor!.dateTo,
      timezoneOffsetHours: timezoneOffsetHours,
    );
    final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day);
    return !endDay.isBefore(today);
  }

  bool _isExpired(ScheduleCatalogItem item, DateTime now, int timezoneOffsetHours) {
    final nowLocal = inBusinessTimezone(now, timezoneOffsetHours: timezoneOffsetHours);
    final endLocal = inBusinessTimezone(item.endsAt, timezoneOffsetHours: timezoneOffsetHours);
    return !nowLocal.isBefore(endLocal.add(const Duration(days: 2)));
  }

  GoogleSheetsInputSheetSpec _specFor(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => GoogleSheetsInputUi.trainings,
      ActivityCategory.hikes => GoogleSheetsInputUi.hikes,
      ActivityCategory.trails => GoogleSheetsInputUi.trails,
    };
  }
}

final class _SheetSnapshot {
  _SheetSnapshot({
    required this.spec,
    required this.sheetId,
    required this.rows,
  });

  final GoogleSheetsInputSheetSpec spec;
  final int sheetId;
  final List<List<Object?>> rows;
}

final class _HeaderMap {
  _HeaderMap({
    required this.liveHeaders,
    required this.specByLiveIndex,
    required this.liveIndexBySpecHeader,
    required this.statusIndexes,
  });

  final List<String> liveHeaders;
  final List<GoogleSheetsInputColumn?> specByLiveIndex;
  final Map<String, int> liveIndexBySpecHeader;
  final Set<int> statusIndexes;

  factory _HeaderMap.from(_SheetSnapshot snapshot) {
    final raw = snapshot.rows.isEmpty ? const <Object?>[] : snapshot.rows.first;
    final liveHeaders = [
      for (final cell in raw) GoogleSheetsValueParser.cellString(cell),
    ];
    final specByLiveIndex = <GoogleSheetsInputColumn?>[];
    final liveIndexBySpecHeader = <String, int>{};
    final statusIndexes = <int>{};
    for (var i = 0; i < liveHeaders.length; i++) {
      final column = snapshot.spec.matchingColumn(liveHeaders[i]);
      specByLiveIndex.add(column);
      if (column == null) {
        continue;
      }
      liveIndexBySpecHeader[column.header] = i;
      if (column.isStatus) {
        statusIndexes.add(i);
      }
    }
    return _HeaderMap(
      liveHeaders: liveHeaders,
      specByLiveIndex: specByLiveIndex,
      liveIndexBySpecHeader: liveIndexBySpecHeader,
      statusIndexes: statusIndexes,
    );
  }

  int? indexOfSpecHeader(String header) => liveIndexBySpecHeader[header];

  bool isStatusIndex(int index) => statusIndexes.contains(index);

  String cell(List<Object?> row, String header) {
    final index = liveIndexBySpecHeader[header];
    if (index == null) {
      return '';
    }
    return GoogleSheetsValueParser.cell(row, index);
  }

  String? optional(List<Object?> row, String header) {
    final value = cell(row, header);
    return value.isEmpty ? null : value;
  }

  bool isEmptyDataRow(List<Object?> row) {
    final width = liveHeaders.length;
    for (var i = 0; i < width; i++) {
      if (statusIndexes.contains(i)) {
        continue;
      }
      if (GoogleSheetsValueParser.cell(row, i).isNotEmpty) {
        return false;
      }
    }
    return true;
  }
}
