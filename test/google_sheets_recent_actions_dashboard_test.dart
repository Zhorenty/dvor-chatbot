import 'package:dvor_chatbot/src/data/google_sheets_recent_actions_dashboard.dart';
import 'package:dvor_chatbot/src/domain/conversation_log.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsRecentActionsDashboard', () {
    test('clips to limit and keeps newest-first order', () {
      final dashboard = GoogleSheetsRecentActionsDashboard.build(
        entries: <ConversationLogEntry>[
          _entry(
              id: 3, userId: 10, username: 'ann', at: DateTime.utc(2026, 8, 18, 12), text: 'три'),
          _entry(
              id: 2, userId: 11, username: 'bob', at: DateTime.utc(2026, 8, 18, 11), text: 'два'),
          _entry(
              id: 1, userId: 12, username: 'cat', at: DateTime.utc(2026, 8, 18, 10), text: 'один'),
        ],
        generatedAt: DateTime.utc(2026, 8, 18, 13),
        limit: 2,
      );

      expect(dashboard.sheetTitle, 'ДЕЙСТВИЯ');
      expect(dashboard.obsoleteSheetTitles, isEmpty);
      expect(dashboard.rows.first.first, 'DVOR · Действия');
      final header = dashboard.rows.firstWhere(
        (row) => row.isNotEmpty && row.first == 'когда',
      );
      expect(
        header.take(6).toList(),
        <Object?>['когда', 'направление', 'user_id', 'username', 'тип', 'превью'],
      );
      final previews = dashboard.rows
          .map((row) => row.length > 5 ? row[5] : null)
          .whereType<String>()
          .where((value) => value == 'три' || value == 'два' || value == 'один')
          .toList();
      expect(previews, <String>['три', 'два']);
    });

    test('renders empty log placeholder', () {
      final dashboard = GoogleSheetsRecentActionsDashboard.build(
        entries: const <ConversationLogEntry>[],
        generatedAt: DateTime.utc(2026, 8, 18, 9),
      );

      expect(
        dashboard.rows.any(
          (row) => row.isNotEmpty && row.first.toString().contains('Пока пусто'),
        ),
        isTrue,
      );
    });
  });
}

ConversationLogEntry _entry({
  required int id,
  required int userId,
  required String username,
  required DateTime at,
  required String text,
}) {
  return ConversationLogEntry(
    id: id,
    occurredAt: at,
    direction: ConversationDirection.inbound,
    peerUserId: userId,
    peerUsername: username,
    chatId: userId,
    contentType: ConversationContentType.text,
    textPreview: text,
  );
}
