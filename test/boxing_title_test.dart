import 'package:dvor_chatbot/src/domain/boxing_title.dart';
import 'package:test/test.dart';

void main() {
  group('isBoxingTrainingTitle', () {
    test('matches catalog boxing titles', () {
      expect(isBoxingTrainingTitle('BOXING DVOR'), isTrue);
      expect(isBoxingTrainingTitle('20.08 BOXING'), isTrue);
      expect(isBoxingTrainingTitle('Бокс'), isTrue);
      expect(isBoxingTrainingTitle('бокс'), isTrue);
      expect(isBoxingTrainingTitle('BOX'), isTrue);
      expect(isBoxingTrainingTitle('boxing'), isTrue);
      expect(isBoxingTrainingTitle('Тренировка бокса'), isTrue);
      expect(isBoxingTrainingTitle('Боксёрский слот'), isTrue);
    });

    test('rejects non-boxing titles', () {
      expect(isBoxingTrainingTitle('силовая'), isFalse);
      expect(isBoxingTrainingTitle('Силовая DVOR'), isFalse);
      expect(isBoxingTrainingTitle('забег'), isFalse);
      expect(isBoxingTrainingTitle('CrossFit'), isFalse);
      expect(isBoxingTrainingTitle('Поход'), isFalse);
      expect(isBoxingTrainingTitle('Трейл'), isFalse);
    });
  });
}
