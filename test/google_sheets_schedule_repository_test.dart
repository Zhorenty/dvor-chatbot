import 'package:dvor_chatbot/src/data/google_sheets_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
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
      expect(upcoming.first.participantsLimit, isNull);
      expect(upcoming.first.includeTrainersInParticipants, isFalse);
      expect(upcoming.first.locationUrl, isNull);
      expect(upcoming.last.title, 'Functional');
      expect(upcoming.last.price, 700);
      expect(upcoming.last.participantsLimit, 16);
      expect(upcoming.last.includeTrainersInParticipants, isTrue);
      expect(upcoming.last.locationUrl, 'https://maps.example/functional');
    });

    test('loads and returns upcoming trainings from date and time columns', () async {
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          final gid = request.url.queryParameters['gid'];
          if (gid == null || gid == '0') {
            return http.Response(
              'title,date,time,location,location_url,price,participants_limit,coach,notes,include_trainers_in_participants\n'
              'Functional,2030-06-04,19:00,Gym A,https://maps.example/functional,700,14,Alex,Bring water,yes\n'
              'Cardio,2030-06-02,18:30,Stadium B,,500,0,,,',
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
      expect(upcoming.first.participantsLimit, isNull);
      expect(upcoming.first.includeTrainersInParticipants, isFalse);
      expect(upcoming.first.locationUrl, isNull);
      expect(upcoming.last.title, 'Functional');
      expect(upcoming.last.startsAt, DateTime(2030, 6, 4, 19, 0));
      expect(upcoming.last.price, 700);
      expect(upcoming.last.participantsLimit, 14);
      expect(upcoming.last.includeTrainersInParticipants, isTrue);
      expect(upcoming.last.locationUrl, 'https://maps.example/functional');
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
      expect(outdoor.first.location, 'Sochi National Park');
      expect(outdoor.first.participantsLimit, 24);
      expect(outdoor.first.equipment, 'Waterproof jacket, trekking shoes');
      expect(outdoor.first.itinerary, 'Gathering 06:30, start 08:00');
      expect(outdoor.last.type, OutdoorActivityType.trail);
      expect(outdoor.last.title, 'Mountain trail');
      expect(outdoor.last.location, 'Lago-Naki Plateau');
      expect(outdoor.last.price, 4500);
      expect(outdoor.last.participantsLimit, isNull);
      expect(outdoor.last.equipment, 'Headlamp, warm layer');
      expect(outdoor.last.itinerary, 'Day 1 climb, day 2 ridge');
    });

    test('loads upcoming yoga from dedicated sheet id', () async {
      final repository = GoogleSheetsScheduleRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv?gid=0'),
        httpClient: MockClient(_mockCsvResponse),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      final yoga = repository.upcomingYoga(now: DateTime(2030, 6, 1), limit: 10);
      expect(yoga, hasLength(1));
      expect(yoga.single.title, 'Morning flow');
      expect(yoga.single.category, ActivityCategory.yoga);
      expect(yoga.single.startsAt, DateTime(2030, 6, 3, 8, 30));
      expect(yoga.single.location, 'Studio C');
      expect(yoga.single.participantsLimit, 12);
      expect(yoga.single.coach, 'Mia');
    });
  });
}

Future<http.Response> _mockCsvResponse(http.Request request) async {
  final gid = request.url.queryParameters['gid'];
  if (gid == '294119056') {
    return http.Response(
      'title,date_from,date_to,location,description,equipment,itinerary,price,participants_limit\n'
      'Hike to waterfalls,2030-06-05,,Sochi National Park,One day route,"Waterproof jacket, trekking shoes","Gathering 06:30, start 08:00",2000,24',
      200,
    );
  }
  if (gid == '1220729038') {
    return http.Response(
      'title,date_from,date_to,location,description,equipment,itinerary,price,participants_limit\n'
      'Mountain trail,2030-06-12,2030-06-14,Lago-Naki Plateau,Three day route,"Headlamp, warm layer","Day 1 climb, day 2 ridge",4500,0',
      200,
    );
  }
  if (gid == '469715453') {
    return http.Response(
      'title,starts_at,location,price,participants_limit,coaches\n'
      'Morning flow,2030-06-03 08:30,Studio C,600,12,Mia',
      200,
    );
  }
  return http.Response(
    'title,starts_at,location,location_url,price,participants_limit,include_trainers_in_participants,coach,notes\n'
    'Functional,2030-06-04 19:00,Gym A,https://maps.example/functional,700,16,1,Alex,Bring water\n'
    'Cardio,2030-06-02 18:30,Stadium B,,500,0,0,,',
    200,
  );
}
