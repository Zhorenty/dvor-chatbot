import 'package:dvor_chatbot/src/data/google_sheets_input_ui.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsInputUi', () {
    test('keeps FUNNEL out of the input-sheet list', () {
      expect(
        GoogleSheetsInputUi.sheets.map((sheet) => sheet.title),
        isNot(contains(GoogleSheetsInputUi.funnelTitle)),
      );
      expect(GoogleSheetsInputUi.legendTitle, isNot(GoogleSheetsInputUi.funnelTitle));
    });

    test('maps live gids to human tab titles', () {
      expect(
        {
          for (final sheet in GoogleSheetsInputUi.sheets) sheet.gid: sheet.title,
        },
        const <int, String>{
          0: 'Тренировки',
          294119056: 'Походы',
          1220729038: 'Трейлы',
          195037978: 'Тренерский штаб',
          2001400867: 'Команда DVOR',
          432112868: 'Промокоды',
        },
      );
    });

    test('every column has a header note and trails stay visually distinct', () {
      for (final sheet in GoogleSheetsInputUi.sheets) {
        expect(sheet.columns, isNotEmpty);
        for (final column in sheet.columns) {
          expect(column.header, isNotEmpty);
          expect(column.note, isNotEmpty);
          expect(column.widthPx, greaterThan(0));
        }
      }
      expect(
        GoogleSheetsInputUi.trails.tabColor,
        isNot(GoogleSheetsInputUi.hikes.tabColor),
      );
    });

    test('does not invent a title row above CSV headers', () {
      for (final sheet in GoogleSheetsInputUi.sheets) {
        expect(
          sheet.columns.first.header.toLowerCase(),
          isNot(contains('как заполнять')),
        );
      }
    });
  });
}
