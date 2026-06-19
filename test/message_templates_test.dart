import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
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

    test('keeps outdoor location as plain text in group notifications', () {
      final text = templates.groupTrainingLowSpots(
        training: TrainingInfo(
          title: '🥾 Поход: ПИК ЗАКАН',
          startsAt: DateTime(2026, 6, 14, 10, 0),
          location: 'Вершина хребта Магито в Карачаево-Черкесии',
          category: ActivityCategory.hikes,
          participantsLimit: 15,
        ),
        freeSpots: 3,
        participantsLimit: 15,
      );

      expect(text, contains('📍 Где: Вершина хребта Магито в Карачаево-Черкесии'));
      expect(text, isNot(contains('<a href=')));
      expect(text, isNot(contains('google.com/maps/search')));
    });
  });

  group('MessageTemplates booking location formatting', () {
    const templates = MessageTemplates();

    test('keeps outdoor booking location as plain text', () {
      final text = templates.bookingCreated(
        _booking(
          trainingKey: 'hikes|2026-06-14T00:00:00.000Z|🥾 Поход: ПИК ЗАКАН|Магито',
          trainingTitle: '🥾 Поход: ПИК ЗАКАН',
          location: 'Вершина хребта Магито в Карачаево-Черкесии',
        ),
      );

      expect(text, contains('📍 Где: Вершина хребта Магито в Карачаево-Черкесии'));
      expect(text, isNot(contains('<a href=')));
      expect(text, isNot(contains('google.com/maps/search')));
    });

    test('keeps indoor booking location as maps link', () {
      final text = templates.bookingCreated(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Зал DVOR',
        ),
      );

      expect(text, contains('<a href="https://www.google.com/maps/search/?api=1'));
      expect(text, contains('📍 Где: <a href='));
    });
  });

  group('MessageTemplates payment lifecycle copy', () {
    const templates = MessageTemplates();

    test('includes 120-minute payment ttl in requisites', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Зал DVOR',
        ),
      );

      expect(text, contains('в течение 120 минут'));
      expect(text, contains('запись отменится автоматически'));
    });
  });

  group('MessageTemplates outdoor details copy', () {
    const templates = MessageTemplates();

    test('renders hikes equipment details as separate block', () {
      final text = templates.hikesEquipment(<OutdoorActivityInfo>[
        OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Поход на Ачишхо',
          dateFrom: DateTime(2026, 7, 21),
          dateTo: DateTime(2026, 7, 21, 23, 59, 59),
          description: 'Дневной маршрут',
          equipment: 'Ботинки, дождевик, вода 2л',
        ),
      ]);

      expect(text, contains('Экипировка для ближайших походов'));
      expect(text, contains('Поход на Ачишхо'));
      expect(text, contains('Ботинки, дождевик, вода 2л'));
    });

    test('renders itinerary details for trails', () {
      final text = templates.trailsItinerary(<OutdoorActivityInfo>[
        OutdoorActivityInfo(
          type: OutdoorActivityType.trail,
          title: 'Трейл Фишт',
          dateFrom: DateTime(2026, 8, 2),
          dateTo: DateTime(2026, 8, 3, 23, 59, 59),
          description: 'Горный трек',
          itinerary: 'Сбор 05:00, выезд 05:30, старт 08:00',
        ),
      ]);

      expect(text, contains('Расписание ближайших трейлов'));
      expect(text, contains('Трейл Фишт'));
      expect(text, contains('Сбор 05:00, выезд 05:30, старт 08:00'));
    });
  });
}

TrainingBooking _booking({
  required String trainingKey,
  required String trainingTitle,
  required String location,
}) {
  final now = DateTime(2026, 6, 1, 12, 0);
  return TrainingBooking(
    id: 1,
    userId: 42,
    userUsername: 'test_user',
    trainingKey: trainingKey,
    trainingTitle: trainingTitle,
    startsAt: DateTime(2026, 6, 14, 10, 0),
    location: location,
    status: BookingStatus.pendingPayment,
    trainingPrice: 1500,
    createdAt: now,
    updatedAt: now,
  );
}
