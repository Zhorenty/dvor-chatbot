import 'package:dvor_chatbot/src/data/google_sheets_dvor_team_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsDvorTeamRepository', () {
    test('loads team usernames from the staff sheet by role', () async {
      Uri? requestedUrl;
      final repository = GoogleSheetsDvorTeamRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv?gid=0'),
        httpClient: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response(
            'имя,username,роль,описание\n'
            'Alex,@alex,Тренер,Head coach\n'
            'Родион,@team_runner,Команда DVOR,\n'
            'Мария,another_member,Команда DVOR,\n'
            '\n',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);
      expect(requestedUrl?.queryParameters['gid'], '195037978');
      expect(repository.containsUsername('@team_runner'), isTrue);
      expect(repository.containsUsername('another_member'), isTrue);
      expect(repository.containsUsername('alex'), isFalse);
      expect(repository.containsUsername('missing'), isFalse);
      expect(repository.usernames(), <String>{'team_runner', 'another_member'});
    });

    test('reads username next to имя and ignores coaches', () async {
      final repository = GoogleSheetsDvorTeamRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'имя,username,роль,статус\n'
            'Родион,@oh_rodya,Команда DVOR,готово\n'
            'Alex,@alex,Тренер,готово\n'
            'Без ника,,Команда DVOR,нет username\n',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      expect(await repository.refresh(force: true), isTrue);
      expect(repository.containsUsername('oh_rodya'), isTrue);
      expect(repository.containsUsername('alex'), isFalse);
      expect(repository.usernames(), <String>{'oh_rodya'});
    });

    test('supports username column aliases', () async {
      final repository = GoogleSheetsDvorTeamRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'telegram,роль\n'
            '@alias_user,Команда DVOR\n',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      expect(await repository.refresh(force: true), isTrue);
      expect(repository.containsUsername('alias_user'), isTrue);
    });

    test('keeps cached usernames within refresh interval', () async {
      var now = DateTime(2026, 8, 6, 12, 0);
      var calls = 0;
      final repository = GoogleSheetsDvorTeamRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        minRefreshInterval: const Duration(minutes: 5),
        nowProvider: () => now,
        httpClient: MockClient((request) async {
          calls += 1;
          return http.Response(
            'username,роль\n@cached_user,Команда DVOR\n',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      expect(await repository.refresh(force: true), isTrue);
      now = now.add(const Duration(minutes: 1));
      expect(await repository.refresh(), isTrue);
      expect(calls, 1);
      expect(repository.containsUsername('cached_user'), isTrue);
    });
  });
}
