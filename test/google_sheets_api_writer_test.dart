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
  final List<List<List<Object?>>> updatedRows = <List<List<Object?>>>[];
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
    updatedRows.add(rows);
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
