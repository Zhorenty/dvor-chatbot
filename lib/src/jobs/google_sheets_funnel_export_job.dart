import 'package:dvor_chatbot/src/application/admin_analytics_service.dart';
import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/application/nobles_list_service.dart';
import 'package:dvor_chatbot/src/data/conversation_log_repository.dart';
import 'package:dvor_chatbot/src/data/google_sheets_analytics_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_nobles_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_recent_actions_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:l/l.dart';

final class GoogleSheetsFunnelExportJob {
  GoogleSheetsFunnelExportJob({
    required OnboardingRepository onboardingRepository,
    required GoogleSheetsWriter writer,
    required AdminAnalyticsService adminAnalyticsService,
    required EconomicSummaryService economicSummaryService,
    required NoblesListService noblesListService,
    ConversationLogRepository conversationLogRepository = const NoopConversationLogRepository(),
    Set<int> adminUserIds = const <int>{},
    this.sheetTitle = GoogleSheetsFunnelDashboard.defaultSheetTitle,
    this.recentActionsLimit = 200,
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _writer = writer,
        _adminAnalyticsService = adminAnalyticsService,
        _economicSummaryService = economicSummaryService,
        _noblesListService = noblesListService,
        _conversationLogRepository = conversationLogRepository,
        _adminUserIds = adminUserIds,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final GoogleSheetsWriter _writer;
  final AdminAnalyticsService _adminAnalyticsService;
  final EconomicSummaryService _economicSummaryService;
  final NoblesListService _noblesListService;
  final ConversationLogRepository _conversationLogRepository;
  final Set<int> _adminUserIds;
  final String sheetTitle;
  final int recentActionsLimit;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    try {
      final now = _nowProvider();
      await _replaceSheet('FUNNEL', () => _buildFunnel(now));
      await _replaceSheet('АНАЛИТИКА', () => _buildAnalytics(now));
      await _replaceSheet('ДВОРЯНЕ', () => _buildNobles(now));
      await _replaceSheet('ДЕЙСТВИЯ', () => _buildRecentActions(now));
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

  Future<GoogleSheetsDashboard> _buildNobles(DateTime now) async {
    final result = await _noblesListService.buildStats();
    return GoogleSheetsNoblesDashboard.build(
      users: result.users,
      totalTrainings: result.totalTrainings,
      generatedAt: now,
    );
  }

  Future<GoogleSheetsDashboard> _buildRecentActions(DateTime now) async {
    final entries = await _conversationLogRepository.recentActions(
      limit: recentActionsLimit,
      excludePeerIds: _adminUserIds,
    );
    return GoogleSheetsRecentActionsDashboard.build(
      entries: entries,
      generatedAt: now,
      limit: recentActionsLimit,
    );
  }
}
