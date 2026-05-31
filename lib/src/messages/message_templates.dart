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
  static const String buttonHelp = '🆘 Помощь';
  static const String buttonRefreshSchedule = '🔄 Обновить расписание';
  static const String buttonPaymentsQueue = '🧾 Заявки на оплату';

  String privateWelcome() {
    return 'Привет! 👋 Я бот спортивного объединения DVOR.\n\n'
        'Давай начнем: кнопки внизу помогут быстро открыть расписание, записаться и посмотреть справку 😉';
  }

  String privateHelp() {
    return 'Вот что я умею прямо сейчас 👇\n'
        '• Показываю ближайшие тренировки 📅\n'
        '• Записываю на ближайшую тренировку ✍️\n'
        '• Принимаю отметку об оплате и отправляю админам 💸\n'
        '• Обновляю расписание из внешнего источника 🔄\n'
        '• Помогаю новичкам в группе 🙌\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /my_bookings, /paid.';
  }

  String trainings(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return 'Пока тренировок в расписании нет 😌 Скоро добавим новые даты!';
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Ближайшие тренировки DVOR 💪'];
    for (final item in items) {
      final coach = item.coach == null ? '' : '\nТренер: ${item.coach}';
      final notes = item.notes == null ? '' : '\nПримечание: ${item.notes}';
      lines.add(
        '\n• ${item.title}\n'
        '🕒 Когда: ${formatter.format(item.startsAt)}\n'
        '📍 Где: ${item.location}$coach$notes',
      );
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
        'После перевода нажми кнопку `$buttonSubmitPayment` или используй /paid <комментарий>.';
  }

  String bookingAlreadyExists(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Ты уже записан(а) на эту тренировку 👌\n'
        'ID записи: ${booking.id}\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return 'Супер, отметку об оплате отправил администратору ✅\n'
        'ID записи: ${booking.id}\n'
        'Статус: ${_statusLabel(booking.status)}.';
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
    lines.add(
      '\nПодтвердить: /approve_payment <id>\n'
      'Отклонить: /reject_payment <id>',
    );
    return lines.join('\n');
  }

  String adminOnlyAction() {
    return 'Это действие доступно только администраторам 🔒';
  }

  String paymentActionUsage() {
    return 'Использование:\n/approve_payment <id>\n/reject_payment <id>\n\n'
        'Например: /approve_payment 42';
  }

  String bookingNotFound(int id) {
    return 'Запись #$id не найдена 😕';
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status)} ✅';
  }

  Map<String, Object?> privateMenuKeyboard({required bool isAdmin}) {
    final rows = <List<Map<String, String>>>[
      <Map<String, String>>[
        <String, String>{'text': buttonTrainings},
        <String, String>{'text': buttonBookTraining},
      ],
      <Map<String, String>>[
        <String, String>{'text': buttonMyBookings},
        <String, String>{'text': buttonSubmitPayment},
      ],
      <Map<String, String>>[
        <String, String>{'text': buttonHelp},
      ],
    ];
    if (isAdmin) {
      rows.add(
        <Map<String, String>>[
          <String, String>{'text': buttonRefreshSchedule},
          <String, String>{'text': buttonPaymentsQueue},
        ],
      );
    }
    return <String, Object?>{
      'keyboard': rows,
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
}
