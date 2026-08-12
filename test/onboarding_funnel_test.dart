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
      expect(texts, isNot(contains('Сейчас не нужно разбираться во всём')));
    });

    test('newcomer /start runs quiz and completes track to map CTA', () async {
      final harness = PrivateHandlersHarness(onboardingDripEnabled: true);

      await harness.handleText(chatId: 202, userId: 202, text: '/start');
      expect(
        harness.messagesTo(202).last.text,
        contains('Сейчас не нужно разбираться во всём'),
      );

      await harness.handleText(
        chatId: 202,
        userId: 202,
        text: MessageTemplates.buttonOnboardingContinue,
      );
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
        contains('как устроен DVOR'),
      );
      expect(state?.preferredBookingCategory.name, 'trainings');
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
  });
}
