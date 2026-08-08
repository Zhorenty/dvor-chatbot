import 'package:dvor_chatbot/src/domain/frank_by_basta.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:test/test.dart';

void main() {
  group('FrankByBasta', () {
    test('matches schedule title with latin BASTA', () {
      expect(FrankByBasta.matchesTitle('🔴 DVORSPORT | FRANK BY BASTA'), isTrue);
    });

    test('matches title with cyrillic Баста', () {
      expect(FrankByBasta.matchesTitle('DVOR x FRANK by Баста'), isTrue);
    });

    test('ignores unrelated trainings', () {
      expect(FrankByBasta.matchesTitle('Функциональная тренировка'), isFalse);
      expect(FrankByBasta.matchesTitle('Frank Ocean yoga'), isFalse);
    });

    test('findIn returns earliest matching upcoming row', () {
      final later = TrainingInfo(
        title: '🔴 DVORSPORT | FRANK BY BASTA',
        startsAt: DateTime(2026, 8, 22, 8, 30),
        location: 'Later',
        price: 0,
      );
      final earlier = TrainingInfo(
        title: '🔴 DVORSPORT | FRANK BY BASTA',
        startsAt: DateTime(2026, 8, 15, 8, 30),
        location: 'Мост Поцелуев',
        price: 0,
      );
      final found = FrankByBasta.findIn(<TrainingInfo>[
        later,
        earlier,
        TrainingInfo(
          title: 'Силовая база',
          startsAt: DateTime(2026, 8, 10, 11),
          location: 'Hall',
          price: 500,
        ),
      ]);
      expect(found, same(earlier));
    });
  });
}
