import 'package:dvor_chatbot/src/data/google_sheets_promo_code_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/promo_code.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsPromoCodeRepository', () {
    test('loads promo codes from dedicated gid', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv?gid=0'),
        httpClient: MockClient((request) async {
          return http.Response(
            'code,discount_percent,categories\n'
            'SUMMER10,10,тренировки\n'
            'FREEDAY,100,все',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      final refreshed = await repository.refresh(force: true);
      expect(refreshed, isTrue);

      expect(
        repository.all(),
        const <PromoCode>[
          PromoCode(
            code: 'SUMMER10',
            discountPercent: 10,
            categories: <ActivityCategory>{ActivityCategory.trainings},
          ),
          PromoCode(code: 'FREEDAY', discountPercent: 100),
        ],
      );
    });

    test('supports column aliases and percent sign', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'промокод,скидка,тип\n'
            'YOGA20,20%,йога',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      await repository.refresh(force: true);
      final promo = repository.findByCode('yoga20');
      expect(promo, isNotNull);
      expect(promo!.discountPercent, 20);
      expect(promo.categories, <ActivityCategory>{ActivityCategory.yoga});
    });

    test('supports multiple categories separated by comma or semicolon', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'code,discount_percent,categories\n'
            'MULTI,15,поход; трейл',
            200,
            headers: const <String, String>{'content-type': 'text/csv; charset=utf-8'},
          );
        }),
      );

      await repository.refresh(force: true);
      final promo = repository.findByCode('MULTI');
      expect(
        promo!.categories,
        <ActivityCategory>{ActivityCategory.hikes, ActivityCategory.trails},
      );
    });

    test('skips rows with invalid or missing discount percent', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'code,discount_percent\n'
            'BAD1,abc\n'
            'BAD2,0\n'
            'BAD3,\n'
            'GOOD,50',
            200,
          );
        }),
      );

      await repository.refresh(force: true);
      expect(repository.all(), hasLength(1));
      expect(repository.all().single.code, 'GOOD');
    });

    test('caps discount percent at 100', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'code,discount_percent\n'
            'HUGE,250',
            200,
          );
        }),
      );

      await repository.refresh(force: true);
      expect(repository.findByCode('HUGE')!.discountPercent, 100);
    });

    test('keeps previous cache when refresh fails', () async {
      var requests = 0;
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          requests += 1;
          if (requests == 1) {
            return http.Response(
              'code,discount_percent\n'
              'SUMMER10,10',
              200,
            );
          }
          return http.Response('server error', 500);
        }),
      );

      final firstRefresh = await repository.refresh(force: true);
      expect(firstRefresh, isTrue);
      expect(repository.all(), hasLength(1));

      final secondRefresh = await repository.refresh(force: true);
      expect(secondRefresh, isFalse);
      expect(repository.all(), hasLength(1));
      expect(repository.all().single.code, 'SUMMER10');
    });

    test('last row wins for duplicate codes', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'code,discount_percent\n'
            'DUP,10\n'
            'dup,30',
            200,
          );
        }),
      );

      await repository.refresh(force: true);
      expect(repository.all(), hasLength(1));
      expect(repository.findByCode('DUP')!.discountPercent, 30);
    });

    test('findByCode is case-insensitive', () async {
      final repository = GoogleSheetsPromoCodeRepository(
        csvUrl: Uri.parse('https://example.com/schedule.csv'),
        httpClient: MockClient((request) async {
          return http.Response(
            'code,discount_percent\n'
            'SUMMER10,10',
            200,
          );
        }),
      );

      await repository.refresh(force: true);
      expect(repository.findByCode('summer10'), isNotNull);
      expect(repository.findByCode('  SuMmEr10  '.trim()), isNotNull);
    });
  });

  group('PromoCode', () {
    test('appliesTo returns true for empty categories set', () {
      const promo = PromoCode(code: 'ALL', discountPercent: 10);
      expect(promo.appliesTo(ActivityCategory.trainings), isTrue);
      expect(promo.appliesTo(ActivityCategory.yoga), isTrue);
    });

    test('appliesTo restricts to configured categories', () {
      const promo = PromoCode(
        code: 'YOGA',
        discountPercent: 10,
        categories: <ActivityCategory>{ActivityCategory.yoga},
      );
      expect(promo.appliesTo(ActivityCategory.yoga), isTrue);
      expect(promo.appliesTo(ActivityCategory.trainings), isFalse);
    });
  });
}
