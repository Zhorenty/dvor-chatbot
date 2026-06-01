import 'package:dvor_chatbot/src/domain/booking_status.dart';
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

  String privateWelcome() {
    return 'Привет! 👋 Я бот спортивного объединения DVOR.\n\n'
        'Давай начнем: кнопки внизу помогут быстро открыть расписание, записаться и посмотреть справку 😉';
  }

  String privateHelp() {
    return 'Вот чем я могу помочь 👇\n'
        '• Показываю ближайшие тренировки с датой, временем и местом 📅\n'
        '• Помогаю записаться на выбранную тренировку ✍️\n'
        '• Показываю твои записи и текущие статусы 🗂\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /my_bookings.';
  }

  String trainings(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return 'Пока тренировок в расписании нет 😌 Скоро добавим новые даты!';
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Ближайшие тренировки DVOR 💪'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final coach = item.coach?.trim();
      final notes = item.notes?.trim();

      lines.addAll(<String>[
        '',
        '• 🏋️ ${item.title}',
        '   🕒 Когда: ${formatter.format(item.startsAt)}',
        '   📍 Где: ${item.location}',
        if (coach != null && coach.isNotEmpty) '   🧑‍🏫 Тренер: $coach',
        if (notes != null && notes.isNotEmpty) '   📝 Примечание: $notes',
      ]);

      if (index != items.length - 1) {
        lines.add('\n   ─────────────────');
      }
    }
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

  String noUpcomingForBooking() {
    return 'Пока нет ближайших тренировок для записи 😌';
  }

  String bookingCreated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'ID записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
        '📍 Где: ${booking.location}\n\n'
        '${paymentDetailsSent()}';
  }

  String bookingAlreadyExists(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Ты уже записан(а) на эту тренировку 👌\n'
        'ID записи: ${booking.id}\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return 'Супер, файл с подтверждением оплаты отправил администратору ✅\n'
        'ID записи: ${booking.id}\n'
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

  String myBookings(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'У тебя пока нет записей на тренировки 🙃';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Твои записи 🗂'];
    for (final booking in bookings) {
      lines.add(
        '\n• #${booking.id} ${booking.trainingTitle}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status)}',
      );
    }
    return lines.join('\n');
  }

  String paymentsQueue(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'Очередь подтверждения оплат пока пустая ✨';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Заявки на подтверждение оплаты 🧾'];
    for (final booking in bookings) {
      final note = booking.paymentNote == null ? '' : '\nКомментарий: ${booking.paymentNote}';
      lines.add(
        '\n• #${booking.id} | user ${booking.userId}\n'
        '${booking.trainingTitle} (${formatter.format(booking.startsAt)})$note',
      );
    }
    lines.add('\nНажми кнопку под заявкой, чтобы подтвердить или отклонить оплату.');
    return lines.join('\n');
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
            'text': '✅ Подтвердить #$bookingId',
            'callback_data': '$callbackApprovePaymentPrefix$bookingId',
          },
          <String, String>{
            'text': '❌ Отклонить #$bookingId',
            'callback_data': '$callbackRejectPaymentPrefix$bookingId',
          },
        ],
      ],
    };
  }

  Map<String, Object?> paymentsQueueInlineKeyboard(List<TrainingBooking> bookings) {
    final rows = <List<Map<String, String>>>[];
    for (final booking in bookings) {
      rows.add(
        <Map<String, String>>[
          <String, String>{
            'text': '✅ #${booking.id}',
            'callback_data': '$callbackApprovePaymentPrefix${booking.id}',
          },
          <String, String>{
            'text': '❌ #${booking.id}',
            'callback_data': '$callbackRejectPaymentPrefix${booking.id}',
          },
        ],
      );
    }
    return <String, Object?>{'inline_keyboard': rows};
  }

  String bookingNotFound(int id) {
    return 'Запись #$id не найдена 😕';
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status)} ✅';
  }

  String paymentInstructions() {
    return 'Реквизиты для оплаты:\n'
        '• Получатель: DVOR CLUB\n'
        '• Банк: DVOR BANK\n'
        '• Номер карты: 0000 1111 2222 3333\n'
        '• Комментарий к переводу: ID записи';
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
        '${paymentInstructions()}\n\n'
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
      lines.add(
        '${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} (${item.location})',
      );
    }
    return lines.join('\n');
  }

  String paymentDetailsSent() {
    return '${paymentInstructions()}\n\n'
        'Когда переведешь оплату, отправь в этот чат файл с подтверждением (чек/скрин).';
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
}
