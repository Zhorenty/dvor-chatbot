import 'dart:convert';
import 'dart:io';

/// Loads a Google service-account JSON map from a file path or inline JSON.
Map<String, Object?> loadGoogleSheetsServiceAccountJson({
  String? path,
  String? inlineJson,
}) {
  final inline = inlineJson?.trim();
  if (inline != null && inline.isNotEmpty) {
    return _decodeCredentials(inline, source: 'GOOGLE_SHEETS_CREDENTIALS_JSON');
  }
  final credentialsPath = path?.trim();
  if (credentialsPath == null || credentialsPath.isEmpty) {
    throw const FormatException(
      'Google Sheets credentials are missing. '
      'Set GOOGLE_SHEETS_CREDENTIALS_PATH or GOOGLE_SHEETS_CREDENTIALS_JSON.',
    );
  }
  final file = File(credentialsPath);
  if (!file.existsSync()) {
    throw FileSystemException(
      'Google Sheets credentials file not found',
      credentialsPath,
    );
  }
  return _decodeCredentials(
    file.readAsStringSync(),
    source: credentialsPath,
  );
}

Map<String, Object?> _decodeCredentials(String raw, {required String source}) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw FormatException('Google Sheets credentials in $source must be a JSON object.');
  }
  return decoded.map(
    (key, value) => MapEntry(key.toString(), value),
  );
}
