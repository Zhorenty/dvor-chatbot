import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/trainer_info.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/keyboards/telegram_keyboards.dart';
import 'package:intl/intl.dart';

final class MessageTemplates {
  const MessageTemplates({
    String? botUsername,
  }) : _botUsername = botUsername;

  final String? _botUsername;

  static const String buttonTrainings = MessageCopy.buttonTrainings;
  static const String buttonCoachingStaff = MessageCopy.buttonCoachingStaff;
  static const String buttonBookTraining = MessageCopy.buttonBookTraining;
  static const String buttonMyBookings = MessageCopy.buttonMyBookings;
  static const String buttonSubmitPayment = MessageCopy.buttonSubmitPayment;
  static const String buttonUseStarterBonus = MessageCopy.buttonUseStarterBonus;
  static const String buttonRescheduleBooking = MessageCopy.buttonRescheduleBooking;
  static const String buttonCancelBooking = MessageCopy.buttonCancelBooking;
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
  static const String buttonManageBookings = MessageCopy.buttonManageBookings;
  static const String buttonBookingsList = MessageCopy.buttonBookingsList;
  static const String buttonCreateBooking = MessageCopy.buttonCreateBooking;
  static const String buttonActiveBookings = MessageCopy.buttonActiveBookings;
  static const String buttonArchivedBookings = MessageCopy.buttonArchivedBookings;
  static const String buttonEditBooking = MessageCopy.buttonEditBooking;
  static const String buttonDeleteBooking = MessageCopy.buttonDeleteBooking;
  static const String buttonRestoreBooking = MessageCopy.buttonRestoreBooking;
  static const String buttonEditBookingPayment = MessageCopy.buttonEditBookingPayment;
  static const String buttonEditBookingUsername = MessageCopy.buttonEditBookingUsername;
  static const String buttonEditBookingEvent = MessageCopy.buttonEditBookingEvent;
  static const String buttonConfirmDeleteBooking = MessageCopy.buttonConfirmDeleteBooking;
  static const String buttonCancelDeleteBooking = MessageCopy.buttonCancelDeleteBooking;
  static const String buttonBackToBookingsList = MessageCopy.buttonBackToBookingsList;
  static const String buttonCreateAnotherBooking = MessageCopy.buttonCreateAnotherBooking;
  static const String buttonConfirmCreateBooking = MessageCopy.buttonConfirmCreateBooking;
  static const String buttonCancelCreateBooking = MessageCopy.buttonCancelCreateBooking;
  static const String buttonStatusPendingPayment = MessageCopy.buttonStatusPendingPayment;
  static const String buttonStatusPaymentSubmitted = MessageCopy.buttonStatusPaymentSubmitted;
  static const String buttonStatusPaid = MessageCopy.buttonStatusPaid;
  static const String buttonStatusPaymentRejected = MessageCopy.buttonStatusPaymentRejected;
  static const String callbackApprovePaymentPrefix = MessageCopy.callbackApprovePaymentPrefix;
  static const String callbackRejectPaymentPrefix = MessageCopy.callbackRejectPaymentPrefix;
  static const String callbackOpenPaymentsQueue = MessageCopy.callbackOpenPaymentsQueue;
  static const String scheduleDocumentUrl = MessageCopy.scheduleDocumentUrl;

  String privateWelcome() {
    return 'Здесь мы тренируемся, растем и кайфуем от бега вместе 💛\n'
        'Поддержка, дисциплина и движение вперед - наша база.\n\n'
        '✅ Основные принципы\n'
        '• Уважение к каждому\n'
        '• Поддержка вместо хейта\n'
        '• Дисциплина = результат\n'
        '• Становимся сильнее и быстрее\n'
        '• Новички и опытные - на равных\n\n'
        '⛔ Внутренние правила\n'
        '• Без мата (или +15 приседаний 😄)\n'
        '• Без токсичности и оскорблений\n'
        '• Без политики и срач-тем\n'
        '• Не опаздываем и не сливаемся\n'
        '• Уважаем формат тренировок\n'
        '• Реклама только через админов\n\n'
        '🌙 Дополнительно\n'
        '• После 00:00 не пишем 💤\n'
        '• Все анонсы через админов\n'
        '• Важная инфа в закрепе 📌\n\n'
        '⛰ Активности\n'
        '• Совместные пробежки\n'
        '• Интервалы / темп / ОФП\n'
        '• Походы и трейлы\n\n'
        '📌 Как пользоваться чатом\n'
        '💬 # БОЛТАЛКА ДВОР 🤼‍♂️ - общение, пробежки, фото/видео, сборы на тренировки\n'
        '📋 ВОПРОСЫ ПО КИПЕ - вопросы по экипировке, ответит тренер\n'
        '📰 АФИШИ ТРЕНЯ - официальная информация\n'
        '🏕 АФИШИ ПОХОДЫ - официальная информация (анонсы публикует администрация)\n\n'
        '💛 Главное\n'
        'Это не просто чат - это команда.\n'
        'Каждая тренировка делает тебя сильнее.\n'
        '\n'
        'Добро пожаловать 🤝';
  }

  String starterBonusOnboardingOffer() {
    return '🎁 Тебе доступна бесплатная тренировка за старт!\n\n'
        'Нажми «${MessageCopy.buttonBookTraining}», выбери тренировку и в подтверждении записи '
        'используй кнопку «${MessageCopy.buttonUseStarterBonus}».';
  }

  String privateHelp() {
    return 'Вот чем я могу помочь 👇\n'
        '• Показываю ближайшие тренировки, походы и трейлы 📅\n'
        '• Показываю список тренеров и контакты штаба 🧑‍🏫\n'
        '• Помогаю записаться на выбранное мероприятие ✍️\n'
        '• Показываю твои записи и текущие статусы 🗂\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        'По остальным вопросам пиши в поддержку: @dvor_support 💬\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /my_bookings, /coaches.';
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

  String coachingStaff(List<TrainerInfo> trainers) {
    if (trainers.isEmpty) {
      return 'Список тренеров пока пуст. Попробуй чуть позже 🙏';
    }
    final lines = <String>['Тренерский штаб DVOR 🧑‍🏫'];
    for (var index = 0; index < trainers.length; index++) {
      final trainer = trainers[index];
      lines.addAll(<String>[
        '',
        '${index + 1}. ${trainer.name}',
        '   🔗 ${trainer.link}',
        '   📝 ${trainer.description}',
      ]);
    }
    return lines.join('\n');
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

  String chooseBookingManagementAction() {
    return 'Управление записями: выбери действие 👇';
  }

  String chooseBookingListSegment() {
    return 'Какой список открыть? 👇';
  }

  String chooseBookingManagementCategory() {
    return 'Выбери категорию мероприятий для управления 👇';
  }

  String chooseAdminBookingFromList(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'Список пуст для выбранных фильтров.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Выбери запись 👇'];
    for (final booking in bookings) {
      final username = _userTag(booking);
      lines.add(
        '#${booking.id} | $username | ${_statusLabel(booking.status)} | ${formatter.format(booking.startsAt)}',
      );
    }
    return lines.join('\n');
  }

  String adminBookingActions(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Запись #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Событие: ${booking.trainingTitle}\n'
        'Дата: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status)}\n\n'
        'Выбери действие 👇';
  }

  String chooseAdminBookingEditField(TrainingBooking booking) {
    return 'Что изменить в записи #${booking.id}?';
  }

  String chooseAdminBookingPaymentStatus(TrainingBooking booking) {
    return 'Выбери новый статус оплаты для записи #${booking.id} 👇';
  }

  String adminBookingAskUsername(TrainingBooking booking) {
    return 'Отправь username пользователя для записи #${booking.id} '
        '(можно с @ или без).';
  }

  String adminBookingUsernameUpdated(TrainingBooking booking) {
    return 'Готово. Пользователь для записи #${booking.id}: ${_userTag(booking)}';
  }

  String adminBookingEventUpdated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Событие для записи #${booking.id} обновлено ✅\n'
        '${booking.trainingTitle}\n'
        '${formatter.format(booking.startsAt)}';
  }

  String adminBookingPaymentStatusUpdated(TrainingBooking booking) {
    return 'Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status)} ✅';
  }

  String adminBookingDeleteConfirm(TrainingBooking booking) {
    return 'Удалить запись #${booking.id}? '
        'Запись перейдет в архив со статусом «Отменена».';
  }

  String adminBookingDeleted(TrainingBooking booking) {
    return 'Запись #${booking.id} переведена в архив ✅';
  }

  String adminBookingRestored(TrainingBooking booking) {
    return 'Запись #${booking.id} восстановлена ✅';
  }

  String adminBookingRestoreNotAllowed(TrainingBooking booking) {
    return 'Запись #${booking.id} нельзя восстановить: мероприятие уже прошло.';
  }

  String chooseCreateBookingCategory() {
    return 'Создание записи: выбери категорию 👇';
  }

  String chooseCreateBookingEvent(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return 'В выбранной категории нет доступных мероприятий для записи.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['Выбери мероприятие для новой записи 👇'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      lines.add(
          '${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} (${item.location})');
    }
    return lines.join('\n');
  }

  String createBookingAskUsername() {
    return 'Введи username пользователя для новой записи '
        '(можно с @ или без).';
  }

  String chooseCreateBookingPaymentStatus() {
    return 'Выбери стартовый статус оплаты 👇';
  }

  String createBookingPreview({
    required TrainingInfo training,
    required String username,
    required BookingStatus status,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Проверь данные новой записи:\n'
        'Пользователь: @$username\n'
        'Событие: ${training.title}\n'
        'Дата: ${formatter.format(training.startsAt)}\n'
        'Локация: ${training.location}\n'
        'Статус: ${_statusLabel(status)}';
  }

  String adminBookingCreated(TrainingBooking booking) {
    return 'Запись #${booking.id} создана ✅';
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
    final botLink = _botDeepLink();
    final botPrompt = botLink == null
        ? '🤖 Чат с ботом: напиши боту в личку и нажми Start'
        : '🤖 Чат с ботом: <a href="$botLink">нажми, чтобы открыть</a>';
    return 'Привет, $mention! 🏃\n'
        'Ты уже в игре!\n'
        'Переходи в бота «Двор» - там твой первый шаг к победе и подарок за старт.\n'
        '$botPrompt\n'
        'Вперёд, чемпион! 🏆';
  }

  String? _botDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=start';
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
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${booking.location}\n\n'
        '${paymentDetailsSent(booking)}';
  }

  String bookingCreatedWithoutPayment(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${booking.location}\n\n'
        'Это бесплатная тренировка, подтверждение оплаты не нужно.';
  }

  String bookingAlreadyExists(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Ты уже записан(а) на эту тренировку 👌\n'
        'Номер записи: ${booking.id}\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return 'Супер, файл с подтверждением оплаты отправил администратору ✅\n'
        'Номер записи: ${booking.id}\n'
        'Статус: ${_statusLabel(booking.status)}.';
  }

  String paymentSubmittedAdminNotification(TrainingBooking booking) {
    return 'Новое подтверждение оплаты 💸\n\n'
        'Пришла новая заявка на проверку оплаты.\n'
        'Мероприятие: ${booking.trainingTitle}\n'
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

  String everyFifthBonusApplied(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Готово! Тренировка по бонусу «каждая 5-я бесплатно» активирована 🎉\n'
        'Запись: #${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status)}';
  }

  String everyFifthBonusUnlockedUser({
    required int completedTrainingsCount,
    required int availableRewardsCount,
  }) {
    return '🎁 Отличная работа! Ты завершил(а) $completedTrainingsCount оплаченных тренировок.\n'
        'Новая бесплатная тренировка по правилу «каждая 5-я» уже доступна.\n'
        'Сейчас доступно бесплатных: $availableRewardsCount.';
  }

  String everyFifthBonusUnlockedAdmin({
    required int userId,
    required String? username,
    required int completedTrainingsCount,
    required int availableRewardsCount,
  }) {
    return 'Новая бесплатная тренировка (каждая 5-я) 🎁\n'
        'Пользователь: ${_userTagById(userId, username: username)} ($userId)\n'
        'Оплаченных и прошедших тренировок: $completedTrainingsCount\n'
        'Доступно бесплатных тренировок: $availableRewardsCount';
  }

  String everyFifthBonusAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Бесплатная запись по правилу «каждая 5-я» 🎁\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Тренировка: ${booking.trainingTitle}\n'
        'Когда: ${formatter.format(booking.startsAt)}';
  }

  String starterBonusExpiryReminder({required DateTime expiresAt}) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '⏳ Напоминание: бесплатная стартовая тренировка сгорит через 1 день.\n'
        'Используй ее до ${formatter.format(expiresAt)}.';
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

  String chooseBookingToManage(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'Сейчас нет записей, которыми можно управлять.';
    }
    return 'Выбери запись для управления 👇';
  }

  String bookingActions(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Запись #${booking.id}\n'
        '${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n\n'
        'Выбери действие 👇';
  }

  String chooseTrainingForReschedule(List<TrainingInfo> items, {required TrainingBooking booking}) {
    if (items.isEmpty) {
      return 'Сейчас нет ближайших тренировок для переноса.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[
      'Куда перенести запись #${booking.id}?',
      'Текущая тренировка: ${booking.trainingTitle}',
      '',
      'Выбери новую тренировку 👇',
    ];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      lines.add(
        '${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} (${item.location})',
      );
    }
    return lines.join('\n');
  }

  String bookingRescheduled({
    required TrainingBooking from,
    required TrainingBooking to,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Готово! Запись #${to.id} перенесена ✅\n'
        'Было: ${from.trainingTitle} (${formatter.format(from.startsAt)})\n'
        'Стало: ${to.trainingTitle} (${formatter.format(to.startsAt)})\n'
        'Статус оплаты сохранен: ${_statusLabel(to.status)}';
  }

  String bookingRescheduleConflict() {
    return 'Не удалось перенести запись: у тебя уже есть запись на выбранную тренировку.';
  }

  String bookingRescheduleSameTraining() {
    return 'Эта запись уже на выбранной тренировке. Выбери другую дату.';
  }

  String bookingCancelled(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Запись #${booking.id} отменена ✅\n'
        '${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Статус: ${_statusLabel(booking.status)}';
  }

  String outdoorCancellationTooLate(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отменить запись #${booking.id} уже нельзя ⛔️\n'
        'До начала (${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}) '
        'осталось меньше 7 дней.';
  }

  String paymentsQueueEmpty() => 'Очередь подтверждения оплат пока пустая ✨';

  String paymentsQueueIntro(int total) {
    return 'Заявки на подтверждение оплаты 🧾\n'
        'Всего ожидают проверки: $total.\n'
        'Ниже отправил каждую заявку отдельным сообщением.';
  }

  String paymentsQueueItem(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final note = booking.paymentNote == null ? '' : '\nКомментарий: ${booking.paymentNote}';
    return 'Заявка #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
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
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final lines = <String>[title];
    for (var index = 0; index < trainings.length; index++) {
      final training = trainings[index];
      final tags = bookingsByTrainingKey[training.sessionKey] ?? const <TrainingBooking>[];
      lines.add(
        '\n${index + 1}. ${training.title}\n'
        '🕒 ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 ${training.location}',
      );
      if (tags.isEmpty) {
        lines.add('   — пока никто не записался');
      } else {
        for (final booking in tags) {
          lines.add(
            '   • ${_userTag(booking)} (${_participantStatusLabel(booking)})',
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

  Map<String, Object?> openPaymentsQueueInlineKeyboard({required int total}) {
    return TelegramKeyboards.openPaymentsQueueInlineKeyboard(
      buttonLabel: _labelWithCount(MessageCopy.buttonPaymentsQueue, total),
    );
  }

  String bookingNotFound(int id) {
    return 'Запись #$id не найдена 😕';
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status)} ✅';
  }

  String paymentAlreadyReviewed(int bookingId) {
    return 'Запись #$bookingId уже не в статусе «На проверке». Обнови очередь и проверь актуальный статус.';
  }

  String adminBookingUpdateConflict() {
    return 'Не удалось сохранить изменения: для этого пользователя уже есть запись на выбранное мероприятие.';
  }

  String paymentInstructions(int bookingId) {
    return 'Реквизиты для оплаты:\n'
        '• Получатель: Родион Одобеско\n'
        '• Банк: 🟦 OZON БАНК 🟦\n'
        '• Номер телефона: +7(918)423-01-03\n'
        '• Комментарий к переводу: "Номер записи: $bookingId"';
  }

  String paymentApprovedForUser(TrainingBooking booking) {
    if (!MessageFormatters.isOutdoorBooking(booking)) {
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

  String bookingRescheduledAdminNotification({
    required TrainingBooking before,
    required TrainingBooking after,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Перенос записи пользователем 🔁\n'
        'Запись: #${after.id}\n'
        'Пользователь: ${_userTag(after)} (${after.userId})\n'
        'Было: ${before.trainingTitle} (${formatter.format(before.startsAt)})\n'
        'Стало: ${after.trainingTitle} (${formatter.format(after.startsAt)})';
  }

  String bookingCancelledAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отмена outdoor-записи пользователем ❌\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Событие: ${booking.trainingTitle}\n'
        'Дата: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}';
  }

  String pendingPaymentReminder(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Напоминание об оплате 💸\n'
        'Запись: #${booking.id}\n'
        '${booking.trainingTitle} (${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)})\n'
        'Текущий статус: ${_statusLabel(booking.status)}\n\n'
        '${paymentInstructions(booking.id)}\n\n'
        'После оплаты отправь в этот чат файл с подтверждением (чек/скрин).';
  }

  String chooseTrainingForBooking(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return noUpcomingForBooking();
    }
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final lines = <String>['Выбери мероприятие для записи 👇'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final feeLabel = item.price == null ? '' : ', взнос: ${_trainingPriceLabel(item.price)}';
      lines.add(
        '${index + 1}. ${item.title} — '
        '${_trainingDateLabel(item, dateTimeFormatter, dateOnlyFormatter)} '
        '(${item.location}$feeLabel)',
      );
    }
    return lines.join('\n');
  }

  String paymentDetailsSent(TrainingBooking booking) {
    if (!MessageFormatters.isOutdoorBooking(booking)) {
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

  Map<String, Object?> scheduleCategoryActionsKeyboard() {
    return TelegramKeyboards.scheduleCategoryActionsKeyboard();
  }

  Map<String, Object?> paymentsQueueCategorySelectionKeyboard({
    required int trainings,
    required int hikes,
    required int trails,
  }) {
    return TelegramKeyboards.categorySelectionKeyboard(
      trainingsLabel: _labelWithCount(MessageCopy.buttonCategoryTrainings, trainings),
      hikesLabel: _labelWithCount(MessageCopy.buttonCategoryHikes, hikes),
      trailsLabel: _labelWithCount(MessageCopy.buttonCategoryTrails, trails),
    );
  }

  Map<String, Object?> paymentConfirmationKeyboard({
    required bool showStarterBonus,
  }) {
    return TelegramKeyboards.paymentConfirmationKeyboard(showStarterBonus: showStarterBonus);
  }

  Map<String, Object?> bookingManagementSelectionKeyboard(List<TrainingBooking> bookings) {
    return TelegramKeyboards.bookingManagementSelectionKeyboard(bookings);
  }

  Map<String, Object?> bookingActionsKeyboard({
    required bool canReschedule,
    required bool canCancel,
  }) {
    return TelegramKeyboards.bookingActionsKeyboard(
      canReschedule: canReschedule,
      canCancel: canCancel,
    );
  }

  Map<String, Object?> adminBookingManagementKeyboard() {
    return TelegramKeyboards.adminBookingManagementKeyboard();
  }

  Map<String, Object?> bookingSegmentKeyboard({
    required int activeCount,
    required int archivedCount,
  }) {
    return TelegramKeyboards.bookingSegmentKeyboard(
      activeCount: activeCount,
      archivedCount: archivedCount,
    );
  }

  Map<String, Object?> adminBookingActionsKeyboard({
    required bool canRestore,
  }) {
    return TelegramKeyboards.adminBookingActionsKeyboard(canRestore: canRestore);
  }

  Map<String, Object?> adminBookingEditFieldsKeyboard() {
    return TelegramKeyboards.adminBookingEditFieldsKeyboard();
  }

  Map<String, Object?> adminBookingDeleteConfirmKeyboard() {
    return TelegramKeyboards.adminBookingDeleteConfirmKeyboard();
  }

  Map<String, Object?> adminBookingAfterActionKeyboard() {
    return TelegramKeyboards.adminBookingAfterActionKeyboard();
  }

  Map<String, Object?> adminCreateBookingConfirmationKeyboard() {
    return TelegramKeyboards.adminCreateBookingConfirmationKeyboard();
  }

  Map<String, Object?> bookingPaymentStatusKeyboard() {
    return TelegramKeyboards.bookingPaymentStatusKeyboard();
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

  String _participantStatusLabel(TrainingBooking booking) {
    return MessageFormatters.participantStatusLabel(booking);
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

  String _bookingDateLabel(
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

  String _trainingDateLabel(
    TrainingInfo training,
    DateFormat dateTimeFormatter,
    DateFormat dateOnlyFormatter,
  ) {
    return MessageFormatters.trainingDateLabel(
      training,
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

  String _labelWithCount(String label, int count) {
    return '$label ($count)';
  }
}
