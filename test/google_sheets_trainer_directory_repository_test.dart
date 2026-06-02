import 'package:dvor_chatbot/src/data/google_sheets_trainer_directory_repository.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsTrainerDirectoryRepository', () {
    test('loads trainers from dedicated gid', () async {
      final repository = GoogleSheetsTrainerDirectoryRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv?gid=0'),
        httpClient: MockClient((request) async {
          final gid = request.url.queryParameters['gid'];
          expect(gid, '195037978');
          return http.Response(
            'name,link,description\n'
            'Alex,@alex,Head coach\n'
            'Maria,maria_run,Running coach',
            200,
          );
        }),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      final items = repository.list();
      expect(
        items,
        const <TrainerInfo>[
          TrainerInfo(name: 'Alex', link: '@alex', description: 'Head coach'),
          TrainerInfo(name: 'Maria', link: '@maria_run', description: 'Running coach'),
        ],
      );
    });

    test('keeps previous cache when refresh fails', () async {
      var requests = 0;
      final repository = GoogleSheetsTrainerDirectoryRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          requests += 1;
          if (requests == 1) {
            return http.Response(
              'name,link,description\n'
              'Alex,@alex,Head coach',
              200,
            );
          }
          return http.Response('server error', 500);
        }),
      );

      final firstRefresh = await repository.refresh(force: true);
      expect(firstRefresh, isTrue);
      expect(repository.list(), hasLength(1));

      final secondRefresh = await repository.refresh(force: true);
      expect(secondRefresh, isFalse);
      expect(repository.list(), hasLength(1));
      expect(repository.list().single.name, 'Alex');
    });
  });
}
