import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:intl/intl.dart';

/// Shared palette and layout helpers for bot-owned dashboards.
/// Colors match [GoogleSheetsFunnelDashboard].
abstract final class GoogleSheetsDashboardTheme {
  static const int columnCount = GoogleSheetsFunnelDashboard.columnCount;
  static const GoogleSheetsRgb ink = GoogleSheetsFunnelDashboard.ink;
  static const GoogleSheetsRgb paper = GoogleSheetsFunnelDashboard.paper;
  static const GoogleSheetsRgb header = GoogleSheetsFunnelDashboard.header;
  static const GoogleSheetsRgb headerText = GoogleSheetsFunnelDashboard.headerText;
  static const GoogleSheetsRgb muted = GoogleSheetsFunnelDashboard.muted;
  static const GoogleSheetsRgb kpiA = GoogleSheetsFunnelDashboard.kpiA;
  static const GoogleSheetsRgb kpiB = GoogleSheetsFunnelDashboard.kpiB;
  static const GoogleSheetsRgb kpiC = GoogleSheetsFunnelDashboard.kpiC;
  static const GoogleSheetsRgb section = GoogleSheetsFunnelDashboard.section;
  static const GoogleSheetsRgb tableHead = GoogleSheetsFunnelDashboard.tableHead;

  static const List<GoogleSheetsRgb> kpiCycle = <GoogleSheetsRgb>[kpiA, kpiB, kpiC];

  static final DateFormat stamp = DateFormat('dd.MM.yyyy HH:mm');
}

final class GoogleSheetsKpiCard {
  const GoogleSheetsKpiCard({
    required this.label,
    required this.value,
    this.hint = '',
    this.numberFormatType,
    this.numberFormatPattern,
  });

  final String label;
  final Object value;
  final String hint;
  final String? numberFormatType;
  final String? numberFormatPattern;
}

final class GoogleSheetsSheetBuilder {
  GoogleSheetsSheetBuilder({this.columnCount = GoogleSheetsDashboardTheme.columnCount});

  final int columnCount;
  final List<List<Object?>> rows = <List<Object?>>[];
  final List<GoogleSheetsRangeStyle> styles = <GoogleSheetsRangeStyle>[];
  final List<GoogleSheetsBandedTable> bandedTables = <GoogleSheetsBandedTable>[];
  final List<GoogleSheetsChart> charts = <GoogleSheetsChart>[];

  int get nextRow => rows.length;

  void paintSheet({int minRows = 40}) {
    final endRow = rows.length > minRows ? rows.length : minRows;
    styles.insert(
      0,
      GoogleSheetsRangeStyle(
        startRow: 0,
        endRowExclusive: endRow,
        startColumn: 0,
        endColumnExclusive: columnCount,
        background: GoogleSheetsDashboardTheme.paper,
        foreground: GoogleSheetsDashboardTheme.ink,
        fontSize: 10,
        wrap: true,
      ),
    );
  }

  void writeBanner({
    required String title,
    required DateTime generatedAt,
    required String subtitle,
  }) {
    final stamp = GoogleSheetsDashboardTheme.stamp.format(generatedAt.toLocal());
    final titleCells = List<Object?>.filled(columnCount, '');
    titleCells[0] = title;
    titleCells[columnCount - 1] = 'Срез $stamp';
    add(titleCells);
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: 0,
        endRowExclusive: 1,
        startColumn: 0,
        endColumnExclusive: columnCount - 1,
        background: GoogleSheetsDashboardTheme.header,
        foreground: GoogleSheetsDashboardTheme.headerText,
        bold: true,
        fontSize: 18,
        merge: true,
        verticalAlignment: 'MIDDLE',
      ),
    );
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: 0,
        endRowExclusive: 1,
        startColumn: columnCount - 1,
        endColumnExclusive: columnCount,
        background: GoogleSheetsDashboardTheme.header,
        foreground: GoogleSheetsDashboardTheme.headerText,
        bold: true,
        fontSize: 11,
        horizontalAlignment: 'RIGHT',
        verticalAlignment: 'MIDDLE',
      ),
    );
    add(<Object?>[subtitle]);
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: 1,
        endRowExclusive: 2,
        startColumn: 0,
        endColumnExclusive: columnCount,
        foreground: GoogleSheetsDashboardTheme.muted,
        fontSize: 10,
        merge: true,
      ),
    );
    blank();
  }

  void writeKpiRow(List<GoogleSheetsKpiCard> cards) {
    if (cards.isEmpty) {
      return;
    }
    final limited = cards.length > 6 ? cards.sublist(0, 6) : cards;
    final labelRow = nextRow;
    final labels = List<Object?>.filled(columnCount, '');
    for (var index = 0; index < limited.length; index++) {
      labels[index * 2] = limited[index].label;
    }
    add(labels);
    final valueRow = nextRow;
    final values = List<Object?>.filled(columnCount, '');
    for (var index = 0; index < limited.length; index++) {
      values[index * 2] = limited[index].value;
    }
    add(values);
    final hintRow = nextRow;
    final hints = List<Object?>.filled(columnCount, '');
    for (var index = 0; index < limited.length; index++) {
      hints[index * 2] = limited[index].hint;
    }
    add(hints);
    for (var index = 0; index < limited.length; index++) {
      final startColumn = index * 2;
      final background =
          GoogleSheetsDashboardTheme.kpiCycle[index % GoogleSheetsDashboardTheme.kpiCycle.length];
      final card = limited[index];
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: labelRow,
          endRowExclusive: labelRow + 1,
          startColumn: startColumn,
          endColumnExclusive: startColumn + 2,
          background: background,
          foreground: GoogleSheetsDashboardTheme.muted,
          bold: true,
          fontSize: 9,
          merge: true,
          horizontalAlignment: 'CENTER',
          verticalAlignment: 'MIDDLE',
          wrap: true,
        ),
      );
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: valueRow,
          endRowExclusive: valueRow + 1,
          startColumn: startColumn,
          endColumnExclusive: startColumn + 2,
          background: background,
          foreground: GoogleSheetsDashboardTheme.ink,
          bold: true,
          fontSize: 18,
          merge: true,
          horizontalAlignment: 'CENTER',
          verticalAlignment: 'MIDDLE',
          numberFormatType: card.numberFormatType,
          numberFormatPattern: card.numberFormatPattern,
        ),
      );
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: hintRow,
          endRowExclusive: hintRow + 1,
          startColumn: startColumn,
          endColumnExclusive: startColumn + 2,
          background: background,
          foreground: GoogleSheetsDashboardTheme.muted,
          fontSize: 9,
          merge: true,
          horizontalAlignment: 'CENTER',
          verticalAlignment: 'MIDDLE',
          wrap: true,
        ),
      );
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: labelRow,
          endRowExclusive: hintRow + 1,
          startColumn: startColumn,
          endColumnExclusive: startColumn + 2,
          borders: true,
        ),
      );
    }
    blank();
  }

  void section(String title) {
    final row = nextRow;
    add(<Object?>[title]);
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: row,
        endRowExclusive: row + 1,
        startColumn: 0,
        endColumnExclusive: columnCount,
        background: GoogleSheetsDashboardTheme.section,
        foreground: GoogleSheetsDashboardTheme.headerText,
        bold: true,
        fontSize: 12,
        merge: true,
        verticalAlignment: 'MIDDLE',
      ),
    );
  }

  void subtitle(String text) {
    final row = nextRow;
    add(<Object?>[text]);
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: row,
        endRowExclusive: row + 1,
        startColumn: 0,
        endColumnExclusive: columnCount,
        foreground: GoogleSheetsDashboardTheme.muted,
        fontSize: 9,
        merge: true,
        wrap: true,
      ),
    );
  }

  void table(int headerRow, int endRowExclusive, int startColumn, int endColumnExclusive) {
    if (endRowExclusive <= headerRow || endColumnExclusive <= startColumn) {
      return;
    }
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: headerRow,
        endRowExclusive: headerRow + 1,
        startColumn: startColumn,
        endColumnExclusive: endColumnExclusive,
        background: GoogleSheetsDashboardTheme.tableHead,
        foreground: GoogleSheetsDashboardTheme.ink,
        bold: true,
        fontSize: 10,
        verticalAlignment: 'MIDDLE',
      ),
    );
    styles.add(
      GoogleSheetsRangeStyle(
        startRow: headerRow,
        endRowExclusive: endRowExclusive,
        startColumn: startColumn,
        endColumnExclusive: endColumnExclusive,
        borders: true,
        innerBorders: true,
      ),
    );
    bandedTables.add(
      GoogleSheetsBandedTable(
        startRow: headerRow,
        endRowExclusive: endRowExclusive,
        startColumn: startColumn,
        endColumnExclusive: endColumnExclusive,
      ),
    );
  }

  void percentColumns(int startRow, int endRowExclusive, List<int> columns) {
    for (final column in columns) {
      styles.add(
        GoogleSheetsRangeStyle(
          startRow: startRow,
          endRowExclusive: endRowExclusive,
          startColumn: column,
          endColumnExclusive: column + 1,
          numberFormatType: 'PERCENT',
          numberFormatPattern: '0.0%',
        ),
      );
    }
  }

  void blank() => add(const <Object?>[]);

  void add(List<Object?> cells) {
    final row = List<Object?>.filled(columnCount, '');
    final limit = cells.length < columnCount ? cells.length : columnCount;
    for (var index = 0; index < limit; index++) {
      row[index] = cells[index];
    }
    rows.add(row);
  }

  Object ratioOrDash(double? value) => value ?? '—';

  GoogleSheetsDashboard toDashboard({
    required String sheetTitle,
    required List<int> columnWidthsPx,
    List<String> obsoleteSheetTitles = const <String>[],
    int frozenRowCount = 1,
    int minPaintRows = 40,
  }) {
    paintSheet(minRows: minPaintRows);
    return GoogleSheetsDashboard(
      sheetTitle: sheetTitle,
      rows: rows,
      charts: charts.where((chart) => chart.hasData).toList(growable: false),
      styles: styles,
      bandedTables: bandedTables,
      columnWidthsPx: columnWidthsPx,
      obsoleteSheetTitles: obsoleteSheetTitles,
      frozenRowCount: frozenRowCount,
    );
  }
}
