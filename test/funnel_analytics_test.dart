import 'dart:io';

import 'package:dvor_chatbot/src/data/sqlite_onboarding_repository.dart';
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
        quizGoal: OnboardingQuizGoal.yogaRecovery,
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
        sessionKey: 'yoga|1',
        trainingTitle: 'Йога утро',
        sentAt: now,
      );
      await repository.submitTrainingFeedback(
        bookingId: 10,
        sessionKey: 'yoga|1',
        rating: TrainingFeedbackRating.great,
        submittedAt: now,
        comment: 'очень мягко и четко',
      );
      await repository.recordTrainingFeedbackRequest(
        bookingId: 11,
        userId: 2,
        sessionKey: 'yoga|1',
        trainingTitle: 'Йога утро',
        sentAt: now,
      );
      await repository.submitTrainingFeedback(
        bookingId: 11,
        sessionKey: 'yoga|1',
        rating: TrainingFeedbackRating.ok,
        submittedAt: now,
      );

      final analytics = await repository.getFunnelAnalytics(now: now);
      expect(analytics.funnelUsers, greaterThanOrEqualTo(2));
      expect(analytics.activationsTotal, 1);
      expect(analytics.quizGoalCounts['yoga_recovery'], 1);
      expect(analytics.trackCounts['outdoor'], 1);
      expect(analytics.nudgeKeyCounts['p1_30m'], 1);
      expect(analytics.feedbackRequestsSent, 2);
      expect(analytics.feedbackResponses, 2);
      expect(analytics.feedbackCommentsCount, 1);
      expect(analytics.recentFeedbackComments, isNotEmpty);
      expect(analytics.topFeedbackSessions.first.trainingTitle, 'Йога утро');
      expect(analytics.topFeedbackSessions.first.greatCount, 1);
      expect(analytics.activationRate21Days, isNotNull);
      expect(analytics.avgTimeToValueDays, isNotNull);
    });

    test('admin tools button sends analytics report', () async {
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
      expect(toolsButtons, contains(MessageTemplates.buttonFunnelAnalytics));

      await harness.handleText(
        chatId: 42,
        userId: 42,
        text: MessageTemplates.buttonFunnelAnalytics,
      );
      final texts = harness.messagesTo(42).map((m) => m.text).join('\n');
      expect(texts, contains('Аналитика воронки'));
      expect(texts, contains('Отзывы после тренировок'));
      expect(texts, contains('Activation'));
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
        trainingTitle: 'Йога',
      );

      await harness.handleText(
        chatId: 88,
        userId: 88,
        text: MessageTemplates.buttonFeedbackSkip,
      );
      final adminMessages = harness.messagesTo(-100501);
      expect(adminMessages, hasLength(1));
      expect(adminMessages.single.text, contains('Йога'));
      expect(adminMessages.single.text, contains('пропуск'));
    });
  });
}
