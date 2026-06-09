import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
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
  static const String buttonPayFully = MessageCopy.buttonPayFully;
  static const String buttonPayPartially = MessageCopy.buttonPayPartially;
  static const String buttonUseStarterBonus = MessageCopy.buttonUseStarterBonus;
  static const String buttonRescheduleBooking = MessageCopy.buttonRescheduleBooking;
  static const String buttonRepeatBooking = MessageCopy.buttonRepeatBooking;
  static const String buttonCancelBooking = MessageCopy.buttonCancelBooking;
  static const String buttonBack = MessageCopy.buttonBack;
  static const String buttonMainMenu = MessageCopy.buttonMainMenu;
  static const String buttonHelp = MessageCopy.buttonHelp;
  static const String buttonCategoryTrainings = MessageCopy.buttonCategoryTrainings;
  static const String buttonCategoryHikes = MessageCopy.buttonCategoryHikes;
  static const String buttonCategoryTrails = MessageCopy.buttonCategoryTrails;
  static const String buttonRefreshSchedule = MessageCopy.buttonRefreshSchedule;
  static const String buttonPaymentsQueue = MessageCopy.buttonPaymentsQueue;
  static const String buttonEconomicSummary = MessageCopy.buttonEconomicSummary;
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
  static const String buttonBookingsPreviousPage = MessageCopy.buttonBookingsPreviousPage;
  static const String buttonBookingsNextPage = MessageCopy.buttonBookingsNextPage;
  static const String buttonCreateAnotherBooking = MessageCopy.buttonCreateAnotherBooking;
  static const String buttonConfirmCreateBooking = MessageCopy.buttonConfirmCreateBooking;
  static const String buttonCancelCreateBooking = MessageCopy.buttonCancelCreateBooking;
  static const String buttonStatusPendingPayment = MessageCopy.buttonStatusPendingPayment;
  static const String buttonStatusPaymentSubmitted = MessageCopy.buttonStatusPaymentSubmitted;
  static const String buttonStatusPartialPaid = MessageCopy.buttonStatusPartialPaid;
  static const String buttonStatusPaid = MessageCopy.buttonStatusPaid;
  static const String buttonStatusFreeTraining = MessageCopy.buttonStatusFreeTraining;
  static const String buttonStatusPaymentRejected = MessageCopy.buttonStatusPaymentRejected;
  static const String buttonSummaryCurrentWeek = MessageCopy.buttonSummaryCurrentWeek;
  static const String buttonSummaryPreviousWeek = MessageCopy.buttonSummaryPreviousWeek;
  static const String buttonSummaryCurrentMonth = MessageCopy.buttonSummaryCurrentMonth;
  static const String buttonSummaryPreviousMonth = MessageCopy.buttonSummaryPreviousMonth;
  static const String callbackApprovePaymentPrefix = MessageCopy.callbackApprovePaymentPrefix;
  static const String callbackApprovePartialPaymentPrefix =
      MessageCopy.callbackApprovePartialPaymentPrefix;
  static const String callbackRejectPaymentPrefix = MessageCopy.callbackRejectPaymentPrefix;
  static const String callbackOpenPaymentsQueue = MessageCopy.callbackOpenPaymentsQueue;
  static const String scheduleDocumentUrl = MessageCopy.scheduleDocumentUrl;

  String privateWelcome() {
    return 'Добро пожаловать в DVOR 🤝\n\n'
        'Здесь ты можешь:\n'
        '• посмотреть расписание,\n'
        '• записаться на тренировку/поход/трейл,\n'
        '• отправить подтверждение оплаты,\n'
        '• управлять своими записями.\n\n'
        'С чего начать:\n'
        '1) Нажми «${MessageCopy.buttonTrainings}» и выбери категорию.\n'
        '2) Нажми «${MessageCopy.buttonBookTraining}» и выбери событие.\n'
        '3) После оплаты нажми «${MessageCopy.buttonSubmitPayment}» и отправь файл чека.\n\n'
        'Если нужна подсказка, нажми «${MessageCopy.buttonHelp}».';
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
        '• Напоминаю про систему лояльности: каждая 5-я тренировка бесплатная 🎁\n'
        '• Показываю твои записи и текущие статусы 🗂\n'
        '• Принимаю файл с подтверждением оплаты и передаю его на проверку 💸\n'
        '• Напоминаю об оплате, если она еще не подтверждена ⏰\n\n'
        'По остальным вопросам пиши в поддержку: @dvor_support 💬\n\n'
        'Если кнопки вдруг пропали, используй команды:\n'
        '/trainings, /book, /my_bookings, /coaches.';
  }

  String privateFallback() {
    return 'Пока не понял сообщение 🤔\n'
        'Используй кнопки меню ниже.\n'
        'Если запутался в шаге записи, нажми «${MessageCopy.buttonMainMenu}» '
        'или «${MessageCopy.buttonHelp}».';
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
        '• 🏋️ ${_escapeHtml(item.title)}',
        '   🕒 Когда: ${formatter.format(item.startsAt)}',
        '   📍 Где: ${_locationLabel(item)}',
        '   👥 Участники: ${_participantsLimitLabel(item.participantsLimit)}',
        if (item.price != null) '   💳 Взнос: ${_trainingPriceLabel(item.price)}',
        if (coach != null && coach.isNotEmpty)
          '   🧑‍🏫 ${_coachTitle(coach)}: ${_escapeHtml(coach)}',
        if (notes != null && notes.isNotEmpty) '   📝 Примечание: ${_escapeHtml(notes)}',
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
        '🔗 ${trainer.link}',
        '📝 ${_normalizeTrainerDescription(trainer.description)}',
      ]);
    }
    return lines.join('\n');
  }

  String chooseBookingCategory() {
    return 'Шаг 1/3: выбери категорию для записи 👇';
  }

  String unknownCategory() {
    return 'Не понял категорию.\n'
        'Нажми одну из кнопок ниже (Тренировки / Походы / Трейлы) 👇';
  }

  String chooseParticipantsCategory() {
    return 'Выбери категорию для списка записавшихся 👇';
  }

  String choosePaymentsQueueCategory() {
    return 'Выбери категорию для заявок на оплату 👇\n'
        'После проверки каждой заявки можно сразу перейти к следующей.';
  }

  String chooseBookingManagementAction() {
    return 'Управление записями: выбери действие 👇';
  }

  String chooseBookingListSegment() {
    return 'Какой список открыть? 👇\n'
        'Подсказка: «Активные» - текущие записи, «Архивные» - завершенные и удаленные.';
  }

  String chooseBookingManagementCategory() {
    return 'Выбери категорию мероприятий для управления 👇';
  }

  String chooseAdminBookingFromList(
    List<TrainingBooking> bookings, {
    required bool archived,
    ActivityCategory? category,
    required int page,
    required int totalPages,
    required int totalCount,
  }) {
    if (bookings.isEmpty) {
      final segmentLabel = archived ? 'Архивные' : 'Активные';
      final categoryLabel = category == null ? 'не выбрана' : _categoryLabel(category);
      return 'Список пуст для выбранных фильтров.\n'
          'Сегмент: $segmentLabel\n'
          'Категория: $categoryLabel';
    }
    final segmentLabel = archived ? 'Архивные' : 'Активные';
    final categoryLabel = category == null ? 'не выбрана' : _categoryLabel(category);
    final lines = <String>[
      'Список записей для управления 👇',
      'Фильтр: $segmentLabel • $categoryLabel',
      'Страница $page/$totalPages • всего записей: $totalCount',
      'Выбери запись кнопкой ниже.',
      'Чтобы сменить фильтры, нажми «${MessageCopy.buttonBack}».',
    ];
    return lines.join('\n');
  }

  String adminBookingActions(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Запись #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Событие: ${booking.trainingTitle}\n'
        'Дата: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}\n\n'
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

  String invalidUsernameInput() {
    return 'Не смог распознать username.\n'
        'Нужен формат @username или username (без пробелов).';
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
    return 'Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status, booking: booking)} ✅';
  }

  String adminBookingDeleteConfirm(TrainingBooking booking) {
    return 'Удалить запись #${booking.id}? '
        'Запись перейдет в архив со статусом «Отменена».';
  }

  String adminBookingDeleted(TrainingBooking booking) {
    return 'Запись #${booking.id} переведена в архив ✅';
  }

  String adminBookingDeletedForUser(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Твою запись #${booking.id} отменил администратор ❌\n'
        '${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Если есть вопросы, напиши в поддержку: @dvor_support';
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
      lines.add('${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} '
          '(${item.location}, участники: ${_participantsLimitLabel(item.participantsLimit)})');
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
    return 'Готово! Google Docs обновил ✅\n'
        'Обновил расписание и список тренеров.';
  }

  String scheduleRefreshFailed() {
    return 'Не получилось обновить Google Docs 😔 Использую последние сохраненные данные.';
  }

  String scheduleRefreshForbidden() {
    return 'Эта кнопка только для админов 🔒';
  }

  String scheduleDocumentLink() {
    return 'Актуальный Google Docs:\n$scheduleDocumentUrl';
  }

  String noUpcomingForBooking() {
    return 'Пока нет ближайших мероприятий для записи 😌';
  }

  String bookingCreated(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${booking.location}\n\n'
        '${paymentDetailsSent(booking)}\n\n'
        'Что дальше:\n'
        '1) Оплати по реквизитам выше.\n'
        '2) Нажми «${MessageCopy.buttonSubmitPayment}».\n'
        '3) Отправь файл чека (документ/фото) в этот чат.';
  }

  String bookingCreatedWithoutPayment(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}\n'
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
        'Текущий статус: ${_statusLabel(booking.status, booking: booking)}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}';
  }

  String bookingParticipantsLimitExceeded() {
    return 'Не удалось записаться: свободных мест больше нет ⛔️\n'
        'Выбери другое мероприятие из списка ниже.';
  }

  String groupTrainingLowSpots({
    required TrainingInfo training,
    required int freeSpots,
    required int participantsLimit,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '🔥 На тренировке почти не осталось мест!\n'
        'Тренировка: ${training.title}\n'
        '🕒 Когда: ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${training.location}\n'
        '👥 Свободных мест: $freeSpots из $participantsLimit\n\n'
        '${_groupBookingCta()}';
  }

  String groupTrainingNoSpotsLeft({
    required TrainingInfo training,
    required int participantsLimit,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '⛔️ Места на эту тренировку закончились\n'
        'Тренировка: ${training.title}\n'
        '🕒 Когда: ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${training.location}\n'
        '👥 Участников: $participantsLimit/$participantsLimit\n\n'
        'Следи за расписанием - новые слоты и тренировки появляются регулярно.\n'
        '${_groupBookingCta()}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return 'Супер, файл с подтверждением оплаты отправил администратору ✅\n'
        'Номер записи: ${booking.id}\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}.\n'
        'Следующий шаг: дождись результата модерации, бот сообщит автоматически.';
  }

  String chooseOutdoorPaymentType() {
    return 'Какой формат оплаты ты уже сделал(а)? 👇\n'
        'Выбери вариант и затем отправь чек.';
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
        'Статус: ${_statusLabel(booking.status, booking: booking)}';
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
        'Статус: ${_statusLabel(booking.status, booking: booking)}';
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
    return 'Не нашел активной записи со статусом "Ожидает оплату" 🤔\n'
        'Проверь «${MessageCopy.buttonMyBookings}» или создай новую запись.';
  }

  String myBookings(
    List<TrainingBooking> bookings, {
    DateTime? now,
  }) {
    if (bookings.isEmpty) {
      return 'У тебя пока нет записей на мероприятия 🙃';
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
          'Статус: ${_statusLabel(booking.status, booking: booking)}',
        );
      }
    }

    if (past.isNotEmpty) {
      lines.add('\nПрошедшие:');
      for (final booking in past) {
        lines.add(
          '\n• #${booking.id} ${booking.trainingTitle}\n'
          '🕒 Когда: ${_myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
          'Статус: ${_statusLabel(booking.status, booking: booking)}',
        );
      }
    }
    return lines.join('\n');
  }

  String chooseBookingToManage(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 'Сейчас нет записей, которыми можно управлять.';
    }
    return 'Выбери запись для управления (кнопки ниже) 👇\n'
        'Можно перенести, отменить или повторить запись.';
  }

  String bookingRescheduleNotAvailable(TrainingBooking? booking) {
    if (booking == null) {
      return 'Не нашел запись для переноса. Выбери запись заново.';
    }
    return 'Перенос доступен только для тренировок.\n'
        'Для записи #${booking.id} используй другие действия.';
  }

  String bookingCancelNotAvailable(TrainingBooking? booking) {
    if (booking == null) {
      return 'Не нашел запись для отмены. Выбери запись заново.';
    }
    return 'Отмена доступна только для походов и трейлов.\n'
        'Для записи #${booking.id} используй другие действия.';
  }

  String bookingActions(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Запись #${booking.id}\n'
        '${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n\n'
        'Выбери действие 👇\n'
        'Подсказка: «${MessageCopy.buttonRepeatBooking}» откроет похожие события.';
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
        '${index + 1}. ${item.title} — ${formatter.format(item.startsAt)} '
        '(${item.location}, участники: ${_participantsLimitLabel(item.participantsLimit)})',
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

  String bookingRescheduleFreeToPaidNotAllowed() {
    return 'Эту запись нельзя перенести на платную тренировку.\n'
        'Бесплатную запись можно переносить только на бесплатные слоты.';
  }

  String bookingCancelled(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Запись #${booking.id} отменена ✅\n'
        '${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}';
  }

  String outdoorCancellationTooLate(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отменить запись #${booking.id} уже нельзя ⛔️\n'
        'До начала (${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}) '
        'осталось меньше 7 дней.';
  }

  String paymentsQueueEmpty() => 'Очередь подтверждения оплат пока пустая ✨';

  String paymentsQueueIntro(int total, {required ActivityCategory category}) {
    return 'Заявки на подтверждение оплаты 🧾\n'
        'Категория: ${_categoryLabel(category)}\n'
        'Всего ожидают проверки: $total.\n'
        'Ниже отправил каждую заявку отдельным сообщением.';
  }

  String paymentsQueueItem(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final paymentType = _paymentTypeLabelFromNote(booking.paymentNote);
    final cleanNote = _cleanPaymentNote(booking.paymentNote);
    final note = cleanNote == null ? '' : '\nКомментарий: $cleanNote';
    return 'Заявка #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 ${booking.location}'
        '${paymentType == null ? '' : '\nТип оплаты: $paymentType'}'
        '$note\n\n'
        'Подтверди или отклони оплату кнопками ниже.\n'
        'После решения можно сразу открыть следующую заявку.';
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
        '📍 ${training.location}\n'
        '👥 Участники: ${tags.length}/${_participantsLimitValueLabel(training.participantsLimit)}',
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
    return 'Использование:\n'
        '/approve_payment <id>\n'
        '/approve_partial_payment <id>\n'
        '/reject_payment <id>\n\n'
        'Например: /approve_partial_payment 42';
  }

  String paymentReviewResultWithNextStep({
    required TrainingBooking booking,
    required int remaining,
  }) {
    final nextStep = remaining > 0
        ? 'Осталось на проверке: $remaining. Нажми «${MessageCopy.buttonPaymentsQueue}», чтобы открыть следующую заявку.'
        : 'Очередь заявок пуста. Можно вернуться в меню.';
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status, booking: booking)} ✅\n'
        '$nextStep';
  }

  Map<String, Object?> paymentDecisionInlineKeyboard(
    int bookingId, {
    bool approvePartial = false,
  }) {
    return TelegramKeyboards.paymentDecisionInlineKeyboard(
      bookingId,
      approvePartial: approvePartial,
    );
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
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status, booking: booking)} ✅';
  }

  String paymentAlreadyReviewed(int bookingId) {
    return 'Запись #$bookingId уже не в статусе «На проверке». Обнови очередь и проверь актуальный статус.';
  }

  String adminBookingUpdateConflict() {
    return 'Не удалось сохранить изменения: для этого пользователя уже есть запись на выбранное мероприятие.';
  }

  String paymentInstructions(int bookingId) {
    return 'Реквизиты для оплаты:\n'
        '• Получатель: Денис Р.\n'
        '• Банк: 🟦 OZON БАНК 🟦\n'
        '• Номер телефона: +7(995)122-06-15';
  }

  String paymentApprovedForUser(TrainingBooking booking) {
    if (booking.status == BookingStatus.partialPaid) {
      return 'Предоплату по записи #${booking.id} подтвердили 🟡\n'
          'Статус: ${_statusLabel(booking.status, booking: booking)}.\n'
          'Оставшуюся сумму можно доплатить ближе к старту.';
    }
    if (!MessageFormatters.isOutdoorBooking(booking)) {
      return 'Оплату по записи #${booking.id} подтвердили ✅\n'
          'Статус: ${_statusLabel(booking.status, booking: booking)}.\n'
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
        'Статус: ${_statusLabel(booking.status, booking: booking)}.\n'
        'Проверь детали платежа и отправь подтверждение еще раз.\n'
        'Если нужен комментарий по отклонению, напиши администратору клуба.';
  }

  String paymentReviewAdminNotification({
    required TrainingBooking booking,
    required int moderatorUserId,
    String? moderatorUsername,
  }) {
    return 'Модерация оплаты выполнена 🧾\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}\n'
        'Проверил админ: ${_userTagById(moderatorUserId, username: moderatorUsername)} ($moderatorUserId)\n'
        'Дальше: при необходимости открой очередь и проверь следующую заявку.';
  }

  String bookingRescheduledAdminNotification({
    required TrainingBooking before,
    required TrainingBooking after,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return 'Операционное событие: перенос записи 🔁\n'
        'Запись: #${after.id}\n'
        'Пользователь: ${_userTag(after)} (${after.userId})\n'
        'Было: ${before.trainingTitle} (${formatter.format(before.startsAt)})\n'
        'Стало: ${after.trainingTitle} (${formatter.format(after.startsAt)})\n'
        'Дальше: проверь состав участников перед ближайшей тренировкой.';
  }

  String bookingCancelledAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Операционное событие: отмена записи ❌\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Событие: ${booking.trainingTitle}\n'
        'Дата: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Дальше: при необходимости свяжись с участником по возврату/перезаписи.';
  }

  String freeBookingCreatedAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Операционное событие: новая бесплатная запись 🎁\n'
        'Запись: #${booking.id}\n'
        'Пользователь: ${_userTag(booking)} (${booking.userId})\n'
        'Событие: ${booking.trainingTitle}\n'
        'Дата: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}';
  }

  String pendingPaymentReminder(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Напоминание об оплате 💸\n'
        'Запись: #${booking.id}\n'
        '${booking.trainingTitle} (${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)})\n'
        'Текущий статус: ${_statusLabel(booking.status, booking: booking)}\n\n'
        '${paymentInstructions(booking.id)}\n\n'
        'После оплаты нажми «${MessageCopy.buttonSubmitPayment}» и отправь в этот чат файл с подтверждением (чек/скрин).\n'
        'Если кнопка не сработала, открой «${MessageCopy.buttonMyBookings}» и выбери нужную запись.';
  }

  String chooseTrainingForBooking(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return noUpcomingForBooking();
    }
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final lines = <String>[
      'Шаг 2/3: выбери мероприятие для записи 👇',
      'Подсказка: отправь номер из списка или нажми кнопку с событием.',
    ];
    final eventLines = <String>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final feeLabel = item.price == null ? '' : ', взнос: ${_trainingPriceLabel(item.price)}';
      eventLines.add(
        '${index + 1}. ${item.title} — '
        '${_trainingDateLabel(item, dateTimeFormatter, dateOnlyFormatter)} '
        '(${item.location}$feeLabel, участники: ${_participantsLimitLabel(item.participantsLimit)})',
      );
    }
    return <String>[
      ...lines,
      eventLines.join('\n\n'),
    ].join('\n');
  }

  String paymentDetailsSent(TrainingBooking booking) {
    if (!MessageFormatters.isOutdoorBooking(booking)) {
      return '${paymentInstructions(booking.id)}\n\n'
          'Когда переведешь оплату, нажми «${MessageCopy.buttonSubmitPayment}» '
          'и отправь в этот чат файл с подтверждением (чек/скрин) 📎\n\n'
          'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.';
    }

    return '${paymentInstructions(booking.id)}\n\n'
        'Правило Outdvor 🚸\n\n'
        '• Предоплата невозвратна при отмене за 7 дней и менее до трейла/похода🦥\n\n'
        'Это не штраф, а уважение к общим расходам на логистику, планирование '
        'тренировки и трансфер. Такие мероприятия любят сильных и решительных. Спасибо за понимание. 💚💪\n'
        '\n\n'
        'Когда переведешь оплату, нажми «${MessageCopy.buttonSubmitPayment}» '
        'и отправь в этот чат файл с подтверждением (чек/скрин) 📎\n\n'
        'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.';
  }

  String paymentProofRequired() {
    return 'Чтобы отправить заявку администратору:\n'
        '1) Нажми «${MessageCopy.buttonSubmitPayment}».\n'
        '2) Пришли файл с подтверждением оплаты (документ или фото чека).\n'
        '3) Дождись ответа о модерации.';
  }

  String paymentProofUnavailableHint(TrainingBooking booking) {
    return 'Не удалось подгрузить файл подтверждения для записи #${booking.id}.\n'
        'Проверь заявку в личке пользователя: ${_userTag(booking)} (${booking.userId}).';
  }

  String economicSummary(EconomicSummary summary, {String? periodLabel}) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final periodRange =
        '${dateFormatter.format(summary.period.startInclusive)} — ${dateFormatter.format(summary.period.endExclusive.subtract(const Duration(days: 1)))}';
    final lines = <String>[
      'Экономическая сводка ${periodLabel ?? 'по периоду'} 📈',
      'Период: $periodRange',
      '',
      'Финансы:',
      '• Выручка: ${_money(summary.totalRevenue)}',
      '• Платных бронирований: ${summary.paidBookingsCount}',
      '• Средний чек: ${_money(summary.averageCheck)}',
      if (summary.freeBookingsCount > 0) '• Бесплатных бронирований: ${summary.freeBookingsCount}',
      if (summary.regularFreeBookingsCount > 0)
        '• Бесплатные по цене мероприятия: ${summary.regularFreeBookingsCount}',
      if (summary.starterFreeBookingsCount > 0)
        '• Бесплатные стартовые: ${summary.starterFreeBookingsCount}',
      if (summary.everyFifthFreeBookingsCount > 0)
        '• Бесплатные по правилу «каждая 5-я»: ${summary.everyFifthFreeBookingsCount}',
      if (summary.unknownPriceBookingsCount > 0)
        '• Без цены в данных: ${summary.unknownPriceBookingsCount}',
      '',
      'По категориям:',
      if (summary.byCategory.isEmpty) '• Нет оплаченных бронирований с ценой',
      ...summary.byCategory.map(
        (item) =>
            '• ${_categoryLabel(item.category)}: ${_money(item.revenue)} (${item.bookingsCount})',
      ),
      '',
      'Топ мероприятий по выручке:',
      if (summary.byEvent.isEmpty) '• Нет данных',
      ...summary.byEvent.map(
        (item) => '• ${item.eventTitle}: ${_money(item.revenue)} (${item.bookingsCount})',
      ),
    ];
    return lines.join('\n');
  }

  String chooseEconomicSummaryPeriod() {
    return 'Выбери период для экономической сводки 👇';
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
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
  }) {
    return TelegramKeyboards.paymentConfirmationKeyboard(
      showStarterBonus: showStarterBonus,
      showCancelBooking: showCancelBooking,
      showOutdoorPaymentTypeChoice: showOutdoorPaymentTypeChoice,
    );
  }

  Map<String, Object?> simpleNavigationKeyboard() {
    return TelegramKeyboards.simpleNavigationKeyboard();
  }

  Map<String, Object?> bookingManagementSelectionKeyboard(List<TrainingBooking> bookings) {
    return TelegramKeyboards.bookingManagementSelectionKeyboard(bookings);
  }

  Map<String, Object?> adminBookingSelectionKeyboard(
    List<TrainingBooking> bookings, {
    required bool hasPreviousPage,
    required bool hasNextPage,
  }) {
    return TelegramKeyboards.adminBookingSelectionKeyboard(
      bookings,
      hasPreviousPage: hasPreviousPage,
      hasNextPage: hasNextPage,
    );
  }

  Map<String, Object?> bookingActionsKeyboard({
    required bool canReschedule,
    required bool canCancel,
    required bool canRepeat,
  }) {
    return TelegramKeyboards.bookingActionsKeyboard(
      canReschedule: canReschedule,
      canCancel: canCancel,
      canRepeat: canRepeat,
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

  Map<String, Object?> economicSummaryPeriodKeyboard() {
    return TelegramKeyboards.economicSummaryPeriodKeyboard();
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

  String _statusLabel(BookingStatus status, {TrainingBooking? booking}) {
    if (booking != null) {
      return MessageFormatters.bookingStatusLabel(booking);
    }
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
        '• $icon ${_escapeHtml(item.title)}',
        '   🗓 Даты: $dateLabel',
        '   📝 Описание: ${_escapeHtml(item.description)}',
        '   👥 Участники: ${_participantsLimitLabel(item.participantsLimit)}',
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

  String _groupBookingCta() {
    final deepLink = _botDeepLink();
    if (deepLink != null) {
      return 'Записаться: $deepLink';
    }
    return 'Чтобы записаться, открой бота в личке и нажми /start.';
  }

  String _categoryLabel(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'Тренировки',
      ActivityCategory.hikes => 'Походы',
      ActivityCategory.trails => 'Трейлы',
    };
  }

  String _participantsLimitLabel(int? participantsLimit) {
    if (participantsLimit == null || participantsLimit <= 0) {
      return 'без ограничений';
    }
    return 'до $participantsLimit';
  }

  String _coachTitle(String coach) {
    final normalized = coach.trim().toLowerCase();
    final hasMultipleCoaches = normalized.contains(',') ||
        normalized.contains(';') ||
        normalized.contains('\n') ||
        normalized.contains(' и ') ||
        normalized.contains(' & ');
    return hasMultipleCoaches ? 'Тренеры' : 'Тренер';
  }

  String _participantsLimitValueLabel(int? participantsLimit) {
    if (participantsLimit == null || participantsLimit <= 0) {
      return '∞';
    }
    return '$participantsLimit';
  }

  String _money(int amount) {
    return '$amount ₽';
  }

  String _locationLabel(TrainingInfo item) {
    final location = _escapeHtml(item.location);
    final url = item.locationUrl?.trim();
    if (url == null || url.isEmpty || !_isSupportedLink(url)) {
      return location;
    }
    return '<a href="${_escapeHtml(url)}">$location</a>';
  }

  bool _isSupportedLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  String? _paymentTypeLabelFromNote(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return null;
    }
    if (paymentNote.startsWith('__payment_choice_partial__')) {
      return 'Предоплата';
    }
    if (paymentNote.startsWith('__payment_choice_full__')) {
      return 'Полная оплата';
    }
    return null;
  }

  String? _cleanPaymentNote(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return null;
    }
    if (paymentNote.startsWith('__payment_choice_partial__')) {
      final text = paymentNote.substring('__payment_choice_partial__'.length).trim();
      return text.isEmpty ? null : text;
    }
    if (paymentNote.startsWith('__payment_choice_full__')) {
      final text = paymentNote.substring('__payment_choice_full__'.length).trim();
      return text.isEmpty ? null : text;
    }
    return paymentNote;
  }

  String _normalizeTrainerDescription(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final rawLines = normalized.split('\n').map((line) => line.trim()).toList(growable: false);
    if (rawLines.every((line) => line.isEmpty)) {
      return 'Описание скоро добавим.';
    }

    final lines = <String>[];
    var previousWasEmpty = false;
    for (final line in rawLines) {
      final isEmpty = line.isEmpty;
      if (isEmpty) {
        if (!previousWasEmpty && lines.isNotEmpty) {
          lines.add('');
        }
        previousWasEmpty = true;
        continue;
      }
      lines.add(line);
      previousWasEmpty = false;
    }

    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    return lines.join('\n');
  }
}
