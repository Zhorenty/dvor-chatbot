import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:intl/intl.dart';

final class MessageTemplates {
  const MessageTemplates();

  static const String buttonTrainings = '📅 Расписание';
  static const String buttonBookTraining = '✍️ Записаться';
  static const String buttonMyBookings = '🗂 Мои записи';
  static const String buttonSubmitPayment = '💸 Я оплатил';
  static const String buttonBack = '⬅️ Назад';
  static const String buttonMainMenu = '🏠 Главное меню';
  static const String buttonHelp = '🆘 Помощь';
  static const String buttonRefreshSchedule = '🔄 Обновить расписание';
  static const String buttonPaymentsQueue = '🧾 Заявки на оплату';
  static const String buttonParticipantsList = '👥 Список записавшихся';
  static const String callbackApprovePaymentPrefix = 'payment:approve:';
  static const String callbackRejectPaymentPrefix = 'payment:reject:';
  static const String scheduleDocumentUrl =
      'https://docs.google.com/spreadsheets/d/1pA6XEjrAAgJT7rFVe86JdfHSl8NCPMJ4Wp7i9JN6a5Q/edit?gid=0#gid=0';

  String privateWelcome() {
    return 'Привет! 👋 Я бот спортивного объединения DVOR.\n\n'
        'Давай начнем: кнопки внизу помогут быстро открыть расписание, записаться и посмотреть справку 😉';
  }

  String privateHelp() {
    return 'Вот чем я могу помочь 👇\n'
        '• Показываю ближайшие тренировки, походы и трейлы 📅\n'
        '• Помогаю записаться на выбранную тренировку ✍️\n'
        '• Показываю твои записи и текущие статусы 🗂\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        'По остальным вопросам пиши в поддержку: @dvor_support 💬\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /my_bookings.';
  }

  String trainings(
    List<TrainingInfo> items, {
    List<OutdoorActivityInfo> outdoorActivities = const <OutdoorActivityInfo>[],
  }) {
    if (items.isEmpty && outdoorActivities.isEmpty) {
      return 'Пока в расписании нет активностей 😌 Скоро добавим новые даты!';
    }

    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final hasOutdoor = outdoorActivities.isNotEmpty;
    final lines = <String>[
      hasOutdoor ? 'Ближайшее расписание DVOR 💪' : 'Ближайшие тренировки DVOR 💪',
    ];

    if (items.isNotEmpty) {
      if (hasOutdoor) {
        lines.add('\nТренировки:');
      }
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final coach = item.coach?.trim();
        final notes = item.notes?.trim();

        lines.addAll(<String>[
          '',
          '• 🏋️ ${item.title}',
          '   🕒 Когда: ${dateTimeFormatter.format(item.startsAt)}',
          '   📍 Где: ${item.location}',
          if (item.price != null) '   💳 Взнос: ${_trainingPriceLabel(item.price)}',
          if (coach != null && coach.isNotEmpty) '   🧑‍🏫 Тренер: $coach',
          if (notes != null && notes.isNotEmpty) '   📝 Примечание: $notes',
        ]);

        if (index != items.length - 1) {
          lines.add('\n   ─────────────────');
        }
      }
    }

    final hikes = outdoorActivities.where((item) => item.type == OutdoorActivityType.hike).toList();
    final trails =
        outdoorActivities.where((item) => item.type == OutdoorActivityType.trail).toList();

    void appendOutdoorSection(
      String title,
      String icon,
      List<OutdoorActivityInfo> sectionItems,
    ) {
      if (sectionItems.isEmpty) {
        return;
      }
      lines.add('\n$title:');
      for (final item in sectionItems) {
        final isOneDay = item.dateFrom.year == item.dateTo.year &&
            item.dateFrom.month == item.dateTo.month &&
            item.dateFrom.day == item.dateTo.day;
        final dateLabel = isOneDay
            ? dateFormatter.format(item.dateFrom)
            : '${dateFormatter.format(item.dateFrom)} — ${dateFormatter.format(item.dateTo)}';
        lines.addAll(<String>[
          '',
          '• $icon ${item.title}',
          '   🗓 Даты: $dateLabel',
          '   📝 Описание: ${item.description}',
          if (item.price != null) '   💳 Стоимость: ${_trainingPriceLabel(item.price)}',
        ]);
      }
    }

    appendOutdoorSection('Походы', '🥾', hikes);
    appendOutdoorSection('Трейлы', '🏃', trails);

    return lines.join('\n');
  }

  String clubInfoPrivate() {
    return 'Добро пожаловать в спортивное объединение DVOR! 🎉\n\n'
        'Мы регулярно проводим тренировки, делимся расписанием и новостями клуба.\n'
        'Хочешь посмотреть ближайшие занятия? Отправь /trainings 👌';
  }

  String groupFallback({required String? botUsername}) {
    final botLink = botUsername == null || botUsername.isEmpty
        ? 'Напишите боту в личку и нажмите Start 🙌'
        : 'Откройте личку с ботом: https://t.me/$botUsername и нажмите Start 🙌';
    return 'Не удалось отправить личное сообщение новому участнику 😕 $botLink';
  }

  String scheduleRefreshDone() {
    return 'Готово! Расписание обновил ✅';
  }

  String scheduleRefreshFailed() {
    return 'Не получилось обновить расписание 😔 Использую последнюю сохраненную версию.';
  }

  String scheduleRefreshForbidden() {
    return 'Эта кнопка только для админов 🔒';
  }

  String scheduleDocumentLink() {
    return 'Актуальное расписание в Google Sheets:\n$scheduleDocumentUrl';
  }

  String noUpcomingForBooking() {
    return 'Пока нет ближайших тренировок для записи 😌';
  }

  String bookingCreated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
        '📍 Где: ${booking.location}\n\n'
        '${paymentDetailsSent(booking.id)}';
  }

  String bookingAlreadyExists(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Ты уже записан(а) на эту тренировку 👌\n'
        'Номер записи: ${booking.id}\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return 'Супер, файл с подтверждением оплаты отправил администратору ✅\n'
        'Номер записи: ${booking.id}\n'
        'Статус: ${_statusLabel(booking.status)}.';
  }

  String paymentSubmittedAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final note = booking.paymentNote?.trim();
    return 'Новое подтверждение оплаты 💸\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${booking.userId}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        'Когда: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status)}'
        '${note == null || note.isEmpty ? '' : '\nКомментарий: $note'}\n\n'
        'Проверь заявку и нажми кнопку ниже 👇';
  }

  String noPendingPayment() {
    return 'Не нашел активной записи со статусом "Ожидает оплату" 🤔';
  }

  String myBookings(
    List<TrainingBooking> bookings, {
    DateTime? now,
  }) {
    if (bookings.isEmpty) {
      return 'У тебя пока нет записей на тренировки 🙃';
    }

    final splitPoint = (now ?? DateTime.now()).toLocal();
    final upcoming = bookings.where((booking) => !booking.startsAt.isBefore(splitPoint)).toList();
    final past = bookings.where((booking) => booking.startsAt.isBefore(splitPoint)).toList();
    past.sort((left, right) => right.startsAt.compareTo(left.startsAt));

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Твои записи 🗂'];

    if (upcoming.isNotEmpty) {
      lines.add('\nАктуальные:');
      for (final booking in upcoming) {
        lines.add(
          '\n• #${booking.id} ${booking.trainingTitle}\n'
          '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
          'Статус: ${_statusLabel(booking.status)}',
        );
      }
    }

    if (past.isNotEmpty) {
      lines.add('\nПрошедшие:');
      for (final booking in past) {
        lines.add(
          '\n• #${booking.id} ${booking.trainingTitle}\n'
          '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
          'Статус: ${_statusLabel(booking.status)}',
        );
      }
    }
    return lines.join('\n');
  }

  String paymentsQueueEmpty() => 'Очередь подтверждения оплат пока пустая ✨';

  String paymentsQueueIntro(int total) {
    return 'Заявки на подтверждение оплаты 🧾\n'
        'Всего ожидают проверки: $total.\n'
        'Ниже отправил каждую заявку отдельным сообщением.';
  }

  String paymentsQueueItem(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final note = booking.paymentNote == null ? '' : '\nКомментарий: ${booking.paymentNote}';
    return 'Заявка #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 ${formatter.format(booking.startsAt)}\n'
        '📍 ${booking.location}'
        '$note\n\n'
        'Подтверди или отклони оплату кнопками ниже.';
  }

  String trainingParticipants({
    required List<TrainingInfo> trainings,
    required Map<String, List<TrainingBooking>> bookingsByTrainingKey,
  }) {
    if (trainings.isEmpty) {
      return 'Ближайших тренировок пока нет, показывать список не для чего.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Список записавшихся по тренировкам 👥'];
    for (var index = 0; index < trainings.length; index++) {
      final training = trainings[index];
      final tags = bookingsByTrainingKey[training.sessionKey] ?? const <TrainingBooking>[];
      lines.add(
        '\n${index + 1}. ${training.title}\n'
        '🕒 ${formatter.format(training.startsAt)}\n'
        '📍 ${training.location}',
      );
      if (tags.isEmpty) {
        lines.add('   — пока никто не записался');
      } else {
        for (final booking in tags) {
          lines.add(
            '   • ${_userTag(booking)} (${_statusLabel(booking.status)})',
          );
        }
      }
    }
    return lines.join('\n');
  }

  String adminOnlyAction() {
    return 'Это действие доступно только администраторам 🔒';
  }

  String paymentActionUsage() {
    return 'Использование:\n/approve_payment <id>\n/reject_payment <id>\n\n'
        'Например: /approve_payment 42';
  }

  Map<String, Object?> paymentDecisionInlineKeyboard(int bookingId) {
    return <String, Object?>{
      'inline_keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{
            'text': '✅ Подтвердить',
            'callback_data': '$callbackApprovePaymentPrefix$bookingId',
          },
          <String, String>{
            'text': '❌ Отклонить',
            'callback_data': '$callbackRejectPaymentPrefix$bookingId',
          },
        ],
      ],
    };
  }

  String bookingNotFound(int id) {
    return 'Запись #$id не найдена 😕';
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status)} ✅';
  }

  String paymentInstructions(int bookingId) {
    return 'Реквизиты для оплаты:\n'
        '• Получатель: Родион Одобеско\n'
        '• Банк: OZON БАНК\n'
        '• Номер телефона: +7 (918) 423-01-03\n'
        '• Комментарий к переводу: "Номер записи: $bookingId"';
  }

  String paymentApprovedForUser(TrainingBooking booking) {
    return 'Оплату по записи #${booking.id} подтвердили ✅\n'
        'Статус: ${_statusLabel(booking.status)}.\n'
        'Спасибо!';
  }

  String paymentRejectedForUser(TrainingBooking booking) {
    return 'Оплату по записи #${booking.id} отклонили ❌\n'
        'Статус: ${_statusLabel(booking.status)}.\n'
        'Проверь детали платежа и отправь подтверждение еще раз.';
  }

  String paymentReviewAdminNotification({
    required TrainingBooking booking,
    required int moderatorUserId,
  }) {
    return 'Модерация оплаты выполнена 🧾\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${booking.userId}\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'Проверил админ: $moderatorUserId';
  }

  String pendingPaymentReminder(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Напоминание об оплате 💸\n'
        'Запись: #${booking.id}\n'
        '${booking.trainingTitle} (${formatter.format(booking.startsAt)})\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n\n'
        '${paymentInstructions(booking.id)}\n\n'
        'После оплаты отправь в этот чат файл с подтверждением (чек/скрин).';
  }

  String chooseTrainingForBooking(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return noUpcomingForBooking();
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Выбери тренировку для записи 👇'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final feeLabel = item.price == null ? '' : ', взнос: ${_trainingPriceLabel(item.price)}';
      lines.add(
        '${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} (${item.location}$feeLabel)',
      );
    }
    return lines.join('\n');
  }

  String paymentDetailsSent(int bookingId) {
    return '${paymentInstructions(bookingId)}\n\n'
        'Когда переведешь оплату, отправь в этот чат файл с подтверждением (чек/скрин) 📎\n'
        'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.';
  }

  String paymentProofRequired() {
    return 'Чтобы отправить заявку администратору, пришли файл с подтверждением оплаты '
        '(документ или фото чека).';
  }

  Map<String, Object?> privateMenuKeyboard({required bool isAdmin}) {
    if (isAdmin) {
      return <String, Object?>{
        'keyboard': <List<Map<String, String>>>[
          <Map<String, String>>[
            <String, String>{'text': buttonRefreshSchedule},
            <String, String>{'text': buttonPaymentsQueue},
          ],
          <Map<String, String>>[
            <String, String>{'text': buttonParticipantsList},
          ],
        ],
        'resize_keyboard': true,
        'one_time_keyboard': false,
      };
    }

    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{'text': buttonTrainings},
        <String, String>{'text': buttonBookTraining},
      ],
      <Map<String, String>>[
        <String, String>{'text': buttonMyBookings},
      ],
      <Map<String, String>>[
        <String, String>{'text': buttonHelp},
      ],
    ];
    return <String, Object?>{
      'keyboard': rows,
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
  }

  Map<String, Object?> bookingSelectionKeyboard(List<TrainingInfo> items) {
    final rows = <List<Map<String, String>>>[];
    for (var index = 0; index < items.length; index++) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': '🎯 ${index + 1}. ${items[index].title}'},
        ],
      );
    }
    rows.add(
      <Map<String, String>>[
        <String, String>{'text': buttonBack},
        <String, String>{'text': buttonMainMenu},
      ],
    );
    return <String, Object?>{
      'keyboard': rows,
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
  }

  Map<String, Object?> paymentConfirmationKeyboard() {
    return <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': buttonBack},
          <String, String>{'text': buttonMainMenu},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': false,
    };
  }

  String _statusLabel(BookingStatus status) {
    return switch (status) {
      BookingStatus.pendingPayment => 'Ожидает оплату',
      BookingStatus.paymentSubmitted => 'Оплата на проверке 👀',
      BookingStatus.paid => 'Оплачено ✅',
      BookingStatus.paymentRejected => 'Оплата отклонена ❌',
      BookingStatus.cancelled => 'Отменено',
    };
  }

  String _userTag(TrainingBooking booking) {
    final username = booking.userUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return '@${username.startsWith('@') ? username.substring(1) : username}';
    }
    return 'tg://user?id=${booking.userId}';
  }

  String _trainingPriceLabel(int? price) {
    if (price == null || price <= 0) {
      return 'бесплатная';
    }
    return '$price ₽';
  }
}
