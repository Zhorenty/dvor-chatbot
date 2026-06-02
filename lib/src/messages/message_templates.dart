import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/keyboards/telegram_keyboards.dart';
import 'package:intl/intl.dart';

final class MessageTemplates {
  const MessageTemplates();

  static const String buttonTrainings = MessageCopy.buttonTrainings;
  static const String buttonBookTraining = MessageCopy.buttonBookTraining;
  static const String buttonMyBookings = MessageCopy.buttonMyBookings;
  static const String buttonSubmitPayment = MessageCopy.buttonSubmitPayment;
  static const String buttonUseStarterBonus = MessageCopy.buttonUseStarterBonus;
  static const String buttonBack = MessageCopy.buttonBack;
  static const String buttonMainMenu = MessageCopy.buttonMainMenu;
  static const String buttonHelp = MessageCopy.buttonHelp;
  static const String buttonCategoryTrainings = MessageCopy.buttonCategoryTrainings;
  static const String buttonCategoryHikes = MessageCopy.buttonCategoryHikes;
  static const String buttonCategoryTrails = MessageCopy.buttonCategoryTrails;
  static const String buttonRefreshSchedule = MessageCopy.buttonRefreshSchedule;
  static const String buttonPaymentsQueue = MessageCopy.buttonPaymentsQueue;
  static const String buttonParticipantsList = MessageCopy.buttonParticipantsList;
  static const String buttonNoblesList = MessageCopy.buttonNoblesList;
  static const String callbackApprovePaymentPrefix = MessageCopy.callbackApprovePaymentPrefix;
  static const String callbackRejectPaymentPrefix = MessageCopy.callbackRejectPaymentPrefix;
  static const String callbackOpenPaymentsQueue = MessageCopy.callbackOpenPaymentsQueue;
  static const String scheduleDocumentUrl = MessageCopy.scheduleDocumentUrl;

  String privateWelcome() {
    return 'Привет! 👋 Я бот спортивного объединения DVOR.\n\n'
        'Давай начнем: кнопки внизу помогут быстро открыть расписание, записаться и посмотреть справку 😉';
  }

  String starterBonusOnboardingOffer() {
    return '🎁 Тебе доступна бесплатная тренировка за старт!\n\n'
        'Нажми «${MessageCopy.buttonBookTraining}», выбери тренировку и в подтверждении записи '
        'используй кнопку «${MessageCopy.buttonUseStarterBonus}».';
  }

  String privateHelp() {
    return 'Вот чем я могу помочь 👇\n'
        '• Показываю ближайшие тренировки, походы и трейлы 📅\n'
        '• Помогаю записаться на выбранное мероприятие ✍️\n'
        '• Показываю твои записи и текущие статусы 🗂\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        'По остальным вопросам пиши в поддержку: @dvor_support 💬\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /my_bookings.';
  }

  String privateFallback() {
    return 'Пока не понял сообщение 🤔\n'
        'Используй кнопки меню ниже или нажми «${MessageCopy.buttonHelp}», '
        'чтобы посмотреть доступные действия.';
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
        if (item.price != null) '   💳 Взнос: ${_trainingPriceLabel(item.price)}',
        if (coach != null && coach.isNotEmpty) '   🧑‍🏫 Тренер: $coach',
        if (notes != null && notes.isNotEmpty) '   📝 Примечание: $notes',
      ]);

      if (index != items.length - 1) {
        lines.add('\n-----');
      }
    }
    return lines.join('\n');
  }

  String hikes(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие походы DVOR 🥾',
      icon: '🥾',
      items: items,
      emptyText: 'Пока походов в расписании нет 😌',
    );
  }

  String trails(List<OutdoorActivityInfo> items) {
    return _outdoorActivitiesList(
      title: 'Ближайшие трейлы DVOR 🏃',
      icon: '🏃',
      items: items,
      emptyText: 'Пока трейлов в расписании нет 😌',
    );
  }

  String chooseScheduleCategory() {
    return 'Выбери раздел расписания 👇';
  }

  String chooseBookingCategory() {
    return 'Выбери категорию для записи 👇';
  }

  String unknownCategory() {
    return 'Не понял категорию. Нажми одну из кнопок ниже 👇';
  }

  String chooseParticipantsCategory() {
    return 'Выбери категорию для списка записавшихся 👇';
  }

  String choosePaymentsQueueCategory() {
    return 'Выбери категорию для заявок на оплату 👇';
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

  String groupWelcome({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final mention = _groupMention(username: username, userId: userId, firstName: firstName);
    return 'Привет, $mention! 🏃\n'
        'Ты уже в игре!\n'
        'Переходи в бота «Двор» — там твой первый шаг к победе и подарок за старт. '
        'Вперёд, чемпион! 🏆';
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
    return 'Пока нет ближайших мероприятий для записи 😌';
  }

  String bookingCreated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
        '📍 Где: ${booking.location}\n\n'
        '${paymentDetailsSent(booking)}';
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

  String paymentSubmittedAdminNotification() {
    return 'Новое подтверждение оплаты 💸\n\n'
        'Пришла новая заявка на проверку оплаты.\n'
        'Нажми кнопку ниже, чтобы открыть очередь заявок 👇';
  }

  String starterBonusApplied(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Готово! Бесплатная тренировка активирована 🎁\n'
        'Запись: #${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status)}';
  }

  String starterBonusUnavailable() {
    return 'Стартовый бонус уже недоступен. Продолжай запись по стандартному сценарию оплаты 💪';
  }

  String starterBonusAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Стартовая бесплатная запись 🎁\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Тренировка: ${booking.trainingTitle}\n'
        'Когда: ${formatter.format(booking.startsAt)}\n'
        'Формат: бесплатная тренировка за старт';
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

    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final lines = <String>['Твои записи 🗂'];

    if (upcoming.isNotEmpty) {
      lines.add('\nАктуальные:');
      for (final booking in upcoming) {
        lines.add(
          '\n• #${booking.id} ${booking.trainingTitle}\n'
          '🕒 Когда: ${_myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
          'Статус: ${_statusLabel(booking.status)}',
        );
      }
    }

    if (past.isNotEmpty) {
      lines.add('\nПрошедшие:');
      for (final booking in past) {
        lines.add(
          '\n• #${booking.id} ${booking.trainingTitle}\n'
          '🕒 Когда: ${_myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
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
    String title = 'Список записавшихся по тренировкам 👥',
    String emptyText = 'Ближайших тренировок пока нет, показывать список не для чего.',
  }) {
    if (trainings.isEmpty) {
      return emptyText;
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[title];
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

  String noblesList(
    List<({int userId, String? username, int trainingsCount})> users, {
    int totalTrainings = 0,
  }) {
    if (users.isEmpty) {
      return 'Пока нет данных по записям, список дворян пуст.';
    }
    final lines = <String>[
      'Список дворян 🏰',
      'Всего записей на тренировки: $totalTrainings',
      '',
    ];
    for (var index = 0; index < users.length; index++) {
      final user = users[index];
      lines.add(
        '${index + 1}. ${_userTagById(user.userId, username: user.username)} (${user.userId}) — '
        '${user.trainingsCount}',
      );
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
    return TelegramKeyboards.paymentDecisionInlineKeyboard(bookingId);
  }

  Map<String, Object?> openPaymentsQueueInlineKeyboard() {
    return TelegramKeyboards.openPaymentsQueueInlineKeyboard();
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
        '• Банк: 🟦 OZON БАНК 🟦\n'
        '• Номер телефона: +7(918)423-01-03\n'
        '• Комментарий к переводу: "Номер записи: $bookingId"';
  }

  String paymentApprovedForUser(TrainingBooking booking) {
    if (!_isOutdoorBookingTitle(booking.trainingTitle)) {
      return 'Оплату по записи #${booking.id} подтвердили ✅\n'
          'Статус: ${_statusLabel(booking.status)}.\n'
          'Спасибо!';
    }

    return '✅ Оплата подтверждена.\n'
        'Ты в команде outdvor🚸\n\n'
        'Место за тобой, предоплата зафиксирована. С этого момента - ты часть команды.\n\n'
        'Мы сделаем все, чтобы это приключение осталось с тобой надолго. '
        'Горы, эмоции, новые люди и чувство "я справился" - это не забывается.\n'
        'Скоро добавим тебя в общий чат поездки🟡\n\n'
        'Готовься. Скоро стартуем 💚';
  }

  String paymentRejectedForUser(TrainingBooking booking) {
    return 'Оплату по записи #${booking.id} отклонили ❌\n'
        'Статус: ${_statusLabel(booking.status)}.\n'
        'Проверь детали платежа и отправь подтверждение еще раз.';
  }

  String paymentReviewAdminNotification({
    required TrainingBooking booking,
    required int moderatorUserId,
    String? moderatorUsername,
  }) {
    return 'Модерация оплаты выполнена 🧾\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'Проверил админ: ${_userTagById(moderatorUserId, username: moderatorUsername)} ($moderatorUserId)';
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
    final lines = <String>['Выбери мероприятие для записи 👇'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final feeLabel = item.price == null ? '' : ', взнос: ${_trainingPriceLabel(item.price)}';
      lines.add(
        '${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} (${item.location}$feeLabel)',
      );
    }
    return lines.join('\n');
  }

  String paymentDetailsSent(TrainingBooking booking) {
    if (!_isOutdoorBookingTitle(booking.trainingTitle)) {
      return '${paymentInstructions(booking.id)}\n\n'
          'Когда переведешь оплату, отправь в этот чат файл с подтверждением (чек/скрин) 📎\n\n'
          'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.';
    }

    return '${paymentInstructions(booking.id)}\n\n'
        'Правило Outdvor 🚸\n\n'
        '• Предоплата невозвратна при отмене за 7 дней и менее до трейла/похода🦥\n\n'
        'Это не штраф, а уважение к общим расходам на логистику, планирование '
        'тренировки и трансфер. Такие мероприятия любят сильных и решительных. Спасибо за понимание. 💚💪\n'
        '\n\n'
        'Когда переведешь оплату, отправь в этот чат файл с подтверждением (чек/скрин) 📎\n\n'
        'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.';
  }

  bool _isOutdoorBookingTitle(String title) {
    final normalized = title.toLowerCase();
    return normalized.contains('поход') || normalized.contains('трейл');
  }

  String paymentProofRequired() {
    return 'Чтобы отправить заявку администратору, пришли файл с подтверждением оплаты '
        '(документ или фото чека).';
  }

  Map<String, Object?> privateMenuKeyboard({required bool isAdmin}) {
    return TelegramKeyboards.privateMenuKeyboard(isAdmin: isAdmin);
  }

  Map<String, Object?> bookingSelectionKeyboard(List<TrainingInfo> items) {
    return TelegramKeyboards.bookingSelectionKeyboard(items);
  }

  Map<String, Object?> categorySelectionKeyboard() {
    return TelegramKeyboards.categorySelectionKeyboard();
  }

  Map<String, Object?> paymentConfirmationKeyboard({
    required bool showStarterBonus,
  }) {
    return TelegramKeyboards.paymentConfirmationKeyboard(showStarterBonus: showStarterBonus);
  }

  String _groupMention({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    final normalizedUsername = username?.trim();
    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      return normalizedUsername.startsWith('@') ? normalizedUsername : '@$normalizedUsername';
    }
    final normalizedFirstName = firstName?.trim();
    if (normalizedFirstName != null && normalizedFirstName.isNotEmpty) {
      return normalizedFirstName;
    }
    return 'tg://user?id=$userId';
  }

  String _statusLabel(BookingStatus status) {
    return MessageFormatters.statusLabel(status);
  }

  String _userTag(TrainingBooking booking) {
    return MessageFormatters.userTag(booking);
  }

  String _userTagById(int userId, {String? username}) {
    return MessageFormatters.userTagById(userId, username: username);
  }

  String _trainingPriceLabel(int? price) {
    return MessageFormatters.trainingPriceLabel(price);
  }

  String _myBookingDateLabel(
    TrainingBooking booking,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    return MessageFormatters.bookingDateLabel(
      booking,
      dateTimeFormatter,
      dateOnlyFormatter,
    );
  }

  String _outdoorActivitiesList({
    required String title,
    required String icon,
    required List<OutdoorActivityInfo> items,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return emptyText;
    }
    final lines = <String>[title];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final dateLabel = MessageFormatters.outdoorDateLabel(item.dateFrom, item.dateTo);
      lines.addAll(<String>[
        '',
        '• $icon ${item.title}',
        '   🗓 Даты: $dateLabel',
        '   📝 Описание: ${item.description}',
        if (item.price != null) '   💳 Стоимость: ${_trainingPriceLabel(item.price)}',
      ]);
      if (index != items.length - 1) {
        lines.add('\n-----');
      }
    }
    return lines.join('\n');
  }
}
