import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/schedule_broadcast_job.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('sends schedule broadcast on Sunday 18:30', () async {
    final now = DateTime.utc(2030, 6, 23, 15, 30); // Sunday 18:30 MSK
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Функциональная тренировка',
        startsAt: DateTime(2030, 6, 24, 19, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
        price: 500,
        coach: 'Алексей',
      ),
    ]);
    final sender = FakeSender();
    final job = ScheduleBroadcastJob(
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
    expect(sender.messages.single.text, contains('Новая неделя DVOR уже в расписании'));
    expect(sender.messages.single.text, contains('Функциональная тренировка'));
    expect(sender.messages.single.text, contains('https://t.me/dvor_chatbot?start=start'));
  });

  test('sends schedule broadcast on Tuesday 10:00', () async {
    final now = DateTime.utc(2030, 6, 25, 7, 0); // Tuesday 10:00 MSK
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Силовая + растяжка',
        startsAt: DateTime(2030, 6, 25, 19, 30),
        location: 'Стадион Кубань',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = ScheduleBroadcastJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.text, contains('Середина недели'));
  });

  test('sends schedule broadcast on Thursday 10:00', () async {
    final now = DateTime.utc(2030, 6, 27, 7, 0); // Thursday 10:00 MSK
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'BOXING DVOR',
        startsAt: DateTime(2030, 6, 27, 19, 30),
        location: 'Варг',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = ScheduleBroadcastJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.text, contains('Не упусти тренировки до выходных'));
  });

  test('does not send outside configured schedule slots', () async {
    final now = DateTime.utc(2030, 6, 23, 15, 29); // Sunday 18:29 MSK
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Функциональная тренировка',
        startsAt: DateTime(2030, 6, 24, 19, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = ScheduleBroadcastJob(
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

  test('does not send duplicate schedule broadcasts in one slot', () async {
    var now = DateTime.utc(2030, 6, 23, 15, 30);
    final scheduleRepository = FakeScheduleRepository(<TrainingInfo>[
      TrainingInfo(
        title: 'Функциональная тренировка',
        startsAt: DateTime(2030, 6, 24, 19, 0),
        location: 'Зал DVOR',
        category: ActivityCategory.trainings,
      ),
    ]);
    final sender = FakeSender();
    final job = ScheduleBroadcastJob(
      scheduleRepository: scheduleRepository,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();
    await job.run();
    now = DateTime.utc(2030, 6, 23, 15, 31);
    await job.run();

    expect(sender.messages, hasLength(1));
  });

  test('skips schedule broadcast when there are no upcoming trainings', () async {
    final now = DateTime.utc(2030, 6, 23, 15, 30);
    final sender = FakeSender();
    final job = ScheduleBroadcastJob(
      scheduleRepository: FakeScheduleRepository(const <TrainingInfo>[]),
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: -1001234567890,
      timezoneOffsetHours: 3,
      nowProvider: () => now,
    );

    await job.run();

    expect(sender.messages, isEmpty);
  });
}
