/// Spreadsheet id from a Google Sheets edit/export URL.
String? spreadsheetIdFromSheetsUrl(String? url) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }
  final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(url);
  return match?.group(1);
}

String quoteA1SheetTitle(String title) {
  return "'${title.replaceAll("'", "''")}'";
}
