import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/jobs/google_sheets_funnel_export_job.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('GoogleSheetsFunnelExportJob', () {
    test('writes the FUNNEL dashboard and drops bot_bookings', () async {
      final writer = _FakeGoogleSheetsWriter();
      final job = GoogleSheetsFunnelExportJob(
        onboardingRepository: FakeOnboardingRepository(),
        writer: writer,
        nowProvider: () => DateTime.utc(2026, 8, 18, 9),
      );

      await job.run();

      expect(writer.replaceDashboardCalls, 1);
      expect(writer.lastDashboard?.sheetTitle, 'FUNNEL');
      expect(writer.lastDashboard?.obsoleteSheetTitles, contains('bot_bookings'));
      expect(writer.lastDashboard?.rows.first.first, 'DVOR · Воронка');
    });

    test('swallows writer errors so the bot keeps running', () async {
      final writer = _FakeGoogleSheetsWriter()..throwOnReplace = StateError('quota');
      final job = GoogleSheetsFunnelExportJob(
        onboardingRepository: FakeOnboardingRepository(),
        writer: writer,
      );

      await job.run();

      expect(writer.replaceDashboardCalls, 1);
    });
  });
}

final class _FakeGoogleSheetsWriter implements GoogleSheetsWriter {
  int replaceDashboardCalls = 0;
  GoogleSheetsDashboard? lastDashboard;
  Object? throwOnReplace;

  @override
  Future<void> replaceSheet({
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) async {}

  @override
  Future<void> replaceDashboard(GoogleSheetsDashboard dashboard) async {
    replaceDashboardCalls += 1;
    final error = throwOnReplace;
    if (error != null) {
      throw error;
    }
    lastDashboard = dashboard;
  }

  @override
  Future<void> close() async {}
}
