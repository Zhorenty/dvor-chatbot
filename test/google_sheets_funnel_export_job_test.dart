import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/admin_analytics_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/jobs/google_sheets_funnel_export_job.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('GoogleSheetsFunnelExportJob', () {
    test('writes funnel and analytics dashboards and drops bot_bookings from FUNNEL', () async {
      final writer = _FakeGoogleSheetsWriter();
      final job = _job(writer: writer);

      await job.run();

      expect(writer.titles, <String>['FUNNEL', 'АНАЛИТИКА']);
      expect(writer.dashboards.first.obsoleteSheetTitles, contains('bot_bookings'));
      expect(writer.dashboards.first.obsoleteSheetTitles, contains('ДВОРЯНЕ'));
      expect(writer.dashboards.first.obsoleteSheetTitles, contains('ДЕЙСТВИЯ'));
      expect(writer.dashboards.first.obsoleteSheetTitles, contains('КАК ЗАПОЛНЯТЬ'));
      expect(writer.dashboards.first.obsoleteSheetTitles, contains('Команда DVOR'));
      expect(writer.dashboards.first.rows.first.first, 'DVOR · Воронка');
    });

    test('keeps writing remaining sheets when one replaceDashboard fails', () async {
      final writer = _FakeGoogleSheetsWriter()..throwOnTitle = 'АНАЛИТИКА';
      final job = _job(writer: writer);

      await job.run();

      expect(writer.replaceDashboardCalls, 2);
      expect(
        writer.dashboards.map((item) => item.sheetTitle).toList(),
        <String>['FUNNEL'],
      );
    });

    test('swallows writer errors so the bot keeps running', () async {
      final writer = _FakeGoogleSheetsWriter()..throwOnReplace = StateError('quota');
      final job = _job(writer: writer);

      await job.run();

      expect(writer.replaceDashboardCalls, 2);
    });
  });
}

GoogleSheetsFunnelExportJob _job({
  required _FakeGoogleSheetsWriter writer,
}) {
  final booking = FakeBookingRepository();
  final onboarding = FakeOnboardingRepository();
  final subscriptions = FakeSubscriptionRepository();
  final schedule = FakeScheduleRepository(const []);
  final catalog = ActivityCatalogService(scheduleRepository: schedule);
  return GoogleSheetsFunnelExportJob(
    onboardingRepository: onboarding,
    writer: writer,
    adminAnalyticsService: AdminAnalyticsService(
      bookingRepository: booking,
      onboardingRepository: onboarding,
      subscriptionRepository: subscriptions,
    ),
    economicSummaryService: EconomicSummaryService(
      bookingRepository: booking,
      catalogService: catalog,
    ),
    nowProvider: () => DateTime.utc(2026, 8, 18, 9),
  );
}

final class _FakeGoogleSheetsWriter implements GoogleSheetsWriter {
  int replaceDashboardCalls = 0;
  final List<GoogleSheetsDashboard> dashboards = <GoogleSheetsDashboard>[];
  Object? throwOnReplace;
  String? throwOnTitle;

  List<String> get titles => dashboards.map((item) => item.sheetTitle).toList(growable: false);

  @override
  Future<void> replaceSheet({
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) async {}

  @override
  Future<void> replaceDashboard(GoogleSheetsDashboard dashboard) async {
    replaceDashboardCalls += 1;
    final always = throwOnReplace;
    if (always != null) {
      throw always;
    }
    if (throwOnTitle != null && dashboard.sheetTitle == throwOnTitle) {
      throw StateError('replace failed: ${dashboard.sheetTitle}');
    }
    dashboards.add(dashboard);
  }

  @override
  Future<void> close() async {}
}
