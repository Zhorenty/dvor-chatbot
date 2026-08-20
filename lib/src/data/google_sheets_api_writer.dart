import 'dart:async';

import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/google_sheets_credentials.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_ids.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/telegram/retry.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:l/l.dart';

final class GoogleSheetsApiWriter implements GoogleSheetsWriter {
  GoogleSheetsApiWriter({
    required GoogleSheetsSpreadsheetGateway gateway,
    Duration requestTimeout = const Duration(seconds: 25),
  })  : _gateway = gateway,
        _requestTimeout = requestTimeout;

  final GoogleSheetsSpreadsheetGateway _gateway;
  final Duration _requestTimeout;

  GoogleSheetsSpreadsheetGateway get gateway => _gateway;

  static Future<GoogleSheetsApiWriter> connectFromConfig(AppConfig config) {
    final spreadsheetId = config.googleSheetsSpreadsheetId;
    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      throw StateError(
        'Google Sheets spreadsheet id is missing. '
        'Set GOOGLE_SHEETS_SPREADSHEET_ID or GOOGLE_SHEETS_CSV_URL.',
      );
    }
    final credentials = loadGoogleSheetsServiceAccountJson(
      path: config.googleSheetsCredentialsPath,
      inlineJson: config.googleSheetsCredentialsJson,
    );
    return connect(
      credentialsJson: credentials,
      spreadsheetId: spreadsheetId,
    );
  }

  static Future<GoogleSheetsApiWriter> connect({
    required Map<String, Object?> credentialsJson,
    required String spreadsheetId,
    Duration requestTimeout = const Duration(seconds: 25),
  }) async {
    final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
    final client = await clientViaServiceAccount(
      credentials,
      const <String>[SheetsApi.spreadsheetsScope],
    );
    return GoogleSheetsApiWriter(
      gateway: GoogleApisSheetsGateway(
        api: SheetsApi(client),
        authClient: client,
        spreadsheetId: spreadsheetId,
      ),
      requestTimeout: requestTimeout,
    );
  }

  @override
  Future<void> replaceSheet({
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) {
    return retry(
      () => _replaceSheetOnce(sheetTitle: sheetTitle, rows: rows),
      shouldRetry: _shouldRetry,
    );
  }

  @override
  Future<void> replaceDashboard(GoogleSheetsDashboard dashboard) {
    return retry(
      () => _replaceDashboardOnce(dashboard),
      shouldRetry: _shouldRetry,
    );
  }

  Future<void> _replaceSheetOnce({
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) async {
    final titles = await _gateway.listSheetTitles().timeout(_requestTimeout);
    if (!titles.contains(sheetTitle)) {
      await _gateway.addSheet(sheetTitle).timeout(_requestTimeout);
    }
    final quoted = quoteA1SheetTitle(sheetTitle);
    await _gateway.clearRange('$quoted!A:Z').timeout(_requestTimeout);
    if (rows.isEmpty) {
      return;
    }
    await _gateway.updateValues(a1Range: '$quoted!A1', rows: rows).timeout(_requestTimeout);
  }

  Future<void> _replaceDashboardOnce(GoogleSheetsDashboard dashboard) async {
    var sheets = await _gateway.describeSheets().timeout(_requestTimeout);
    for (final obsolete in dashboard.obsoleteSheetTitles) {
      sheets = await _deleteNamed(sheets, obsolete, keepTitle: dashboard.sheetTitle);
    }
    sheets = await _deleteNamed(sheets, dashboard.sheetTitle, keepTitle: null);
    await _gateway.addSheet(dashboard.sheetTitle).timeout(_requestTimeout);
    sheets = await _gateway.describeSheets().timeout(_requestTimeout);
    final target = _named(sheets, dashboard.sheetTitle);
    if (target == null) {
      throw StateError('Failed to create Google Sheets tab ${dashboard.sheetTitle}.');
    }
    final quoted = quoteA1SheetTitle(dashboard.sheetTitle);
    if (dashboard.rows.isNotEmpty) {
      await _gateway
          .updateValues(
            a1Range: '$quoted!A1',
            rows: dashboard.rows,
            valueInputOption: 'USER_ENTERED',
          )
          .timeout(_requestTimeout);
    }
    await _gateway
        .applyDashboardLook(sheetId: target.sheetId, dashboard: dashboard)
        .timeout(_requestTimeout);
  }

  Future<List<GoogleSheetsSheetInfo>> _deleteNamed(
    List<GoogleSheetsSheetInfo> sheets,
    String title, {
    required String? keepTitle,
  }) async {
    final match = _named(sheets, title);
    if (match == null || match.title == keepTitle) {
      return sheets;
    }
    if (sheets.length <= 1) {
      return sheets;
    }
    await _gateway.deleteSheet(match.sheetId).timeout(_requestTimeout);
    return _gateway.describeSheets().timeout(_requestTimeout);
  }

  GoogleSheetsSheetInfo? _named(List<GoogleSheetsSheetInfo> sheets, String title) {
    for (final sheet in sheets) {
      if (sheet.title == title) {
        return sheet;
      }
    }
    return null;
  }

  @override
  Future<void> close() => _gateway.close();

  bool _shouldRetry(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    if (error is DetailedApiRequestError) {
      final status = error.status;
      return status == null || status == 429 || status >= 500;
    }
    return true;
  }
}

final class GoogleApisSheetsGateway implements GoogleSheetsSpreadsheetGateway {
  GoogleApisSheetsGateway({
    required SheetsApi api,
    required String spreadsheetId,
    http.Client? authClient,
  })  : _api = api,
        _spreadsheetId = spreadsheetId,
        _authClient = authClient;

  final SheetsApi _api;
  final String _spreadsheetId;
  final http.Client? _authClient;

  @override
  Future<Set<String>> listSheetTitles() async {
    final sheets = await describeSheets();
    return sheets.map((sheet) => sheet.title).toSet();
  }

  @override
  Future<List<GoogleSheetsSheetInfo>> describeSheets() async {
    final spreadsheet = await _api.spreadsheets.get(
      _spreadsheetId,
      $fields: 'sheets.properties(sheetId,title),sheets.charts.chartId',
    );
    final result = <GoogleSheetsSheetInfo>[];
    for (final sheet in spreadsheet.sheets ?? const <Sheet>[]) {
      final title = sheet.properties?.title;
      final sheetId = sheet.properties?.sheetId;
      if (title == null || sheetId == null) {
        continue;
      }
      result.add(
        GoogleSheetsSheetInfo(
          title: title,
          sheetId: sheetId,
          chartIds: sheet.charts
                  ?.map((chart) => chart.chartId)
                  .whereType<int>()
                  .toList(growable: false) ??
              const <int>[],
        ),
      );
    }
    return result;
  }

  @override
  Future<void> addSheet(String title) async {
    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: <Request>[
          Request(
            addSheet: AddSheetRequest(
              properties: SheetProperties(
                title: title,
                gridProperties: GridProperties(
                  hideGridlines: true,
                  frozenRowCount: 1,
                ),
                tabColor: Color(red: 0.12, green: 0.23, blue: 0.18),
              ),
            ),
          ),
        ],
      ),
      _spreadsheetId,
    );
  }

  @override
  Future<void> deleteSheet(int sheetId) async {
    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: <Request>[
          Request(deleteSheet: DeleteSheetRequest(sheetId: sheetId)),
        ],
      ),
      _spreadsheetId,
    );
  }

  @override
  Future<void> clearRange(String a1Range) async {
    await _api.spreadsheets.values.clear(
      ClearValuesRequest(),
      _spreadsheetId,
      a1Range,
    );
  }

  @override
  Future<void> updateValues({
    required String a1Range,
    required List<List<Object?>> rows,
    String valueInputOption = 'RAW',
  }) async {
    await _api.spreadsheets.values.update(
      ValueRange(values: rows),
      _spreadsheetId,
      a1Range,
      valueInputOption: valueInputOption,
    );
  }

  @override
  Future<List<List<Object?>>> getValues(String a1Range) async {
    final result = await _api.spreadsheets.values.get(
      _spreadsheetId,
      a1Range,
      valueRenderOption: 'FORMATTED_VALUE',
    );
    final values = result.values;
    if (values == null) {
      return const <List<Object?>>[];
    }
    return [
      for (final row in values) <Object?>[...row],
    ];
  }

  @override
  Future<void> deleteDimension({
    required int sheetId,
    required String dimension,
    required int startIndex,
    required int endIndex,
  }) async {
    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: <Request>[
          Request(
            deleteDimension: DeleteDimensionRequest(
              range: DimensionRange(
                sheetId: sheetId,
                dimension: dimension,
                startIndex: startIndex,
                endIndex: endIndex,
              ),
            ),
          ),
        ],
      ),
      _spreadsheetId,
    );
  }

  @override
  Future<void> applyDashboardLook({
    required int sheetId,
    required GoogleSheetsDashboard dashboard,
  }) async {
    final formatRequests = <Request>[
      ..._columnWidthRequests(sheetId, dashboard.columnWidthsPx),
      ..._styleRequests(sheetId, dashboard.styles),
      ..._bandingRequests(sheetId, dashboard.bandedTables),
    ];
    if (formatRequests.isNotEmpty) {
      await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(requests: formatRequests),
        _spreadsheetId,
      );
    }
    final chartRequests = _chartRequests(sheetId, dashboard.charts);
    if (chartRequests.isEmpty) {
      return;
    }
    try {
      await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(requests: chartRequests),
        _spreadsheetId,
      );
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets funnel charts failed: $error', stackTrace);
    }
  }

  List<Request> _columnWidthRequests(int sheetId, List<int> widths) {
    final requests = <Request>[];
    for (var index = 0; index < widths.length; index++) {
      requests.add(
        Request(
          updateDimensionProperties: UpdateDimensionPropertiesRequest(
            range: DimensionRange(
              sheetId: sheetId,
              dimension: 'COLUMNS',
              startIndex: index,
              endIndex: index + 1,
            ),
            properties: DimensionProperties(pixelSize: widths[index]),
            fields: 'pixelSize',
          ),
        ),
      );
    }
    return requests;
  }

  List<Request> _styleRequests(int sheetId, List<GoogleSheetsRangeStyle> styles) {
    final requests = <Request>[];
    for (final style in styles) {
      final range = GridRange(
        sheetId: sheetId,
        startRowIndex: style.startRow,
        endRowIndex: style.endRowExclusive,
        startColumnIndex: style.startColumn,
        endColumnIndex: style.endColumnExclusive,
      );
      if (style.merge) {
        requests.add(
          Request(
            mergeCells: MergeCellsRequest(range: range, mergeType: 'MERGE_ALL'),
          ),
        );
      }
      final format = _cellFormat(style);
      final fields = _formatFields(style);
      if (format != null && fields != null) {
        requests.add(
          Request(
            repeatCell: RepeatCellRequest(
              range: range,
              cell: CellData(userEnteredFormat: format),
              fields: 'userEnteredFormat($fields)',
            ),
          ),
        );
      }
      if (style.borders) {
        requests.add(_borderRequest(range, inner: style.innerBorders));
      }
    }
    return requests;
  }

  Request _borderRequest(GridRange range, {required bool inner}) {
    final outer = Border(
      style: 'SOLID_MEDIUM',
      width: 2,
      color: Color(red: 0.42, green: 0.50, blue: 0.44),
    );
    final grid = Border(
      style: 'SOLID',
      width: 1,
      color: Color(red: 0.62, green: 0.68, blue: 0.63),
    );
    return Request(
      updateBorders: UpdateBordersRequest(
        range: range,
        top: outer,
        bottom: outer,
        left: outer,
        right: outer,
        innerHorizontal: inner ? grid : null,
        innerVertical: inner ? grid : null,
      ),
    );
  }

  List<Request> _bandingRequests(int sheetId, List<GoogleSheetsBandedTable> tables) {
    return [
      for (final table in tables)
        if (table.endRowExclusive > table.startRow && table.endColumnExclusive > table.startColumn)
          Request(
            addBanding: AddBandingRequest(
              bandedRange: BandedRange(
                range: GridRange(
                  sheetId: sheetId,
                  startRowIndex: table.startRow,
                  endRowIndex: table.endRowExclusive,
                  startColumnIndex: table.startColumn,
                  endColumnIndex: table.endColumnExclusive,
                ),
                rowProperties: BandingProperties(
                  headerColor: Color(red: 0.83, green: 0.88, blue: 0.83),
                  firstBandColor: Color(red: 0.99, green: 0.99, blue: 0.97),
                  secondBandColor: Color(red: 0.93, green: 0.95, blue: 0.93),
                ),
              ),
            ),
          ),
    ];
  }

  CellFormat? _cellFormat(GoogleSheetsRangeStyle style) {
    TextFormat? text;
    if (style.bold || style.fontSize != null || style.foreground != null) {
      text = TextFormat(
        bold: style.bold ? true : null,
        fontSize: style.fontSize,
        foregroundColor: _color(style.foreground),
      );
    }
    NumberFormat? number;
    if (style.numberFormatType != null) {
      number = NumberFormat(
        type: style.numberFormatType,
        pattern: style.numberFormatPattern,
      );
    }
    if (text == null &&
        number == null &&
        style.background == null &&
        style.horizontalAlignment == null &&
        style.verticalAlignment == null &&
        !style.wrap) {
      return null;
    }
    return CellFormat(
      backgroundColor: _color(style.background),
      textFormat: text,
      horizontalAlignment: style.horizontalAlignment,
      verticalAlignment: style.verticalAlignment,
      wrapStrategy: style.wrap ? 'WRAP' : null,
      numberFormat: number,
    );
  }

  String? _formatFields(GoogleSheetsRangeStyle style) {
    final parts = <String>[];
    if (style.background != null) {
      parts.add('backgroundColor');
    }
    if (style.bold || style.fontSize != null || style.foreground != null) {
      parts.add('textFormat');
    }
    if (style.horizontalAlignment != null) {
      parts.add('horizontalAlignment');
    }
    if (style.verticalAlignment != null) {
      parts.add('verticalAlignment');
    }
    if (style.wrap) {
      parts.add('wrapStrategy');
    }
    if (style.numberFormatType != null) {
      parts.add('numberFormat');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(',');
  }

  List<Request> _chartRequests(int sheetId, List<GoogleSheetsChart> charts) {
    return [
      for (final chart in charts)
        if (chart.hasData)
          Request(
            addChart: AddChartRequest(chart: _embeddedChart(sheetId, chart)),
          ),
    ];
  }

  EmbeddedChart _embeddedChart(int sheetId, GoogleSheetsChart chart) {
    final dataStartRow =
        chart.kind == GoogleSheetsChartKind.pie ? chart.headerRow + 1 : chart.headerRow;
    final labels = _chartData(
      sheetId: sheetId,
      startRow: dataStartRow,
      endRow: chart.endRowExclusive,
      startColumn: chart.labelColumn,
      endColumn: chart.labelColumn + 1,
    );
    final values = _chartData(
      sheetId: sheetId,
      startRow: dataStartRow,
      endRow: chart.endRowExclusive,
      startColumn: chart.valueColumn,
      endColumn: chart.valueColumn + 1,
    );
    final spec = ChartSpec(
      title: chart.title,
      titleTextFormat: TextFormat(bold: true, fontSize: 12),
      backgroundColorStyle: ColorStyle(
        rgbColor: Color(red: 0.98, green: 0.97, blue: 0.94),
      ),
      basicChart: chart.kind == GoogleSheetsChartKind.pie
          ? null
          : BasicChartSpec(
              chartType: chart.kind == GoogleSheetsChartKind.bar ? 'BAR' : 'COLUMN',
              legendPosition: chart.legendPosition,
              headerCount: 1,
              axis: <BasicChartAxis>[
                BasicChartAxis(position: 'BOTTOM_AXIS'),
              ],
              domains: <BasicChartDomain>[
                BasicChartDomain(domain: labels),
              ],
              series: <BasicChartSeries>[
                BasicChartSeries(
                  series: values,
                  targetAxis: 'BOTTOM_AXIS',
                  colorStyle: ColorStyle(
                    rgbColor: Color(red: 0.24, green: 0.42, blue: 0.32),
                  ),
                ),
              ],
            ),
      pieChart: chart.kind == GoogleSheetsChartKind.pie
          ? PieChartSpec(
              legendPosition: chart.legendPosition,
              pieHole: chart.pieHole,
              domain: labels,
              series: values,
            )
          : null,
    );
    return EmbeddedChart(
      spec: spec,
      position: EmbeddedObjectPosition(
        overlayPosition: OverlayPosition(
          anchorCell: GridCoordinate(
            sheetId: sheetId,
            rowIndex: chart.anchorRow,
            columnIndex: chart.anchorColumn,
          ),
          widthPixels: chart.widthPixels,
          heightPixels: chart.heightPixels,
        ),
      ),
    );
  }

  ChartData _chartData({
    required int sheetId,
    required int startRow,
    required int endRow,
    required int startColumn,
    required int endColumn,
  }) {
    return ChartData(
      sourceRange: ChartSourceRange(
        sources: <GridRange>[
          GridRange(
            sheetId: sheetId,
            startRowIndex: startRow,
            endRowIndex: endRow,
            startColumnIndex: startColumn,
            endColumnIndex: endColumn,
          ),
        ],
      ),
    );
  }

  Color? _color(GoogleSheetsRgb? rgb) {
    if (rgb == null) {
      return null;
    }
    return Color(red: rgb.red, green: rgb.green, blue: rgb.blue);
  }

  @override
  Future<void> close() async {
    _authClient?.close();
  }
}
