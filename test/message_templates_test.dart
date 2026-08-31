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
      expect(text, contains('Другие слоты — в боте'));
      expect(text, isNot(contains('появляются регулярно')));
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
      expect(text, isNot(contains('yandex.ru/maps')));
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

      expect(text, contains('Сегодня: Функциональная тренировка'));
      expect(text, contains('Запись в боте, в пару тапов'));
      expect(text, contains('https://t.me/dvor_chatbot?start=book'));
      expect(text, isNot(contains('Хочешь попасть')));
      expect(text, isNot(contains('Записывайся')));
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

      expect(text, contains('Завтра: Утренняя тренировка'));
      expect(text, contains('Запись в боте, в пару тапов'));
      expect(text, isNot(contains('Планируй заранее')));
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

    test('builds schedule broadcast with weekday-aware headline and list', () {
      final text = templates.groupScheduleBroadcast(
        trainings: <TrainingInfo>[
          TrainingInfo(
            title: 'Силовая + растяжка',
            startsAt: DateTime(2026, 7, 21, 19, 30),
            location: 'Стадион Кубань',
            category: ActivityCategory.trainings,
            price: 0,
            coach: 'Дарья Данченко',
          ),
        ],
        weekday: DateTime.tuesday,
      );

      expect(text, contains('Середина недели'));
      expect(text, contains('Силовая + растяжка'));
      expect(text, contains('вт, 21.07.2026 19:30'));
      expect(text, contains('бесплатная'));
      expect(text, contains('Дарья Данченко'));
      expect(text, contains('https://t.me/dvor_chatbot?start=book'));
    });

    test('schedule broadcast headlines stay factual without FOMO', () {
      final sample = <TrainingInfo>[
        TrainingInfo(
          title: 'Силовая + растяжка',
          startsAt: DateTime(2026, 7, 21, 19, 30),
          location: 'Стадион Кубань',
          category: ActivityCategory.trainings,
        ),
      ];
      const forbidden = <String>[
        'Не упусти',
        'успей',
        'кайф',
        'комьюнити',
        'досуг',
        'зарядиться',
      ];

      for (final weekday in <int>[
        DateTime.sunday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.monday,
      ]) {
        final text = templates.groupScheduleBroadcast(
          trainings: sample,
          weekday: weekday,
        );
        for (final word in forbidden) {
          expect(text.toLowerCase(), isNot(contains(word.toLowerCase())));
        }
      }

      expect(
        templates.groupScheduleBroadcast(trainings: sample, weekday: DateTime.thursday),
        contains('Слоты до выходных уже в расписании'),
      );
      expect(
        templates.groupScheduleBroadcast(trainings: sample, weekday: DateTime.sunday),
        isNot(contains('Бег, сила, бокс')),
      );
    });

    test('builds referral broadcast with program steps', () {
      final text = templates.groupReferralBroadcast();

      expect(text, contains('Приведи друга'));
      expect(text, contains('Реферальная программа'));
      expect(text, contains('первую платную тренировку'));
      expect(text, contains('https://t.me/dvor_chatbot?start=book'));
      expect(text, isNot(contains('кайф')));
      expect(text, isNot(contains('Собирай свою команду')));
    });
  });

  group('MessageTemplates onboarding funnel copy', () {
    const templates = MessageTemplates();

    test('welcome leads with booking, not a club lecture', () {
      final text = templates.onboardingWelcome();
      expect(text, contains('Первый шаг — записаться на тренировку'));
      expect(text, contains('Что сейчас важнее'));
      expect(text, isNot(contains('комьюнити')));
      expect(text, isNot(contains('семья')));
    });

    test('club map is a booking CTA and optional group door', () {
      final text = templates.onboardingClubMap(starterBonusAvailable: true);
      expect(text, contains('выбрать слот и записаться'));
      expect(text, contains('Можно зайти и ничего не писать'));
      expect(text, contains('приходи один'));
      expect(text, contains('бесплатная тренировка за старт'));
      expect(text, isNot(contains('успей')));
      expect(text, isNot(contains('движ')));
      expect(text, isNot(contains('знаком')));
    });
  });

  group('MessageTemplates brand voice copy', () {
    const templates = MessageTemplates();

    test('private welcome is a slot door, not a cashier-only dump', () {
      final text = templates.privateWelcome();
      expect(text, contains('слоты DVOR'));
      expect(text, contains('Быстрый старт'));
      expect(text, isNot(contains('комьюнити')));
      expect(text, isNot(contains('знаком')));
    });

    test('group welcome has no trophy closer', () {
      final text = templates.groupWelcome(
        username: 'neo',
        userId: 1,
        firstName: 'Neo',
      );
      expect(text, contains('Добро пожаловать в DVOR'));
      expect(text, isNot(contains('Вперёд')));
      expect(text, isNot(contains('🏆')));
    });

    test('onboarding nudge to book stays factual', () {
      final text = templates.onboardingNudgePrimaryCta();
      expect(text, contains('Ближайшие слоты уже в расписании'));
      expect(text, isNot(contains('идеального момента')));
      expect(text, isNot(contains('успей')));
    });

    test('onboarding nudge can name a concrete slot', () {
      final text = templates.onboardingNudgePrimaryCta(
        nearest: TrainingInfo(
          title: 'Утренняя силовая',
          startsAt: DateTime(2026, 7, 26, 8, 0),
          location: 'Стадион',
        ),
      );
      expect(text, contains('Утренняя силовая'));
      expect(text, contains('Стадион'));
      expect(text, contains('Запишись, если подходит'));
    });

    test('onboarding map can list city slots from the sheet', () {
      final text = templates.onboardingClubMap(
        starterBonusAvailable: false,
        citySlots: <TrainingInfo>[
          TrainingInfo(
            title: 'Утренняя силовая',
            startsAt: DateTime(2026, 8, 26, 19),
            location: 'Зал',
          ),
        ],
      );
      expect(text, contains('Силовая: Утренняя силовая'));
      expect(text, isNot(contains('Даша')));
    });

    test('booking slot notes are a fact, not a brand lecture', () {
      final text = templates.bookingSlotPrepNotes(
        trainingTitle: 'Силовая',
        notes: 'Вода и полотенце',
      );
      expect(text, contains('Что взять на «Силовая»'));
      expect(text, contains('Вода и полотенце'));
    });

    test('help opens as slot status, not a gym kiosk slogan', () {
      final text = templates.privateHelp();
      expect(text, contains('слоты, запись и статус'));
      expect(text, isNot(contains('комьюнити')));
    });

    test('outdoor payment confirmation is status, not a manifesto', () {
      final text = templates.paymentApprovedForUser(
        TrainingBooking(
          id: 77,
          userId: 1,
          userUsername: 'neo',
          trainingKey: 'hikes|1',
          trainingTitle: '🥾 Поход: Архыз',
          startsAt: DateTime(2026, 10, 15),
          location: 'Архыз',
          status: BookingStatus.paid,
          trainingPrice: 5000,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      expect(text, contains('Полная оплата подтверждена'));
      expect(text, contains('Место за тобой'));
      expect(text, isNot(contains('новые люди')));
      expect(text, isNot(contains('Готовься')));
      expect(text, isNot(contains('часть команды')));
    });

    test('loyalty unlock is gender-neutral', () {
      final text = templates.everyFifthBonusUnlockedUser(
        completedTrainingsCount: 5,
        availableRewardsCount: 1,
      );
      expect(text, contains('Каждая 5-я'));
      expect(text, isNot(contains('завершил')));
    });

    test('payment submitted goes to review without administration wording', () {
      final text = templates.paymentSubmitted(
        TrainingBooking(
          id: 99,
          userId: 1,
          userUsername: 'neo',
          trainingKey: 'trainings|1',
          trainingTitle: 'Силовая',
          startsAt: DateTime(2026, 7, 1, 19),
          location: 'площадка',
          status: BookingStatus.paymentSubmitted,
          trainingPrice: 500,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      expect(text, contains('на проверку'));
      expect(text, isNot(contains('администратор')));
    });
  });

  group('MessageTemplates group invite nudge', () {
    const templates = MessageTemplates();

    test('first invite has a single CTA to the DVOR group', () {
      final text = templates.groupInviteNudge(1);
      expect(text, contains('группе DVOR'));
      expect(text, contains('расписание и запись'));
      expect(text, contains('можно ничего не писать'));
      expect(text, isNot(contains('не упусти')));
      expect(text, isNot(contains('комьюнити')));
      expect(text, isNot(contains('семьи')));
      final markup = templates.groupInviteUrlKeyboard();
      final inline = markup['inline_keyboard'] as List<dynamic>;
      final button = Map<String, Object?>.from((inline.first as List<dynamic>).first as Map);
      expect(button['text'], 'Открыть группу');
      expect(button['url'], 'https://t.me/+n4ksCb3kFRQ5MTcy');
    });
  });

  group('MessageTemplates admin broadcast', () {
    const templates = MessageTemplates();

    test('prompt mentions photos and albums', () {
      final text = templates.adminBroadcastPrompt();
      expect(text, contains('фото'));
      expect(text, contains('альбом'));
    });

    test('media preview includes photo count', () {
      expect(templates.adminBroadcastMediaPreview(photoCount: 1), contains('1 фото'));
      expect(templates.adminBroadcastMediaPreview(photoCount: 3), contains('3 фото'));
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
      expect(text, contains('📍 Где: Вершина хребта Магито в Карачаево-Черкесии'));
      expect(text, isNot(contains('Тренировка:')));
      expect(text, isNot(contains('google.com/maps/search')));
      expect(text, isNot(contains('yandex.ru/maps')));
    });

    test('uses sheet map url on indoor booking confirmation', () {
      final text = templates.bookingCreated(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Surf Coffee x Riverside',
          locationUrl: 'https://yandex.ru/maps/org/surf_coffee/123',
        ),
      );

      expect(
        text,
        contains(
          '<a href="https://yandex.ru/maps/org/surf_coffee/123">Surf Coffee x Riverside</a>',
        ),
      );
      expect(text, isNot(contains('google.com/maps/search')));
    });

    test('falls back to yandex maps search when indoor booking has no map url', () {
      final text = templates.bookingCreated(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Зал DVOR',
        ),
      );

      expect(
        text,
        contains('<a href="https://yandex.ru/maps/?text=%D0%97%D0%B0%D0%BB%20DVOR">'),
      );
      expect(text, contains('📍 Где: <a href='));
      expect(text, isNot(contains('google.com/maps/search')));
    });
  });

  group('MessageTemplates payment lifecycle copy', () {
    const templates = MessageTemplates();

    test('includes 30-minute payment ttl in requisites', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Зал DVOR',
        ),
      );

      expect(text, contains('30 минут'));
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

    test('shows custom outdoor prepay percent in requisites', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'hikes|2026-06-14T00:00:00.000Z|🥾 Поход: ПИК ЗАКАН|Магито',
          trainingTitle: '🥾 Поход: ПИК ЗАКАН',
          location: 'Вершина хребта Магито в Карачаево-Черкесии',
          trainingPrice: 2000,
          trainingPrepayPercent: 30,
        ),
      );

      expect(text, contains('600 ₽'));
      expect(text, contains('(30% предоплата)'));
      expect(text, contains('Остальные 70% — после похода.'));
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

  group('MessageTemplates promo code copy', () {
    const templates = MessageTemplates();

    test('shows discounted amount in requisites when promo code applied', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Зал DVOR',
          trainingPrice: 750,
          promoCode: 'SUMMER50',
          promoDiscountPercent: 50,
        ),
      );

      expect(text, contains('К оплате: <b>750 ₽</b>'));
      expect(text, contains('SUMMER50'));
      expect(text, contains('−50%'));
    });

    test('does not show promo line when no promo code applied', () {
      final text = templates.paymentInstructions(
        _booking(
          trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
          trainingTitle: '🏋️ Кроссфит',
          location: 'Зал DVOR',
        ),
      );

      expect(text, isNot(contains('промокод')));
    });

    test('promoCodeApplied shows old and new price with discount percent', () {
      final booking = _booking(
        trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
        trainingTitle: '🏋️ Кроссфит',
        location: 'Зал DVOR',
        trainingPrice: 750,
        promoCode: 'SUMMER50',
        promoDiscountPercent: 50,
      );

      final text = templates.promoCodeApplied(booking, originalPrice: 1500);

      expect(text, contains('SUMMER50'));
      expect(text, contains('−50%'));
      expect(text, contains('1500 ₽'));
      expect(text, contains('750 ₽'));
    });

    test('promoCodeAppliedFree announces free booking without payment', () {
      final booking = _booking(
        trainingKey: 'trainings|2026-06-14T19:00:00.000Z|🏋️ Кроссфит|Зал',
        trainingTitle: '🏋️ Кроссфит',
        location: 'Зал DVOR',
        trainingPrice: 0,
        promoCode: 'FREEDAY',
        promoDiscountPercent: 100,
        status: BookingStatus.paid,
      );

      final text = templates.promoCodeAppliedFree(booking, originalPrice: 1500);

      expect(text, contains('FREEDAY'));
      expect(text, contains('−100%'));
      expect(text, contains('бесплатна'));
    });

    test('promoCodeInvalid and promoCodeNotApplicableToCategory return distinct messages', () {
      expect(templates.promoCodeInvalid(),
          isNot(equals(templates.promoCodeNotApplicableToCategory())));
      expect(templates.promoCodeInvalid(), isNotEmpty);
      expect(templates.promoCodeNotApplicableToCategory(), isNotEmpty);
    });

    test('promoCodeEntryPrompt mentions the back button', () {
      expect(templates.promoCodeEntryPrompt(), contains(MessageTemplates.buttonBack));
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

    test('renders selected outdoor detail card with description and price', () {
      final text = templates.chooseOutdoorDetailType(
        OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Поход на Ачишхо',
          dateFrom: DateTime(2026, 7, 21),
          dateTo: DateTime(2026, 7, 21, 23, 59, 59),
          location: 'Красная Поляна',
          description: 'Дневной маршрут\nс красивыми видами',
          price: 2500,
        ),
      );

      expect(text, contains('Поход на Ачишхо'));
      expect(text, contains('📍 Красная Поляна'));
      expect(text, contains('2500 ₽ (1250 ₽ предоплата 50%)'));
      expect(text, contains('📝 <b>Описание:</b>'));
      expect(text, contains('Дневной маршрут'));
      expect(text, contains('с красивыми видами'));
      expect(text, contains('Выбери действие'));
    });

    test('renders custom prepay percent on outdoor detail card', () {
      final text = templates.chooseOutdoorDetailType(
        OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Поход на Ачишхо',
          dateFrom: DateTime(2026, 7, 21),
          dateTo: DateTime(2026, 7, 21, 23, 59, 59),
          location: 'Красная Поляна',
          description: 'Дневной маршрут',
          price: 2500,
          prepayPercent: 40,
        ),
      );

      expect(text, contains('2500 ₽ (1000 ₽ предоплата 40%)'));
    });

    test('renders outdoor interest admin notification', () {
      final text = templates.outdoorInterestAdminNotification(
        userId: 42,
        username: 'hike_fan',
        activity: OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Поход на Ачишхо',
          dateFrom: DateTime(2026, 7, 21),
          dateTo: DateTime(2026, 7, 21, 23, 59, 59),
          location: 'Красная Поляна',
          description: 'Дневной маршрут',
          price: 2500,
        ),
      );

      expect(text, contains('Кто-то заинтересовался походом'));
      expect(text, contains('@hike_fan'));
      expect(text, contains('(42)'));
      expect(text, contains('Поход на Ачишхо'));
      expect(text, contains('Красная Поляна'));
      expect(text, contains('записи ещё нет'));
    });

    test('renders subscription interest admin notification', () {
      final text = templates.subscriptionInterestAdminNotification(
        userId: 77,
        username: 'box_fan',
      );

      expect(text, contains('Кто-то заинтересовался абонементом'));
      expect(text, contains('@box_fan'));
      expect(text, contains('(77)'));
      expect(text, contains('бокс-карту'));
      expect(text, contains('заявки ещё нет'));
    });

    test('renders from-to dates for multi-day hikes in schedule', () {
      final text = templates.hikes(<OutdoorActivityInfo>[
        OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Поход на Фишт',
          dateFrom: DateTime(2026, 8, 2),
          dateTo: DateTime(2026, 8, 4, 23, 59, 59),
          location: 'Плато Фишт',
          description: 'Трёхдневный маршрут с ночёвками',
        ),
        OutdoorActivityInfo(
          type: OutdoorActivityType.hike,
          title: 'Однодневный выход',
          dateFrom: DateTime(2026, 8, 10),
          dateTo: DateTime(2026, 8, 10, 23, 59, 59),
          description: 'Дневной маршрут',
        ),
      ]);

      expect(text, contains('🕒 от 02.08.2026 до 04.08.2026'));
      expect(text, contains('🕒 10.08.2026'));
      expect(text, isNot(contains('от 10.08.2026 до 10.08.2026')));
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
  String? locationUrl,
  int? trainingPrice,
  int? trainingPrepayPercent,
  String? promoCode,
  int? promoDiscountPercent,
  BookingStatus status = BookingStatus.pendingPayment,
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
    locationUrl: locationUrl,
    status: status,
    trainingPrice: trainingPrice ?? 1500,
    trainingPrepayPercent: trainingPrepayPercent,
    promoCode: promoCode,
    promoDiscountPercent: promoDiscountPercent,
    createdAt: now,
    updatedAt: now,
  );
}
