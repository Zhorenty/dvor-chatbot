import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

void main() {
  group('MessageTemplates group spot notifications', () {
    const templates = MessageTemplates(botUsername: 'dvor_chatbot');

    test('uses hike wording when no spots are left', () {
      final text = templates.groupTrainingNoSpotsLeft(
        training: TrainingInfo(
          title: '🥾 Поход: ПИК ЗАКАН',
          startsAt: DateTime(2026, 6, 14, 10, 0),
          location: 'Вершина хребта Магито',
          category: ActivityCategory.hikes,
          participantsLimit: 15,
        ),
        participantsLimit: 15,
      );

      expect(text, contains('В походе не осталось мест'));
    });

    test('uses trail wording when no spots are left', () {
      final text = templates.groupTrainingNoSpotsLeft(
        training: TrainingInfo(
          title: '🏃 Трейл: Эльбрус',
          startsAt: DateTime(2026, 6, 14, 10, 0),
          location: 'Приэльбрусье',
          category: ActivityCategory.trails,
          participantsLimit: 20,
        ),
        participantsLimit: 20,
      );

      expect(text, contains('На трейле не осталось мест'));
    });

    test('uses hike wording when spots are almost over', () {
      final text = templates.groupTrainingLowSpots(
        training: TrainingInfo(
          title: '🥾 Поход: ПИК ЗАКАН',
          startsAt: DateTime(2026, 6, 14, 10, 0),
          location: 'Вершина хребта Магито',
          category: ActivityCategory.hikes,
          participantsLimit: 15,
        ),
        freeSpots: 3,
        participantsLimit: 15,
      );

      expect(text, contains('В походе почти не осталось мест'));
    });
  });
}
