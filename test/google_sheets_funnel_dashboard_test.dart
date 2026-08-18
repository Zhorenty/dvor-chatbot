import 'package:dvor_chatbot/src/data/google_sheets_funnel_dashboard.dart';
import 'package:dvor_chatbot/src/domain/funnel_analytics.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleSheetsFunnelDashboard', () {
    test('builds KPI cards, funnel steps and charts', () {
      final dashboard = GoogleSheetsFunnelDashboard.build(_analytics());

      expect(dashboard.sheetTitle, 'FUNNEL');
      expect(dashboard.obsoleteSheetTitles, contains('bot_bookings'));
      expect(dashboard.rows.first.first, 'DVOR · Воронка');
      expect(
        dashboard.rows.any((row) => row.contains('1. Начали квиз')),
        isTrue,
      );
      expect(
        dashboard.rows.any((row) => row.contains('5. Первая тренировка')),
        isTrue,
      );
      expect(dashboard.charts, isNotEmpty);
      expect(dashboard.bandedTables, isNotEmpty);
      expect(dashboard.styles.any((style) => style.merge), isTrue);
      expect(dashboard.styles.any((style) => style.borders), isTrue);
      expect(
        dashboard.styles.any((style) => style.numberFormatType == 'PERCENT'),
        isTrue,
      );
      expect(
        dashboard.charts.map((chart) => chart.title),
        containsAll(<String>['Путь новичка', 'Откуда пришли', 'Оценки']),
      );
      final funnelHeader = dashboard.rows.firstWhere(
        (row) => row.isNotEmpty && row.first == 'Шаг',
      );
      expect(
          funnelHeader.take(4).toList(), <Object?>['Шаг', 'Люди', 'От старта', 'От предыдущего']);
      expect(
        dashboard.rows.any(
          (row) =>
              row.isNotEmpty && row.first.toString().contains('Пропуск квиза сразу ведёт на шаг 4'),
        ),
        isTrue,
      );
    });
  });
}

FunnelAnalytics _analytics() {
  return FunnelAnalytics(
    generatedAt: DateTime.utc(2026, 8, 18, 9),
    startedUsersTotal: 40,
    legacyUsers: 10,
    funnelUsers: 30,
    completedUsers: 4,
    phaseCounts: const <String, int>{
      'phase1_quiz': 8,
      'phase2_activation': 12,
      'phase3_integration': 6,
    },
    entryTypeCounts: const <String, int>{
      'group': 20,
      'cold': 8,
      'referral': 2,
    },
    quizGoalCounts: const <String, int>{
      'form_strength': 10,
      'endurance_run': 7,
    },
    quizExperienceCounts: const <String, int>{
      'beginner': 9,
      'regular': 5,
    },
    trackCounts: const <String, int>{
      'one_off': 18,
      'outdoor': 6,
    },
    startedLast7Days: 5,
    startedLast30Days: 18,
    activationsTotal: 12,
    activationsLast7Days: 3,
    activationsLast30Days: 9,
    activationRate21Days: 0.4,
    avgTimeToValueDays: 2.5,
    snoozeActiveNow: 1,
    nudgeKeyCounts: const <String, int>{'p1_30m': 4, 'p2_d2': 2},
    feedbackRequestsSent: 10,
    feedbackResponses: 6,
    feedbackSkipped: 2,
    feedbackRatingCounts: const <String, int>{'great': 4, 'ok': 2},
    feedbackCommentsCount: 1,
    recentFeedbackComments: <RecentFeedbackComment>[
      RecentFeedbackComment(
        trainingTitle: 'Силовая',
        rating: 'great',
        submittedAt: DateTime.utc(2026, 8, 17, 18),
        comment: 'Держали темп.',
      ),
    ],
    topFeedbackSessions: const <FeedbackSessionSummary>[
      FeedbackSessionSummary(
        trainingTitle: 'Силовая',
        sessionKey: 'k1',
        responses: 4,
        greatCount: 3,
        okCount: 1,
        weakCount: 0,
      ),
    ],
  );
}
