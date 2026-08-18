import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:dvor_chatbot/src/data/google_sheets_credentials.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_ids.dart';
import 'package:dvor_chatbot/src/data/google_sheets_input_ui.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'credentials',
      abbr: 'c',
      help: 'Path to the service-account JSON. Not committed.',
    )
    ..addOption(
      'spreadsheet-id',
      abbr: 's',
      defaultsTo: GoogleSheetsInputUi.spreadsheetId,
    );
  final parsed = parser.parse(arguments);
  final credentialsPath =
      parsed['credentials'] as String? ?? Platform.environment['GOOGLE_SHEETS_CREDENTIALS_PATH'];
  if (credentialsPath == null || credentialsPath.trim().isEmpty) {
    stderr.writeln(
      'Set --credentials or GOOGLE_SHEETS_CREDENTIALS_PATH to the service-account JSON.',
    );
    exitCode = 64;
    return;
  }

  final spreadsheetId = (parsed['spreadsheet-id'] as String).trim();
  final credentials = ServiceAccountCredentials.fromJson(
    loadGoogleSheetsServiceAccountJson(path: credentialsPath),
  );
  final client = await clientViaServiceAccount(
    credentials,
    const <String>[SheetsApi.spreadsheetsScope],
  );
  try {
    await _FormatInputSheets(SheetsApi(client), spreadsheetId).run();
  } finally {
    client.close();
  }
}

final class _FormatInputSheets {
  _FormatInputSheets(this._api, this._spreadsheetId);

  final SheetsApi _api;
  final String _spreadsheetId;
  String _formulaSep = ',';

  Future<void> run() async {
    var meta = await _loadMeta();
    _formulaSep = (meta.locale ?? '').toLowerCase().startsWith('ru') ? ';' : ',';
    stdout.writeln('Spreadsheet $_spreadsheetId locale=${meta.locale ?? "unknown"}');
    await _ensureLegendSheet(meta);
    meta = await _loadMeta();

    for (final spec in GoogleSheetsInputUi.sheets) {
      final live = _sheetByGid(meta, spec.gid);
      if (live == null) {
        stderr.writeln('Skip ${spec.title}: gid=${spec.gid} not found.');
        continue;
      }
      if (_isFunnel(live)) {
        stderr.writeln('Skip gid=${spec.gid}: this tab is FUNNEL.');
        continue;
      }
      stdout.writeln(
        'Sheet gid=${spec.gid} "${live.properties?.title}" → "${spec.title}"',
      );
      final plan = await _planSheet(spec, live);
      await _batch(plan.cleanup);
      await _batch(plan.format);
      meta = await _loadMeta();
    }

    final funnel = _sheetByTitle(meta, GoogleSheetsInputUi.funnelTitle);
    if (funnel != null) {
      await _batch(_cleanupProtections(funnel, headerOnly: false));
      await _batch(<Request>[
        Request(
          addProtectedRange: AddProtectedRangeRequest(
            protectedRange: ProtectedRange(
              description: 'FUNNEL пишет бот — руками не править.',
              warningOnly: true,
              range: GridRange(sheetId: funnel.properties!.sheetId),
            ),
          ),
        ),
      ]);
    }
    await _writeLegend();
    await _verifyCsvHeaders();
    stdout.writeln('Done. Input sheets formatted in place; FUNNEL was not rebuilt.');
  }

  Future<_SpreadsheetMeta> _loadMeta() async {
    final spreadsheet = await _api.spreadsheets.get(
      _spreadsheetId,
      $fields: 'properties.locale,sheets(properties,bandedRanges.bandedRangeId,'
          'conditionalFormats,basicFilter,protectedRanges(protectedRangeId,range),merges)',
    );
    return _SpreadsheetMeta(
      locale: spreadsheet.properties?.locale,
      sheets: spreadsheet.sheets ?? const <Sheet>[],
    );
  }

  Sheet? _sheetByGid(_SpreadsheetMeta meta, int gid) {
    for (final sheet in meta.sheets) {
      if (sheet.properties?.sheetId == gid) {
        return sheet;
      }
    }
    return null;
  }

  Sheet? _sheetByTitle(_SpreadsheetMeta meta, String title) {
    for (final sheet in meta.sheets) {
      if (sheet.properties?.title == title) {
        return sheet;
      }
    }
    return null;
  }

  bool _isFunnel(Sheet sheet) => sheet.properties?.title == GoogleSheetsInputUi.funnelTitle;

  Future<void> _ensureLegendSheet(_SpreadsheetMeta meta) async {
    if (_sheetByTitle(meta, GoogleSheetsInputUi.legendTitle) != null) {
      return;
    }
    stdout.writeln('Add sheet ${GoogleSheetsInputUi.legendTitle}');
    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: <Request>[
          Request(
            addSheet: AddSheetRequest(
              properties: SheetProperties(
                title: GoogleSheetsInputUi.legendTitle,
                index: 0,
                tabColorStyle: ColorStyle(rgbColor: _color(GoogleSheetsInputUi.headerTab)),
                gridProperties: GridProperties(
                  frozenRowCount: 1,
                  rowCount: 16,
                  columnCount: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      _spreadsheetId,
    );
  }

  Future<_SheetPlan> _planSheet(GoogleSheetsInputSheetSpec spec, Sheet live) async {
    final sheetId = live.properties!.sheetId!;
    final quoted = quoteA1SheetTitle(live.properties!.title ?? spec.title);
    var formatted = await _api.spreadsheets.values.get(
      _spreadsheetId,
      '$quoted!A:Z',
    );
    var rows = _asStringRows(formatted.values);
    if (rows.isEmpty) {
      throw StateError('${spec.title}: empty sheet, expected a header row.');
    }
    var headers = [
      for (final cell in rows.first) GoogleSheetsInputUi.normalizeHeader(cell),
    ];
    _assertRequiredHeaders(spec, headers);

    final skipCols = <int>{};
    for (var i = 0; i < headers.length; i++) {
      final column = spec.matchingColumn(headers[i]);
      if (column != null && (column.isCheckbox || column.isStatus)) {
        skipCols.add(i);
      }
    }
    final leadingEmpty = _leadingEmptyCount(rows, skipCols);
    if (leadingEmpty > 0) {
      await _batch(<Request>[
        Request(
          deleteDimension: DeleteDimensionRequest(
            range: DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: 1,
              endIndex: 1 + leadingEmpty,
            ),
          ),
        ),
      ]);
      stdout.writeln('  deleted $leadingEmpty empty row(s) under header');
      formatted = await _api.spreadsheets.values.get(
        _spreadsheetId,
        '$quoted!A:Z',
      );
      rows = _asStringRows(formatted.values);
      headers = [
        for (final cell in rows.first) GoogleSheetsInputUi.normalizeHeader(cell),
      ];
      skipCols
        ..clear()
        ..addAll({
          for (var i = 0; i < headers.length; i++)
            if (spec.matchingColumn(headers[i])?.isCheckbox == true ||
                spec.matchingColumn(headers[i])?.isStatus == true)
              i,
        });
    }

    final lastContent = _lastContentRow(rows, skipCols);
    final reshaped = _reshapeRows(spec, rows, lastContent);
    final indexByHeader = <String, int>{
      for (var i = 0; i < spec.columns.length; i++)
        GoogleSheetsInputUi.normalizeHeader(spec.columns[i].header): i,
    };
    final usedColumns = spec.columns.length;
    final targetRows = math.max(
      (reshaped.length - 1) + 1 + GoogleSheetsInputUi.extraRows,
      1 + GoogleSheetsInputUi.extraRows,
    );
    stdout.writeln(
      '  headers=${spec.columns.map((column) => column.header).join(", ")} '
      'contentRows=${reshaped.length - 1} target=${targetRows}x$usedColumns',
    );

    await _batch(<Request>[
      Request(
        updateSheetProperties: UpdateSheetPropertiesRequest(
          properties: SheetProperties(
            sheetId: sheetId,
            gridProperties: GridProperties(
              rowCount: targetRows,
              columnCount: usedColumns,
            ),
          ),
          fields: 'gridProperties.rowCount,gridProperties.columnCount',
        ),
      ),
    ]);

    final write = _gridWithStatus(spec, reshaped, targetRows);
    final statusIndex =
        spec.indexOfHeader(GoogleSheetsInputUi.statusHeader) ?? spec.columns.length - 1;
    final dataCols = statusIndex;
    await _api.spreadsheets.values.update(
      ValueRange(
        values: [
          for (final row in write) row.sublist(0, dataCols),
        ],
      ),
      _spreadsheetId,
      '$quoted!A1',
      valueInputOption: 'RAW',
    );
    await _api.spreadsheets.values.update(
      ValueRange(
        values: [
          for (final row in write) <Object?>[row[statusIndex]],
        ],
      ),
      _spreadsheetId,
      '$quoted!${GoogleSheetsInputUi.columnLetter(statusIndex)}1',
      valueInputOption: 'USER_ENTERED',
    );

    final cleanup = <Request>[
      ..._cleanupLook(live),
      ..._cleanupAllProtections(live),
      Request(
        setDataValidation: SetDataValidationRequest(
          range: GridRange(sheetId: sheetId),
        ),
      ),
      Request(
        repeatCell: RepeatCellRequest(
          range: GridRange(sheetId: sheetId),
          cell: CellData(),
          fields: 'dataValidation',
        ),
      ),
    ];
    if (live.basicFilter != null) {
      cleanup.add(
        Request(clearBasicFilter: ClearBasicFilterRequest(sheetId: sheetId)),
      );
    }
    for (final merge in live.merges ?? const <GridRange>[]) {
      cleanup.add(Request(unmergeCells: UnmergeCellsRequest(range: merge)));
    }

    final conversions = _conversionUpdates(
      spec: spec,
      indexByHeader: indexByHeader,
      rows: reshaped,
      lastContent: reshaped.length - 1,
    );
    if (conversions.isNotEmpty) {
      final title = live.properties?.title ?? spec.title;
      await _api.spreadsheets.values.batchUpdate(
        BatchUpdateValuesRequest(
          valueInputOption: 'USER_ENTERED',
          data: [
            for (final cell in conversions)
              ValueRange(
                range: '${quoteA1SheetTitle(title)}!${_a1(cell.column)}${cell.row + 1}',
                values: <List<Object?>>[
                  <Object?>[cell.value],
                ],
              ),
          ],
        ),
        _spreadsheetId,
      );
      stdout.writeln('  converted ${conversions.length} date/number cells');
    }

    final format = <Request>[
      Request(
        updateSheetProperties: UpdateSheetPropertiesRequest(
          properties: SheetProperties(
            sheetId: sheetId,
            title: spec.title,
            tabColorStyle: ColorStyle(rgbColor: _color(spec.tabColor)),
            gridProperties: GridProperties(
              frozenRowCount: 1,
              hideGridlines: false,
              rowCount: targetRows,
              columnCount: usedColumns,
            ),
          ),
          fields: 'title,tabColorStyle,gridProperties.frozenRowCount,'
              'gridProperties.hideGridlines,gridProperties.rowCount,gridProperties.columnCount',
        ),
      ),
    ];
    format.addAll(_styleRequests(spec, sheetId, targetRows, usedColumns, indexByHeader));
    format.addAll(_noteRequests(spec, sheetId, indexByHeader));
    format.addAll(_validationRequests(spec, sheetId, targetRows, indexByHeader));
    format.addAll(_conditionalRequests(spec, sheetId, targetRows, usedColumns, indexByHeader));
    format.add(
      Request(
        setBasicFilter: SetBasicFilterRequest(
          filter: BasicFilter(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: targetRows,
              startColumnIndex: 0,
              endColumnIndex: usedColumns,
            ),
          ),
        ),
      ),
    );
    format.add(
      Request(
        addProtectedRange: AddProtectedRangeRequest(
          protectedRange: ProtectedRange(
            description: 'Шапка. Не переименовывай колонки — их читает бот.',
            warningOnly: true,
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: usedColumns,
            ),
          ),
        ),
      ),
    );
    format.add(
      Request(
        addProtectedRange: AddProtectedRangeRequest(
          protectedRange: ProtectedRange(
            description: 'Колонка статус — формула. Бот её не читает.',
            warningOnly: true,
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: 1,
              endRowIndex: targetRows,
              startColumnIndex: statusIndex,
              endColumnIndex: statusIndex + 1,
            ),
          ),
        ),
      ),
    );
    return _SheetPlan(cleanup: cleanup, format: format);
  }

  void _assertRequiredHeaders(GoogleSheetsInputSheetSpec spec, List<String> headers) {
    final missing = <String>[];
    for (final required in [...spec.requiredHeaders, ...spec.requiredDateHeaders]) {
      final column = spec.columnNamed(required);
      final found = column != null && headers.any(column.matches);
      if (!found) {
        missing.add(required);
      }
    }
    if (missing.isNotEmpty) {
      throw StateError(
        '${spec.title}: missing CSV headers ${missing.join(", ")}. Refusing to format.',
      );
    }
  }

  List<Request> _cleanupLook(Sheet live) {
    final sheetId = live.properties!.sheetId!;
    final requests = <Request>[];
    for (final banded in live.bandedRanges ?? const <BandedRange>[]) {
      final id = banded.bandedRangeId;
      if (id == null) {
        continue;
      }
      requests.add(Request(deleteBanding: DeleteBandingRequest(bandedRangeId: id)));
    }
    final rules = live.conditionalFormats ?? const <ConditionalFormatRule>[];
    for (var index = rules.length - 1; index >= 0; index--) {
      requests.add(
        Request(
          deleteConditionalFormatRule: DeleteConditionalFormatRuleRequest(
            sheetId: sheetId,
            index: index,
          ),
        ),
      );
    }
    return requests;
  }

  List<Request> _cleanupAllProtections(Sheet live) {
    final sheetId = live.properties!.sheetId!;
    final requests = <Request>[];
    for (final protection in live.protectedRanges ?? const <ProtectedRange>[]) {
      final id = protection.protectedRangeId;
      if (id == null) {
        continue;
      }
      final range = protection.range;
      if (range?.sheetId != sheetId) {
        continue;
      }
      requests.add(
        Request(deleteProtectedRange: DeleteProtectedRangeRequest(protectedRangeId: id)),
      );
    }
    return requests;
  }

  List<Request> _cleanupProtections(Sheet live, {required bool headerOnly}) {
    final sheetId = live.properties!.sheetId!;
    final requests = <Request>[];
    for (final protection in live.protectedRanges ?? const <ProtectedRange>[]) {
      final id = protection.protectedRangeId;
      if (id == null) {
        continue;
      }
      final range = protection.range;
      final wholeSheet = range == null ||
          ((range.startRowIndex == null || range.startRowIndex == 0) &&
              range.endRowIndex == null &&
              range.startColumnIndex == null &&
              range.endColumnIndex == null);
      final headerRow = range != null && (range.startRowIndex ?? 0) == 0 && range.endRowIndex == 1;
      if (headerOnly && !headerRow) {
        continue;
      }
      if (!headerOnly && !wholeSheet) {
        continue;
      }
      if (range != null && range.sheetId != null && range.sheetId != sheetId) {
        continue;
      }
      requests.add(
        Request(deleteProtectedRange: DeleteProtectedRangeRequest(protectedRangeId: id)),
      );
    }
    return requests;
  }

  List<Request> _styleRequests(
    GoogleSheetsInputSheetSpec spec,
    int sheetId,
    int targetRows,
    int usedColumns,
    Map<String, int> indexByHeader,
  ) {
    final requests = <Request>[
      Request(
        repeatCell: RepeatCellRequest(
          range: GridRange(
            sheetId: sheetId,
            startRowIndex: 0,
            endRowIndex: targetRows,
            startColumnIndex: 0,
            endColumnIndex: usedColumns,
          ),
          cell: CellData(
            userEnteredFormat: CellFormat(
              backgroundColor: _color(GoogleSheetsInputUi.paper),
              textFormat: TextFormat(
                foregroundColor: _color(GoogleSheetsInputUi.ink),
                fontSize: 10,
              ),
              verticalAlignment: 'MIDDLE',
            ),
          ),
          fields: 'userEnteredFormat(backgroundColor,textFormat,verticalAlignment)',
        ),
      ),
      Request(
        repeatCell: RepeatCellRequest(
          range: GridRange(
            sheetId: sheetId,
            startRowIndex: 0,
            endRowIndex: 1,
            startColumnIndex: 0,
            endColumnIndex: usedColumns,
          ),
          cell: CellData(
            userEnteredFormat: CellFormat(
              backgroundColor: _color(GoogleSheetsInputUi.tableHead),
              textFormat: TextFormat(
                bold: true,
                fontSize: 10,
                foregroundColor: _color(GoogleSheetsInputUi.ink),
              ),
              horizontalAlignment: 'CENTER',
              verticalAlignment: 'MIDDLE',
              wrapStrategy: 'WRAP',
            ),
          ),
          fields: 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment,'
              'verticalAlignment,wrapStrategy)',
        ),
      ),
      Request(
        updateDimensionProperties: UpdateDimensionPropertiesRequest(
          range: DimensionRange(
            sheetId: sheetId,
            dimension: 'ROWS',
            startIndex: 0,
            endIndex: 1,
          ),
          properties: DimensionProperties(pixelSize: 36),
          fields: 'pixelSize',
        ),
      ),
      Request(
        addBanding: AddBandingRequest(
          bandedRange: BandedRange(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: 0,
              endRowIndex: targetRows,
              startColumnIndex: 0,
              endColumnIndex: usedColumns,
            ),
            rowProperties: BandingProperties(
              headerColor: _color(GoogleSheetsInputUi.tableHead),
              firstBandColor: Color(red: 0.99, green: 0.99, blue: 0.97),
              secondBandColor: Color(red: 0.93, green: 0.95, blue: 0.93),
            ),
          ),
        ),
      ),
      Request(
        updateBorders: UpdateBordersRequest(
          range: GridRange(
            sheetId: sheetId,
            startRowIndex: 0,
            endRowIndex: targetRows,
            startColumnIndex: 0,
            endColumnIndex: usedColumns,
          ),
          top: _outerBorder,
          bottom: _outerBorder,
          left: _outerBorder,
          right: _outerBorder,
          innerHorizontal: _innerBorder,
          innerVertical: _innerBorder,
        ),
      ),
    ];

    for (final column in spec.columns) {
      final index = indexByHeader[GoogleSheetsInputUi.normalizeHeader(column.header)];
      if (index == null) {
        continue;
      }
      requests.add(
        Request(
          updateDimensionProperties: UpdateDimensionPropertiesRequest(
            range: DimensionRange(
              sheetId: sheetId,
              dimension: 'COLUMNS',
              startIndex: index,
              endIndex: index + 1,
            ),
            properties: DimensionProperties(pixelSize: column.widthPx),
            fields: 'pixelSize',
          ),
        ),
      );
      if (column.wrap) {
        requests.add(
          Request(
            repeatCell: RepeatCellRequest(
              range: GridRange(
                sheetId: sheetId,
                startRowIndex: 1,
                endRowIndex: targetRows,
                startColumnIndex: index,
                endColumnIndex: index + 1,
              ),
              cell: CellData(
                userEnteredFormat: CellFormat(wrapStrategy: 'WRAP'),
              ),
              fields: 'userEnteredFormat.wrapStrategy',
            ),
          ),
        );
      }
      final numberFormat = _numberFormat(column.kind);
      if (numberFormat != null) {
        requests.add(
          Request(
            repeatCell: RepeatCellRequest(
              range: GridRange(
                sheetId: sheetId,
                startRowIndex: 1,
                endRowIndex: targetRows,
                startColumnIndex: index,
                endColumnIndex: index + 1,
              ),
              cell: CellData(
                userEnteredFormat: CellFormat(numberFormat: numberFormat),
              ),
              fields: 'userEnteredFormat.numberFormat',
            ),
          ),
        );
      }
      if (column.kind == GoogleSheetsInputColumnKind.checkbox ||
          column.kind == GoogleSheetsInputColumnKind.date ||
          column.kind == GoogleSheetsInputColumnKind.time ||
          column.kind == GoogleSheetsInputColumnKind.number ||
          column.kind == GoogleSheetsInputColumnKind.percent) {
        requests.add(
          Request(
            repeatCell: RepeatCellRequest(
              range: GridRange(
                sheetId: sheetId,
                startRowIndex: 1,
                endRowIndex: targetRows,
                startColumnIndex: index,
                endColumnIndex: index + 1,
              ),
              cell: CellData(
                userEnteredFormat: CellFormat(horizontalAlignment: 'CENTER'),
              ),
              fields: 'userEnteredFormat.horizontalAlignment',
            ),
          ),
        );
      }
    }
    return requests;
  }

  List<Request> _noteRequests(
    GoogleSheetsInputSheetSpec spec,
    int sheetId,
    Map<String, int> indexByHeader,
  ) {
    final values = <CellData>[];
    var maxIndex = -1;
    for (final column in spec.columns) {
      final index = indexByHeader[GoogleSheetsInputUi.normalizeHeader(column.header)];
      if (index == null) {
        continue;
      }
      maxIndex = math.max(maxIndex, index);
    }
    if (maxIndex < 0) {
      return const <Request>[];
    }
    for (var i = 0; i <= maxIndex; i++) {
      values.add(CellData());
    }
    for (final column in spec.columns) {
      final index = indexByHeader[GoogleSheetsInputUi.normalizeHeader(column.header)];
      if (index == null) {
        continue;
      }
      values[index] = CellData(note: column.note);
    }
    return <Request>[
      Request(
        updateCells: UpdateCellsRequest(
          fields: 'note',
          start: GridCoordinate(sheetId: sheetId, rowIndex: 0, columnIndex: 0),
          rows: <RowData>[RowData(values: values)],
        ),
      ),
    ];
  }

  List<Request> _validationRequests(
    GoogleSheetsInputSheetSpec spec,
    int sheetId,
    int targetRows,
    Map<String, int> indexByHeader,
  ) {
    final requests = <Request>[];
    for (final column in spec.columns) {
      final index = indexByHeader[GoogleSheetsInputUi.normalizeHeader(column.header)];
      if (index == null) {
        continue;
      }
      final rule = _validationRule(column, index);
      if (rule == null) {
        continue;
      }
      requests.add(
        Request(
          setDataValidation: SetDataValidationRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: 1,
              endRowIndex: targetRows,
              startColumnIndex: index,
              endColumnIndex: index + 1,
            ),
            rule: rule,
          ),
        ),
      );
    }
    return requests;
  }

  String _cellA1(int index, {int row = 2}) => '${GoogleSheetsInputUi.columnLetter(index)}$row';

  String _blankOrFormula(int index, String rest) {
    return '=OR(${_cellA1(index)}=""$_formulaSep $rest)';
  }

  DataValidationRule? _validationRule(GoogleSheetsInputColumn column, int index) {
    switch (column.kind) {
      case GoogleSheetsInputColumnKind.date:
        return DataValidationRule(
          condition: BooleanCondition(type: 'DATE_IS_VALID'),
          inputMessage: 'Выбери дату в календаре. Пусто можно.',
          showCustomUi: true,
          strict: false,
        );
      case GoogleSheetsInputColumnKind.time:
        return DataValidationRule(
          condition: BooleanCondition(
            type: 'CUSTOM_FORMULA',
            values: <ConditionValue>[
              ConditionValue(
                userEnteredValue: _blankOrFormula(
                  index,
                  'ISNUMBER(${_cellA1(index)})$_formulaSep '
                  'REGEXMATCH(TO_TEXT(${_cellA1(index)})$_formulaSep '
                  '"^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?\$")',
                ),
              ),
            ],
          ),
          inputMessage: 'Время, например 19:30 или 8:30. Пусто можно.',
          showCustomUi: true,
          strict: false,
        );
      case GoogleSheetsInputColumnKind.number:
      case GoogleSheetsInputColumnKind.percent:
      case GoogleSheetsInputColumnKind.url:
      case GoogleSheetsInputColumnKind.text:
      case GoogleSheetsInputColumnKind.status:
        return null;
      case GoogleSheetsInputColumnKind.checkbox:
        return DataValidationRule(
          condition: BooleanCondition(type: 'BOOLEAN'),
          showCustomUi: true,
          strict: false,
        );
      case GoogleSheetsInputColumnKind.categories:
        return DataValidationRule(
          condition: BooleanCondition(
            type: 'ONE_OF_LIST',
            values: [
              for (final value in GoogleSheetsInputUi.categoryDropdownValues)
                ConditionValue(userEnteredValue: value),
            ],
          ),
          inputMessage: 'все / Тренировки / Походы / Трейлы. Можно через запятую.',
          showCustomUi: true,
          strict: false,
        );
      case GoogleSheetsInputColumnKind.coach:
        return DataValidationRule(
          condition: BooleanCondition(
            type: 'ONE_OF_RANGE',
            values: <ConditionValue>[
              ConditionValue(
                userEnteredValue:
                    '=${quoteA1SheetTitle(GoogleSheetsInputUi.coachesTitle)}!\$A\$2:\$A\$500',
              ),
            ],
          ),
          inputMessage: 'Имя из штаба или своё.',
          showCustomUi: true,
          strict: false,
        );
    }
  }

  NumberFormat? _numberFormat(GoogleSheetsInputColumnKind kind) {
    switch (kind) {
      case GoogleSheetsInputColumnKind.date:
        return NumberFormat(type: 'DATE', pattern: 'dd.mm.yyyy');
      case GoogleSheetsInputColumnKind.time:
        return NumberFormat(type: 'TIME', pattern: 'HH:mm');
      case GoogleSheetsInputColumnKind.number:
      case GoogleSheetsInputColumnKind.percent:
        return NumberFormat(type: 'NUMBER', pattern: '0');
      case GoogleSheetsInputColumnKind.text:
      case GoogleSheetsInputColumnKind.checkbox:
      case GoogleSheetsInputColumnKind.categories:
      case GoogleSheetsInputColumnKind.url:
      case GoogleSheetsInputColumnKind.coach:
      case GoogleSheetsInputColumnKind.status:
        return null;
    }
  }

  List<Request> _conditionalRequests(
    GoogleSheetsInputSheetSpec spec,
    int sheetId,
    int targetRows,
    int usedColumns,
    Map<String, int> indexByHeader,
  ) {
    final requests = <Request>[];
    final required = <int>[
      for (final header in [...spec.requiredHeaders, ...spec.requiredDateHeaders])
        if (indexByHeader.containsKey(GoogleSheetsInputUi.normalizeHeader(header)))
          indexByHeader[GoogleSheetsInputUi.normalizeHeader(header)]!,
    ];
    final content = <int>[
      for (final column in spec.columns)
        if (column.kind != GoogleSheetsInputColumnKind.checkbox &&
            column.kind != GoogleSheetsInputColumnKind.status &&
            indexByHeader.containsKey(GoogleSheetsInputUi.normalizeHeader(column.header)))
          indexByHeader[GoogleSheetsInputUi.normalizeHeader(column.header)]!,
    ];
    if (required.isNotEmpty && content.isNotEmpty) {
      final contentExpr = content.map(_filled).join('$_formulaSep ');
      final requiredExpr = required.map(_empty).join('$_formulaSep ');
      requests.add(
        Request(
          addConditionalFormatRule: AddConditionalFormatRuleRequest(
            index: 0,
            rule: ConditionalFormatRule(
              ranges: <GridRange>[
                GridRange(
                  sheetId: sheetId,
                  startRowIndex: 1,
                  endRowIndex: targetRows,
                  startColumnIndex: 0,
                  endColumnIndex: usedColumns,
                ),
              ],
              booleanRule: BooleanRule(
                condition: BooleanCondition(
                  type: 'CUSTOM_FORMULA',
                  values: <ConditionValue>[
                    ConditionValue(
                      userEnteredValue: '=AND(OR($contentExpr)$_formulaSep OR($requiredExpr))',
                    ),
                  ],
                ),
                format: CellFormat(
                  backgroundColor: _color(GoogleSheetsInputUi.incomplete),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final duplicateHeader = spec.highlightDuplicateHeader;
    if (duplicateHeader != null) {
      final index = indexByHeader[GoogleSheetsInputUi.normalizeHeader(duplicateHeader)];
      if (index != null) {
        final letter = _a1(index);
        requests.add(
          Request(
            addConditionalFormatRule: AddConditionalFormatRuleRequest(
              index: 0,
              rule: ConditionalFormatRule(
                ranges: <GridRange>[
                  GridRange(
                    sheetId: sheetId,
                    startRowIndex: 1,
                    endRowIndex: targetRows,
                    startColumnIndex: index,
                    endColumnIndex: index + 1,
                  ),
                ],
                booleanRule: BooleanRule(
                  condition: BooleanCondition(
                    type: 'CUSTOM_FORMULA',
                    values: <ConditionValue>[
                      ConditionValue(
                        userEnteredValue:
                            '=AND(${_filled(index)}$_formulaSep COUNTIF(\$$letter\$2:\$$letter$targetRows$_formulaSep \$${letter}2)>1)',
                      ),
                    ],
                  ),
                  format: CellFormat(
                    backgroundColor: _color(GoogleSheetsInputUi.duplicate),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return requests;
  }

  String _filled(int column) => '\$${_a1(column)}2<>""';

  String _empty(int column) => '\$${_a1(column)}2=""';

  List<_CellWrite> _conversionUpdates({
    required GoogleSheetsInputSheetSpec spec,
    required Map<String, int> indexByHeader,
    required List<List<String>> rows,
    required int lastContent,
  }) {
    final writes = <_CellWrite>[];
    for (final column in spec.columns) {
      final index = indexByHeader[GoogleSheetsInputUi.normalizeHeader(column.header)];
      if (index == null) {
        continue;
      }
      for (var row = 1; row <= lastContent && row < rows.length; row++) {
        final raw = _cell(rows[row], index);
        if (raw.isEmpty) {
          continue;
        }
        switch (column.kind) {
          case GoogleSheetsInputColumnKind.date:
            if (_datePattern.hasMatch(raw)) {
              writes.add(_CellWrite(row: row, column: index, value: raw));
            }
          case GoogleSheetsInputColumnKind.time:
            if (_timePattern.hasMatch(raw)) {
              writes.add(_CellWrite(row: row, column: index, value: raw));
            }
          case GoogleSheetsInputColumnKind.percent:
            final match = _percentPattern.firstMatch(raw);
            if (match != null) {
              writes.add(_CellWrite(row: row, column: index, value: match.group(1)!));
            } else if (_plainNumberPattern.hasMatch(raw)) {
              writes.add(_CellWrite(row: row, column: index, value: raw));
            }
          case GoogleSheetsInputColumnKind.number:
            if (_plainNumberPattern.hasMatch(raw)) {
              writes.add(_CellWrite(row: row, column: index, value: raw));
            } else {
              final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
              if (digits.isNotEmpty && raw.contains('₽')) {
                writes.add(_CellWrite(row: row, column: index, value: digits));
              }
            }
          case GoogleSheetsInputColumnKind.text:
          case GoogleSheetsInputColumnKind.checkbox:
          case GoogleSheetsInputColumnKind.categories:
          case GoogleSheetsInputColumnKind.url:
          case GoogleSheetsInputColumnKind.coach:
          case GoogleSheetsInputColumnKind.status:
            break;
        }
      }
    }
    return writes;
  }

  List<List<String>> _reshapeRows(
    GoogleSheetsInputSheetSpec spec,
    List<List<String>> rows,
    int lastContent,
  ) {
    final liveHeaders = [
      for (final cell in rows.first) GoogleSheetsInputUi.normalizeHeader(cell),
    ];
    final sourceBySpec = <String, int>{};
    for (var i = 0; i < liveHeaders.length; i++) {
      final column = spec.matchingColumn(liveHeaders[i]);
      if (column == null || column.isStatus) {
        continue;
      }
      sourceBySpec.putIfAbsent(GoogleSheetsInputUi.normalizeHeader(column.header), () => i);
    }
    const titleKeys = <String>{'название', 'имя'};
    final result = <List<String>>[
      [for (final column in spec.columns) column.header],
    ];
    for (var r = 1; r <= lastContent && r < rows.length; r++) {
      final next = <String>[];
      for (final column in spec.columns) {
        if (column.isStatus) {
          next.add('');
          continue;
        }
        final source = sourceBySpec[GoogleSheetsInputUi.normalizeHeader(column.header)];
        var value = source == null ? '' : _cell(rows[r], source);
        if (titleKeys.contains(GoogleSheetsInputUi.normalizeHeader(column.header))) {
          value = value.trim();
        }
        next.add(value);
      }
      result.add(next);
    }
    return result;
  }

  List<List<Object?>> _gridWithStatus(
    GoogleSheetsInputSheetSpec spec,
    List<List<String>> reshaped,
    int targetRows,
  ) {
    final statusIndex =
        spec.indexOfHeader(GoogleSheetsInputUi.statusHeader) ?? spec.columns.length - 1;
    final grid = <List<Object?>>[];
    for (var r = 0; r < targetRows; r++) {
      final row = <Object?>[];
      for (var c = 0; c < spec.columns.length; c++) {
        if (r == 0) {
          row.add(spec.columns[c].header);
        } else if (c == statusIndex) {
          row.add(
            GoogleSheetsInputUi.statusFormula(
              spec: spec,
              formulaSep: _formulaSep,
              targetRows: targetRows,
              row: r + 1,
            ),
          );
        } else if (r < reshaped.length && c < reshaped[r].length) {
          row.add(reshaped[r][c]);
        } else {
          row.add('');
        }
      }
      grid.add(row);
    }
    return grid;
  }

  Future<void> _writeLegend() async {
    final live = _sheetByTitle(await _loadMeta(), GoogleSheetsInputUi.legendTitle);
    if (live == null) {
      throw StateError('Legend sheet ${GoogleSheetsInputUi.legendTitle} is missing.');
    }
    final sheetId = live.properties!.sheetId!;
    final rows = <List<Object?>>[
      <Object?>['Как заполнять', ''],
      <Object?>[
        'После правок в боте: Админ-меню → Обновить Google Sheets. Лист FUNNEL руками не трогать.',
        '',
      ],
      <Object?>['', ''],
      <Object?>[
        '=HYPERLINK("#gid=0"$_formulaSep"Тренировки")',
        'Обязательно: название, дата, время, место. Иначе бот строку пропустит — смотри колонку статус.',
      ],
      <Object?>[
        '',
        'тренеры_в_лимите — считать тренеров в лимите мест, не «пригласить». '
            'без_промокода — промо на эту тренировку не действует. Время как 19:30.',
      ],
      <Object?>[
        '=HYPERLINK("#gid=294119056"$_formulaSep"Походы")',
        'Обязательно: название, дата_с, описание. дата_по пусто = один день. '
            'предоплата пусто = 50% (не пиши 50 в пустую ячейку).',
      ],
      <Object?>[
        '=HYPERLINK("#gid=1220729038"$_formulaSep"Трейлы")',
        'Те же поля, что у походов. Пустая предоплата тоже 50%.',
      ],
      <Object?>[
        '=HYPERLINK("#gid=195037978"$_formulaSep"Тренерский штаб")',
        'Обязательно: имя, username, описание. Без username строка не попадёт в бота.',
      ],
      <Object?>[
        '=HYPERLINK("#gid=2001400867"$_formulaSep"Команда DVOR")',
        'В username только ник (@name). Колонка имя — для людей, бот её не читает.',
      ],
      <Object?>[
        '=HYPERLINK("#gid=432112868"$_formulaSep"Промокоды")',
        'Обязательно: промокод и скидка. Категории: все / Тренировки / Походы / Трейлы. '
            'Пусто или «все» = все категории. Дубль кода: побеждает нижняя строка.',
      ],
      <Object?>['', ''],
      <Object?>[
        GoogleSheetsInputUi.funnelTitle,
        'Не заполнять. Лист пересобирает бот.',
      ],
      <Object?>['', ''],
      <Object?>[
        'gid (админу)',
        'Тренировки 0 · Походы 294119056 · Трейлы 1220729038 · '
            'Тренерский штаб 195037978 · Команда DVOR 2001400867 · Промокоды 432112868',
      ],
    ];
    final quoted = quoteA1SheetTitle(GoogleSheetsInputUi.legendTitle);
    await _api.spreadsheets.values.clear(ClearValuesRequest(), _spreadsheetId, '$quoted!A:Z');
    await _api.spreadsheets.values.update(
      ValueRange(values: rows),
      _spreadsheetId,
      '$quoted!A1',
      valueInputOption: 'USER_ENTERED',
    );
    await _batch(<Request>[
      Request(
        updateSheetProperties: UpdateSheetPropertiesRequest(
          properties: SheetProperties(
            sheetId: sheetId,
            title: GoogleSheetsInputUi.legendTitle,
            index: 0,
            tabColorStyle: ColorStyle(rgbColor: _color(GoogleSheetsInputUi.headerTab)),
            gridProperties: GridProperties(
              frozenRowCount: 1,
              rowCount: 16,
              columnCount: 2,
              hideGridlines: false,
            ),
          ),
          fields: 'title,index,tabColorStyle,gridProperties.frozenRowCount,'
              'gridProperties.rowCount,gridProperties.columnCount,gridProperties.hideGridlines',
        ),
      ),
      Request(
        repeatCell: RepeatCellRequest(
          range: GridRange(
            sheetId: sheetId,
            startRowIndex: 0,
            endRowIndex: 16,
            startColumnIndex: 0,
            endColumnIndex: 2,
          ),
          cell: CellData(
            userEnteredFormat: CellFormat(
              backgroundColor: _color(GoogleSheetsInputUi.paper),
              textFormat: TextFormat(
                foregroundColor: _color(GoogleSheetsInputUi.ink),
                fontSize: 10,
              ),
              wrapStrategy: 'WRAP',
              verticalAlignment: 'MIDDLE',
            ),
          ),
          fields: 'userEnteredFormat(backgroundColor,textFormat,wrapStrategy,verticalAlignment)',
        ),
      ),
      Request(
        repeatCell: RepeatCellRequest(
          range: GridRange(
            sheetId: sheetId,
            startRowIndex: 0,
            endRowIndex: 1,
            startColumnIndex: 0,
            endColumnIndex: 2,
          ),
          cell: CellData(
            userEnteredFormat: CellFormat(
              backgroundColor: _color(GoogleSheetsInputUi.headerTab),
              textFormat: TextFormat(
                bold: true,
                foregroundColor: _color(GoogleSheetsInputUi.headerText),
                fontSize: 11,
              ),
            ),
          ),
          fields: 'userEnteredFormat(backgroundColor,textFormat)',
        ),
      ),
      Request(
        updateDimensionProperties: UpdateDimensionPropertiesRequest(
          range: DimensionRange(
            sheetId: sheetId,
            dimension: 'COLUMNS',
            startIndex: 0,
            endIndex: 1,
          ),
          properties: DimensionProperties(pixelSize: 200),
          fields: 'pixelSize',
        ),
      ),
      Request(
        updateDimensionProperties: UpdateDimensionPropertiesRequest(
          range: DimensionRange(
            sheetId: sheetId,
            dimension: 'COLUMNS',
            startIndex: 1,
            endIndex: 2,
          ),
          properties: DimensionProperties(pixelSize: 640),
          fields: 'pixelSize',
        ),
      ),
    ]);
  }

  Future<void> _verifyCsvHeaders() async {
    for (final spec in GoogleSheetsInputUi.sheets) {
      final url =
          'https://docs.google.com/spreadsheets/d/$_spreadsheetId/export?format=csv&gid=${spec.gid}';
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) {
          stderr.writeln('CSV gid=${spec.gid} HTTP ${response.statusCode}');
          continue;
        }
        final body = await utf8.decodeStream(response);
        final firstLine = body.split('\n').first.replaceAll('\r', '');
        final live = [
          for (final cell in firstLine.split(',')) GoogleSheetsInputUi.normalizeHeader(cell),
        ];
        final expected = [
          for (final column in spec.columns) GoogleSheetsInputUi.normalizeHeader(column.header),
        ];
        final prefix = live.take(expected.length).toList();
        if (prefix.join(',') != expected.join(',')) {
          stderr.writeln(
            'CSV gid=${spec.gid} header changed: $firstLine',
          );
        } else {
          stdout.writeln('CSV gid=${spec.gid} header OK: $firstLine');
        }
      } finally {
        client.close();
      }
    }
  }

  Future<void> _batch(List<Request> requests) async {
    const chunkSize = 40;
    for (var offset = 0; offset < requests.length; offset += chunkSize) {
      final chunk = requests.sublist(
        offset,
        math.min(offset + chunkSize, requests.length),
      );
      if (chunk.isEmpty) {
        continue;
      }
      await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(requests: chunk),
        _spreadsheetId,
      );
    }
  }
}

final class _SpreadsheetMeta {
  const _SpreadsheetMeta({required this.locale, required this.sheets});

  final String? locale;
  final List<Sheet> sheets;
}

final class _SheetPlan {
  const _SheetPlan({required this.cleanup, required this.format});

  final List<Request> cleanup;
  final List<Request> format;
}

final class _CellWrite {
  const _CellWrite({required this.row, required this.column, required this.value});

  final int row;
  final int column;
  final String value;
}

final Border _outerBorder = Border(
  style: 'SOLID_MEDIUM',
  width: 1,
  color: Color(red: 0.42, green: 0.50, blue: 0.44),
);

final Border _innerBorder = Border(
  style: 'SOLID',
  width: 1,
  color: Color(red: 0.62, green: 0.68, blue: 0.63),
);

final RegExp _datePattern = RegExp(r'^(\d{1,2}\.\d{1,2}\.\d{4}|\d{4}-\d{2}-\d{2})$');
final RegExp _timePattern = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');
final RegExp _percentPattern = RegExp(r'^(\d{1,3})\s*%$');
final RegExp _plainNumberPattern = RegExp(r'^\d+([.,]\d+)?$');

Color _color(GoogleSheetsRgb rgb) => Color(red: rgb.red, green: rgb.green, blue: rgb.blue);

List<List<String>> _asStringRows(List<List<Object?>>? values) {
  if (values == null) {
    return const <List<String>>[];
  }
  return [
    for (final row in values) [for (final cell in row) (cell ?? '').toString()],
  ];
}

int _leadingEmptyCount(List<List<String>> rows, Set<int> skipCols) {
  var count = 0;
  for (var row = 1; row < rows.length; row++) {
    var empty = true;
    for (var column = 0; column < rows[row].length; column++) {
      if (skipCols.contains(column)) {
        continue;
      }
      if (rows[row][column].trim().isNotEmpty) {
        empty = false;
        break;
      }
    }
    if (!empty) {
      break;
    }
    count += 1;
  }
  return count;
}

int _lastContentRow(List<List<String>> rows, Set<int> checkboxCols) {
  var last = 0;
  for (var row = 1; row < rows.length; row++) {
    for (var column = 0; column < rows[row].length; column++) {
      if (checkboxCols.contains(column)) {
        continue;
      }
      if (rows[row][column].trim().isNotEmpty) {
        last = row;
        break;
      }
    }
  }
  return last;
}

String _cell(List<String> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index].trim();
}

String _a1(int column) => GoogleSheetsInputUi.columnLetter(column);
