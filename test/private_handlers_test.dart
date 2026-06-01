import 'package:dvor_chatbot/src/bot/handlers/private_handlers.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
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

    test('handles /trainings command in private chat', () async {
      final sender = _FakeSender();
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(
          <TrainingInfo>[
            TrainingInfo(
              title: 'Тестовая тренировка',
              startsAt: DateTime(2026, 6, 4, 19, 0),
              location: 'Тестовый зал',
            ),
          ],
        ),
        bookingRepository: _FakeBookingRepository(),
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 12, 'type': 'private'},
        'text': '/trainings',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Ближайшие тренировки'));
      expect(sender.messages.single.text, contains('Тестовая тренировка'));
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

      expect(handled, isTrue);
      expect(sender.messages, hasLength(1));
      expect(sender.messages.single.text, contains('Тренировка из кнопки'));
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
      expect(sender.messages.single.text, contains('Показываю ближайшие тренировки'));
      expect(sender.messages.single.text, contains('/trainings, /book, /my_bookings, /paid'));
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
      expect(sender.messages.single.text, contains('Расписание обновил'));
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

    test('book command starts training selection flow', () async {
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
      expect(sender.messages.single.text, contains('Выбери тренировку'));
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
      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 161, 'type': 'private'},
        'from': <String, dynamic>{'id': 1601},
        'text': '🎯 2. Second session',
      });

      expect(handled, isTrue);
      expect(bookingRepository.createCalls, 1);
      expect(bookingRepository.lastCreatedTraining?.title, 'Second session');
      expect(sender.messages.last.text, contains('записал тебя'));
      expect(sender.messages.last.text, contains('Реквизиты для оплаты'));
    });

    test('paid button is available right after training is selected', () async {
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
        'text': '🎯 1. Book me',
      });

      final submitted = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 162, 'type': 'private'},
        'from': <String, dynamic>{'id': 1602},
        'text': MessageTemplates.buttonSubmitPayment,
      });
      expect(submitted, isTrue);
      expect(bookingRepository.submitCalls, 1);
    });

    test('submits payment for latest pending booking', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..submitResult = _booking(status: BookingStatus.paymentSubmitted);
      final handlers = PrivateHandlers(
        sender: sender,
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 17, 'type': 'private'},
        'from': <String, dynamic>{'id': 1700},
        'text': '/paid transfer sent',
      });

      expect(handled, isTrue);
      expect(bookingRepository.submitCalls, 1);
      expect(sender.messages.single.text, contains('отметку об оплате отправил администратору'));
    });

    test('sends admin chat notification when payment submitted', () async {
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
        scheduleRepository: _FakeScheduleRepository(const <TrainingInfo>[]),
        bookingRepository: bookingRepository,
        templates: const MessageTemplates(),
        adminUserIds: const <int>{},
        adminChatId: -100777,
      );

      final handled = await handlers.handle(<String, dynamic>{
        'chat': <String, dynamic>{'id': 1701, 'type': 'private'},
        'from': <String, dynamic>{'id': 1701},
        'text': '/paid transfer sent',
      });

      expect(handled, isTrue);
      expect(sender.messages, hasLength(2));
      expect(sender.messages[0].chatId, -100777);
      expect(sender.messages[0].text, contains('Новое подтверждение оплаты'));
      final adminMarkup = sender.messages[0].replyMarkup;
      expect(adminMarkup, isNotNull);
      expect(adminMarkup!['inline_keyboard'], isA<List<Object?>>());
      expect(sender.messages[1].chatId, 1701);
      expect(sender.messages[1].text, contains('отметку об оплате отправил администратору'));
    });

    test('shows payments queue for admins', () async {
      final sender = _FakeSender();
      final bookingRepository = _FakeBookingRepository()
        ..queue = <TrainingBooking>[_booking(status: BookingStatus.paymentSubmitted)];
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

      expect(handled, isTrue);
      expect(sender.messages.single.text, contains('Заявки на подтверждение оплаты'));
      final markup = sender.messages.single.replyMarkup;
      expect(markup, isNotNull);
      final keyboard = markup!['inline_keyboard'];
      expect(keyboard, isA<List<Object?>>());
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
  });
}

final class _FakeScheduleRepository implements TrainingScheduleRepository {
  _FakeScheduleRepository(
    this._items, {
    this.refreshResult = true,
  });

  final List<TrainingInfo> _items;
  final bool refreshResult;
  int refreshCalls = 0;

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) => _items.take(limit).toList();

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
  TrainingBooking? submitResult;
  TrainingInfo? lastCreatedTraining;
  List<TrainingBooking> pendingForReminder = const <TrainingBooking>[];
  int remindersMarked = 0;

  @override
  Future<BookingCreateResult> createPendingBooking({
    required int userId,
    required TrainingInfo training,
  }) async {
    createCalls += 1;
    lastCreatedTraining = training;
    return BookingCreateResult(
      booking: _booking(
        id: 99,
        userId: userId,
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
  String title = 'Training',
  DateTime? startsAt,
  String location = 'Hall',
  BookingStatus status = BookingStatus.pendingPayment,
}) {
  final now = DateTime(2026, 1, 1, 10);
  return TrainingBooking(
    id: id,
    userId: userId,
    trainingKey: 'key-$id',
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
