import 'package:dvor_chatbot/src/data/google_sheets_api_writer.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsApiWriter', () {
    test('creates a missing sheet, then clears and replaces values', () async {
      final gateway = _FakeSpreadsheetGateway();
      final writer = GoogleSheetsApiWriter(gateway: gateway);

      await writer.replaceSheet(
        sheetTitle: 'FUNNEL',
        rows: const <List<Object?>>[
          <Object?>['id', 'status'],
          <Object?>[1, 'paid'],
        ],
      );

      expect(gateway.addedTitles, <String>['FUNNEL']);
      expect(gateway.clearedRanges, <String>["'FUNNEL'!A:Z"]);
      expect(gateway.updatedRanges, <String>["'FUNNEL'!A1"]);
      expect(gateway.updatedRows.single, hasLength(2));
    });

    test('does not recreate a sheet that already exists', () async {
      final gateway = _FakeSpreadsheetGateway(existingTitles: <String>{'FUNNEL'});
      final writer = GoogleSheetsApiWriter(gateway: gateway);

      await writer.replaceSheet(
        sheetTitle: 'FUNNEL',
        rows: const <List<Object?>>[
          <Object?>['id'],
        ],
      );

      expect(gateway.addedTitles, isEmpty);
      expect(gateway.clearedRanges, isNotEmpty);
    });

    test('rebuilds FUNNEL dashboard and deletes bot_bookings', () async {
      final gateway = _FakeSpreadsheetGateway(
        existingTitles: <String>{'schedule', 'bot_bookings'},
      );
      final writer = GoogleSheetsApiWriter(gateway: gateway);
      const dashboard = GoogleSheetsDashboard(
        sheetTitle: 'FUNNEL',
        rows: <List<Object?>>[
          <Object?>['DVOR · Воронка'],
        ],
        charts: <GoogleSheetsChart>[
          GoogleSheetsChart(
            title: 'Путь новичка',
            kind: GoogleSheetsChartKind.bar,
            headerRow: 0,
            endRowExclusive: 3,
            labelColumn: 0,
            valueColumn: 1,
            anchorRow: 0,
            anchorColumn: 3,
          ),
        ],
        styles: <GoogleSheetsRangeStyle>[
          GoogleSheetsRangeStyle(
            startRow: 0,
            endRowExclusive: 1,
            startColumn: 0,
            endColumnExclusive: 4,
            bold: true,
            merge: true,
          ),
        ],
        columnWidthsPx: <int>[200, 100],
      );

      await writer.replaceDashboard(dashboard);

      expect(gateway.deletedTitles, contains('bot_bookings'));
      expect(gateway.addedTitles, contains('FUNNEL'));
      expect(gateway.appliedDashboards, 1);
      expect(gateway.updatedRows.single.first.first, 'DVOR · Воронка');
    });
  });
}

final class _FakeSpreadsheetGateway implements GoogleSheetsSpreadsheetGateway {
  _FakeSpreadsheetGateway({Set<String> existingTitles = const <String>{}}) {
    var nextId = 1;
    for (final title in existingTitles) {
      titles[title] = nextId;
      nextId += 1;
    }
    _nextId = nextId;
  }

  final Map<String, int> titles = <String, int>{};
  final List<String> addedTitles = <String>[];
  final List<String> deletedTitles = <String>[];
  final List<String> clearedRanges = <String>[];
  final List<String> updatedRanges = <String>[];
  final List<String> updatedValueInputOptions = <String>[];
  final List<List<List<Object?>>> updatedRows = <List<List<Object?>>>[];
  final List<String> getValueRanges = <String>[];
  final List<({int sheetId, String dimension, int startIndex, int endIndex})> deletedDimensions =
      <({int sheetId, String dimension, int startIndex, int endIndex})>[];
  final Map<String, List<List<Object?>>> grids = <String, List<List<Object?>>>{};
  int appliedDashboards = 0;
  late int _nextId;

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
  Future<void> addSheet(String title) async {
    addedTitles.add(title);
    titles[title] = _nextId;
    _nextId += 1;
  }

  @override
  Future<void> deleteSheet(int sheetId) async {
    final match = titles.entries.where((entry) => entry.value == sheetId);
    if (match.isEmpty) {
      return;
    }
    final title = match.first.key;
    deletedTitles.add(title);
    titles.remove(title);
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
    updatedRows.add(rows);
    _applyUpdate(a1Range, rows);
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
    if (dimension != 'ROWS') {
      return;
    }
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

  void _applyUpdate(String a1Range, List<List<Object?>> rows) {
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
    return (
      row: int.parse(match.group(2)!) - 1,
      column: _columnIndex(match.group(1)!),
    );
  }

  int _columnIndex(String letters) {
    var n = 0;
    for (final code in letters.codeUnits) {
      n = n * 26 + (code - 64);
    }
    return n - 1;
  }

  @override
  Future<void> applyDashboardLook({
    required int sheetId,
    required GoogleSheetsDashboard dashboard,
  }) async {
    appliedDashboards += 1;
  }

  @override
  Future<void> close() async {}
}
