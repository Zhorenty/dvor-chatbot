import 'package:dvor_chatbot/src/data/google_sheets_ids.dart';
import 'package:test/test.dart';

void main() {
  group('spreadsheetIdFromSheetsUrl', () {
    test('parses export and edit URLs', () {
      expect(
        spreadsheetIdFromSheetsUrl(
          'https://docs.google.com/spreadsheets/d/1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q/export?format=csv&gid=0',
        ),
        '1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q',
      );
      expect(
        spreadsheetIdFromSheetsUrl(
          'https://docs.google.com/spreadsheets/d/abc-123_ID/edit?gid=0#gid=0',
        ),
        'abc-123_ID',
      );
    });

    test('returns null for empty or unrelated URLs', () {
      expect(spreadsheetIdFromSheetsUrl(null), isNull);
      expect(spreadsheetIdFromSheetsUrl(''), isNull);
      expect(spreadsheetIdFromSheetsUrl('https://example.com/sheet.csv'), isNull);
    });
  });

  group('quoteA1SheetTitle', () {
    test('quotes and escapes single quotes', () {
      expect(quoteA1SheetTitle('bot_bookings'), "'bot_bookings'");
      expect(quoteA1SheetTitle("O'Brien"), "'O''Brien'");
    });
  });
}
