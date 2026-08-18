/// RGB in 0..1, for Google Sheets CellFormat / charts.
final class GoogleSheetsRgb {
  const GoogleSheetsRgb(this.red, this.green, this.blue);

  final double red;
  final double green;
  final double blue;
}

enum GoogleSheetsChartKind { bar, column, pie }

final class GoogleSheetsChart {
  const GoogleSheetsChart({
    required this.title,
    required this.kind,
    required this.headerRow,
    required this.endRowExclusive,
    required this.labelColumn,
    required this.valueColumn,
    required this.anchorRow,
    required this.anchorColumn,
    this.widthPixels = 480,
    this.heightPixels = 260,
    this.pieHole,
    this.legendPosition = 'RIGHT_LEGEND',
  });

  final String title;
  final GoogleSheetsChartKind kind;

  /// Inclusive header row (0-based). Data is `(headerRow+1)..endRowExclusive`.
  final int headerRow;
  final int endRowExclusive;
  final int labelColumn;
  final int valueColumn;
  final int anchorRow;
  final int anchorColumn;
  final int widthPixels;
  final int heightPixels;
  final double? pieHole;
  final String legendPosition;

  bool get hasData => endRowExclusive > headerRow + 1;
}

final class GoogleSheetsRangeStyle {
  const GoogleSheetsRangeStyle({
    required this.startRow,
    required this.endRowExclusive,
    required this.startColumn,
    required this.endColumnExclusive,
    this.background,
    this.foreground,
    this.bold = false,
    this.fontSize,
    this.merge = false,
    this.horizontalAlignment,
    this.verticalAlignment,
    this.numberFormatType,
    this.numberFormatPattern,
    this.wrap = false,
    this.borders = false,
    this.innerBorders = false,
  });

  final int startRow;
  final int endRowExclusive;
  final int startColumn;
  final int endColumnExclusive;
  final GoogleSheetsRgb? background;
  final GoogleSheetsRgb? foreground;
  final bool bold;
  final int? fontSize;
  final bool merge;
  final String? horizontalAlignment;
  final String? verticalAlignment;
  final String? numberFormatType;
  final String? numberFormatPattern;
  final bool wrap;
  final bool borders;
  final bool innerBorders;
}

final class GoogleSheetsBandedTable {
  const GoogleSheetsBandedTable({
    required this.startRow,
    required this.endRowExclusive,
    required this.startColumn,
    required this.endColumnExclusive,
  });

  final int startRow;
  final int endRowExclusive;
  final int startColumn;
  final int endColumnExclusive;
}

final class GoogleSheetsDashboard {
  const GoogleSheetsDashboard({
    required this.sheetTitle,
    required this.rows,
    required this.charts,
    required this.styles,
    this.bandedTables = const <GoogleSheetsBandedTable>[],
    this.columnWidthsPx = const <int>[],
    this.obsoleteSheetTitles = const <String>['bot_bookings'],
  });

  final String sheetTitle;
  final List<List<Object?>> rows;
  final List<GoogleSheetsChart> charts;
  final List<GoogleSheetsRangeStyle> styles;
  final List<GoogleSheetsBandedTable> bandedTables;
  final List<int> columnWidthsPx;
  final List<String> obsoleteSheetTitles;
}

final class GoogleSheetsSheetInfo {
  const GoogleSheetsSheetInfo({
    required this.title,
    required this.sheetId,
    this.chartIds = const <int>[],
  });

  final String title;
  final int sheetId;
  final List<int> chartIds;
}
