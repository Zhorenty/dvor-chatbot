import 'package:dvor_chatbot/src/data/google_sheets_api_writer.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsApiWriter', () {
    test('creates a missing sheet, then clears and replaces values', () async {
      final gateway = _FakeSpreadsheetGateway();
      final writer = GoogleSheetsApiWriter(gateway: gateway);

      await writer.replaceSheet(
        sheetTitle: 'bot_bookings',
        rows: const <List<Object?>>[
          <Object?>['id', 'status'],
          <Object?>[1, 'paid'],
        ],
      );

      expect(gateway.addedTitles, <String>['bot_bookings']);
      expect(gateway.clearedRanges, <String>["'bot_bookings'!A:Z"]);
      expect(gateway.updatedRanges, <String>["'bot_bookings'!A1"]);
      expect(gateway.updatedRows.single, hasLength(2));
    });

    test('does not recreate a sheet that already exists', () async {
      final gateway = _FakeSpreadsheetGateway(existingTitles: <String>{'bot_bookings'});
      final writer = GoogleSheetsApiWriter(gateway: gateway);

      await writer.replaceSheet(
        sheetTitle: 'bot_bookings',
        rows: const <List<Object?>>[
          <Object?>['id'],
        ],
      );

      expect(gateway.addedTitles, isEmpty);
      expect(gateway.clearedRanges, isNotEmpty);
    });
  });
}

final class _FakeSpreadsheetGateway implements GoogleSheetsSpreadsheetGateway {
  _FakeSpreadsheetGateway({Set<String> existingTitles = const <String>{}})
      : titles = Set<String>.from(existingTitles);

  final Set<String> titles;
  final List<String> addedTitles = <String>[];
  final List<String> clearedRanges = <String>[];
  final List<String> updatedRanges = <String>[];
  final List<List<List<Object?>>> updatedRows = <List<List<Object?>>>[];

  @override
  Future<Set<String>> listSheetTitles() async => Set<String>.from(titles);

  @override
  Future<void> addSheet(String title) async {
    addedTitles.add(title);
    titles.add(title);
  }

  @override
  Future<void> clearRange(String a1Range) async {
    clearedRanges.add(a1Range);
  }

  @override
  Future<void> updateValues({
    required String a1Range,
    required List<List<Object?>> rows,
  }) async {
    updatedRanges.add(a1Range);
    updatedRows.add(rows);
  }

  @override
  Future<void> close() async {}
}
