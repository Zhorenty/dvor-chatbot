import 'dart:async';

import 'package:dvor_chatbot/src/config/app_config.dart';
import 'package:dvor_chatbot/src/data/google_sheets_credentials.dart';
import 'package:dvor_chatbot/src/data/google_sheets_ids.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/telegram/retry.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

final class GoogleSheetsApiWriter implements GoogleSheetsWriter {
  GoogleSheetsApiWriter({
    required GoogleSheetsSpreadsheetGateway gateway,
    Duration requestTimeout = const Duration(seconds: 20),
  })  : _gateway = gateway,
        _requestTimeout = requestTimeout;

  final GoogleSheetsSpreadsheetGateway _gateway;
  final Duration _requestTimeout;

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
    Duration requestTimeout = const Duration(seconds: 20),
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
    final spreadsheet = await _api.spreadsheets.get(
      _spreadsheetId,
      $fields: 'sheets.properties.title',
    );
    return spreadsheet.sheets
            ?.map((sheet) => sheet.properties?.title)
            .whereType<String>()
            .toSet() ??
        const <String>{};
  }

  @override
  Future<void> addSheet(String title) async {
    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: <Request>[
          Request(
            addSheet: AddSheetRequest(
              properties: SheetProperties(title: title),
            ),
          ),
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
  }) async {
    await _api.spreadsheets.values.update(
      ValueRange(values: rows),
      _spreadsheetId,
      a1Range,
      valueInputOption: 'RAW',
    );
  }

  @override
  Future<void> close() async {
    _authClient?.close();
  }
}
