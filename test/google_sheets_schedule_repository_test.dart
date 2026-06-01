import 'package:dvor_chatbot/src/data/google_sheets_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsScheduleRepository', () {
    test('loads and returns upcoming trainings from csv', () async {
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return _mockCsvResponse(request);
        }),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      final upcoming = repository.upcoming(now: DateTime(2030, 6, 1), limit: 5);
      expect(upcoming, hasLength(2));
      expect(upcoming.first.title, 'Cardio');
      expect(upcoming.first.price, 500);
      expect(upcoming.last.title, 'Functional');
      expect(upcoming.last.price, 700);
    });

    test('loads and returns upcoming trainings from date and time columns', () async {
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          final gid = request.url.queryParameters['gid'];
          if (gid == null || gid == '0') {
            return http.Response(
              'title,date,time,location,price,coach,notes\n'
              'Functional,2030-06-04,19:00,Gym A,700,Alex,Bring water\n'
              'Cardio,2030-06-02,18:30,Stadium B,500,,',
              200,
            );
          }
          return _mockCsvResponse(request);
        }),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      final upcoming = repository.upcoming(now: DateTime(2030, 6, 1), limit: 5);
      expect(upcoming, hasLength(2));
      expect(upcoming.first.title, 'Cardio');
      expect(upcoming.first.startsAt, DateTime(2030, 6, 2, 18, 30));
      expect(upcoming.first.price, 500);
      expect(upcoming.last.title, 'Functional');
      expect(upcoming.last.startsAt, DateTime(2030, 6, 4, 19, 0));
      expect(upcoming.last.price, 700);
    });

    test('keeps previous cache when refresh fails', () async {
      var requestCount = 0;
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          final gid = request.url.queryParameters['gid'];
          if (gid != null && gid != '0') {
            return _mockCsvResponse(request);
          }
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

    test('loads upcoming hikes and trails from dedicated sheet ids', () async {
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv?gid=0'),
        httpClient: MockClient(_mockCsvResponse),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      final outdoor = repository.upcomingOutdoorActivities(now: DateTime(2030, 6, 1), limit: 10);
      expect(outdoor, hasLength(2));
      expect(outdoor.first.type, OutdoorActivityType.hike);
      expect(outdoor.first.title, 'Hike to waterfalls');
      expect(outdoor.first.dateFrom, DateTime(2030, 6, 5));
      expect(outdoor.first.dateTo, DateTime(2030, 6, 5, 23, 59, 59));
      expect(outdoor.last.type, OutdoorActivityType.trail);
      expect(outdoor.last.title, 'Mountain trail');
      expect(outdoor.last.price, 4500);
    });
  });
}

Future<http.Response> _mockCsvResponse(http.Request request) async {
  final gid = request.url.queryParameters['gid'];
  if (gid == '294119056') {
    return http.Response(
      'title,date_from,date_to,description,price\n'
      'Hike to waterfalls,2030-06-05,,One day route,2000',
      200,
    );
  }
  if (gid == '1220729038') {
    return http.Response(
      'title,date_from,date_to,description,price\n'
      'Mountain trail,2030-06-12,2030-06-14,Three day route,4500',
      200,
    );
  }
  return http.Response(
    'title,starts_at,location,price,coach,notes\n'
    'Functional,2030-06-04 19:00,Gym A,700,Alex,Bring water\n'
    'Cardio,2030-06-02 18:30,Stadium B,500,,',
    200,
  );
}
