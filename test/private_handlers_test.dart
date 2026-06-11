import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

typedef _FakeScheduleRepository = FakeScheduleRepository;
typedef _FakeBookingRepository = FakeBookingRepository;
typedef _FakeOnboardingRepository = FakeOnboardingRepository;
typedef _FakeSender = FakeSender;
typedef _FakeTrainerDirectoryRepository = FakeTrainerDirectoryRepository;

TrainingBooking _booking({
  int id = 10,
  int userId = 1,
  String? userUsername,
  int? paymentProofChatId,
  int? paymentProofMessageId,
  String? trainingKey,
  String title = 'Training',
  DateTime? startsAt,
  String location = 'Hall',
  BookingStatus status = BookingStatus.pendingPayment,
  String? paymentNote,
}) {
  return fakeBooking(
    id: id,
    userId: userId,
    userUsername: userUsername,
    paymentProofChatId: paymentProofChatId,
    paymentProofMessageId: paymentProofMessageId,
    trainingKey: trainingKey,
    title: title,
    startsAt: startsAt,
    location: location,
    status: status,
    paymentNote: paymentNote,
  );
}

List<String> _keyboardTexts(Map<String, Object?>? replyMarkup) => keyboardTexts(replyMarkup);

void main() {
  group('PrivateHandlers', () {
    test('handles /start command in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 11, 'type': 'private'},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 11);
      expect(sender.messages.single.text, contains('Добро пожаловать в DVOR'));
      expect(sender.messages.single.text, contains('https://t.me/+n4ksCb3kFRQ5MTcy'));
      expect(sender.messages.single.text, contains('публикуем афиши всех мероприятий'));
      expect(sender.messages.single.replyMarkup, isNotNull);
      expect(sender.pinnedMessages, hasLength(1));
      expect(sender.pinnedMessages.single.chatId, 11);
      expect(sender.pinnedMessages.single.messageId, 1);
    });

    test('deletes group welcome message when user sends /start', () async {
      final sender = _FakeSender();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(
          userId: 111,
          pendingWelcome: const PendingWelcomeMessage(
            userId: 111,
            groupChatId: -100900,
            welcomeMessageId: 45,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 111, 'type': 'private'},
        'from': <String, dynamic>{'id': 111},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.deletedMessages, hasLength(1));
      expect(sender.deletedMessages.single.chatId, -100900);
      expect(sender.deletedMessages.single.messageId, 45);
    });

    test('shows starter bonus onboarding offer on /start when available', () async {
      final sender = _FakeSender();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(userId: 112, bonusAvailable: true);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 112, 'type': 'private'},
        'from': <String, dynamic>{'id': 112},
        'text': '/start',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Добро пожаловать в DVOR'));
      expect(sender.messages.first.text, contains('https://t.me/+n4ksCb3kFRQ5MTcy'));
      expect(sender.messages.last.text, contains('бесплатная тренировка'));
      expect(sender.messages.last.text, contains(MessageTemplates.buttonBookTraining));
      expect(sender.messages.last.text, contains(MessageTemplates.buttonUseStarterBonus));
      expect(sender.pinnedMessages, hasLength(1));
      expect(sender.pinnedMessages.single.chatId, 112);
      expect(sender.pinnedMessages.single.messageId, 1);
    });

    test('shows only admin buttons in private menu for admin users', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9100},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9100, 'type': 'private'},
        'from': <String, dynamic>{'id': 9100},
        'text': '/start',
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonRefreshSchedule));
      expect(buttons, contains(MessageTemplates.buttonPaymentsQueue));
      expect(buttons, contains(MessageTemplates.buttonEconomicSummary));
      expect(buttons, contains(MessageTemplates.buttonParticipantsList));
      expect(buttons, contains(MessageTemplates.buttonNoblesList));
      expect(buttons, contains(MessageTemplates.buttonManageBookings));
      expect(buttons, isNot(contains(MessageTemplates.buttonTrainings)));
      expect(buttons, isNot(contains(MessageTemplates.buttonBookTraining)));
      expect(buttons, isNot(contains(MessageTemplates.buttonCoachingStaff)));
      expect(buttons, isNot(contains(MessageTemplates.buttonMyBookings)));
      expect(buttons, isNot(contains(MessageTemplates.buttonHelp)));
    });

    test('shows coaching staff button for regular users in private menu', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9101, 'type': 'private'},
        'from': <String, dynamic>{'id': 9101},
        'text': '/start',
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonCoachingStaff));
      expect(buttons, contains(MessageTemplates.buttonTrainings));
      expect(buttons, contains(MessageTemplates.buttonMyBookings));
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
    });

    test('shows participants button in private menu for yoga trainer role', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1363267745, 'type': 'private'},
        'from': <String, dynamic>{'id': 1363267745},
        'text': '/start',
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonParticipantsList));
      expect(buttons, contains(MessageTemplates.buttonTrainings));
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, isNot(contains(MessageTemplates.buttonRefreshSchedule)));
      expect(buttons, isNot(contains(MessageTemplates.buttonPaymentsQueue)));
      expect(buttons, isNot(contains(MessageTemplates.buttonEconomicSummary)));
      expect(buttons, isNot(contains(MessageTemplates.buttonNoblesList)));
      expect(buttons, isNot(contains(MessageTemplates.buttonManageBookings)));
    });

    test('handles coaching staff button and prints trainers list', () async {
      final sender = _FakeSender();
      final trainerDirectoryRepository = _FakeTrainerDirectoryRepository(
        const <TrainerInfo>[
          TrainerInfo(
            name: 'Алексей Петров',
            link: '@alxpetrov',
            description: 'Силовая и функциональная подготовка',
          ),
          TrainerInfo(
            name: 'Мария Романова',
            link: '@maria_run',
            description: '  Беговые тренировки  \n\n и восстановление  ',
          ),
        ],
      );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        trainerDirectoryRepository: trainerDirectoryRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 9102, 'type': 'private'},
        'from': <String, dynamic>{'id': 9102},
        'text': MessageTemplates.buttonCoachingStaff,
      });

      expect(handled, isTrue);
      expect(trainerDirectoryRepository.refreshCalls, 1);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Тренерский штаб DVOR'));
      expect(sender.messages.single.text, contains('Алексей Петров'));
      expect(sender.messages.single.text, contains('@maria_run'));
      expect(sender.messages.single.text, contains('\n🔗 @alxpetrov'));
      expect(sender.messages.single.text, contains('\n📝 Беговые тренировки\n\nи восстановление'));
      expect(sender.messages.single.text, isNot(contains('\n   🔗')));
      expect(
        _keyboardTexts(sender.messages.single.replyMarkup),
        contains(MessageTemplates.buttonCoachingStaff),
      );
    });

    test('handles wrapped update with message payload', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'update_id': 101,
        'message': <String, dynamic>{
          'chat': <String, dynamic>{'id': 111, 'type': 'private'},
          'from': <String, dynamic>{'id': 111},
          'text': '/start',
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 111);
      expect(sender.messages.single.text, contains('Добро пожаловать в DVOR'));
    });

    test('handles /trainings command with category selection', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тестовая тренировка',
              startsAt: DateTime(2026, 6, 4, 19, 0),
              location: 'Тестовый зал',
              locationUrl: 'https://maps.example/test-gym',
              price: 0,
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 12, 'type': 'private'},
        'from': <String, dynamic>{'id': 1200},
        'text': '/trainings',
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 12, 'type': 'private'},
        'from': <String, dynamic>{'id': 1200},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Выбери раздел расписания'));
      expect(sender.messages.last.text, contains('Ближайшие тренировки'));
      expect(sender.messages.last.text, contains('Тестовая тренировка'));
      expect(
        sender.messages.last.text,
        contains('<a href="https://maps.example/test-gym">Тестовый зал</a>'),
      );
      expect(sender.messages.last.text, contains('бесплатная'));
      expect(sender.messages.last.parseMode, 'HTML');
      expect(sender.messages.last.disableWebPagePreview, isTrue);
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, contains(MessageTemplates.buttonBack));
    });

    test('links coaches in schedule when username is available', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Функциональная тренировка',
              startsAt: DateTime(2026, 6, 6, 19, 0),
              location: 'Зал DVOR',
              coach: 'Алексей Петров, Мария Романова и гость',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        trainerDirectoryRepository: _FakeTrainerDirectoryRepository(
          const <TrainerInfo>[
            TrainerInfo(name: 'Алексей Петров', link: '@alxpetrov', description: 'Head coach'),
            TrainerInfo(
              name: 'Мария Романова',
              link: 'https://t.me/maria_run',
              description: 'Running coach',
            ),
            TrainerInfo(
              name: 'Гость',
              link: 'https://example.com/guest',
              description: 'Guest coach',
            ),
          ],
        ),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 125, 'type': 'private'},
        'from': <String, dynamic>{'id': 1250},
        'text': '/trainings',
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 125, 'type': 'private'},
        'from': <String, dynamic>{'id': 1250},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      final text = sender.messages.last.text;
      expect(
        text,
        contains('<a href="https://t.me/alxpetrov">Алексей Петров</a>'),
      );
      expect(
        text,
        contains('<a href="https://t.me/maria_run">Мария Романова</a>'),
      );
      expect(text, contains('гость'));
      expect(text, contains('🧑‍🏫 Тренер:'));
      expect(sender.messages.last.parseMode, 'HTML');
    });

    test('handles menu trainings button in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тренировка из кнопки',
              startsAt: DateTime(2026, 6, 5, 19, 0),
              location: 'Тестовый зал',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 13, 'type': 'private'},
        'from': <String, dynamic>{'id': 1301},
        'text': MessageTemplates.buttonTrainings,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 13, 'type': 'private'},
        'from': <String, dynamic>{'id': 1301},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.last.text, contains('Тренировка из кнопки'));
    });

    test('shows hikes in schedule category', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тренировка',
              startsAt: DateTime(2026, 6, 5, 19, 0),
              location: 'Зал',
            ),
          ],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на водопады',
              dateFrom: DateTime(2026, 6, 10),
              dateTo: DateTime(2026, 6, 10, 23, 59, 59),
              description: 'Однодневный маршрут',
              price: 2500,
            ),
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Трейл перевал',
              dateFrom: DateTime(2026, 6, 20),
              dateTo: DateTime(2026, 6, 22, 23, 59, 59),
              description: 'Трехдневный трек',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonTrainings,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.last.text, contains('Ближайшие походы'));
      expect(sender.messages.last.text, contains('Поход на водопады'));
      expect(sender.messages.last.text, isNot(contains('Трейл перевал')));
    });

    test('shows trails in schedule category', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Трейл перевал',
              dateFrom: DateTime(2026, 6, 20),
              dateTo: DateTime(2026, 6, 22, 23, 59, 59),
              description: 'Трехдневный трек',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 130, 'type': 'private'},
        'from': <String, dynamic>{'id': 1300},
        'text': MessageTemplates.buttonCategoryTrails,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Ближайшие трейлы'));
      expect(sender.messages.last.text, contains('Трейл перевал'));
    });

    test('help button shows client-facing bot capabilities', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 131, 'type': 'private'},
        'from': <String, dynamic>{'id': 1310},
        'text': MessageTemplates.buttonHelp,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(
        sender.messages.single.text,
        contains('Показываю ближайшие тренировки, йогу, походы и трейлы'),
      );
      expect(sender.messages.single.text, contains('каждая 5-я тренировка бесплатная'));
      expect(sender.messages.single.text, contains('публикуем афиши всех мероприятий'));
      expect(sender.messages.single.text, contains('https://t.me/+n4ksCb3kFRQ5MTcy'));
      expect(sender.messages.single.text, contains('/trainings, /book, /my_bookings'));
      expect(sender.messages.single.text, isNot(contains('внешнего источника')));
    });

    test('refresh button is forbidden for non-admin users', () async {
      final sender = _FakeSender();
      final repository = _FakeScheduleRepository(const <TrainingInfo>[]);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: repository,
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 14, 'type': 'private'},
        'from': <String, dynamic>{'id': 1302},
        'text': MessageTemplates.buttonRefreshSchedule,
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('только для админов'));
      expect(repository.refreshCalls, 0);
    });

    test('refresh button triggers repository sync for admin users', () async {
      final sender = _FakeSender();
      final repository = _FakeScheduleRepository(
        const <TrainingInfo>[],
        refreshResult: true,
      );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: repository,
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1303},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 15, 'type': 'private'},
        'from': <String, dynamic>{'id': 1303},
        'text': MessageTemplates.buttonRefreshSchedule,
      });

      expect(handled, isTrue);
      expect(repository.refreshCalls, 1);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Google Docs обновил'));
      expect(sender.messages.last.text, contains(MessageTemplates.scheduleDocumentUrl));
    });

    test('ignores non-private chat messages', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': -1001, 'type': 'supergroup'},
        'text': '/start',
      });

      expect(handled, isFalse);
      expect(sender.messages, isEmpty);
    });

    test('sends fallback for unknown private message', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 140, 'type': 'private'},
        'from': <String, dynamic>{'id': 1400},
        'text': 'какая погода?',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Пока не понял сообщение'));
      expect(sender.messages.single.text, contains(MessageTemplates.buttonHelp));
      expect(sender.messages.single.replyMarkup, isNotNull);
    });

    test('ignores pinned service message in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'chat': <String, dynamic>{'id': 141, 'type': 'private'},
          'from': <String, dynamic>{'id': 1410},
          'pinned_message': <String, dynamic>{'message_id': 1},
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, isEmpty);
    });

    test('book command starts booking category selection flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
              price: 0,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 16, 'type': 'private'},
        'from': <String, dynamic>{'id': 1600},
        'text': '/book',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 0);
      expect(sender.messages.single.text, contains('выбери категорию для записи'));
    });

    test('book button uses viewed schedule category without reselect', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на Бзерпинский карниз',
              dateFrom: DateTime(2026, 7, 20),
              dateTo: DateTime(2026, 7, 21, 23, 59, 59),
              description: 'Двухдневный маршрут',
              price: 4100,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': MessageTemplates.buttonTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1610, 'type': 'private'},
        'from': <String, dynamic>{'id': 1610},
        'text': MessageTemplates.buttonBookTraining,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages.last.text, contains('выбери мероприятие для записи'));
      expect(sender.messages.last.text, contains('🥾 Поход: Поход на Бзерпинский карниз'));
      expect(sender.messages.last.text, isNot(contains('выбери категорию для записи')));
    });

    test('back from quick booking returns to viewed schedule category', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Трейл Фишт',
              dateFrom: DateTime(2026, 8, 2),
              dateTo: DateTime(2026, 8, 3, 23, 59, 59),
              description: 'Горный маршрут',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonCategoryTrails,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonBookTraining,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1611, 'type': 'private'},
        'from': <String, dynamic>{'id': 1611},
        'text': MessageTemplates.buttonBack,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Ближайшие трейлы DVOR'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBookTraining));
      expect(buttons, contains(MessageTemplates.buttonBack));
    });

    test('creates booking after selecting a training button', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
            TrainingInfo(
              title: 'Second session',
              startsAt: DateTime(2026, 7, 11, 18, 0),
              location: 'Hall 2',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601, 'username': 'second_user'},
        'text': '🎯 2. Second session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastCreatedTraining?.title, 'Second session');
      expect(bookingRepository.lastCreatedUsername, 'second_user');
      expect(sender.messages.last.text, contains('записал тебя'));
      expect(sender.messages.last.text, contains('Реквизиты для оплаты'));
    });

    test('sends group notification when free spots drop below 30%', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Full body',
        startsAt: DateTime(2026, 7, 15, 19, 0),
        location: 'Main hall',
        participantsLimit: 10,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = List<TrainingBooking>.generate(
          8,
          (index) => _booking(
            id: 300 + index,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.pendingPayment,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        targetChatId: -100777,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1614, 'type': 'private'},
        'from': <String, dynamic>{'id': 1614},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1614, 'type': 'private'},
        'from': <String, dynamic>{'id': 1614},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1614, 'type': 'private'},
        'from': <String, dynamic>{'id': 1614},
        'text': '🎯 1. Full body',
      });

      expect(handled, isTrue);
      final groupMessages = sender.messages.where((message) => message.chatId == -100777).toList();
      expect(groupMessages, hasLength(1));
      expect(groupMessages.single.text, contains('почти не осталось мест'));
      expect(groupMessages.single.text, contains('Свободных мест: 2 из 10'));
    });

    test('sends group notification when no spots are left', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Intense cardio',
        startsAt: DateTime(2026, 7, 16, 20, 0),
        location: 'Arena',
        participantsLimit: 3,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = List<TrainingBooking>.generate(
          3,
          (index) => _booking(
            id: 500 + index,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.pendingPayment,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        targetChatId: -100778,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1615, 'type': 'private'},
        'from': <String, dynamic>{'id': 1615},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1615, 'type': 'private'},
        'from': <String, dynamic>{'id': 1615},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1615, 'type': 'private'},
        'from': <String, dynamic>{'id': 1615},
        'text': '🎯 1. Intense cardio',
      });

      expect(handled, isTrue);
      final groupMessages = sender.messages.where((message) => message.chatId == -100778).toList();
      expect(groupMessages, hasLength(1));
      expect(groupMessages.single.text, contains('Места на эту тренировку закончились'));
      expect(groupMessages.single.text, contains('Участников: 3/3'));
    });

    test('shows error when participants limit is reached during booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..createException = const BookingParticipantsLimitExceededException('limit reached');
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Limited session',
              startsAt: DateTime(2026, 7, 11, 18, 0),
              location: 'Hall 2',
              participantsLimit: 1,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1613, 'type': 'private'},
        'from': <String, dynamic>{'id': 1613},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1613, 'type': 'private'},
        'from': <String, dynamic>{'id': 1613},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1613, 'type': 'private'},
        'from': <String, dynamic>{'id': 1613},
        'text': '🎯 1. Limited session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(sender.messages.last.text, contains('свободных мест больше нет'));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🎯 1. Limited session'));
    });

    test('creates free booking without payment confirmation flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 12, 18, 0),
              location: 'Open gym',
              price: 0,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -1001612,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1612, 'type': 'private'},
        'from': <String, dynamic>{'id': 1612},
        'text': '🎯 1. Free session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(sender.messages.last.text, contains('Это бесплатная тренировка'));
      expect(sender.messages.last.text, isNot(contains('Реквизиты для оплаты')));
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonTrainings));
      expect(buttons, isNot(contains(MessageTemplates.buttonSubmitPayment)));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -1001612).text;
      expect(adminMessage, contains('новая бесплатная запись'));
      expect(adminMessage, contains('Статус: Бесплатно'));
    });

    test('shows starter bonus button and applies free training once', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(userId: 1604, bonusAvailable: true);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Starter session',
              startsAt: DateTime(2026, 7, 12, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': '🎯 1. Starter session',
      });

      final keyboardBefore = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboardBefore, contains(MessageTemplates.buttonUseStarterBonus));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 164, 'type': 'private'},
        'from': <String, dynamic>{'id': 1604},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Бесплатная тренировка активирована'));
      expect(sender.messages.last.text, contains('Статус: Бесплатно: стартовая тренировка 🎁'));
    });

    test('sends admin notification for starter bonus booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final onboardingRepository = _FakeOnboardingRepository()
        ..seedUser(userId: 1605, bonusAvailable: true);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Admin starter session',
              startsAt: DateTime(2026, 7, 13, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: onboardingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100778,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': '🎯 1. Admin starter session',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 165, 'type': 'private'},
        'from': <String, dynamic>{'id': 1605},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100778).text;
      expect(adminMessage, contains('Стартовая бесплатная запись'));
      expect(adminMessage, contains('Формат: бесплатная тренировка за старт'));
    });

    test('applies every-fifth bonus when starter bonus unavailable', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..everyFifthProgress = const EveryFifthRewardProgress(
          qualifiedTrainingsCount: 8,
          usedRewardsCount: 1,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Fifth reward session',
              startsAt: DateTime(2026, 7, 14, 19, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        onboardingRepository: _FakeOnboardingRepository()..seedUser(userId: 1606),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100889,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': '🎯 1. Fifth reward session',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 166, 'type': 'private'},
        'from': <String, dynamic>{'id': 1606, 'username': 'fifth_user'},
        'text': MessageTemplates.buttonUseStarterBonus,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('каждая 5-я бесплатно'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100889).text;
      expect(adminMessage, contains('каждая 5-я'));
    });

    test('notifies user and admin when every-fifth reward unlocks', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..everyFifthProgress = const EveryFifthRewardProgress(
          qualifiedTrainingsCount: 4,
          usedRewardsCount: 0,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        onboardingRepository: _FakeOnboardingRepository()..seedUser(userId: 1607),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100999,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 167, 'type': 'private'},
        'from': <String, dynamic>{'id': 1607, 'username': 'unlock_user'},
        'text': '/my_bookings',
      });

      expect(handled, isTrue);
      final userNotify = sender.messages.firstWhere((message) => message.chatId == 167).text;
      final adminNotify = sender.messages.firstWhere((message) => message.chatId == -100999).text;
      expect(userNotify, contains('Новая бесплатная тренировка'));
      expect(adminNotify, contains('@unlock_user'));
    });

    test('creates booking after selecting a hike category item', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Поход на хребет',
              dateFrom: DateTime(2026, 7, 13),
              dateTo: DateTime(2026, 7, 14, 23, 59, 59),
              description: 'Ночевка в лагере',
              price: 3200,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1620},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1620},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      final chooseActivityText = sender.messages.last.text;
      expect(chooseActivityText, contains('выбери мероприятие для записи'));
      expect(chooseActivityText, contains('🥾 Поход: Поход на хребет — 13.07.2026'));
      expect(chooseActivityText, isNot(contains('13.07.2026 00:00')));
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1620},
        'text': '🎯 1. 🥾 Поход: Поход на хребет',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastCreatedTraining?.title, contains('Поход на хребет'));
      expect(bookingRepository.lastCreatedTraining?.location, contains('Ночевка в лагере'));
      expect(sender.messages.last.text, contains('записал тебя'));
    });

    test('payment is not submitted without proof file', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': '🎯 1. Book me',
      });

      final submitted = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': MessageTemplates.buttonSubmitPayment,
      });
      expect(submitted, isTrue);
      expect(bookingRepository.submitCalls, 0);
      expect(sender.messages.last.text, contains('Пришли файл'));
    });

    test('asks for payment proof file when text is sent at confirmation step', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': '🎯 1. Book me',
      });

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 163, 'type': 'private'},
        'from': <String, dynamic>{'id': 1603},
        'text': 'уже оплатил',
      });

      expect(handled, isTrue);
      expect(bookingRepository.submitCalls, 0);
      expect(sender.messages.last.text, contains('Пришли файл'));
    });

    test('cancels outdoor pending booking from payment confirmation step', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 99,
            userId: 1608,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            title: '🥾 Поход: Архыз',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Архыз',
              dateFrom: now.add(const Duration(days: 9)),
              dateTo: now.add(const Duration(days: 9, hours: 8)),
              description: 'Маршрут',
              price: 4500,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': MessageTemplates.buttonCategoryHikes,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': '🎯 1. 🥾 Поход: Архыз',
      });

      final keyboard = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(keyboard, contains(MessageTemplates.buttonCancelBooking));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 168, 'type': 'private'},
        'from': <String, dynamic>{'id': 1608},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 99);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('cancels latest pending outdoor booking without active flow', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 450,
            userId: 2601,
            trainingKey: 'trails|2026-06-12T09:00:00.000Z|🏃 Трейл: Плато|Горы',
            title: '🏃 Трейл: Плато',
            startsAt: now.add(const Duration(days: 11)),
            location: 'Горы',
            status: BookingStatus.pendingPayment,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 450,
            userId: 2601,
            trainingKey: 'trails|2026-06-12T09:00:00.000Z|🏃 Трейл: Плато|Горы',
            title: '🏃 Трейл: Плато',
            startsAt: now.add(const Duration(days: 11)),
            location: 'Горы',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 269, 'type': 'private'},
        'from': <String, dynamic>{'id': 2601},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 450);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('submits payment after sending payment proof file', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Book me',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': '🎯 1. Book me',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'message_id': 301,
          'chat': <String, dynamic>{'id': 17, 'type': 'private'},
          'from': <String, dynamic>{'id': 1700},
          'document': <String, Object?>{'file_id': 'doc-proof'},
          'caption': 'Оплата по booking 99',
        },
      });

      expect(handled, isTrue);
      expect(bookingRepository.submitCalls, 1);
      expect(bookingRepository.lastSubmittedBookingId, 99);
      expect(sender.messages.last.text,
          contains('файл с подтверждением оплаты отправил администратору'));
    });

    test('sends admin chat notification only after proof file is sent', () async {
      final sender = _FakeSender();
      final submittedBooking = _booking(
        id: 55,
        userId: 1701,
        title: 'Functional',
        status: BookingStatus.paymentSubmitted,
      );
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = submittedBooking
        ..queue = <TrainingBooking>[submittedBooking];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Functional',
              startsAt: DateTime(2026, 7, 10, 18, 0),
              location: 'Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100777,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': '/book',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': '🎯 1. Functional',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'message': <String, dynamic>{
          'message_id': 401,
          'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
          'from': <String, dynamic>{'id': 1701},
          'photo': <Map<String, Object?>>[
            <String, Object?>{'file_id': 'photo-proof'},
          ],
        },
      });

      expect(handled, isTrue);
      expect(sender.copiedMessages, isEmpty);
      final adminNotification = sender.messages[sender.messages.length - 2];
      expect(adminNotification.chatId, -100777);
      expect(adminNotification.text, contains('Новое подтверждение оплаты'));
      expect(adminNotification.text, contains('Мероприятие: Functional'));
      final adminMarkup = adminNotification.replyMarkup;
      expect(adminMarkup, isNotNull);
      expect(adminMarkup!['inline_keyboard'], isA<List<Object?>>());
      final adminKeyboard = adminMarkup['inline_keyboard']! as List<Object?>;
      final adminFirstRow = adminKeyboard.first as List<Object?>;
      final openQueueButton = adminFirstRow.first as Map<Object?, Object?>;
      expect(openQueueButton['text'], '${MessageTemplates.buttonPaymentsQueue} (1)');
      expect(openQueueButton['callback_data'], MessageTemplates.callbackOpenPaymentsQueue);
      final userConfirmation = sender.messages.last;
      expect(userConfirmation.chatId, 1701);
      expect(
          userConfirmation.text, contains('файл с подтверждением оплаты отправил администратору'));
    });

    test('shows payments queue for selected admin category', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          _booking(
            id: 81,
            status: BookingStatus.paymentSubmitted,
            paymentProofChatId: 50081,
            paymentProofMessageId: 90081,
          ),
          _booking(
            id: 82,
            status: BookingStatus.paymentSubmitted,
            title: '🥾 Поход: Morning session',
            userUsername: 'queue_user',
            paymentProofChatId: 50082,
            paymentProofMessageId: 90082,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1800},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 18, 'type': 'private'},
        'from': <String, dynamic>{'id': 1800},
        'text': '/payments_queue',
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 18, 'type': 'private'},
        'from': <String, dynamic>{'id': 1800},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages.first.text, contains('Выбери категорию для заявок'));
      final categoryMarkup = sender.messages.first.replyMarkup;
      expect(categoryMarkup, isNotNull);
      expect(
        categoryMarkup!['keyboard'],
        <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': '${MessageTemplates.buttonCategoryTrainings} (1)'},
            <String, String>{'text': '${MessageTemplates.buttonCategoryYoga} (0)'},
          ],
          <Map<String, String>>[
            <String, String>{'text': '${MessageTemplates.buttonCategoryHikes} (1)'},
            <String, String>{'text': '${MessageTemplates.buttonCategoryTrails} (0)'},
          ],
          <Map<String, String>>[
            <String, String>{'text': MessageTemplates.buttonBack},
            <String, String>{'text': MessageTemplates.buttonMainMenu},
          ],
        ],
      );
      expect(sender.messages[1].text, contains('Всего ожидают проверки: 1'));
      expect(sender.copiedMessages, hasLength(1));
      expect(sender.copiedMessages.single.toChatId, 18);
      expect(sender.copiedMessages.single.fromChatId, 50082);
      expect(sender.copiedMessages.single.messageId, 90082);

      final firstItemMessage = sender.messages[2];
      expect(firstItemMessage.text, contains('Заявка #82'));
      final markup = firstItemMessage.replyMarkup;
      expect(markup, isNotNull);
      final keyboard = markup!['inline_keyboard'];
      expect(keyboard, isA<List<Object?>>());

      final firstRow = (keyboard as List<Object?>).first as List<Object?>;
      final approveButton = firstRow.first as Map<Object?, Object?>;
      expect(approveButton['text'], '✅ Подтвердить оплату');
    });

    test('splits my bookings into upcoming and past sections', () {
      final templates = const MessageTemplates();
      final text = templates.myBookings(
        <TrainingBooking>[
          _booking(
            id: 90,
            startsAt: DateTime(2026, 6, 20, 19, 0),
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 91,
            startsAt: DateTime(2026, 5, 20, 19, 0),
            status: BookingStatus.paid,
          ),
        ],
        now: DateTime(2026, 6, 1, 12, 0),
      );

      expect(text, contains('Актуальные:'));
      expect(text, contains('Прошедшие:'));
      expect(text, contains('#90'));
      expect(text, contains('#91'));
    });

    test('shows date without time for hike and trail bookings', () {
      final templates = const MessageTemplates();
      final text = templates.myBookings(
        <TrainingBooking>[
          _booking(
            id: 92,
            title: '🏃 Трейл: TRAIL двора — Адыгея',
            startsAt: DateTime(2026, 6, 6, 0, 0),
            status: BookingStatus.paid,
          ),
          _booking(
            id: 93,
            title: '🥾 Поход: Лаго-Наки',
            startsAt: DateTime(2026, 6, 7, 14, 30),
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 94,
            title: 'Тренировка: Функциональная',
            startsAt: DateTime(2026, 6, 8, 19, 15),
            status: BookingStatus.pendingPayment,
          ),
        ],
        now: DateTime(2026, 6, 1, 12, 0),
      );

      expect(text, contains('🏃 Трейл: TRAIL двора — Адыгея\n🕒 Когда: 06.06.2026\n'));
      expect(text, contains('🥾 Поход: Лаго-Наки\n🕒 Когда: 07.06.2026\n'));
      expect(text, contains('Тренировка: Функциональная\n🕒 Когда: 08.06.2026 19:15\n'));
      expect(text, isNot(contains('06.06.2026 00:00')));
      expect(text, isNot(contains('07.06.2026 14:30')));
    });

    test('uses date without time in outdoor booking confirmations', () {
      final templates = const MessageTemplates();
      final outdoorBooking = _booking(
        id: 95,
        trainingKey: 'hikes|2026-06-07T00:00:00.000Z|🥾 Поход: ЧЕРНОГОР|Маршрут',
        title: '🥾 Поход: ЧЕРНОГОР ВОСХОЖДЕНИЕ',
        startsAt: DateTime(2026, 6, 7, 14, 30),
      );

      final createdText = templates.bookingCreated(outdoorBooking);
      final existingText = templates.bookingAlreadyExists(outdoorBooking);
      final reminderText = templates.pendingPaymentReminder(outdoorBooking);

      expect(createdText, contains('🕒 Когда: 07.06.2026'));
      expect(existingText, contains('🕒 Когда: 07.06.2026'));
      expect(reminderText, contains('ЧЕРНОГОР ВОСХОЖДЕНИЕ (07.06.2026)'));

      expect(createdText, isNot(contains('07.06.2026 14:30')));
      expect(existingText, isNot(contains('07.06.2026 14:30')));
      expect(reminderText, isNot(contains('07.06.2026 14:30')));
    });

    test('uses dedicated payment details and contacts for yoga booking', () {
      final templates = const MessageTemplates();
      final yogaBooking = _booking(
        id: 196,
        trainingKey: 'yoga|2026-07-12T17:00:00.000Z|Йога баланс|Студия',
        title: 'Йога баланс',
        startsAt: DateTime(2026, 7, 12, 17, 0),
      );

      final detailsText = templates.paymentDetailsSent(yogaBooking);

      expect(detailsText, contains('Елена П.'));
      expect(detailsText, contains('Т-БАНК'));
      expect(detailsText, contains('+7(961)313-11-44'));
      expect(detailsText, contains('По вопросам теории и практики'));
      expect(detailsText, contains('@dvor_support'));
    });

    test('reschedules training booking from my bookings and notifies admin chat', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 301,
            userId: 2301,
            trainingKey: TrainingInfo(
              title: 'Old session',
              startsAt: DateTime(2026, 7, 5, 19, 0),
              location: 'Hall A',
            ).sessionKey,
            title: 'Old session',
            startsAt: DateTime(2026, 7, 5, 19, 0),
            location: 'Hall A',
            status: BookingStatus.paid,
          ),
        ]
        ..rescheduleResult = BookingRescheduleResult(
          outcome: BookingRescheduleOutcome.success,
          booking: _booking(
            id: 301,
            userId: 2301,
            trainingKey: TrainingInfo(
              title: 'New session',
              startsAt: DateTime(2026, 7, 8, 19, 0),
              location: 'Hall B',
            ).sessionKey,
            title: 'New session',
            startsAt: DateTime(2026, 7, 8, 19, 0),
            location: 'Hall B',
            status: BookingStatus.paid,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Old session',
              startsAt: DateTime(2026, 7, 5, 19, 0),
              location: 'Hall A',
            ),
            TrainingInfo(
              title: 'New session',
              startsAt: DateTime(2026, 7, 8, 19, 0),
              location: 'Hall B',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100601,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '/my_bookings',
      });
      final afterSelection = sender.messages.last;
      expect(_keyboardTexts(afterSelection.replyMarkup), contains('🧾 #301 Old session'));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '🧾 #301 Old session',
      });
      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonRescheduleBooking));
      expect(actionButtons, isNot(contains(MessageTemplates.buttonCancelBooking)));

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2301, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '🎯 2. New session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 1);
      expect(bookingRepository.lastRescheduledBookingId, 301);
      expect(bookingRepository.lastRescheduleTraining?.title, 'New session');
      expect(sender.messages.last.chatId, 2301);
      expect(sender.messages.last.text, contains('перенесена'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100601);
      expect(adminMessage.text, contains('Операционное событие: перенос записи'));
      expect(adminMessage.text, contains('Было: Old session'));
      expect(adminMessage.text, contains('Стало: New session'));
    });

    test('does not allow rescheduling free booking to paid training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 351,
            userId: 2351,
            trainingKey: TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 0,
            ).sessionKey,
            title: 'Free session',
            startsAt: DateTime(2026, 7, 7, 19, 0),
            location: 'Hall A',
            status: BookingStatus.freeTraining,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 0,
            ),
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 10, 19, 0),
              location: 'Hall B',
              price: 2500,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': '🧾 #351 Free session',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2351, 'type': 'private'},
        'from': <String, dynamic>{'id': 2351},
        'text': '🎯 2. Paid session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('нельзя перенести на платную тренировку'));
    });

    test('does not allow rescheduling paid booking to free training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 353,
            userId: 2353,
            trainingKey: TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ).sessionKey,
            title: 'Paid session',
            startsAt: DateTime(2026, 7, 7, 19, 0),
            location: 'Hall A',
            status: BookingStatus.paid,
            trainingPrice: 2500,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ),
            TrainingInfo(
              title: 'Free session',
              startsAt: DateTime(2026, 7, 10, 19, 0),
              location: 'Hall B',
              price: 0,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': '🧾 #353 Paid session',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2353, 'type': 'private'},
        'from': <String, dynamic>{'id': 2353},
        'text': '🎯 2. Free session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('нельзя перенести на бесплатную тренировку'));
    });

    test('does not allow rescheduling paid booking to training with different price', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 354,
            userId: 2354,
            trainingKey: TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ).sessionKey,
            title: 'Paid session',
            startsAt: DateTime(2026, 7, 7, 19, 0),
            location: 'Hall A',
            status: BookingStatus.paid,
            trainingPrice: 2500,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Paid session',
              startsAt: DateTime(2026, 7, 7, 19, 0),
              location: 'Hall A',
              price: 2500,
            ),
            TrainingInfo(
              title: 'Premium session',
              startsAt: DateTime(2026, 7, 10, 19, 0),
              location: 'Hall B',
              price: 3000,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': '🧾 #354 Paid session',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2354, 'type': 'private'},
        'from': <String, dynamic>{'id': 2354},
        'text': '🎯 2. Premium session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('с другой стоимостью'));
    });

    test('does not allow rescheduling zero-price booking to paid training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          fakeBooking(
            id: 352,
            userId: 2352,
            trainingKey: TrainingInfo(
              title: 'Community class',
              startsAt: DateTime(2026, 7, 7, 20, 0),
              location: 'Hall C',
              price: 0,
            ).sessionKey,
            title: 'Community class',
            startsAt: DateTime(2026, 7, 7, 20, 0),
            location: 'Hall C',
            status: BookingStatus.paid,
            trainingPrice: 0,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Community class',
              startsAt: DateTime(2026, 7, 7, 20, 0),
              location: 'Hall C',
              price: 0,
            ),
            TrainingInfo(
              title: 'Premium class',
              startsAt: DateTime(2026, 7, 12, 20, 0),
              location: 'Hall D',
              price: 2800,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': '🧾 #352 Community class',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2352, 'type': 'private'},
        'from': <String, dynamic>{'id': 2352},
        'text': '🎯 2. Premium class',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 0);
      expect(sender.messages.last.text, contains('нельзя перенести на платную тренировку'));
    });

    test('shows conflict message when rescheduling to already booked training', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 302,
            userId: 2302,
            trainingKey: TrainingInfo(
              title: 'Core',
              startsAt: DateTime(2026, 7, 6, 19, 0),
              location: 'Hall A',
            ).sessionKey,
            title: 'Core',
            startsAt: DateTime(2026, 7, 6, 19, 0),
            location: 'Hall A',
          ),
        ]
        ..rescheduleResult = const BookingRescheduleResult(
          outcome: BookingRescheduleOutcome.conflict,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Core',
              startsAt: DateTime(2026, 7, 6, 19, 0),
              location: 'Hall A',
            ),
            TrainingInfo(
              title: 'Speed',
              startsAt: DateTime(2026, 7, 9, 19, 0),
              location: 'Hall B',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🧾 #302 Core',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonRescheduleBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2302, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🎯 2. Speed',
      });

      expect(handled, isTrue);
      expect(bookingRepository.rescheduleCalls, 1);
      expect(sender.messages.last.text, contains('уже есть запись на выбранную тренировку'));
    });

    test('keeps active booking manageable when history has many archived items', () async {
      final sender = _FakeSender();
      final now = DateTime.now();
      final archived = List<TrainingBooking>.generate(
        12,
        (index) => _booking(
          id: 3600 + index,
          userId: 2360,
          trainingKey: 'hikes|archived-$index',
          title: 'Архивный поход #$index',
          startsAt: now.subtract(Duration(days: 40 + index)),
          location: 'Archive',
          status: BookingStatus.cancelled,
        ),
      );
      final active = _booking(
        id: 3699,
        userId: 2360,
        trainingKey: 'hikes|active-slot',
        title: '🥾 Поход: Живой слот',
        startsAt: now.add(const Duration(days: 10)),
        location: 'Маршрут',
        status: BookingStatus.paid,
      );
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[...archived, active];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2360, 'type': 'private'},
        'from': <String, dynamic>{'id': 2360},
        'text': '/my_bookings',
      });

      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains('🧾 #3699 🥾 Поход: Живой слот'));
      expect(buttons, isNot(contains('🧾 #3600 Архивный поход #0')));
    });

    test('cancels outdoor booking before 7 days and notifies admin chat', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 401,
            userId: 2401,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            title: '🥾 Поход: Архыз',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.paid,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 401,
            userId: 2401,
            trainingKey: 'hikes|2026-06-10T12:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            title: '🥾 Поход: Архыз',
            startsAt: now.add(const Duration(days: 9)),
            location: 'Маршрут',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100602,
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': '🧾 #401 🥾 Поход: Архыз',
      });
      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonCancelBooking));
      expect(actionButtons, isNot(contains(MessageTemplates.buttonRescheduleBooking)));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2401, 'type': 'private'},
        'from': <String, dynamic>{'id': 2401},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 401);
      expect(sender.messages.last.text, contains('отменена'));
      final adminMessage = sender.messages.firstWhere((message) => message.chatId == -100602);
      expect(adminMessage.text, contains('Операционное событие: отмена записи'));
      expect(adminMessage.text, contains('🥾 Поход: Архыз'));
    });

    test('does not cancel outdoor booking when less than 7 days left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 402,
            userId: 2402,
            trainingKey: 'trails|2026-06-08T11:00:00.000Z|🏃 Трейл: Плато|Горы',
            title: '🏃 Трейл: Плато',
            startsAt: now.add(const Duration(days: 6, hours: 23)),
            location: 'Горы',
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2402, 'type': 'private'},
        'from': <String, dynamic>{'id': 2402},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2402, 'type': 'private'},
        'from': <String, dynamic>{'id': 2402},
        'text': '🧾 #402 🏃 Трейл: Плато',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2402, 'type': 'private'},
        'from': <String, dynamic>{'id': 2402},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 0);
      expect(sender.messages.last.text, contains('меньше 7 дней'));
    });

    test('cancels yoga booking when at least 24 hours left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 403,
            userId: 2403,
            trainingKey: 'yoga|2026-06-03T12:30:00.000Z|Утренняя йога|Студия',
            title: 'Утренняя йога',
            startsAt: now.add(const Duration(days: 2)),
            location: 'Студия',
            status: BookingStatus.paid,
          ),
        ]
        ..cancelResult = BookingActionResult(
          outcome: BookingActionOutcome.success,
          booking: _booking(
            id: 403,
            userId: 2403,
            trainingKey: 'yoga|2026-06-03T12:30:00.000Z|Утренняя йога|Студия',
            title: 'Утренняя йога',
            startsAt: now.add(const Duration(days: 2)),
            location: 'Студия',
            status: BookingStatus.cancelled,
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': '🧾 #403 Утренняя йога',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2403, 'type': 'private'},
        'from': <String, dynamic>{'id': 2403},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 1);
      expect(bookingRepository.lastCancelledBookingId, 403);
      expect(sender.messages.last.text, contains('отменена'));
    });

    test('does not cancel yoga booking when less than 24 hours left', () async {
      final now = DateTime(2026, 6, 1, 12, 0);
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 404,
            userId: 2404,
            trainingKey: 'yoga|2026-06-02T10:30:00.000Z|Вечерняя йога|Студия',
            title: 'Вечерняя йога',
            startsAt: now.add(const Duration(hours: 23)),
            location: 'Студия',
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        nowProvider: () => now,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2404, 'type': 'private'},
        'from': <String, dynamic>{'id': 2404},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2404, 'type': 'private'},
        'from': <String, dynamic>{'id': 2404},
        'text': '🧾 #404 Вечерняя йога',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 2404, 'type': 'private'},
        'from': <String, dynamic>{'id': 2404},
        'text': MessageTemplates.buttonCancelBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.cancelCalls, 0);
      expect(sender.messages.last.text, contains('меньше 24 часов'));
      expect(sender.messages.last.text, contains('@dvor_support'));
    });

    test('shows participants list for selected admin category', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Morning Run',
        startsAt: DateTime(2026, 9, 2, 7, 30),
        location: 'Park',
      );
      final archivedTraining = TrainingInfo(
        title: 'Old Run',
        startsAt: DateTime(2025, 9, 2, 7, 30),
        location: 'Old Park',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 70,
            userId: 7001,
            userUsername: 'runner_one',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
          ),
          _booking(
            id: 72,
            userId: 7002,
            userUsername: 'runner_bonus',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.paid,
            paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
          ),
          _booking(
            id: 73,
            userId: 7003,
            userUsername: 'runner_rejected',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.paymentRejected,
          ),
          _booking(
            id: 74,
            userId: 7004,
            userUsername: 'runner_cancelled',
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
            status: BookingStatus.cancelled,
          ),
          _booking(
            id: 75,
            userId: 7005,
            userUsername: 'runner_archived',
            trainingKey: archivedTraining.sessionKey,
            title: archivedTraining.title,
            startsAt: archivedTraining.startsAt,
            location: archivedTraining.location,
            status: BookingStatus.paid,
          ),
        ];
      bookingRepository.adminBookings = <TrainingBooking>[
        _booking(
          id: 75,
          userId: 7005,
          userUsername: 'runner_archived',
          trainingKey: archivedTraining.sessionKey,
          title: archivedTraining.title,
          startsAt: archivedTraining.startsAt,
          location: archivedTraining.location,
          status: BookingStatus.paid,
        ),
      ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2000},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2000},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2000},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.first.text, contains('Выбери категорию для списка записавшихся'));
      expect(sender.messages.last.text, contains('Список записавшихся'));
      expect(sender.messages.last.text, contains('👥 Участники: 2/∞'));
      expect(sender.messages.last.text, contains('@runner_one'));
      expect(
        sender.messages.last.text,
        contains('@runner_bonus (Бесплатно: стартовая тренировка 🎁)'),
      );
      expect(sender.messages.last.text, contains('@runner_cancelled (Отменено ❌)'));
      expect(
        sender.messages.last.text.indexOf('@runner_cancelled'),
        greaterThan(sender.messages.last.text.indexOf('@runner_bonus')),
      );
      expect(sender.messages.last.text, contains('Old Run'));
      expect(sender.messages.last.text, contains('@runner_archived (Оплачено ✅)'));
      expect(sender.messages.last.text, isNot(contains('@runner_rejected')));
    });

    test('shows yoga participants list directly for yoga trainer role', () async {
      final sender = _FakeSender();
      final yoga = TrainingInfo(
        title: 'Sunrise Yoga',
        startsAt: DateTime(2026, 9, 3, 8, 0),
        location: 'Yoga Hall',
        category: ActivityCategory.yoga,
      );
      final run = TrainingInfo(
        title: 'Morning Run',
        startsAt: DateTime(2026, 9, 3, 7, 0),
        location: 'Park',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 801,
            userId: 8101,
            userUsername: 'yogi',
            trainingKey: yoga.sessionKey,
            title: yoga.title,
            startsAt: yoga.startsAt,
            location: yoga.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 802,
            userId: 8102,
            userUsername: 'runner',
            trainingKey: run.sessionKey,
            title: run.title,
            startsAt: run.startsAt,
            location: run.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[yoga, run]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1363267745, 'type': 'private'},
        'from': <String, dynamic>{'id': 1363267745},
        'text': MessageTemplates.buttonParticipantsList,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Список записавшихся'));
      expect(sender.messages.single.text, contains('@yogi'));
      expect(sender.messages.single.text, isNot(contains('@runner')));
      expect(sender.messages.single.text, isNot(contains('Выбери категорию')));
    });

    test('merges outdoor participants when activity date changes', () async {
      final sender = _FakeSender();
      final oldHike = TrainingInfo(
        title: '🥾 Поход: DVORCAMP',
        startsAt: DateTime(2026, 7, 2),
        location: 'Тренировки, тропы и теплые вечера.',
        category: ActivityCategory.hikes,
      );
      final newHike = TrainingInfo(
        title: '🥾 Поход: DVORCAMP',
        startsAt: DateTime(2026, 7, 3),
        location: 'Тренировки, тропы и теплые вечера.',
        category: ActivityCategory.hikes,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 901,
            userId: 9001,
            userUsername: 'mi_harkevich',
            trainingKey: oldHike.sessionKey,
            title: oldHike.title,
            startsAt: oldHike.startsAt,
            location: oldHike.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 902,
            userId: 9001,
            userUsername: 'mi_harkevich',
            trainingKey: newHike.sessionKey,
            title: newHike.title,
            startsAt: newHike.startsAt,
            location: newHike.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 903,
            userId: 9002,
            userUsername: 'whatshapped',
            trainingKey: oldHike.sessionKey,
            title: oldHike.title,
            startsAt: oldHike.startsAt,
            location: oldHike.location,
            status: BookingStatus.cancelled,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 901,
            userId: 9001,
            userUsername: 'mi_harkevich',
            trainingKey: oldHike.sessionKey,
            title: oldHike.title,
            startsAt: oldHike.startsAt,
            location: oldHike.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'DVORCAMP',
              dateFrom: newHike.startsAt,
              dateTo: newHike.startsAt,
              description: newHike.location,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2001},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonCategoryHikes,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(RegExp('🥾 Поход: DVORCAMP').allMatches(messageText).length, 1);
      expect(messageText, contains('🕒 03.07.2026'));
      expect(messageText, isNot(contains('🕒 02.07.2026')));
      expect(RegExp('@mi_harkevich').allMatches(messageText).length, 1);
      expect(messageText, contains('@whatshapped (Отменено ❌)'));
    });

    test('merges trail participants when activity date changes', () async {
      final sender = _FakeSender();
      final oldTrail = TrainingInfo(
        title: '🏃 Трейл: Лаго-Наки',
        startsAt: DateTime(2026, 8, 10),
        location: 'Горный маршрут',
        category: ActivityCategory.trails,
      );
      final newTrail = TrainingInfo(
        title: '🏃 Трейл: Лаго-Наки',
        startsAt: DateTime(2026, 8, 12),
        location: 'Горный маршрут',
        category: ActivityCategory.trails,
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 910,
            userId: 9101,
            userUsername: 'trail_runner',
            trainingKey: oldTrail.sessionKey,
            title: oldTrail.title,
            startsAt: oldTrail.startsAt,
            location: oldTrail.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 911,
            userId: 9101,
            userUsername: 'trail_runner',
            trainingKey: newTrail.sessionKey,
            title: newTrail.title,
            startsAt: newTrail.startsAt,
            location: newTrail.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 912,
            userId: 9102,
            userUsername: 'trail_cancelled',
            trainingKey: oldTrail.sessionKey,
            title: oldTrail.title,
            startsAt: oldTrail.startsAt,
            location: oldTrail.location,
            status: BookingStatus.cancelled,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 910,
            userId: 9101,
            userUsername: 'trail_runner',
            trainingKey: oldTrail.sessionKey,
            title: oldTrail.title,
            startsAt: oldTrail.startsAt,
            location: oldTrail.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.trail,
              title: 'Лаго-Наки',
              dateFrom: newTrail.startsAt,
              dateTo: newTrail.startsAt,
              description: newTrail.location,
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2002},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2002},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2002},
        'text': MessageTemplates.buttonCategoryTrails,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(RegExp('🏃 Трейл: Лаго-Наки').allMatches(messageText).length, 1);
      expect(messageText, contains('🕒 12.08.2026'));
      expect(messageText, isNot(contains('🕒 10.08.2026')));
      expect(RegExp('@trail_runner').allMatches(messageText).length, 1);
      expect(messageText, contains('@trail_cancelled (Отменено ❌)'));
    });

    test('merges training participants when session date changes', () async {
      final sender = _FakeSender();
      final oldTraining = TrainingInfo(
        title: 'Функционалка',
        startsAt: DateTime(2026, 9, 1, 19, 0),
        location: 'Зал А',
      );
      final newTraining = TrainingInfo(
        title: 'Функционалка',
        startsAt: DateTime(2026, 9, 2, 19, 0),
        location: 'Зал А',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 920,
            userId: 9201,
            userUsername: 'fit_user',
            trainingKey: oldTraining.sessionKey,
            title: oldTraining.title,
            startsAt: oldTraining.startsAt,
            location: oldTraining.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 921,
            userId: 9201,
            userUsername: 'fit_user',
            trainingKey: newTraining.sessionKey,
            title: newTraining.title,
            startsAt: newTraining.startsAt,
            location: newTraining.location,
            status: BookingStatus.paid,
          ),
          _booking(
            id: 922,
            userId: 9202,
            userUsername: 'fit_cancelled',
            trainingKey: oldTraining.sessionKey,
            title: oldTraining.title,
            startsAt: oldTraining.startsAt,
            location: oldTraining.location,
            status: BookingStatus.cancelled,
          ),
        ]
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 920,
            userId: 9201,
            userUsername: 'fit_user',
            trainingKey: oldTraining.sessionKey,
            title: oldTraining.title,
            startsAt: oldTraining.startsAt,
            location: oldTraining.location,
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[newTraining]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2003},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2003},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 20, 'type': 'private'},
        'from': <String, dynamic>{'id': 2003},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(categoryHandled, isTrue);
      final messageText = sender.messages.last.text;
      expect(RegExp('Функционалка').allMatches(messageText).length, 1);
      expect(messageText, contains('🕒 02.09.2026 19:00'));
      expect(messageText, isNot(contains('🕒 01.09.2026 19:00')));
      expect(RegExp('@fit_user').allMatches(messageText).length, 1);
      expect(messageText, contains('@fit_cancelled (Отменено ❌)'));
    });

    test('shows nobles list for admin with training counts', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          _booking(
            id: 801,
            userId: 5002,
            userUsername: 'runner_two',
            status: BookingStatus.pendingPayment,
          ),
          _booking(
            id: 802,
            userId: 5001,
            userUsername: 'runner_one',
            status: BookingStatus.paid,
          ),
          _booking(
            id: 803,
            userId: 5001,
            userUsername: 'runner_one',
            status: BookingStatus.paymentSubmitted,
          ),
          _booking(
            id: 804,
            userId: 5003,
            status: BookingStatus.paymentRejected,
          ),
          _booking(
            id: 805,
            userId: 5001,
            userUsername: 'runner_one',
            title: '🥾 Поход: Архыз',
            status: BookingStatus.paid,
          ),
          _booking(
            id: 806,
            userId: 5002,
            userUsername: 'runner_two',
            title: '🏃 Трейл: Лаго-Наки',
            status: BookingStatus.paymentSubmitted,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2100},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 21, 'type': 'private'},
        'from': <String, dynamic>{'id': 2100},
        'text': MessageTemplates.buttonNoblesList,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      final text = sender.messages.single.text;
      expect(text, contains('Список дворян'));
      expect(text, contains('Всего записей на тренировки: 4'));
      expect(text, contains('1. @runner_one (5001) — 2'));
      expect(text, contains('2. @runner_two (5002) — 1'));
      expect(text, contains('tg://user?id=5003 (5003) — 1'));
      expect(text, isNot(contains('Поход')));
      expect(text, isNot(contains('Трейл')));
    });

    test('forbids nobles list for non-admin users', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{9999},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 22, 'type': 'private'},
        'from': <String, dynamic>{'id': 2200},
        'text': MessageTemplates.buttonNoblesList,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('только администраторам'));
    });

    test('shows tg user link when participant has no username', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Evening Run',
        startsAt: DateTime(2026, 9, 3, 19, 30),
        location: 'Park',
      );
      final bookingRepository = _FakeBookingRepository()
        ..bookingsByTrainingKey = <TrainingBooking>[
          _booking(
            id: 71,
            userId: 7101,
            trainingKey: training.sessionKey,
            title: training.title,
            startsAt: training.startsAt,
            location: training.location,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2001},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 21, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonParticipantsList,
      });
      final categoryHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 21, 'type': 'private'},
        'from': <String, dynamic>{'id': 2001},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(handled, isTrue);
      expect(categoryHandled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages.last.text, contains('tg://user?id=7101'));
    });

    test('opens admin booking management menu', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2300},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2300},
        'text': MessageTemplates.buttonManageBookings,
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Управление записями'));
      final buttons = _keyboardTexts(sender.messages.single.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonBookingsList));
      expect(buttons, contains(MessageTemplates.buttonCreateBooking));
    });

    test('paginates admin bookings list in management flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 9, archived: 0)
        ..adminBookings = List<TrainingBooking>.generate(
          9,
          (index) => _booking(
            id: 601 + index,
            userId: 9601 + index,
            title: 'Morning Run ${index + 1}',
            startsAt: DateTime(2026, 10, 1 + index, 10, 0),
          ),
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2305},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': '${MessageTemplates.buttonActiveBookings} (9)',
      });
      final firstPageHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonCategoryTrainings,
      });

      expect(firstPageHandled, isTrue);
      expect(sender.messages.last.text, contains('Страница 1/2'));
      expect(sender.messages.last.text, contains('Записи на текущей странице'));
      expect(sender.messages.last.text, contains('1. #601 Morning Run 1'));
      expect(sender.messages.last.text, contains('8. #608 Morning Run 8'));
      expect(sender.messages.last.text, isNot(contains('#609 Morning Run 9')));
      final firstPageButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(firstPageButtons, contains('🧾 #601 Morning Run 1'));
      expect(firstPageButtons, contains('🧾 #608 Morning Run 8'));
      expect(firstPageButtons, isNot(contains('🧾 #609 Morning Run 9')));
      expect(firstPageButtons, contains(MessageTemplates.buttonBookingsNextPage));
      expect(firstPageButtons, isNot(contains(MessageTemplates.buttonBookingsPreviousPage)));

      final secondPageHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2305},
        'text': MessageTemplates.buttonBookingsNextPage,
      });

      expect(secondPageHandled, isTrue);
      expect(sender.messages.last.text, contains('Страница 2/2'));
      expect(sender.messages.last.text, contains('1. #609 Morning Run 9'));
      expect(sender.messages.last.text, isNot(contains('#608 Morning Run 8')));
      final secondPageButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(secondPageButtons, contains('🧾 #609 Morning Run 9'));
      expect(secondPageButtons, contains(MessageTemplates.buttonBookingsPreviousPage));
      expect(secondPageButtons, isNot(contains(MessageTemplates.buttonBookingsNextPage)));
    });

    test('archives selected booking from admin management flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 0, archived: 1)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 501,
            userId: 9001,
            userUsername: 'archived_runner',
            trainingKey: 'trainings|2026-10-01T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Park',
            status: BookingStatus.pendingPayment,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2301},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '${MessageTemplates.buttonArchivedBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': '🧾 #501 Morning Run',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonDeleteBooking,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2301},
        'text': MessageTemplates.buttonConfirmDeleteBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.adminArchiveCalls, 1);
      expect(bookingRepository.lastAdminArchivedBookingId, 501);
      final userNotification = sender.messages.firstWhere((message) => message.chatId == 9001).text;
      expect(userNotification, contains('запись #501 отменил администратор'));
      expect(userNotification, contains('@dvor_support'));
      expect(sender.messages.last.text, contains('переведена в архив'));
    });

    test('restores archived booking when event is upcoming', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 0, archived: 1)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 502,
            userId: 9002,
            userUsername: 'restore_runner',
            trainingKey: 'trainings|2026-10-02T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 2, 10, 0),
            location: 'Park',
            status: BookingStatus.cancelled,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2303},
        nowProvider: () => DateTime(2026, 9, 30, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': '${MessageTemplates.buttonArchivedBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': '🧾 #502 Morning Run',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2303},
        'text': MessageTemplates.buttonRestoreBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.adminBookings.single.status, BookingStatus.pendingPayment);
      expect(sender.messages.last.text, contains('восстановлена'));
    });

    test('shows conflict message when admin edit collides with existing booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..adminSegmentCounts = (active: 1, archived: 0)
        ..adminBookings = <TrainingBooking>[
          _booking(
            id: 503,
            userId: -5003,
            userUsername: 'dup_runner',
            trainingKey: 'trainings|2026-10-03T10:00:00.000Z|Morning Run|Park',
            title: 'Morning Run',
            startsAt: DateTime(2026, 10, 3, 10, 0),
            location: 'Park',
            status: BookingStatus.pendingPayment,
          ),
        ]
        ..throwAdminUpdateConflict = true;
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2304},
        nowProvider: () => DateTime(2026, 9, 30, 10, 0),
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonBookingsList,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': '${MessageTemplates.buttonActiveBookings} (1)',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': '🧾 #503 Morning Run',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonEditBooking,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonEditBookingPayment,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2304},
        'text': MessageTemplates.buttonStatusFreeTraining,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('уже есть запись на выбранное мероприятие'));
    });

    test('creates booking from admin wizard', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Bootcamp',
        startsAt: DateTime(2026, 9, 18, 19, 0),
        location: 'Main Hall',
      );
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(<TrainingInfo>[training]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{2302},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonManageBookings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonCreateBooking,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonCategoryTrainings,
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '🎯 1. Bootcamp',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': '@new_runner',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonStatusFreeTraining,
      });
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 23, 'type': 'private'},
        'from': <String, dynamic>{'id': 2302},
        'text': MessageTemplates.buttonConfirmCreateBooking,
      });

      expect(handled, isTrue);
      expect(bookingRepository.adminBookings, hasLength(1));
      expect(bookingRepository.adminBookings.single.userUsername, 'new_runner');
      expect(bookingRepository.adminBookings.single.status, BookingStatus.freeTraining);
      expect(sender.messages.last.text, contains('создана'));
    });

    test('notifies user and admin chat on approve payment', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1900},
        adminChatId: -100555,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 19, 'type': 'private'},
        'from': <String, dynamic>{'id': 1900, 'username': 'chief_admin'},
        'text': '/approve_payment 10',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('подтвердили'));
      expect(sender.messages[1].chatId, -100555);
      expect(sender.messages[1].text, contains('Модерация оплаты выполнена'));
      expect(sender.messages[1].text, contains('Пользователь: tg://user?id=1 (1)'));
      expect(sender.messages[1].text, contains('Проверил админ: @chief_admin (1900)'));
      expect(sender.messages[2].chatId, 19);
      expect(sender.messages[2].text, contains('Статус записи #10 обновлен'));
    });

    test('handles payment moderation callback buttons for admin', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1950},
        adminChatId: -100556,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-1',
          'from': <String, dynamic>{'id': 1950, 'username': 'moderator_anna'},
          'data': '${MessageTemplates.callbackRejectPaymentPrefix}22',
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1950, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('отклонили'));
      expect(sender.messages[1].chatId, -100556);
      expect(sender.messages[1].text, contains('Проверил админ: @moderator_anna (1950)'));
      expect(sender.messages[2].chatId, 1950);
      expect(sender.messages[2].text, contains('Статус записи #22 обновлен'));
      expect(sender.answeredCallbacks, hasLength(1));
      expect(sender.answeredCallbacks.single.callbackQueryId, 'cbq-1');
    });

    test('handles partial payment moderation callback buttons for admin', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1955},
        adminChatId: -100559,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-partial',
          'from': <String, dynamic>{'id': 1955, 'username': 'moderator_olga'},
          'data': '${MessageTemplates.callbackApprovePartialPaymentPrefix}25',
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1955, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('Предоплату по записи #25 подтвердили'));
      expect(sender.messages[1].chatId, -100559);
      expect(sender.messages[1].text, contains('Статус: Предоплата внесена 🟡'));
      expect(sender.messages[2].chatId, 1955);
      expect(sender.messages[2].text, contains('Предоплата внесена 🟡'));
      expect(sender.answeredCallbacks, hasLength(1));
      expect(sender.answeredCallbacks.single.callbackQueryId, 'cbq-partial');
    });

    test('shows already reviewed message when payment status is stale', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..paymentReviewResult = const PaymentReviewResult(
          outcome: PaymentReviewOutcome.invalidStatus,
        );
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1990},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1990, 'type': 'private'},
        'from': <String, dynamic>{'id': 1990},
        'text': '/approve_payment 22',
      });

      expect(handled, isTrue);
      expect(bookingRepository.reviewCalls, 1);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('уже не в статусе «На проверке»'));
    });

    test('opens payments queue flow from admin notification callback', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1952},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-open-queue',
          'from': <String, dynamic>{'id': 1952},
          'data': MessageTemplates.callbackOpenPaymentsQueue,
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1952, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.chatId, 1952);
      expect(sender.messages.single.text, contains('Выбери категорию для заявок'));
      expect(sender.answeredCallbacks, hasLength(1));
      expect(sender.answeredCallbacks.single.callbackQueryId, 'cbq-open-queue');
    });

    test('payment moderation callback is not treated as training selection', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Admin training',
              startsAt: DateTime(2026, 7, 15, 19, 0),
              location: 'Main Hall',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{1951},
        adminChatId: -100557,
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1951, 'type': 'private'},
        'from': <String, dynamic>{'id': 1951},
        'text': '/book',
      });
      final handled = await handlers.handle(<String, dynamic>{
        'callback_query': <String, dynamic>{
          'id': 'cbq-2',
          'from': <String, dynamic>{'id': 1951},
          'data': '${MessageTemplates.callbackApprovePaymentPrefix}23',
          'message': <String, dynamic>{
            'chat': <String, dynamic>{'id': 1951, 'type': 'private'},
          },
        },
      });

      expect(handled, isTrue);
      expect(sender.messages.any((message) => message.text.contains('Не понял выбор')), isFalse);
      expect(sender.messages.last.chatId, 1951);
      expect(sender.messages.last.text, contains('Статус записи #23 обновлен'));
    });

    test('shows outdoor payment choice buttons in payment flow', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 930,
            userId: 3930,
            title: '🏃 Трейл: Приэльбрусье',
            trainingKey: 'trails|2026-10-01T10:00:00.000Z|🏃 Трейл: Приэльбрусье|Маршрут',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Маршрут',
            status: BookingStatus.pendingPayment,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3930, 'type': 'private'},
        'from': <String, dynamic>{'id': 3930},
        'text': MessageTemplates.buttonSubmitPayment,
      });

      expect(handled, isTrue);
      final buttons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(buttons, contains(MessageTemplates.buttonPayFully));
      expect(buttons, contains(MessageTemplates.buttonPayPartially));
    });

    test('repeat booking action opens booking flow for same category', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..userBookings = <TrainingBooking>[
          _booking(
            id: 901,
            userId: 3901,
            title: '🥾 Поход: Архыз',
            trainingKey: 'hikes|2026-10-01T10:00:00.000Z|🥾 Поход: Архыз|Маршрут',
            startsAt: DateTime(2026, 10, 1, 10, 0),
            location: 'Маршрут',
            status: BookingStatus.paid,
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          const <TrainingInfo>[],
          outdoorItems: <OutdoorActivityInfo>[
            OutdoorActivityInfo(
              type: OutdoorActivityType.hike,
              title: 'Архыз выходные',
              dateFrom: DateTime(2026, 10, 15),
              dateTo: DateTime(2026, 10, 16, 23, 59, 59),
              description: 'Маршрут 2 дня',
            ),
          ],
        ),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3901, 'type': 'private'},
        'from': <String, dynamic>{'id': 3901},
        'text': '/my_bookings',
      });
      await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3901, 'type': 'private'},
        'from': <String, dynamic>{'id': 3901},
        'text': '🧾 #901 🥾 Поход: Архыз',
      });

      final actionButtons = _keyboardTexts(sender.messages.last.replyMarkup);
      expect(actionButtons, contains(MessageTemplates.buttonRepeatBooking));

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 3901, 'type': 'private'},
        'from': <String, dynamic>{'id': 3901},
        'text': MessageTemplates.buttonRepeatBooking,
      });

      expect(handled, isTrue);
      expect(sender.messages.last.text, contains('Шаг 2/3: выбери мероприятие для записи'));
      expect(sender.messages.last.text, contains('🥾 Поход: Архыз выходные'));
    });

    test('opens and sends economic summary by selected period', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          TrainingBooking(
            id: 99,
            userId: 7001,
            userUsername: 'admin_econ',
            trainingKey: 'trainings|summary',
            trainingTitle: 'Test event',
            startsAt: DateTime(2026, 11, 2, 19),
            location: 'Hall',
            status: BookingStatus.paid,
            trainingPrice: 1200,
            createdAt: DateTime(2026, 11, 2, 18),
            updatedAt: DateTime(2026, 11, 2, 20),
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{4902},
        nowProvider: () => DateTime(2026, 11, 10, 12),
      );

      final openHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 4902, 'type': 'private'},
        'from': <String, dynamic>{'id': 4902},
        'text': MessageTemplates.buttonEconomicSummary,
      });
      expect(openHandled, isTrue);
      expect(sender.messages.single.text, contains('Выбери период'));

      final sendHandled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 4902, 'type': 'private'},
        'from': <String, dynamic>{'id': 4902},
        'text': MessageTemplates.buttonSummaryPreviousWeek,
      });
      expect(sendHandled, isTrue);
      expect(sender.messages.last.text, contains('Экономическая сводка'));
      expect(sender.messages.last.text, contains('Финансы:'));
    });

    test('supports economic summary command with period argument', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          TrainingBooking(
            id: 100,
            userId: 7002,
            userUsername: 'admin_econ_cmd',
            trainingKey: 'trainings|summary2',
            trainingTitle: 'Cmd event',
            startsAt: DateTime(2026, 11, 3, 19),
            location: 'Hall',
            status: BookingStatus.paid,
            trainingPrice: 1500,
            createdAt: DateTime(2026, 11, 3, 18),
            updatedAt: DateTime(2026, 11, 3, 20),
          ),
        ];
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{4903},
        nowProvider: () => DateTime(2026, 11, 10, 12),
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 4903, 'type': 'private'},
        'from': <String, dynamic>{'id': 4903},
        'text': '/economic_summary current_month',
      });

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('за текущий месяц'));
    });
  });
}
