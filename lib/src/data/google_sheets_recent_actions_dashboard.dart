import 'package:dvor_chatbot/src/data/google_sheets_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/data/google_sheets_sheet_builder.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';

/// DM action feed for the `ДЕЙСТВИЯ` sheet.
abstract final class GoogleSheetsRecentActionsDashboard {
  static const String defaultSheetTitle = GoogleSheetsFunnelDashboard.recentActionsSheetTitle;
  static const String emptyPlaceholder =
      'Пока пусто. Лог появляется после сообщений пользователей и ответов бота '
      '(история до включения логирования недоступна).';

  static GoogleSheetsDashboard build({
    required List<ConversationLogEntry> entries,
    required DateTime generatedAt,
    int limit = 200,
    String sheetTitle = defaultSheetTitle,
  }) {
    final visible = entries.take(limit < 1 ? 1 : limit).toList(growable: false);
    final sheet = GoogleSheetsSheetBuilder(columnCount: 6);
    sheet.writeBanner(
      title: 'DVOR · Действия',
      generatedAt: generatedAt,
      subtitle: 'Лента DM-лога, без админов, newest first. '
          'Лист обновляет бот — руками не править.',
    );
    sheet.add(
      const <Object?>['когда', 'направление', 'user_id', 'username', 'тип', 'превью'],
    );
    final headerRow = sheet.nextRow - 1;
    if (visible.isEmpty) {
      sheet.add(<Object?>[emptyPlaceholder, '', '', '', '', '']);
    } else {
      for (final entry in visible) {
        sheet.add(
          <Object?>[
            GoogleSheetsDashboardTheme.stamp.format(entry.occurredAt.toLocal()),
            _directionLabel(entry.direction),
            entry.peerUserId,
            entry.peerUsername ?? '',
            _contentTypeLabel(entry.contentType),
            _plainPreview(entry.textPreview),
          ],
        );
      }
    }
    sheet.table(headerRow, sheet.nextRow, 0, 6);
    return sheet.toDashboard(
      sheetTitle: sheetTitle,
      columnWidthsPx: const <int>[150, 120, 110, 160, 110, 420],
      frozenRowCount: headerRow + 1,
      minPaintRows: visible.length + 8,
    );
  }

  static String _directionLabel(ConversationDirection direction) => switch (direction) {
        ConversationDirection.inbound => 'входящее',
        ConversationDirection.outbound => 'исходящее',
      };

  static String _contentTypeLabel(ConversationContentType type) => switch (type) {
        ConversationContentType.text => 'текст',
        ConversationContentType.photo => 'фото',
        ConversationContentType.document => 'документ',
        ConversationContentType.copy => 'копия',
        ConversationContentType.other => 'сообщение',
      };

  static String _plainPreview(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    return trimmed
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
