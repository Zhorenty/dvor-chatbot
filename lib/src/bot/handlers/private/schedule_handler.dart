import 'package:dvor_chatbot/src/domain/activity_category.dart';

typedef ParticipantsCopy = ({String title, String emptyText});

final class ScheduleHandler {
  const ScheduleHandler();

  ParticipantsCopy participantsCopy(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => (
          title: 'Список записавшихся по тренировкам 👥',
          emptyText: 'Ближайших тренировок пока нет, показывать список не для чего.',
        ),
      ActivityCategory.hikes => (
          title: 'Список записавшихся по походам 👥',
          emptyText: 'Ближайших походов пока нет, показывать список не для чего.',
        ),
      ActivityCategory.trails => (
          title: 'Список записавшихся по трейлам 👥',
          emptyText: 'Ближайших трейлов пока нет, показывать список не для чего.',
        ),
    };
  }
}
