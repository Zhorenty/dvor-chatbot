import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_writer.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:l/l.dart';

final class GoogleSheetsFunnelExportJob {
  GoogleSheetsFunnelExportJob({
    required OnboardingRepository onboardingRepository,
    required GoogleSheetsWriter writer,
    this.sheetTitle = GoogleSheetsFunnelDashboard.defaultSheetTitle,
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _writer = writer,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final GoogleSheetsWriter _writer;
  final String sheetTitle;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    try {
      final analytics = await _onboardingRepository.getFunnelAnalytics(
        now: _nowProvider(),
      );
      final dashboard = GoogleSheetsFunnelDashboard.build(
        analytics,
        sheetTitle: sheetTitle,
      );
      await _writer.replaceDashboard(dashboard);
      l.i(
        'Google Sheets funnel export completed. '
        'sheet=$sheetTitle charts=${dashboard.charts.length}',
      );
    } on Object catch (error, stackTrace) {
      l.w('Google Sheets funnel export failed: $error', stackTrace);
    }
  }
}
