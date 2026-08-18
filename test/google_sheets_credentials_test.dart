import 'dart:io';

import 'package:dvor_chatbot/src/data/google_sheets_credentials.dart';
import 'package:test/test.dart';

void main() {
  group('loadGoogleSheetsServiceAccountJson', () {
    test('loads inline JSON', () {
      const raw = '{"type":"service_account","client_email":"bot@example.iam.gserviceaccount.com"}';
      final parsed = loadGoogleSheetsServiceAccountJson(inlineJson: raw);
      expect(parsed['type'], 'service_account');
      expect(parsed['client_email'], 'bot@example.iam.gserviceaccount.com');
    });

    test('loads JSON from a file path', () {
      final file = File('${Directory.systemTemp.path}/dvor-sheets-creds-test.json')
        ..writeAsStringSync('{"type":"service_account","project_id":"dvor"}');
      addTearDown(() {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
      final parsed = loadGoogleSheetsServiceAccountJson(path: file.path);
      expect(parsed['project_id'], 'dvor');
    });

    test('throws when credentials are missing', () {
      expect(
        () => loadGoogleSheetsServiceAccountJson(),
        throwsFormatException,
      );
    });
  });
}
