import 'package:dvor_chatbot/src/data/google_sheets_nobles_dashboard.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsNoblesDashboard', () {
    test('keeps ranking order, total and columns', () {
      final dashboard = GoogleSheetsNoblesDashboard.build(
        users: const <({int userId, String? username, int trainingsCount})>[
          (userId: 7, username: 'anna', trainingsCount: 12),
          (userId: 3, username: 'boris', trainingsCount: 8),
          (userId: 9, username: null, trainingsCount: 8),
        ],
        totalTrainings: 28,
        generatedAt: DateTime.utc(2026, 8, 18, 9),
      );

      expect(dashboard.sheetTitle, 'ДВОРЯНЕ');
      expect(dashboard.obsoleteSheetTitles, isEmpty);
      expect(dashboard.rows.first.first, 'DVOR · Дворяне');
      expect(
        dashboard.rows[1].first.toString(),
        contains('Всего записей в зачёт: 28'),
      );
      expect(
        dashboard.rows[1].first.toString(),
        contains('starts_at < now'),
      );
      final header = dashboard.rows.firstWhere(
        (row) => row.isNotEmpty && row.first == '#',
      );
      expect(header.take(4).toList(), <Object?>['#', 'user_id', 'username', 'тренировок']);
      final firstUser = dashboard.rows.firstWhere(
        (row) => row.isNotEmpty && row.first == 1,
      );
      expect(firstUser.take(4).toList(), <Object?>[1, 7, 'anna', 12]);
      expect(dashboard.bandedTables, isNotEmpty);
      expect(dashboard.frozenRowCount, greaterThan(1));
    });

    test('renders an empty ranking table', () {
      final dashboard = GoogleSheetsNoblesDashboard.build(
        users: const <({int userId, String? username, int trainingsCount})>[],
        totalTrainings: 0,
        generatedAt: DateTime.utc(2026, 8, 18, 9),
      );

      expect(
        dashboard.rows.any((row) => row.contains('Пока нет')),
        isTrue,
      );
      expect(dashboard.bandedTables, isNotEmpty);
    });
  });
}
