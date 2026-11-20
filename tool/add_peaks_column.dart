import 'dart:io';

import 'package:dvor_chatbot/src/data/google_sheets_credentials.dart';
import 'package:dvor_chatbot/src/data/google_sheets_input_ui.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

/// Adds the `без_вершинок` checkbox column to the live Тренировки / Походы /
/// Трейлы sheets when it is missing. Safe to re-run.
///
///   GOOGLE_SHEETS_CREDENTIALS_PATH=secrets/google-sheets.json \
///     dart run tool/add_peaks_column.dart
Future<void> main() async {
  final path = Platform.environment['GOOGLE_SHEETS_CREDENTIALS_PATH'];
  if (path == null || path.isEmpty) {
    stderr.writeln('Set GOOGLE_SHEETS_CREDENTIALS_PATH.');
    exitCode = 64;
    return;
  }
  final client = await clientViaServiceAccount(
    ServiceAccountCredentials.fromJson(loadGoogleSheetsServiceAccountJson(path: path)),
    const <String>[SheetsApi.spreadsheetsScope],
  );
  try {
    final api = SheetsApi(client);
    const id = GoogleSheetsInputUi.spreadsheetId;
    const header = 'без_вершинок';
    for (final spec in <GoogleSheetsInputSheetSpec>[
      GoogleSheetsInputUi.trainings,
      GoogleSheetsInputUi.hikes,
      GoogleSheetsInputUi.trails,
    ]) {
      final meta = await api.spreadsheets.get(id, $fields: 'sheets.properties');
      final sheet = meta.sheets!.firstWhere((s) => s.properties?.sheetId == spec.gid);
      final title = sheet.properties!.title!;
      final quoted = "'${title.replaceAll("'", "''")}'";
      final rows = (await api.spreadsheets.values.get(id, '$quoted!1:1')).values;
      final headers = <String>[
        for (final cell in (rows == null || rows.isEmpty ? const <Object?>[] : rows.first))
          GoogleSheetsInputUi.normalizeHeader('$cell'),
      ];
      if (headers.contains(header)) {
        stdout.writeln('$title: already has $header');
        continue;
      }
      var column = headers.indexWhere((h) => h.isEmpty);
      if (column < 0) {
        column = headers.length;
      }
      final grid = sheet.properties!.gridProperties;
      final columnCount = grid?.columnCount ?? 0;
      if (column >= columnCount) {
        await api.spreadsheets.batchUpdate(
          BatchUpdateSpreadsheetRequest(requests: <Request>[
            Request(
              appendDimension: AppendDimensionRequest(
                sheetId: spec.gid,
                dimension: 'COLUMNS',
                length: column + 1 - columnCount,
              ),
            ),
          ]),
          id,
        );
      }
      final letter = GoogleSheetsInputUi.columnLetter(column);
      await api.spreadsheets.values.update(
        ValueRange(values: <List<Object?>>[
          <Object?>[header],
        ]),
        id,
        '$quoted!${letter}1',
        valueInputOption: 'USER_ENTERED',
      );
      final sheetId = spec.gid;
      await api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(requests: <Request>[
          Request(
            setDataValidation: SetDataValidationRequest(
              range: GridRange(
                sheetId: sheetId,
                startRowIndex: 1,
                endRowIndex: grid?.rowCount ?? 500,
                startColumnIndex: column,
                endColumnIndex: column + 1,
              ),
              rule: DataValidationRule(
                condition: BooleanCondition(type: 'BOOLEAN'),
                showCustomUi: true,
                strict: false,
              ),
            ),
          ),
        ]),
        id,
      );
      stdout.writeln('$title: added $header in column $letter');
    }
  } finally {
    client.close();
  }
}
