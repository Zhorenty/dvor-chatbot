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

    test('uses Russian working headers and keeps status last', () {
      expect(
        GoogleSheetsInputUi.trainings.columns.map((column) => column.header).toList(),
        <String>[
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
      );
      expect(
        GoogleSheetsInputUi.hikes.columns.map((column) => column.header),
        GoogleSheetsInputUi.trails.columns.map((column) => column.header),
      );
      expect(GoogleSheetsInputUi.hikes.columns.map((column) => column.header).take(4), <String>[
        'название',
        'дата_с',
        'дата_по',
        'описание',
      ]);
      for (final sheet in GoogleSheetsInputUi.sheets) {
        expect(sheet.columns.last.header, GoogleSheetsInputUi.statusHeader);
        expect(sheet.columns.last.kind, GoogleSheetsInputColumnKind.status);
      }
    });

    test('keeps a large empty-row buffer and a short category list', () {
      expect(GoogleSheetsInputUi.extraRows, greaterThanOrEqualTo(150));
      expect(GoogleSheetsInputUi.categoryDropdownValues, <String>[
        'все',
        'Тренировки',
        'Походы',
        'Трейлы',
      ]);
    });

    test('maps English live headers to the Russian spec', () {
      expect(GoogleSheetsInputUi.trainings.matchingColumn('title')?.header, 'название');
      expect(GoogleSheetsInputUi.trainings.matchingColumn('include_trainers')?.header,
          'тренеры_в_лимите');
      expect(GoogleSheetsInputUi.hikes.matchingColumn('date_from')?.header, 'дата_с');
      expect(GoogleSheetsInputUi.promoCodes.matchingColumn('code')?.header, 'промокод');
    });

    test('status formula names missing required fields and default prepay', () {
      final formula = GoogleSheetsInputUi.statusFormula(
        spec: GoogleSheetsInputUi.hikes,
        formulaSep: ';',
        targetRows: 50,
      );
      expect(formula, startsWith('='));
      expect(formula, contains('готово'));
      expect(formula, contains('нет названия'));
      expect(formula, contains('нет описания'));
      expect(formula, contains('предоплата 50% по умолчанию'));
      expect(formula, contains('дата_по пусто = один день'));
    });
  });
}
