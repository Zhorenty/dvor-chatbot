import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';

/// Transport for writing rows and dashboards into a Google Spreadsheet.
abstract interface class GoogleSheetsWriter {
  Future<void> replaceSheet({
    required String sheetTitle,
    required List<List<Object?>> rows,
  });

  Future<void> replaceDashboard(GoogleSheetsDashboard dashboard);

  Future<void> close();
}

/// Low-level spreadsheet operations used by the Google Sheets API writer.
abstract interface class GoogleSheetsSpreadsheetGateway {
  Future<Set<String>> listSheetTitles();

  Future<List<GoogleSheetsSheetInfo>> describeSheets();

  Future<void> addSheet(String title);

  Future<void> deleteSheet(int sheetId);

  Future<void> clearRange(String a1Range);

  Future<void> updateValues({
    required String a1Range,
    required List<List<Object?>> rows,
    String valueInputOption = 'RAW',
  });

  Future<void> applyDashboardLook({
    required int sheetId,
    required GoogleSheetsDashboard dashboard,
  });

  Future<void> close();
}
