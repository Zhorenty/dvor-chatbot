import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:test/test.dart';

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
      expect(sender.messages.single.text, contains('DVOR'));
      expect(sender.messages.single.replyMarkup, isNotNull);
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
      expect(buttons, contains(MessageTemplates.buttonParticipantsList));
      expect(buttons, isNot(contains(MessageTemplates.buttonTrainings)));
      expect(buttons, isNot(contains(MessageTemplates.buttonBookTraining)));
      expect(buttons, isNot(contains(MessageTemplates.buttonMyBookings)));
      expect(buttons, isNot(contains(MessageTemplates.buttonHelp)));
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
      expect(sender.messages.single.text, contains('DVOR'));
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
      expect(sender.messages.last.text, contains('бесплатная'));
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
          sender.messages.single.text, contains('Показываю ближайшие тренировки, походы и трейлы'));
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
      expect(sender.messages.first.text, contains('Расписание обновил'));
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
      expect(sender.messages.single.text, contains('Выбери категорию для записи'));
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
      expect(sender.messages.last.text, contains('пришли файл'));
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
      expect(sender.messages.last.text, contains('пришли файл'));
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
      expect(sender.messages.last.text,
          contains('файл с подтверждением оплаты отправил администратору'));
    });

    test('sends admin chat notification only after proof file is sent', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(
          id: 55,
          userId: 1701,
          title: 'Functional',
          status: BookingStatus.paymentSubmitted,
        );
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
      expect(sender.copiedMessages, hasLength(1));
      expect(sender.copiedMessages.single.toChatId, -100777);
      final adminNotification = sender.messages[sender.messages.length - 2];
      expect(adminNotification.chatId, -100777);
      expect(adminNotification.text, contains('Новое подтверждение оплаты'));
      final adminMarkup = adminNotification.replyMarkup;
      expect(adminMarkup, isNotNull);
      expect(adminMarkup!['inline_keyboard'], isA<List<Object?>>());
      final userConfirmation = sender.messages.last;
      expect(userConfirmation.chatId, 1701);
      expect(
          userConfirmation.text, contains('файл с подтверждением оплаты отправил администратору'));
    });

    test('shows payments queue for selected admin category', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[
          _booking(id: 81, status: BookingStatus.paymentSubmitted),
          _booking(
            id: 82,
            status: BookingStatus.paymentSubmitted,
            title: '🥾 Поход: Morning session',
            userUsername: 'queue_user',
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
      expect(sender.messages[1].text, contains('Всего ожидают проверки: 1'));

      final firstItemMessage = sender.messages[2];
      expect(firstItemMessage.text, contains('Заявка #82'));
      final markup = firstItemMessage.replyMarkup;
      expect(markup, isNotNull);
      final keyboard = markup!['inline_keyboard'];
      expect(keyboard, isA<List<Object?>>());

      final firstRow = (keyboard as List<Object?>).first as List<Object?>;
      final approveButton = firstRow.first as Map<Object?, Object?>;
      expect(approveButton['text'], '✅ Подтвердить');
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

    test('shows participants list for selected admin category', () async {
      final sender = _FakeSender();
      final training = TrainingInfo(
        title: 'Morning Run',
        startsAt: DateTime(2026, 9, 2, 7, 30),
        location: 'Park',
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
      expect(sender.messages.last.text, contains('@runner_one'));
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
        'from': <String, dynamic>{'id': 1900},
        'text': '/approve_payment 10',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(3));
      expect(sender.messages[0].chatId, 1);
      expect(sender.messages[0].text, contains('подтвердили'));
      expect(sender.messages[1].chatId, -100555);
      expect(sender.messages[1].text, contains('Модерация оплаты выполнена'));
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
          'from': <String, dynamic>{'id': 1950},
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
      expect(sender.messages[2].chatId, 1950);
      expect(sender.messages[2].text, contains('Статус записи #22 обновлен'));
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
  });
}

final class _FakeScheduleRepository implements TrainingScheduleRepository {
  _FakeScheduleRepository(
    this._items, {
    this.outdoorItems = const <OutdoorActivityInfo>[],
    this.refreshResult = true,
  });

  final List<TrainingInfo> _items;
  final List<OutdoorActivityInfo> outdoorItems;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) => _items.take(limit).toList();

  @override
  List<OutdoorActivityInfo> upcomingOutdoorActivities({DateTime? now, int limit = 8}) =>
      outdoorItems.take(limit).toList();

  @override
  Future<bool> refresh({bool force = false}) async {
    refreshCalls += 1;
    return refreshResult;
  }
}

final class _FakeBookingRepository implements BookingRepository {
  int createCalls = 0;
  int submitCalls = 0;
  List<TrainingBooking> queue = const <TrainingBooking>[];
  List<TrainingBooking> bookingsByTrainingKey = const <TrainingBooking>[];
  TrainingBooking? submitResult;
  TrainingInfo? lastCreatedTraining;
  String? lastCreatedUsername;
  List<TrainingBooking> pendingForReminder = const <TrainingBooking>[];
  int remindersMarked = 0;

  @override
  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    String? userUsername,
    required TrainingInfo training,
  }) async {
    createCalls += 1;
    lastCreatedTraining = training;
    lastCreatedUsername = userUsername;
    return BookingCreateResult(
      booking: _booking(
        id: 99,
        userId: userId,
        userUsername: userUsername,
        title: training.title,
        startsAt: training.startsAt,
        location: training.location,
      ),
      created: true,
    );
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<List<TrainingBooking>> listByStatus(
    BookingStatus status, {
    int limit = 20,
  }) async {
    return queue;
  }

  @override
  Future<List<TrainingBooking>> listByTrainingKeys(
    Set<String> trainingKeys, {
    int limit = 200,
  }) async {
    return bookingsByTrainingKey
        .where((booking) => trainingKeys.contains(booking.trainingKey))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<TrainingBooking>> listUserBookings(int userId, {int limit = 10}) async {
    return <TrainingBooking>[
      _booking(
        id: 1,
        userId: userId,
        title: 'Test booking',
        startsAt: DateTime(2026, 7, 10, 18),
        location: 'Gym',
      ),
    ];
  }

  @override
  Future<TrainingBooking?> submitPaymentForLatestPending(
    int userId, {
    String? note,
  }) async {
    submitCalls += 1;
    return submitResult;
  }

  @override
  Future<TrainingBooking?> updateStatus(int bookingId, BookingStatus status) async {
    return _booking(id: bookingId, status: status);
  }

  @override
  Future<List<TrainingBooking>> listPendingPaymentForReminder({
    required DateTime createdBefore,
    required DateTime remindedBefore,
    int limit = 20,
  }) async {
    return pendingForReminder.take(limit).toList(growable: false);
  }

  @override
  Future<void> markReminderSent(int bookingId) async {
    remindersMarked += 1;
  }
}

TrainingBooking _booking({
  int id = 10,
  int userId = 1,
  String? userUsername,
  String? trainingKey,
  String title = 'Training',
  DateTime? startsAt,
  String location = 'Hall',
  BookingStatus status = BookingStatus.pendingPayment,
}) {
  final now = DateTime(2026, 1, 1, 10);
  return TrainingBooking(
    id: id,
    userId: userId,
    userUsername: userUsername,
    trainingKey: trainingKey ?? 'key-$id',
    trainingTitle: title,
    startsAt: startsAt ?? DateTime(2026, 8, 1, 18),
    location: location,
    status: status,
    paymentNote: null,
    createdAt: now,
    updatedAt: now,
  );
}

final class _FakeSender implements MessageSender {
  final List<_SentMessage> messages = <_SentMessage>[];
  final List<_CopiedMessage> copiedMessages = <_CopiedMessage>[];

  @override
  Future<int> sendMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    Map<String, Object?>? replyMarkup,
  }) async {
    messages.add(
      _SentMessage(
        chatId: chatId,
        text: text,
        disableNotification: disableNotification,
        replyMarkup: replyMarkup,
      ),
    );
    return messages.length;
  }

  @override
  Future<int> copyMessage(
    int chatId, {
    required int fromChatId,
    required int messageId,
    bool disableNotification = true,
  }) async {
    copiedMessages.add(
      _CopiedMessage(
        toChatId: chatId,
        fromChatId: fromChatId,
        messageId: messageId,
        disableNotification: disableNotification,
      ),
    );
    return copiedMessages.length;
  }
}

final class _SentMessage {
  const _SentMessage({
    required this.chatId,
    required this.text,
    required this.disableNotification,
    required this.replyMarkup,
  });

  final int chatId;
  final String text;
  final bool disableNotification;
  final Map<String, Object?>? replyMarkup;
}

final class _CopiedMessage {
  const _CopiedMessage({
    required this.toChatId,
    required this.fromChatId,
    required this.messageId,
    required this.disableNotification,
  });

  final int toChatId;
  final int fromChatId;
  final int messageId;
  final bool disableNotification;
}

List<String> _keyboardTexts(Map<String, Object?>? replyMarkup) {
  if (replyMarkup == null) {
    return const <String>[];
  }
  final keyboard = replyMarkup['keyboard'];
  if (keyboard is! List) {
    return const <String>[];
  }

  final texts = <String>[];
  for (final row in keyboard) {
    if (row is! List) {
      continue;
    }
    for (final button in row) {
      if (button is Map && button['text'] is String) {
        texts.add(button['text'] as String);
      }
    }
  }
  return texts;
}
