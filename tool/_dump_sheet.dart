// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:dvor_chatbot/src/data/google_sheets_credentials.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

Future<void> main() async {
  const spreadsheetId = '1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q';
  const targetGid = 1294309430;
  final credentials = ServiceAccountCredentials.fromJson(
    loadGoogleSheetsServiceAccountJson(path: 'secrets/google-sheets.json'),
  );
  final client = await clientViaServiceAccount(
    credentials,
    const <String>[SheetsApi.spreadsheetsScope],
  );
  try {
    final api = SheetsApi(client);
    final spreadsheet = await api.spreadsheets.get(
      spreadsheetId,
      includeGridData: true,
      ranges: <String>[],
    );
    final sheets = spreadsheet.sheets ?? const <Sheet>[];
    stdout
        .writeln('locale=${spreadsheet.properties?.locale} title=${spreadsheet.properties?.title}');
    stdout.writeln('--- sheets ---');
    Sheet? target;
    for (final sheet in sheets) {
      final p = sheet.properties;
      stdout.writeln(
        'gid=${p?.sheetId} title="${p?.title}" rows=${p?.gridProperties?.rowCount} cols=${p?.gridProperties?.columnCount} tab=${p?.tabColor}',
      );
      if (p?.sheetId == targetGid) {
        target = sheet;
      }
    }
    if (target == null) {
      stderr.writeln('TARGET NOT FOUND');
      exitCode = 1;
      return;
    }
    final title = target.properties?.title ?? '';
    stdout.writeln('\n=== TARGET "$title" ===');
    final values = await api.spreadsheets.values.get(
      spreadsheetId,
      "'${title.replaceAll("'", "''")}'!A1:Z80",
      valueRenderOption: 'FORMATTED_VALUE',
    );
    final rows = values.values ?? const <List<Object?>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final cells = <String>[];
      for (var c = 0; c < row.length; c++) {
        final text = '${row[c]}'.replaceAll('\n', '\\n');
        if (text.trim().isEmpty) continue;
        cells.add('${String.fromCharCode(65 + c)}:$text');
      }
      if (cells.isEmpty) {
        stdout.writeln('${i + 1}|');
      } else {
        stdout.writeln('${i + 1}|${cells.join(' || ')}');
      }
    }

    // formatting snapshot of first rows
    final data = target.data ?? const <GridData>[];
    stdout.writeln('\n=== FORMAT SNAPSHOT ===');
    if (data.isEmpty) {
      stdout.writeln('no grid data');
    }
    for (final grid in data) {
      final metaRows = grid.rowMetadata ?? const <DimensionProperties>[];
      for (var r = 0; r < metaRows.length && r < 12; r++) {
        stdout.writeln('rowHeight ${r + 1}=${metaRows[r].pixelSize}');
      }
      final rowData = grid.rowData ?? const <RowData>[];
      final startRow = grid.startRow ?? 0;
      final startCol = grid.startColumn ?? 0;
      for (var r = 0; r < rowData.length && r < 40; r++) {
        final cells = rowData[r].values ?? const <CellData>[];
        for (var c = 0; c < cells.length && c < 8; c++) {
          final cell = cells[c];
          final text = cell.formattedValue ?? cell.userEnteredValue?.stringValue ?? '';
          if (text.trim().isEmpty && cell.userEnteredFormat == null) continue;
          final fmt = cell.userEnteredFormat;
          final bg = fmt?.backgroundColor;
          final fg = fmt?.textFormat?.foregroundColor;
          final bold = fmt?.textFormat?.bold;
          final size = fmt?.textFormat?.fontSize;
          final note = cell.note;
          stdout.writeln(
            'r${startRow + r + 1}c${startCol + c + 1} bold=$bold size=$size '
            'bg=${_rgb(bg)} fg=${_rgb(fg)} wrap=${fmt?.wrapStrategy} '
            'align=${fmt?.horizontalAlignment} note=${note == null ? "" : "yes"} '
            'text=${text.replaceAll("\n", " / ").substring(0, text.length > 180 ? 180 : text.length)}',
          );
        }
      }
    }
    final merges = target.merges ?? const <GridRange>[];
    stdout.writeln('\nmerges=${merges.length}');
    for (final m in merges.take(30)) {
      stdout.writeln(
        'merge r${m.startRowIndex}-${m.endRowIndex} c${m.startColumnIndex}-${m.endColumnIndex}',
      );
    }
    stdout.writeln(jsonEncode({
      'title': target.properties?.title,
      'frozen': target.properties?.gridProperties?.frozenRowCount,
      'rows': target.properties?.gridProperties?.rowCount,
      'cols': target.properties?.gridProperties?.columnCount,
      'banded': target.bandedRanges?.length,
      'filter': target.basicFilter != null,
    }));
  } finally {
    client.close();
  }
}

String _rgb(Color? c) {
  if (c == null) return '-';
  String n(double? v) => ((v ?? 0) * 100).round().toString();
  return '${n(c.red)},${n(c.green)},${n(c.blue)}';
}
