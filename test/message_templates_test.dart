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

  group('MessageTemplates training schedule and promo copy', () {
    const templates = MessageTemplates(botUsername: 'dvor_chatbot');

    test('shows short weekday in trainings schedule date', () {
      final text = templates.trainings(<TrainingInfo>[
        TrainingInfo(
          title: 'Функциональная тренировка',
          startsAt: DateTime(2026, 6, 22, 19, 0),
          location: 'Зал DVOR',
          category: ActivityCategory.trainings,
        ),
      ]);

      expect(text, contains('🕒 пн, 22.06.2026 19:00'));
    });

    test('builds group promo for training day with booking cta', () {
      final text = templates.groupTrainingTodayPromo(
        training: TrainingInfo(
          title: 'Функциональная тренировка',
          startsAt: DateTime(2026, 6, 22, 19, 0),
          location: 'Зал DVOR',
          category: ActivityCategory.trainings,
        ),
      );

      expect(text, contains('Тренировка уже сегодня'));
      expect(text, contains('Записывайся'));
      expect(text, contains('https://t.me/dvor_chatbot?start=start'));
    });

    test('builds day-before promo with tomorrow wording', () {
      final text = templates.groupTrainingTodayPromo(
        training: TrainingInfo(
          title: 'Утренняя тренировка',
          startsAt: DateTime(2026, 6, 22, 10, 0),
          location: 'Зал DVOR',
          category: ActivityCategory.trainings,
        ),
        isToday: false,
      );

      expect(text, contains('Тренировка уже завтра'));
      expect(text, contains('Планируй заранее'));
    });

    test('includes notes in group promo when provided', () {
      final text = templates.groupTrainingTodayPromo(
        training: TrainingInfo(
          title: 'Функциональная тренировка',
          startsAt: DateTime(2026, 6, 22, 19, 0),
          location: 'Зал DVOR',
          category: ActivityCategory.trainings,
          notes: 'Возьми воду и полотенце',
        ),
      );

      expect(text, contains('📝 Возьми воду и полотенце'));
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

      expect(text, contains('Событие: 🥾 Поход: ПИК ЗАКАН'));
      expect(text, contains('📍 Вершина хребта Магито в Карачаево-Черкесии'));
      expect(text, isNot(contains('📍 Где:')));
      expect(text, isNot(contains('Тренировка:')));
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

    test('shows outdoor 50-50 payment split in requisites', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'hikes|2026-06-14T00:00:00.000Z|🥾 Поход: ПИК ЗАКАН|Магито',
          trainingTitle: '🥾 Поход: ПИК ЗАКАН',
          location: 'Вершина хребта Магито в Карачаево-Черкесии',
        ),
      );

      expect(text, contains('Реквизиты OUTDVOR'));
      expect(text, contains('К оплате сейчас:'));
      expect(text, contains('750 ₽'));
      expect(text, contains('Остальные 50% — после похода.'));
    });

    test('shows trail-specific final payment wording in requisites', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'trails|2026-08-14T00:00:00.000Z|🏃 Трейл: FISH-TRAIL|Фишт',
          trainingTitle: '🏃 Трейл: FISH-TRAIL',
          location: 'Плато Фишт',
        ),
      );

      expect(text, contains('Остальные 50% — после трейла.'));
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
          location: 'Красная Поляна, старт у подъемника',
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
          location: 'Плато Фишт',
          itinerary: 'Сбор 05:00, выезд 05:30, старт 08:00',
        ),
      ]);

      expect(text, contains('Расписание ближайших трейлов'));
      expect(text, contains('Трейл Фишт'));
      expect(text, contains('Сбор 05:00, выезд 05:30, старт 08:00'));
    });

    test('renders outdoor schedule location when provided', () {
      final text = templates.hikes(<OutdoorActivityInfo>[
        OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Поход на Бзерпинский карниз',
          dateFrom: DateTime(2026, 9, 12),
          dateTo: DateTime(2026, 9, 12, 23, 59, 59),
          location: 'Роза Хутор, КПП Лаура',
          description: 'Маршрут среднего уровня',
        ),
      ]);

      expect(text, contains('📍 Где: Роза Хутор, КПП Лаура'));
    });

    test('renders full multi-line trail description in schedule list', () {
      final text = templates.trails(<OutdoorActivityInfo>[
        OutdoorActivityInfo(
          type: OutdoorActivityType.trail,
          title: 'Трейл Фишт',
          dateFrom: DateTime(2026, 8, 2),
          dateTo: DateTime(2026, 8, 3, 23, 59, 59),
          description: 'Готовы к настоящему вызову? Тогда вперед!\n\n'
              'Трейл от Яворовой Поляны до Фишта - это уже не прогулка.\n'
              '• реальные подъемы и участки, где придется включать характер\n'
              '• живописные тропы, свежий горный воздух',
          location: 'Плато Фишт',
        ),
      ]);

      expect(text, contains('📝 <b>Описание:</b>'));
      expect(text, contains('Готовы к настоящему вызову? Тогда вперед!'));
      expect(
        text,
        contains('Трейл от Яворовой Поляны до Фишта - это уже не прогулка.'),
      );
      expect(text, contains('• реальные подъемы и участки, где придется включать характер'));
      expect(text, contains('• живописные тропы, свежий горный воздух'));
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
