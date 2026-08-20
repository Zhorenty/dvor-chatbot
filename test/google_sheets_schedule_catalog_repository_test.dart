import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_input_ui.dart';
import 'package:dvor_chatbot/src/data/google_sheets_schedule_catalog_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/schedule_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsScheduleCatalogRepository', () {
    test('create writes russian data columns and skips статус', () async {
      final gateway = _CatalogGateway()..seedTrainings();
      final repository = GoogleSheetsScheduleCatalogRepository(gateway: gateway);

      final created = await repository.create(
        const ScheduleEventDraft(
          category: ActivityCategory.trainings,
          title: 'BOXING DVOR',
          date: '19.08.2026',
          time: '19:30',
          location: 'Стадион Кубань',
          price: 350,
        ),
      );

      expect(created.title, 'BOXING DVOR');
      expect(created.sheetRow, 2);
      expect(gateway.updatedValueInputOptions, everyElement('USER_ENTERED'));
      expect(gateway.updatedRanges, isNot(contains(contains('L2'))));
      expect(gateway.clearedRanges, isEmpty);
      expect(gateway.deletedTitles, isEmpty);
      final row = gateway.grids['Тренировки']![1];
      expect(row[0], 'BOXING DVOR');
      expect(row[1], '19.08.2026');
      expect(row[2], '19:30');
      expect(row[3], 'Стадион Кубань');
      expect(row[6], 350);
      expect(row.length < 12 || row[11] == '' || row[11] == 'формула', isTrue);
    });

    test('update does not overwrite other fields or статус', () async {
      final gateway = _CatalogGateway()..seedTrainings(withEvent: true);
      gateway.grids['Тренировки']![1][11] = 'готово';
      final repository = GoogleSheetsScheduleCatalogRepository(gateway: gateway);
      final identity = (await repository.listEvents(
        ActivityCategory.trainings,
        now: DateTime(2026, 8, 1),
      ))
          .single;

      await repository.update(
        identity: identity,
        patch: const ScheduleEventDraft(
          category: ActivityCategory.trainings,
          location: 'Парк',
        ),
      );

      final row = gateway.grids['Тренировки']![1];
      expect(row[0], 'BOXING DVOR');
      expect(row[3], 'Парк');
      expect(row[11], 'готово');
    });

    test('delete removes the matching row', () async {
      final gateway = _CatalogGateway()..seedTrainings(withEvent: true);
      final repository = GoogleSheetsScheduleCatalogRepository(gateway: gateway);
      final identity = (await repository.listEvents(
        ActivityCategory.trainings,
        now: DateTime(2026, 8, 1),
      ))
          .single;

      await repository.delete(identity);

      expect(gateway.deletedDimensions, hasLength(1));
      expect(gateway.deletedDimensions.single.startIndex, 1);
      expect(gateway.deletedDimensions.single.endIndex, 2);
      expect(gateway.grids['Тренировки'], hasLength(1));
    });

    test('empty data row is not an event', () async {
      final gateway = _CatalogGateway()..seedTrainings();
      gateway.grids['Тренировки']!.add(<Object?>['', '', '', '', '', '', '', '', '', '', '', '']);
      final repository = GoogleSheetsScheduleCatalogRepository(gateway: gateway);

      final items = await repository.listEvents(
        ActivityCategory.trainings,
        now: DateTime(2026, 8, 1),
        includePast: true,
      );

      expect(items, isEmpty);
    });

    test('create uses the first empty formatted row', () async {
      final gateway = _CatalogGateway()..seedTrainings(withEvent: true);
      gateway.grids['Тренировки']!.add(<Object?>['', '', '', '']);
      final repository = GoogleSheetsScheduleCatalogRepository(gateway: gateway);

      final created = await repository.create(
        const ScheduleEventDraft(
          category: ActivityCategory.trainings,
          title: 'RUN',
          date: '20.08.2026',
          time: '8:30',
          location: 'Набережная',
        ),
      );

      expect(created.sheetRow, 3);
    });

    test('retention keeps yesterday and deletes after two days; outdoor uses dateTo', () async {
      final gateway = _CatalogGateway()
        ..seedTrainings()
        ..seedOutdoor(GoogleSheetsInputUi.hikes.title)
        ..seedOutdoor(GoogleSheetsInputUi.trails.title)
        ..seedIgnoredSheets();
      gateway.grids['Тренировки']!.add(<Object?>[
        'Old',
        '17.08.2026',
        '19:30',
        'Стадион',
      ]);
      gateway.grids['Тренировки']!.add(<Object?>[
        'Yesterday',
        '19.08.2026',
        '19:30',
        'Стадион',
      ]);
      gateway.grids['Походы']!.add(<Object?>[
        'Hike',
        '15.08.2026',
        '17.08.2026',
        'Лес',
      ]);
      gateway.grids['Походы']!.add(<Object?>[
        '',
        '',
        '',
        '',
      ]);
      final repository = GoogleSheetsScheduleCatalogRepository(gateway: gateway);

      final result = await repository.deleteExpired(
        now: DateTime(2026, 8, 20, 19, 30),
        timezoneOffsetHours: 3,
      );

      expect(result.trainingsDeleted, 1);
      expect(result.hikesDeleted, 1);
      expect(result.trailsDeleted, 0);
      expect(
        result.requestedSheetTitles,
        <String>['Тренировки', 'Походы', 'Трейлы'],
      );
      expect(result.requestedSheetTitles, isNot(contains('FUNNEL')));
      expect(result.requestedSheetTitles, isNot(contains('Тренерский штаб')));
      expect(
        gateway.grids['Тренировки']!.map((row) => row.isEmpty ? '' : row.first),
        contains('Yesterday'),
      );
      expect(
        gateway.grids['Тренировки']!.map((row) => row.isEmpty ? '' : row.first),
        isNot(contains('Old')),
      );
    });
  });
}

final class _CatalogGateway implements GoogleSheetsSpreadsheetGateway {
  _CatalogGateway() {
    titles['Тренировки'] = 0;
    titles['Походы'] = 294119056;
    titles['Трейлы'] = 1220729038;
  }

  final Map<String, int> titles = <String, int>{};
  final Map<String, List<List<Object?>>> grids = <String, List<List<Object?>>>{};
  final List<String> updatedRanges = <String>[];
  final List<String> updatedValueInputOptions = <String>[];
  final List<String> clearedRanges = <String>[];
  final List<String> deletedTitles = <String>[];
  final List<String> getValueRanges = <String>[];
  final List<({int sheetId, String dimension, int startIndex, int endIndex})> deletedDimensions =
      <({int sheetId, String dimension, int startIndex, int endIndex})>[];

  void seedTrainings({bool withEvent = false}) {
    grids['Тренировки'] = <List<Object?>>[
      <Object?>[
        'название',
        'дата',
        'время',
        'место',
        'карта',
        'тренер',
        'цена',
        'лимит',
        'заметки',
        'тренеры_в_лимите',
        'без_промокода',
        'статус',
      ],
    ];
    if (withEvent) {
      grids['Тренировки']!.add(<Object?>[
        'BOXING DVOR',
        '19.08.2026',
        '19:30',
        'Стадион Кубань',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'формула',
      ]);
    }
  }

  void seedOutdoor(String title) {
    grids[title] = <List<Object?>>[
      <Object?>[
        'название',
        'дата_с',
        'дата_по',
        'описание',
        'место',
        'цена',
        'предоплата',
        'лимит',
        'экипировка',
        'план',
        'статус',
      ],
    ];
  }

  void seedIgnoredSheets() {
    titles['FUNNEL'] = 99;
    titles['Тренерский штаб'] = 195037978;
    grids['FUNNEL'] = <List<Object?>>[
      <Object?>['id'],
    ];
    grids['Тренерский штаб'] = <List<Object?>>[
      <Object?>['имя'],
    ];
  }

  @override
  Future<Set<String>> listSheetTitles() async => titles.keys.toSet();

  @override
  Future<List<GoogleSheetsSheetInfo>> describeSheets() async {
    return [
      for (final entry in titles.entries)
        GoogleSheetsSheetInfo(title: entry.key, sheetId: entry.value),
    ];
  }

  @override
  Future<void> addSheet(String title) async {}

  @override
  Future<void> deleteSheet(int sheetId) async {
    final match = titles.entries.where((entry) => entry.value == sheetId);
    if (match.isEmpty) {
      return;
    }
    deletedTitles.add(match.first.key);
    titles.remove(match.first.key);
  }

  @override
  Future<void> clearRange(String a1Range) async {
    clearedRanges.add(a1Range);
  }

  @override
  Future<void> updateValues({
    required String a1Range,
    required List<List<Object?>> rows,
    String valueInputOption = 'RAW',
  }) async {
    updatedRanges.add(a1Range);
    updatedValueInputOptions.add(valueInputOption);
    final title = _titleFromRange(a1Range);
    final grid = grids.putIfAbsent(title, () => <List<Object?>>[]);
    final cell = _a1Start(a1Range);
    for (var r = 0; r < rows.length; r++) {
      final rowIndex = cell.row + r;
      while (grid.length <= rowIndex) {
        grid.add(<Object?>[]);
      }
      final line = grid[rowIndex];
      for (var c = 0; c < rows[r].length; c++) {
        final colIndex = cell.column + c;
        while (line.length <= colIndex) {
          line.add('');
        }
        line[colIndex] = rows[r][c];
      }
    }
  }

  @override
  Future<List<List<Object?>>> getValues(String a1Range) async {
    getValueRanges.add(a1Range);
    final title = _titleFromRange(a1Range);
    return [
      for (final row in grids[title] ?? const <List<Object?>>[]) List<Object?>.from(row),
    ];
  }

  @override
  Future<void> deleteDimension({
    required int sheetId,
    required String dimension,
    required int startIndex,
    required int endIndex,
  }) async {
    deletedDimensions.add(
      (sheetId: sheetId, dimension: dimension, startIndex: startIndex, endIndex: endIndex),
    );
    final title = titles.entries
        .where((entry) => entry.value == sheetId)
        .map((entry) => entry.key)
        .firstOrNull;
    if (title == null) {
      return;
    }
    final grid = grids[title];
    if (grid == null) {
      return;
    }
    for (var i = endIndex - 1; i >= startIndex; i--) {
      if (i >= 0 && i < grid.length) {
        grid.removeAt(i);
      }
    }
  }

  @override
  Future<void> applyDashboardLook({
    required int sheetId,
    required GoogleSheetsDashboard dashboard,
  }) async {}

  @override
  Future<void> close() async {}

  String _titleFromRange(String a1Range) {
    final bang = a1Range.indexOf('!');
    final raw = bang < 0 ? a1Range : a1Range.substring(0, bang);
    return raw.replaceAll("'", '');
  }

  ({int row, int column}) _a1Start(String a1Range) {
    final bang = a1Range.indexOf('!');
    final cell = bang < 0 ? 'A1' : a1Range.substring(bang + 1).split(':').first;
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cell);
    if (match == null) {
      return (row: 0, column: 0);
    }
    var column = 0;
    for (final code in match.group(1)!.codeUnits) {
      column = column * 26 + (code - 64);
    }
    return (row: int.parse(match.group(2)!) - 1, column: column - 1);
  }
}
