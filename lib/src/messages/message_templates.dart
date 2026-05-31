import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:intl/intl.dart';

final class MessageTemplates {
  const MessageTemplates();

  static const String buttonTrainings = 'Расписание';
  static const String buttonBookTraining = 'Записаться';
  static const String buttonMyBookings = 'Мои записи';
  static const String buttonSubmitPayment = 'Я оплатил';
  static const String buttonHelp = 'Помощь';
  static const String buttonRefreshSchedule = 'Обновить расписание';
  static const String buttonPaymentsQueue = 'Заявки на оплату';

  String privateWelcome() {
    return 'Привет! Я бот спортивного объединения DVOR.\n\n'
        'Используйте кнопки внизу, чтобы быстро открыть расписание и справку.';
  }

  String privateHelp() {
    return 'Что умеет бот сейчас:\n'
        '• Показывает ближайшие тренировки\n'
        '• Записывает на ближайшую тренировку\n'
        '• Принимает отметку об оплате и отправляет админам\n'
        '• Обновляет расписание из внешнего источника\n'
        '• Помогает новым участникам в группе\n\n'
        'Если кнопки не отображаются, можно использовать команды:\n'
        '/trainings, /book, /my_bookings, /paid.';
  }

  String trainings(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return 'Пока нет запланированных тренировок. Скоро добавим новые даты.';
    }

    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Ближайшие тренировки DVOR:'];
    for (final item in items) {
      final coach = item.coach == null ? '' : '\nТренер: ${item.coach}';
      final notes = item.notes == null ? '' : '\nПримечание: ${item.notes}';
      lines.add(
        '\n• ${item.title}\n'
        'Когда: ${formatter.format(item.startsAt)}\n'
        'Где: ${item.location}$coach$notes',
      );
    }
    return lines.join('\n');
  }

  String clubInfoPrivate() {
    return 'Добро пожаловать в спортивное объединение DVOR!\n\n'
        'Здесь мы регулярно проводим тренировки, делимся расписанием и новостями клуба.\n'
        'Чтобы посмотреть ближайшие тренировки, отправьте команду /trainings.';
  }

  String groupFallback({required String? botUsername}) {
    final botLink = botUsername == null || botUsername.isEmpty
        ? 'Напишите боту в личку и нажмите Start.'
        : 'Откройте личку с ботом: https://t.me/$botUsername и нажмите Start.';
    return 'Не получилось отправить личное сообщение новому участнику. $botLink';
  }

  String scheduleRefreshDone() {
    return 'Расписание успешно обновлено.';
  }

  String scheduleRefreshFailed() {
    return 'Не удалось обновить расписание. Использую последнее сохраненное.';
  }

  String scheduleRefreshForbidden() {
    return 'Эта кнопка доступна только администраторам.';
  }

  String noUpcomingForBooking() {
    return 'Сейчас нет ближайших тренировок для записи.';
  }

  String bookingCreated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Запись создана. Статус: ${_statusLabel(booking.status)}.\n'
        'ID записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        'Когда: ${formatter.format(booking.startsAt)}\n'
        'Где: ${booking.location}\n\n'
        'После перевода нажмите кнопку `Я оплатил` или используйте /paid <комментарий>.';
  }

  String bookingAlreadyExists(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'У вас уже есть запись на эту тренировку.\n'
        'ID записи: ${booking.id}\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n'
        'Когда: ${formatter.format(booking.startsAt)}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return 'Отметка об оплате отправлена администратору.\n'
        'ID записи: ${booking.id}\n'
        'Статус: ${_statusLabel(booking.status)}.';
  }

  String noPendingPayment() {
    return 'Не нашел активной записи со статусом "Ожидает оплату".';
  }

  String myBookings(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'У вас пока нет записей на тренировки.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Ваши записи:'];
    for (final booking in bookings) {
      lines.add(
        '\n• #${booking.id} ${booking.trainingTitle}\n'
        'Когда: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status)}',
      );
    }
    return lines.join('\n');
  }

  String paymentsQueue(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'Очередь подтверждения оплат пуста.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Заявки на подтверждение оплаты:'];
    for (final booking in bookings) {
      final note = booking.paymentNote == null ? '' : '\nКомментарий: ${booking.paymentNote}';
      lines.add(
        '\n• #${booking.id} | user ${booking.userId}\n'
        '${booking.trainingTitle} (${formatter.format(booking.startsAt)})$note',
      );
    }
    lines.add(
      '\nПодтверждение: /approve_payment <id>\n'
      'Отклонение: /reject_payment <id>',
    );
    return lines.join('\n');
  }

  String adminOnlyAction() {
    return 'Действие доступно только администраторам.';
  }

  String paymentActionUsage() {
    return 'Использование:\n/approve_payment <id>\n/reject_payment <id>';
  }

  String bookingNotFound(int id) {
    return 'Запись #$id не найдена.';
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status)}.';
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
      BookingStatus.paymentSubmitted => 'Оплата на проверке',
      BookingStatus.paid => 'Оплачено',
      BookingStatus.paymentRejected => 'Оплата отклонена',
      BookingStatus.cancelled => 'Отменено',
    };
  }
}
