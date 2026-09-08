import 'package:dvor_chatbot/src/application/admin_analytics_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/data/google_sheets_analytics_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:l/l.dart';

final class GoogleSheetsFunnelExportJob {
  GoogleSheetsFunnelExportJob({
    required OnboardingRepository onboardingRepository,
    required GoogleSheetsWriter writer,
    required AdminAnalyticsService adminAnalyticsService,
    required EconomicSummaryService economicSummaryService,
    this.sheetTitle = GoogleSheetsFunnelDashboard.defaultSheetTitle,
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _writer = writer,
        _adminAnalyticsService = adminAnalyticsService,
        _economicSummaryService = economicSummaryService,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final GoogleSheetsWriter _writer;
  final AdminAnalyticsService _adminAnalyticsService;
  final EconomicSummaryService _economicSummaryService;
  final String sheetTitle;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    try {
      final now = _nowProvider();
      await _replaceSheet('FUNNEL', () => _buildFunnel(now));
      await _replaceSheet('АНАЛИТИКА', () => _buildAnalytics(now));
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets export failed: $error', stackTrace);
    }
  }

  Future<void> _replaceSheet(
    String label,
    Future<GoogleSheetsDashboard> Function() build,
  ) async {
    try {
      final dashboard = await build();
      await _writer.replaceDashboard(dashboard);
      l.i(
        'Google Sheets $label export completed. '
        'sheet=${dashboard.sheetTitle} charts=${dashboard.charts.length}',
      );
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets $label export failed: $error', stackTrace);
    }
  }

  Future<GoogleSheetsDashboard> _buildFunnel(DateTime now) async {
    final analytics = await _onboardingRepository.getFunnelAnalytics(now: now);
    return GoogleSheetsFunnelDashboard.build(analytics, sheetTitle: sheetTitle);
  }

  Future<GoogleSheetsDashboard> _buildAnalytics(DateTime now) async {
    final bookings = await _adminAnalyticsService.buildBookingAnalytics(now: now);
    final loyalty = await _adminAnalyticsService.buildLoyaltyAnalytics(now: now);
    final subscriptions = await _adminAnalyticsService.buildSubscriptionAnalytics(now: now);
    final currentWeek = await _economicSummaryService.buildSummary(
      _economicSummaryService.currentWeeklyPeriod(now),
    );
    final currentMonth = await _economicSummaryService.buildSummary(
      _economicSummaryService.currentMonthlyPeriod(now),
    );
    return GoogleSheetsAnalyticsDashboard.build(
      bookings: bookings,
      loyalty: loyalty,
      subscriptions: subscriptions,
      currentWeek: currentWeek,
      currentMonth: currentMonth,
    );
  }
}
