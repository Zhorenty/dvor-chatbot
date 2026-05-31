import 'package:dvor_chatbot/src/data/google_sheets_schedule_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsScheduleRepository', () {
    test('loads and returns upcoming trainings from csv', () async {
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((_) async {
          return http.Response(
            'title,starts_at,location,coach,notes\n'
            'Functional,2030-06-04 19:00,Gym A,Alex,Bring water\n'
            'Cardio,2030-06-02 18:30,Stadium B,,',
            200,
          );
        }),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      final upcoming = repository.upcoming(now: DateTime(2030, 6, 1), limit: 5);
      expect(upcoming, hasLength(2));
      expect(upcoming.first.title, 'Cardio');
      expect(upcoming.last.title, 'Functional');
    });

    test('keeps previous cache when refresh fails', () async {
      var requestCount = 0;
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((_) async {
          requestCount += 1;
          if (requestCount == 1) {
            return http.Response(
              'title,starts_at,location\nStrength,2030-06-07 11:00,Gym C',
              200,
            );
          }
          return http.Response('server error', 500);
        }),
      );

      final firstRefresh = await repository.refresh(force: true);
      expect(firstRefresh, isTrue);

      final secondRefresh = await repository.refresh(force: true);
      expect(secondRefresh, isFalse);

      final upcoming = repository.upcoming(now: DateTime(2030, 6, 1), limit: 5);
      expect(upcoming, hasLength(1));
      expect(upcoming.single.title, 'Strength');
    });
  });
}
