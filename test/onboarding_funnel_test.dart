import 'dart:io';

import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/application/onboarding_service.dart';
import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/onboarding_nudge_job.dart';
import 'package:dvor_chatbot/src/jobs/training_feedback_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/private_handlers_harness.dart';
import 'support/telegram_fixtures.dart';

void main() {
  group('Onboarding funnel', () {
    test('legacy users keep classic /start welcome without quiz', () async {
      final onboarding = FakeOnboardingRepository()
        ..seedUser(
          userId: 101,
          phase: OnboardingPhase.legacySkipped,
          onboardingStartedAt: DateTime.utc(2026, 1, 1),
        );
      final harness = PrivateHandlersHarness(
        onboardingRepository: onboarding,
        onboardingDripEnabled: true,
      );

      await harness.handleText(chatId: 101, userId: 101, text: '/start');

      final texts = harness.messagesTo(101).map((m) => m.text).join('\n');
      expect(texts, contains('Быстрый старт'));
      expect(texts, isNot(contains('Первый шаг — записаться на тренировку')));
    });

    test('newcomer /start runs quiz and completes track to map CTA', () async {
      final harness = PrivateHandlersHarness(onboardingDripEnabled: true);

      await harness.handleText(chatId: 202, userId: 202, text: '/start');
      expect(
        harness.messagesTo(202).last.text,
        contains('Первый шаг — записаться на тренировку'),
      );
      expect(harness.messagesTo(202).last.text, contains('Что сейчас важнее'));

      await harness.handleText(
        chatId: 202,
        userId: 202,
        text: MessageTemplates.buttonQuizGoalForm,
      );
      await harness.handleText(
        chatId: 202,
        userId: 202,
        text: MessageTemplates.buttonQuizExpBeginner,
      );
      await harness.handleText(
        chatId: 202,
        userId: 202,
        text: MessageTemplates.buttonTrackOneOff,
      );

      final state = await harness.onboarding.getOnboardingState(202);
      expect(state?.quizGoal, OnboardingQuizGoal.formStrength);
      expect(state?.selectedTrack, OnboardingTrack.oneOff);
      expect(state?.phase, OnboardingPhase.phase2Activation);
      expect(
        harness.messagesTo(202).last.text,
        contains('выбрать слот и записаться'),
      );
      expect(harness.messagesTo(202).last.text, contains('Можно зайти и ничего не писать'));
      expect(harness.messagesTo(202).last.text, isNot(contains('успей')));
      expect(state?.preferredBookingCategory.name, 'trainings');
    });

    test('skip from first question still shows booking CTA', () async {
      final harness = PrivateHandlersHarness(onboardingDripEnabled: true);

      await harness.handleText(chatId: 232, userId: 232, text: '/start');
      await harness.handleText(
        chatId: 232,
        userId: 232,
        text: MessageTemplates.buttonOnboardingSkipQuiz,
      );

      expect(
        harness.messagesTo(232).last.text,
        contains('выбрать слот и записаться'),
      );
      final state = await harness.onboarding.getOnboardingState(232);
      expect(state?.phase, OnboardingPhase.phase2Activation);
      expect(state?.selectedTrack, OnboardingTrack.oneOff);
    });

    test('start=book skips quiz and opens booking categories', () async {
      final harness = PrivateHandlersHarness(onboardingDripEnabled: true);

      await harness.handleText(chatId: 212, userId: 212, text: '/start book');

      final texts = harness.messagesTo(212).map((m) => m.text).join('\n');
      expect(texts, contains('Выбери категорию для записи'));
      expect(texts, isNot(contains('Что сейчас важнее')));
      final state = await harness.onboarding.getOnboardingState(212);
      expect(state?.phase, OnboardingPhase.phase2Activation);
      expect(state?.selectedTrack, OnboardingTrack.oneOff);
    });

    test('booking during quiz leaves the quiz and opens categories', () async {
      final harness = PrivateHandlersHarness(onboardingDripEnabled: true);

      await harness.handleText(chatId: 222, userId: 222, text: '/start');
      await harness.handleText(
        chatId: 222,
        userId: 222,
        text: MessageTemplates.buttonBookTraining,
      );

      expect(
        harness.messagesTo(222).last.text,
        contains('Выбери категорию для записи'),
      );
      final state = await harness.onboarding.getOnboardingState(222);
      expect(state?.phase, OnboardingPhase.phase2Activation);
      expect(state?.selectedTrack, OnboardingTrack.oneOff);
    });

    test('cold start has no starter bonus', () async {
      final dir = Directory.systemTemp.createTempSync('onboarding_cold_');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });
      final repository = SqliteOnboardingRepository(
        dbPath: '${dir.path}/onboarding.sqlite',
      );
      await repository.init();
      addTearDown(repository.close);

      final state = await repository.ensureStartedUser(
        303,
        startedAt: DateTime.utc(2026, 7, 25, 12),
        entryType: OnboardingEntryType.cold,
      );
      expect(state.phase, OnboardingPhase.phase1Quiz);
      expect(await repository.hasStarterBonusAvailable(303), isFalse);
    });

    test('group join after backfill can get starter bonus', () async {
      final dir = Directory.systemTemp.createTempSync('onboarding_group_');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });
      final repository = SqliteOnboardingRepository(
        dbPath: '${dir.path}/onboarding.sqlite',
      );
      await repository.init();
      addTearDown(repository.close);

      final joinedAt = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await repository.registerGroupWelcome(
        userId: 404,
        groupChatId: -100,
        welcomeMessageId: 1,
        joinedAt: joinedAt,
      );
      await repository.ensureStartedUser(
        404,
        startedAt: joinedAt.add(const Duration(hours: 1)),
        entryType: OnboardingEntryType.group,
      );
      expect(await repository.hasStarterBonusAvailable(404), isTrue);
    });

    test('activation is marked once', () async {
      final onboarding = FakeOnboardingRepository()
        ..seedUser(
          userId: 505,
          phase: OnboardingPhase.phase2Activation,
          onboardingStartedAt: DateTime.utc(2026, 7, 20),
        );
      final first = await onboarding.tryMarkActivation(
        505,
        activatedAt: DateTime.utc(2026, 7, 25),
      );
      final second = await onboarding.tryMarkActivation(
        505,
        activatedAt: DateTime.utc(2026, 7, 26),
      );
      expect(first, isTrue);
      expect(second, isFalse);
      final state = await onboarding.getOnboardingState(505);
      expect(state?.activationAt, isNotNull);
    });

    test('nudge job is idempotent for same key', () async {
      final now = DateTime.utc(2026, 7, 25, 12);
      final onboarding = FakeOnboardingRepository()
        ..seedUser(
          userId: 606,
          phase: OnboardingPhase.phase1Quiz,
          step: OnboardingStep.quizGoal,
          onboardingStartedAt: now.subtract(const Duration(hours: 3)),
        );
      final sender = FakeSender();
      final service = OnboardingService(
        onboardingRepository: onboarding,
        dripEnabled: true,
      );
      final job = OnboardingNudgeJob(
        onboardingRepository: onboarding,
        onboardingService: service,
        sender: sender,
        templates: const MessageTemplates(),
        nowProvider: () => now,
      );

      await job.run();
      expect(onboarding.sentNudgeKeys, isNotEmpty);
      final firstKey = onboarding.sentNudgeKeys.single;

      await job.run();
      // Same nudge_key must never be resent; a later key may still be due.
      expect(
        onboarding.sentNudgeKeys.where((key) => key == firstKey).length,
        1,
      );
      expect(await onboarding.hasNudgeBeenSent(userId: 606, nudgeKey: 'p1_30m'), isTrue);
    });

    test('day-1 nudge names the nearest slot from the schedule', () async {
      final now = DateTime.utc(2026, 7, 25, 12);
      final onboarding = FakeOnboardingRepository()
        ..seedUser(
          userId: 616,
          phase: OnboardingPhase.phase1Quiz,
          step: OnboardingStep.quizGoal,
          onboardingStartedAt: now.subtract(const Duration(hours: 25)),
        )
        ..sentNudgeKeys.addAll(<String>['616::p1_30m', '616::p1_2h', '616::p1_6h']);
      final sender = FakeSender();
      final service = OnboardingService(
        onboardingRepository: onboarding,
        dripEnabled: true,
      );
      final job = OnboardingNudgeJob(
        onboardingRepository: onboarding,
        onboardingService: service,
        sender: sender,
        templates: const MessageTemplates(),
        catalogService: ActivityCatalogService(
          scheduleRepository: FakeScheduleRepository(
            <TrainingInfo>[
              TrainingInfo(
                title: 'Утренняя силовая',
                startsAt: DateTime(2026, 7, 26, 8, 0),
                location: 'Стадион',
              ),
            ],
          ),
        ),
        nowProvider: () => now,
      );

      await job.run();

      expect(sender.messages, isNotEmpty);
      expect(sender.messages.first.text, contains('Утренняя силовая'));
      expect(sender.messages.first.text, contains('Стадион'));
      expect(sender.messages.first.text, isNot(contains('кто мы')));
    });

    test('booking a training sends sheet notes as what to bring', () async {
      final harness = PrivateHandlersHarness(
        trainings: <TrainingInfo>[
          TrainingInfo(
            title: 'Силовая',
            startsAt: DateTime(2026, 8, 26, 19, 0),
            location: 'Зал',
            price: 0,
            notes: 'Вода и полотенце',
          ),
        ],
      );

      await harness.handleText(chatId: 717, userId: 717, text: '/book');
      await harness.handleText(
        chatId: 717,
        userId: 717,
        text: MessageTemplates.buttonCategoryTrainings,
      );
      await harness.handleText(chatId: 717, userId: 717, text: '🎯 1. Силовая');

      final texts = harness.messagesTo(717).map((m) => m.text).join('\n');
      expect(texts, contains('Что взять на «Силовая»'));
      expect(texts, contains('Вода и полотенце'));
    });

    test('training feedback request and submit persist', () async {
      final dir = Directory.systemTemp.createTempSync('feedback_');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });
      final repository = SqliteOnboardingRepository(
        dbPath: '${dir.path}/feedback.sqlite',
      );
      await repository.init();
      addTearDown(repository.close);

      await repository.recordTrainingFeedbackRequest(
        bookingId: 9,
        userId: 777,
        sessionKey: 'session',
        trainingTitle: 'Силовая',
        sentAt: DateTime.utc(2026, 7, 25, 12),
      );
      await repository.submitTrainingFeedback(
        bookingId: 9,
        sessionKey: 'session',
        rating: TrainingFeedbackRating.great,
        submittedAt: DateTime.utc(2026, 7, 25, 12, 5),
        comment: 'качает',
      );

      expect(await repository.hasTrainingFeedback(9), isTrue);
      expect(await repository.hasTrainingFeedbackRequest(9), isTrue);
    });

    test('training feedback job asks once', () async {
      final now = DateTime.utc(2026, 7, 25, 15);
      final bookingRepo = FakeBookingRepository();
      final startsAt = now.subtract(const Duration(hours: 2, minutes: 5));
      bookingRepo.queue = <TrainingBooking>[
        TrainingBooking(
          id: 11,
          userId: 808,
          userUsername: 'u808',
          trainingKey: 'trainings|k',
          trainingTitle: 'Силовая',
          startsAt: startsAt,
          location: 'Зал',
          status: BookingStatus.paid,
          trainingPrice: 1000,
          createdAt: startsAt.subtract(const Duration(days: 1)),
          updatedAt: startsAt.subtract(const Duration(days: 1)),
        ),
      ];
      final onboarding = FakeOnboardingRepository()
        ..seedUser(userId: 808, phase: OnboardingPhase.legacySkipped);
      final sender = FakeSender();
      var flowStarts = 0;
      final job = TrainingFeedbackJob(
        bookingRepository: bookingRepo,
        onboardingRepository: onboarding,
        sender: sender,
        templates: const MessageTemplates(),
        enabled: true,
        nowProvider: () => now,
        onAskFeedback: ({
          required int userId,
          required int bookingId,
          required String sessionKey,
          required String trainingTitle,
        }) async {
          flowStarts += 1;
        },
      );

      await job.run();
      await job.run();

      expect(flowStarts, 1);
      expect(sender.messages.where((m) => m.chatId == 808).length, 1);
      expect(onboarding.feedbackRequestBookingIds, contains(11));
      expect(sender.messages.first.text, contains('Как прошла тренировка'));
    });

    test('hike feedback asks next day at noon after single-day end', () async {
      // Business noon on 15 June (UTC+3) = 09:00 UTC.
      final now = DateTime.utc(2026, 6, 15, 9, 5);
      final bookingRepo = FakeBookingRepository();
      final startsAt = DateTime(2026, 6, 14);
      bookingRepo.queue = <TrainingBooking>[
        TrainingBooking(
          id: 21,
          userId: 909,
          userUsername: 'hiker',
          trainingKey: 'hikes|2026-06-14T00:00:00.000Z|🥾 Поход: Ачишхо|Локация',
          trainingTitle: '🥾 Поход: Ачишхо',
          startsAt: startsAt,
          location: 'Локация',
          status: BookingStatus.paid,
          trainingPrice: 3000,
          createdAt: startsAt.subtract(const Duration(days: 3)),
          updatedAt: startsAt.subtract(const Duration(days: 3)),
        ),
      ];
      final schedule = FakeScheduleRepository(
        const <TrainingInfo>[],
        outdoorItems: <OutdoorActivityInfo>[
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Ачишхо',
            dateFrom: DateTime(2026, 6, 14),
            dateTo: DateTime(2026, 6, 14, 23, 59, 59),
            description: 'однодневный',
          ),
        ],
      );
      final onboarding = FakeOnboardingRepository()
        ..seedUser(userId: 909, phase: OnboardingPhase.legacySkipped);
      final sender = FakeSender();
      final job = TrainingFeedbackJob(
        bookingRepository: bookingRepo,
        onboardingRepository: onboarding,
        sender: sender,
        templates: const MessageTemplates(),
        enabled: true,
        catalogService: ActivityCatalogService(scheduleRepository: schedule),
        timezoneOffsetHours: 3,
        nowProvider: () => now,
        onAskFeedback: ({
          required int userId,
          required int bookingId,
          required String sessionKey,
          required String trainingTitle,
        }) async {},
      );

      await job.run();

      expect(onboarding.feedbackRequestBookingIds, contains(21));
      expect(sender.messages.single.text, contains('Как прошел поход'));
      expect(sender.messages.single.text, isNot(contains('Как прошла тренировка')));
    });

    test('multi-day hike feedback waits until day after dateTo at noon', () async {
      final tooEarly = DateTime.utc(2026, 6, 22, 9, 5); // noon business on end day
      final due = DateTime.utc(2026, 6, 23, 9, 5); // noon+ business day after end
      final bookingRepo = FakeBookingRepository();
      final startsAt = DateTime(2026, 6, 20);
      final booking = TrainingBooking(
        id: 22,
        userId: 910,
        userUsername: 'trekker',
        trainingKey: 'hikes|2026-06-20T00:00:00.000Z|🥾 Поход: Карниз|Локация',
        trainingTitle: '🥾 Поход: Карниз',
        startsAt: startsAt,
        location: 'Локация',
        status: BookingStatus.paid,
        trainingPrice: 5000,
        createdAt: startsAt.subtract(const Duration(days: 5)),
        updatedAt: startsAt.subtract(const Duration(days: 5)),
      );
      bookingRepo.queue = <TrainingBooking>[booking];
      final schedule = FakeScheduleRepository(
        const <TrainingInfo>[],
        outdoorItems: <OutdoorActivityInfo>[
          OutdoorActivityInfo(
            type: OutdoorActivityType.hike,
            title: 'Карниз',
            dateFrom: DateTime(2026, 6, 20),
            dateTo: DateTime(2026, 6, 22, 23, 59, 59),
            description: 'многодневный',
          ),
        ],
      );
      final onboarding = FakeOnboardingRepository()
        ..seedUser(userId: 910, phase: OnboardingPhase.legacySkipped);
      final sender = FakeSender();
      TrainingFeedbackJob buildJob(DateTime now) {
        return TrainingFeedbackJob(
          bookingRepository: bookingRepo,
          onboardingRepository: onboarding,
          sender: sender,
          templates: const MessageTemplates(),
          enabled: true,
          catalogService: ActivityCatalogService(scheduleRepository: schedule),
          timezoneOffsetHours: 3,
          nowProvider: () => now,
          onAskFeedback: ({
            required int userId,
            required int bookingId,
            required String sessionKey,
            required String trainingTitle,
          }) async {},
        );
      }

      await buildJob(tooEarly).run();
      expect(onboarding.feedbackRequestBookingIds, isEmpty);
      expect(sender.messages, isEmpty);

      await buildJob(due).run();
      expect(onboarding.feedbackRequestBookingIds, contains(22));
      expect(sender.messages.single.text, contains('Как прошел поход'));
    });

    test('group welcome deep link uses start=start', () {
      const templates = MessageTemplates(botUsername: 'dvor_chatbot');
      final text = templates.groupWelcome(
        username: 'neo',
        userId: 1,
        firstName: 'Neo',
      );
      expect(text, contains('https://t.me/dvor_chatbot?start=start'));
      expect(text, isNot(contains('start=book')));
    });

    test('group welcome shows profile name with username hidden as link', () {
      const templates = MessageTemplates();
      final text = templates.groupWelcome(
        username: 'Exitoso_1',
        userId: 42,
        firstName: 'Георгий',
      );
      expect(text, contains('Привет, <a href="https://t.me/Exitoso_1">Георгий</a>!'));
      expect(text, isNot(contains('@Exitoso_1')));
    });

    test('group welcome falls back to text mention without username', () {
      const templates = MessageTemplates();
      final text = templates.groupWelcome(
        username: null,
        userId: 42,
        firstName: 'Георгий',
      );
      expect(text, contains('Привет, <a href="tg://user?id=42">Георгий</a>!'));
    });

    test('city map names nearest sheet slots, not weekday coaches', () async {
      final harness = PrivateHandlersHarness(
        onboardingDripEnabled: true,
        trainings: <TrainingInfo>[
          TrainingInfo(
            title: 'Утренняя силовая',
            startsAt: DateTime(2026, 8, 26, 19),
            location: 'Зал',
          ),
          TrainingInfo(
            title: 'Бокс',
            startsAt: DateTime(2026, 8, 27, 19),
            location: 'Ринг',
          ),
          TrainingInfo(
            title: 'Общий забег',
            startsAt: DateTime(2026, 8, 29, 9),
            location: 'Парк',
          ),
        ],
      );

      await harness.handleText(chatId: 303, userId: 303, text: '/start');
      await harness.handleText(
        chatId: 303,
        userId: 303,
        text: MessageTemplates.buttonQuizGoalForm,
      );
      await harness.handleText(
        chatId: 303,
        userId: 303,
        text: MessageTemplates.buttonQuizExpBeginner,
      );
      await harness.handleText(
        chatId: 303,
        userId: 303,
        text: MessageTemplates.buttonTrackOneOff,
      );

      final text = harness.messagesTo(303).last.text;
      expect(text, contains('Ближайшие слоты в городе'));
      expect(text, contains('Силовая: Утренняя силовая'));
      expect(text, contains('Бокс: Бокс'));
      expect(text, contains('Забег: Общий забег'));
      expect(text, isNot(contains('Даша')));
      expect(text, isNot(contains('в среду')));
    });

    test('came-alone circle is sent on club map when uploaded', () async {
      final onboarding = FakeOnboardingRepository();
      await onboarding.upsertOnboardingMedia(
        slot: OnboardingMediaSlot.cameAlone,
        fileId: 'came_alone_note',
        kind: OnboardingMediaKind.videoNote,
        updatedAt: DateTime.utc(2026, 8, 24),
      );
      final harness = PrivateHandlersHarness(
        onboardingRepository: onboarding,
        onboardingDripEnabled: true,
      );

      await harness.handleText(chatId: 404, userId: 404, text: '/start');
      await harness.handleText(
        chatId: 404,
        userId: 404,
        text: MessageTemplates.buttonQuizGoalForm,
      );
      await harness.handleText(
        chatId: 404,
        userId: 404,
        text: MessageTemplates.buttonQuizExpBeginner,
      );
      await harness.handleText(
        chatId: 404,
        userId: 404,
        text: MessageTemplates.buttonTrackOneOff,
      );

      expect(harness.sender.media, hasLength(1));
      expect(harness.sender.media.single.fileId, 'came_alone_note');
      expect(harness.sender.media.single.kind, SentMediaKind.videoNote);
    });

    test('venue circle is sent after first booking when uploaded', () async {
      final onboarding = FakeOnboardingRepository()
        ..seedUser(userId: 505, phase: OnboardingPhase.phase2Activation);
      await onboarding.upsertOnboardingMedia(
        slot: OnboardingMediaSlot.venue,
        fileId: 'venue_note',
        kind: OnboardingMediaKind.videoNote,
        updatedAt: DateTime.utc(2026, 8, 24),
      );
      final harness = PrivateHandlersHarness(
        onboardingRepository: onboarding,
        onboardingDripEnabled: true,
        trainings: <TrainingInfo>[
          TrainingInfo(
            title: 'Силовая',
            startsAt: DateTime(2026, 8, 26, 19),
            location: 'Зал',
            price: 0,
          ),
        ],
      );

      await harness.handleText(chatId: 505, userId: 505, text: '/book');
      await harness.handleText(
        chatId: 505,
        userId: 505,
        text: MessageTemplates.buttonCategoryTrainings,
      );
      await harness.handleText(chatId: 505, userId: 505, text: '🎯 1. Силовая');

      expect(
        harness.sender.media.where((item) => item.fileId == 'venue_note'),
        isNotEmpty,
      );
      expect(
        harness.messagesTo(505).map((item) => item.text).join('\n'),
        contains('Первая тренировка в DVOR'),
      );
    });

    test('admin can replace onboarding circle through tools', () async {
      final harness = PrivateHandlersHarness(adminUserIds: const <int>{1});

      await harness.handleText(
        chatId: 1,
        userId: 1,
        text: MessageTemplates.buttonAdminTools,
      );
      await harness.handleText(
        chatId: 1,
        userId: 1,
        text: MessageTemplates.buttonOnboardingMedia,
      );
      await harness.handleText(
        chatId: 1,
        userId: 1,
        text: MessageTemplates.buttonOnboardingMediaVenue,
      );
      await harness.handleUpdate(
        privateVideoNoteMessageUpdate(
          chatId: 1,
          userId: 1,
          messageId: 9,
          fileId: 'admin_venue_note',
        ),
      );

      final stored = await harness.onboarding.getOnboardingMedia(OnboardingMediaSlot.venue);
      expect(stored?.fileId, 'admin_venue_note');
      expect(stored?.kind, OnboardingMediaKind.videoNote);
      expect(
        harness.messagesTo(1).last.text,
        contains('Сохранил'),
      );
    });
  });
}
