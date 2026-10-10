import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/boxing_title.dart';
import 'package:dvor_chatbot/src/domain/featured_trainings.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/frank_run_broadcast_job.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  test('boxing camp leaves trainings and opens in camps', () {
    final camp = TrainingInfo(
      title: 'Боксерский кэмп',
      startsAt: DateTime(2026, 11, 2, 10),
      location: 'Зал',
      price: 4000,
    );
    final boxing = TrainingInfo(
      title: 'BOXING DVOR',
      startsAt: DateTime(2026, 11, 1, 19),
      location: 'Зал',
      price: 500,
    );
    final catalog = ActivityCatalogService(
      scheduleRepository: FakeScheduleRepository(<TrainingInfo>[boxing, camp]),
    );

    expect(isBoxingTrainingTitle(camp.title), isFalse);
    expect(isBoxingTrainingTitle(boxing.title), isTrue);
    expect(catalog.bookableItems(ActivityCategory.trainings).map((item) => item.title), <String>[
      'BOXING DVOR',
    ]);
    final camps = catalog.bookableItems(ActivityCategory.trails);
    expect(camps, hasLength(1));
    expect(camps.single.title, '🎯 Кэмп: Боксерский кэмп');
    expect(camps.single.category, ActivityCategory.trails);
    expect(camps.single.startsAt, DateTime(2026, 11, 2, 10));
    expect(
      catalog.categoryForKeyAndTitle(
        trainingKey: 'trainings|old',
        trainingTitle: 'Боксерский кэмп',
      ),
      ActivityCategory.trails,
    );
  });

  test('FRANK run is a training at 08:30 and the DM names that time', () {
    final event = FeaturedTrainings.events.single;
    expect(event.startsAt, DateTime(2026, 10, 17, 8, 30));
    expect(event.location, 'Мост поцелуев');
    expect(event.price, 0);
    final text = const MessageTemplates().frankRunBroadcast();
    expect(text, contains('8:30'));
    expect(text, contains('Моста поцелуев'));
    expect(text, contains('Frank by Basta'));
    expect(text, contains('бесплатн'));
    expect(text, isNot(contains('500')));
    expect(text, isNot(contains('8:00')));
  });

  test('client menu puts the FRANK run on the top button until it starts', () {
    final before = const MessageTemplates().privateMenuKeyboard(
      isAdmin: false,
      now: DateTime(2026, 10, 10, 12),
    );
    final after = const MessageTemplates().privateMenuKeyboard(
      isAdmin: false,
      now: DateTime(2026, 10, 17, 8, 30),
    );
    final admin = const MessageTemplates().privateMenuKeyboard(
      isAdmin: true,
      now: DateTime(2026, 10, 10, 12),
    );

    expect(keyboardTexts(before).first, MessageCopy.buttonFrankRun);
    expect(keyboardTexts(after), isNot(contains(MessageCopy.buttonFrankRun)));
    expect(keyboardTexts(admin), isNot(contains(MessageCopy.buttonFrankRun)));
  });

  test('FRANK menu button books the free run', () async {
    final bookings = FakeBookingRepository();
    final sender = FakeSender();
    final handlers = PrivateHandlers(
      sender: sender,
      scheduleRepository: FakeScheduleRepository(const <TrainingInfo>[]),
      bookingRepository: bookings,
      templates: const MessageTemplates(),
      adminUserIds: const <int>{},
      nowProvider: () => DateTime(2026, 10, 10, 12),
    );

    final handled = await handlers.handle(<String, dynamic>{
      'chat': <String, dynamic>{'id': 11, 'type': 'private'},
      'from': <String, dynamic>{'id': 11},
      'text': MessageCopy.buttonFrankRun,
    });

    expect(handled, isTrue);
    expect(bookings.lastCreatedTraining?.title, 'DVOR x FRANK — RUN & RAVE');
    expect(bookings.lastCreatedTraining?.price, 0);
    expect(bookings.lastUpdatedStatus, BookingStatus.paid);
    expect(sender.messages.last.text, contains('бесплатн'));
  });

  test('FRANK broadcast goes to started users once', () async {
    final onboarding = FakeOnboardingRepository();
    await onboarding.ensureStartedUser(7, startedAt: DateTime.utc(2026, 10, 1));
    final sender = FakeSender();
    final job = FrankRunBroadcastJob(
      sender: sender,
      onboardingRepository: onboarding,
      templates: const MessageTemplates(),
      nowProvider: () => DateTime(2026, 10, 10, 12),
    );

    await job.run();
    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.chatId, 7);
    expect(sender.messages.single.text, contains('8:30'));

    await job.run();
    expect(sender.messages, hasLength(1));
  });

  test('FRANK broadcast does not send after the start', () async {
    final onboarding = FakeOnboardingRepository();
    await onboarding.ensureStartedUser(7, startedAt: DateTime.utc(2026, 10, 1));
    final sender = FakeSender();
    final job = FrankRunBroadcastJob(
      sender: sender,
      onboardingRepository: onboarding,
      templates: const MessageTemplates(),
      nowProvider: () => DateTime(2026, 10, 17, 8, 30),
    );

    await job.run();
    expect(sender.messages, isEmpty);
  });
}
