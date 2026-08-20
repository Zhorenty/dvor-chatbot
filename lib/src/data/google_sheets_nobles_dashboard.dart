import 'package:dvor_chatbot/src/application/nobles_list_service.dart';
import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_sheet_builder.dart';

/// Ranking table for the `ДВОРЯНЕ` sheet.
abstract final class GoogleSheetsNoblesDashboard {
  static const String defaultSheetTitle = GoogleSheetsFunnelDashboard.noblesSheetTitle;

  static GoogleSheetsDashboard build({
    required List<NobleUserStats> users,
    required int totalTrainings,
    required DateTime generatedAt,
    String sheetTitle = defaultSheetTitle,
  }) {
    final sheet = GoogleSheetsSheetBuilder(columnCount: 4);
    sheet.writeBanner(
      title: 'DVOR · Дворяне',
      generatedAt: generatedAt,
      subtitle: 'Всего записей в зачёт: $totalTrainings. '
          'Правило: starts_at < now, только тренировки. '
          'Лист обновляет бот — руками не править.',
    );
    sheet.add(const <Object?>['#', 'user_id', 'username', 'тренировок']);
    final headerRow = sheet.nextRow - 1;
    if (users.isEmpty) {
      sheet.add(const <Object?>['Пока нет', '', '', 0]);
    } else {
      for (var index = 0; index < users.length; index++) {
        final user = users[index];
        sheet.add(
          <Object?>[
            index + 1,
            user.userId,
            user.username ?? '',
            user.trainingsCount,
          ],
        );
      }
    }
    sheet.table(headerRow, sheet.nextRow, 0, 4);
    return sheet.toDashboard(
      sheetTitle: sheetTitle,
      columnWidthsPx: const <int>[60, 120, 180, 120],
      frozenRowCount: headerRow + 1,
      minPaintRows: users.length + 8,
    );
  }
}
