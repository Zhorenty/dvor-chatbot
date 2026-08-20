import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/funnel_analytics.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/domain/training_feedback.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';
import 'support/private_handlers_harness.dart';

void main() {
  group('Funnel analytics', () {
    test('sqlite aggregates onboarding and anonymous feedback', () async {
      final dir = Directory.systemTemp.createTempSync('funnel_analytics_');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });
      final repository = SqliteOnboardingRepository(dbPath: '${dir.path}/db.sqlite');
      await repository.init();
      addTearDown(repository.close);

      final now = DateTime.utc(2026, 7, 25, 15);
      await repository.ensureStartedUser(
        1,
        startedAt: now.subtract(const Duration(days: 3)),
        entryType: OnboardingEntryType.cold,
      );
      await repository.updateOnboardingProgress(
        userId: 1,
        quizGoal: OnboardingQuizGoal.enduranceRun,
        quizExperience: OnboardingQuizExperience.beginner,
        selectedTrack: OnboardingTrack.oneOff,
        phase: OnboardingPhase.phase2Activation,
      );
      await repository.tryMarkActivation(
        1,
        activatedAt: now.subtract(const Duration(days: 1)),
      );

      await repository.registerGroupWelcome(
        userId: 2,
        groupChatId: -100,
        welcomeMessageId: 9,
        joinedAt: now.subtract(const Duration(hours: 2)),
      );
      await repository.ensureStartedUser(
        2,
        startedAt: now.subtract(const Duration(hours: 1)),
        entryType: OnboardingEntryType.group,
      );
      await repository.updateOnboardingProgress(
        userId: 2,
        quizGoal: OnboardingQuizGoal.formStrength,
        selectedTrack: OnboardingTrack.outdoor,
        phase: OnboardingPhase.phase1Map,
      );

      await repository.recordNudgeSent(
        userId: 2,
        nudgeKey: 'p1_30m',
        sentAt: now,
        phase: OnboardingPhase.phase1Quiz,
      );

      await repository.recordTrainingFeedbackRequest(
        bookingId: 10,
        userId: 1,
        sessionKey: 'trainings|1',
        trainingTitle: 'Утренняя тренировка',
        sentAt: now,
      );
      await repository.submitTrainingFeedback(
        bookingId: 10,
        sessionKey: 'trainings|1',
        rating: TrainingFeedbackRating.great,
        submittedAt: now,
        comment: 'очень мягко и четко',
      );
      await repository.recordTrainingFeedbackRequest(
        bookingId: 11,
        userId: 2,
        sessionKey: 'trainings|1',
        trainingTitle: 'Утренняя тренировка',
        sentAt: now,
      );
      await repository.submitTrainingFeedback(
        bookingId: 11,
        sessionKey: 'trainings|1',
        rating: TrainingFeedbackRating.ok,
        submittedAt: now,
      );

      final analytics = await repository.getFunnelAnalytics(now: now);
      expect(analytics.funnelUsers, greaterThanOrEqualTo(2));
      expect(analytics.activationsTotal, 1);
      expect(analytics.quizGoalAnsweredCount, 2);
      expect(analytics.quizExperienceAnsweredCount, 1);
      expect(analytics.trackChosenCount, 2);
      expect(analytics.quizGoalCounts['endurance_run'], 1);
      expect(analytics.trackCounts['outdoor'], 1);
      expect(analytics.mapToActivationRate, 0.5);
      expect(analytics.nudgeKeyCounts['p1_30m'], 1);
      expect(analytics.feedbackRequestsSent, 2);
      expect(analytics.feedbackResponses, 2);
      expect(analytics.feedbackCommentsCount, 1);
      expect(analytics.recentFeedbackComments, isNotEmpty);
      expect(analytics.topFeedbackSessions.first.trainingTitle, 'Утренняя тренировка');
      expect(analytics.topFeedbackSessions.first.greatCount, 1);
      expect(analytics.activationRate21Days, isNotNull);
      expect(analytics.avgTimeToValueDays, isNotNull);
    });

    test('onboarding funnel report explains steps in plain language', () {
      const templates = MessageTemplates();
      final text = templates.funnelAnalyticsOnboarding(
        FunnelAnalytics(
          generatedAt: DateTime.utc(2026, 8, 18, 8, 25),
          startedUsersTotal: 120,
          legacyUsers: 75,
          funnelUsers: 45,
          completedUsers: 0,
          phaseCounts: const <String, int>{
            'phase1_quiz': 8,
            'phase2_activation': 12,
            'phase3_integration': 10,
            'legacy_skipped': 75,
          },
          entryTypeCounts: const <String, int>{
            'group': 30,
            'cold': 10,
            'referral': 5,
            'legacy': 75,
          },
          quizGoalCounts: const <String, int>{
            'form_strength': 16,
            'endurance_run': 10,
            'outdoor_hikes': 4,
            'unknown': 2,
          },
          quizExperienceCounts: const <String, int>{
            'beginner': 18,
            'returning': 8,
            'regular': 4,
          },
          trackCounts: const <String, int>{
            'one_off': 22,
            'outdoor': 8,
          },
          startedLast7Days: 8,
          startedLast30Days: 22,
          activationsTotal: 12,
          activationsLast7Days: 3,
          activationsLast30Days: 8,
          activationRate21Days: 0.27,
          avgTimeToValueDays: 4.2,
          snoozeActiveNow: 2,
          nudgeKeyCounts: const <String, int>{
            'p1_30m': 10,
            'p2_d2': 4,
          },
          feedbackRequestsSent: 0,
          feedbackResponses: 0,
          feedbackSkipped: 0,
          feedbackRatingCounts: const <String, int>{},
          feedbackCommentsCount: 0,
          recentFeedbackComments: const <RecentFeedbackComment>[],
          topFeedbackSessions: const <FeedbackSessionSummary>[],
        ),
      );

      expect(text, contains('Путь новичка'));
      expect(text, contains('Начали квиз'));
      expect(text, contains('Первая тренировка (активация)'));
      expect(text, contains('из группы: <b>30</b> (25%)'));
      expect(text, contains('через 30 минут: дожать квиз'));
      expect(text, contains('ждут первую запись'));
      expect(text, isNot(contains('TTV')));
      expect(text, isNot(contains('idempotent')));
      expect(text, isNot(contains('Activation')));
    });

    test('admin tools button opens analytics menu with segments', () async {
      final onboarding = FakeOnboardingRepository()
        ..seedUser(
          userId: 9001,
          phase: OnboardingPhase.phase2Activation,
          onboardingStartedAt: DateTime.utc(2026, 7, 20),
        );
      await onboarding.tryMarkActivation(
        9001,
        activatedAt: DateTime.utc(2026, 7, 22),
      );
      final harness = PrivateHandlersHarness(
        adminUserIds: const <int>{42},
        onboardingRepository: onboarding,
      );

      await harness.handleText(
        chatId: 42,
        userId: 42,
        text: MessageTemplates.buttonAdminTools,
      );
      final toolsButtons = keyboardTexts(harness.messagesTo(42).last.replyMarkup);
      expect(toolsButtons, isNot(contains(MessageTemplates.buttonAdminAnalytics)));
      expect(toolsButtons, isNot(contains(MessageTemplates.buttonFunnelAnalytics)));

      await harness.handleText(
        chatId: 42,
        userId: 42,
        text: MessageTemplates.buttonAdminAnalytics,
      );
      final analyticsButtons = keyboardTexts(harness.messagesTo(42).last.replyMarkup);
      expect(analyticsButtons, contains(MessageTemplates.buttonFunnelAnalytics));
      expect(analyticsButtons, contains(MessageTemplates.buttonFeedbackAnalytics));
      expect(analyticsButtons, contains(MessageTemplates.buttonEconomicSummary));
      expect(analyticsButtons, contains(MessageTemplates.buttonBookingAnalytics));
      expect(analyticsButtons, contains(MessageTemplates.buttonLoyaltyAnalytics));
      expect(analyticsButtons, contains(MessageTemplates.buttonSubscriptionAnalytics));

      await harness.handleText(
        chatId: 42,
        userId: 42,
        text: MessageTemplates.buttonFunnelAnalytics,
      );
      final funnelText = harness.messagesTo(42).last.text;
      expect(funnelText, contains('Воронка онбординга'));
      expect(funnelText, contains('Путь новичка'));
      expect(funnelText, contains('Первая тренировка'));
      expect(funnelText, isNot(contains('Activation')));
      expect(funnelText, isNot(contains('Анонимный фидбэк')));

      await harness.handleText(
        chatId: 42,
        userId: 42,
        text: MessageTemplates.buttonFeedbackAnalytics,
      );
      final feedbackText = harness.messagesTo(42).last.text;
      expect(feedbackText, contains('Анонимный фидбэк'));
    });

    test('training feedback notifies admin chat anonymously once completed', () async {
      final harness = PrivateHandlersHarness(
        adminUserIds: const <int>{42},
        adminChatId: -100500,
      );
      harness.handlers.beginTrainingFeedbackFlow(
        userId: 77,
        bookingId: 501,
        sessionKey: 'session',
        trainingTitle: 'Силовая вечер',
      );

      await harness.handleText(
        chatId: 77,
        userId: 77,
        text: MessageTemplates.buttonFeedbackGreat,
      );
      expect(
        harness.messagesTo(-100500),
        isEmpty,
        reason: 'admin is notified only after the flow finishes',
      );

      await harness.handleText(
        chatId: 77,
        userId: 77,
        text: 'было мощно',
      );
      final adminMessages = harness.messagesTo(-100500);
      expect(adminMessages, hasLength(1));
      expect(adminMessages.single.text, contains('анонимный отзыв'));
      expect(adminMessages.single.text, contains('Силовая вечер'));
      expect(adminMessages.single.text, contains('отлично'));
      expect(adminMessages.single.text, contains('было мощно'));
      expect(adminMessages.single.text, isNot(contains('77')));
    });

    test('skipped training feedback also notifies admin', () async {
      final harness = PrivateHandlersHarness(
        adminChatId: -100501,
      );
      harness.handlers.beginTrainingFeedbackFlow(
        userId: 88,
        bookingId: 502,
        sessionKey: 'session-2',
        trainingTitle: 'Силовая',
      );

      await harness.handleText(
        chatId: 88,
        userId: 88,
        text: MessageTemplates.buttonFeedbackSkip,
      );
      final adminMessages = harness.messagesTo(-100501);
      expect(adminMessages, hasLength(1));
      expect(adminMessages.single.text, contains('Силовая'));
      expect(adminMessages.single.text, contains('пропуск'));
    });
  });
}
