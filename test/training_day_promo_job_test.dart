import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/training_day_promo_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('sends same-day 12:00 promo for trainings at or after 16:00', () async {
    final now = DateTime.utc(2030, 6, 22, 9, 0);
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Функциональная тренировка',
        startsAt: DateTime(2030, 6, 22, 19, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = TrainingDayPromoJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(botUsername: 'dvor_chatbot'),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.chatId, -1001234567890);
    expect(sender.messages.single.parseMode, 'HTML');
    expect(sender.messages.single.text, contains('Тренировка уже сегодня'));
  });

  test('sends 20:00 day-before promo for trainings before 16:00', () async {
    final now = DateTime.utc(2030, 6, 21, 17, 0);
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Утренняя тренировка',
        startsAt: DateTime(2030, 6, 22, 10, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = TrainingDayPromoJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.text, contains('Тренировка уже завтра'));
  });

  test('does not send outside configured promo time', () async {
    final now = DateTime.utc(2030, 6, 22, 8, 59);
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Функциональная тренировка',
        startsAt: DateTime(2030, 6, 22, 19, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = TrainingDayPromoJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, isEmpty);
  });

  test('does not send duplicate promos for same training in one slot', () async {
    var now = DateTime.utc(2030, 6, 22, 9, 0);
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Функциональная тренировка',
        startsAt: DateTime(2030, 6, 22, 19, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = TrainingDayPromoJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();
    await job.run();
    now = DateTime.utc(2030, 6, 22, 9, 1);
    await job.run();

    expect(sender.messages, hasLength(1));
  });
}
