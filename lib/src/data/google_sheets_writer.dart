/// Transport for writing rows into a Google Spreadsheet.
abstract interface class GoogleSheetsWriter {
  Future<void> replaceSheet({
    required String sheetTitle,
    required List<List<Object?>> rows,
  });

  Future<void> close();
}

/// Low-level spreadsheet operations used by [GoogleSheetsApiWriter].
abstract interface class GoogleSheetsSpreadsheetGateway {
  Future<Set<String>> listSheetTitles();

  Future<void> addSheet(String title);

  Future<void> clearRange(String a1Range);

  Future<void> updateValues({
    required String a1Range,
    required List<List<Object?>> rows,
  });

  Future<void> close();
}
