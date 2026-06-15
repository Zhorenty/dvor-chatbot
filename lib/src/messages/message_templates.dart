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
import 'package:dvor_chatbot/src/messages/templates/group_templates.dart';
import 'package:dvor_chatbot/src/messages/templates/private_navigation_templates.dart';
import 'package:dvor_chatbot/src/messages/templates/schedule_templates.dart';
import 'package:intl/intl.dart';

final class MessageTemplates {
  const MessageTemplates({
    String? botUsername,
  }) : _botUsername = botUsername;

  final String? _botUsername;
  final PrivateNavigationTemplates _privateNavigationTemplates = const PrivateNavigationTemplates();
  final ScheduleTemplates _scheduleTemplates = const ScheduleTemplates();
  GroupTemplates get _groupTemplates => GroupTemplates(botUsername: _botUsername);

  static const String buttonTrainings = MessageCopy.buttonTrainings;
  static const String buttonCoachingStaff = MessageCopy.buttonCoachingStaff;
  static const String buttonBookTraining = MessageCopy.buttonBookTraining;
  static const String buttonProfile = MessageCopy.buttonProfile;
  static const String buttonProfileBookings = MessageCopy.buttonProfileBookings;
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
  static const String buttonCategoryYoga = MessageCopy.buttonCategoryYoga;
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
    return _privateNavigationTemplates.privateWelcome();
  }

  String starterBonusOnboardingOffer() {
    return _privateNavigationTemplates.starterBonusOnboardingOffer();
  }

  String privateHelp() {
    return _privateNavigationTemplates.privateHelp();
  }

  String privateFallback() {
    return _privateNavigationTemplates.privateFallback();
  }

  String trainings(
    List<TrainingInfo> items, {
    List<TrainerInfo> trainers = const <TrainerInfo>[],
  }) {
    return _scheduleTemplates.trainings(items, trainers: trainers);
  }

  String hikes(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.hikes(items);
  }

  String yoga(
    List<TrainingInfo> items, {
    List<TrainerInfo> trainers = const <TrainerInfo>[],
  }) {
    return _scheduleTemplates.yoga(items, trainers: trainers);
  }

  String trails(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.trails(items);
  }

  String chooseScheduleCategory() {
    return _scheduleTemplates.chooseScheduleCategory();
  }

  String coachingStaff(List<TrainerInfo> trainers) {
    return _scheduleTemplates.coachingStaff(trainers);
  }

  String chooseBookingCategory() {
    return 'Шаг 1/3: выбери категорию для записи 👇';
  }

  String unknownCategory() {
    return 'Не понял категорию.\n'
        'Нажми одну из кнопок ниже (Тренировки / Йога / Походы / Трейлы) 👇';
  }

  String chooseParticipantsCategory() {
    return '👥 <b>Список записавшихся</b>\n'
        'Выбери категорию ниже.';
  }

  String choosePaymentsQueueCategory() {
    return '🧾 <b>Очередь заявок на оплату</b>\n'
        'Выбери категорию ниже.\n'
        'После проверки каждой заявки можно сразу перейти к следующей.';
  }

  String chooseBookingManagementAction() {
    return '🛠 <b>Управление записями</b>\n'
        'Выбери действие 👇';
  }

  String chooseBookingListSegment() {
    return '📚 <b>Какой список открыть?</b>\n'
        'Подсказка: «Активные» - текущие записи, «Архивные» - завершенные и удаленные.';
  }

  String chooseBookingManagementCategory() {
    return '🗂 <b>Категория мероприятий</b>\n'
        'Выбери категорию для управления 👇';
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
      return '📭 <b>Список пуст для выбранных фильтров</b>\n'
          'Сегмент: <b>${_escapeHtml(segmentLabel)}</b>\n'
          'Категория: <b>${_escapeHtml(categoryLabel)}</b>';
    }
    final segmentLabel = archived ? 'Архивные' : 'Активные';
    final categoryLabel = category == null ? 'не выбрана' : _categoryLabel(category);
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[
      '🧾 <b>Список записей для управления</b>',
      'Фильтр: <b>${_escapeHtml(segmentLabel)} • ${_escapeHtml(categoryLabel)}</b>',
      'Страница <b>$page/$totalPages</b> • всего записей: <b>$totalCount</b>',
      '<b>Записи на текущей странице:</b>',
    ];
    for (var index = 0; index < bookings.length; index++) {
      final booking = bookings[index];
      lines.addAll(<String>[
        '',
        '🧩 <b>${index + 1}. #${booking.id} ${_escapeHtml(booking.trainingTitle)}</b>',
        '👤 ${_escapeHtml(_userTag(booking))} (${booking.userId})',
        '🕒 ${dateFormatter.format(booking.startsAt)}',
        '💳 ${_escapeHtml(_statusLabel(booking.status, booking: booking))}',
      ]);
    }
    lines.addAll(<String>[
      '',
      'Выбери запись кнопкой ниже.',
      'Чтобы сменить фильтры, нажми «${MessageCopy.buttonBack}».',
    ]);
    return lines.join('\n');
  }

  String adminBookingActions(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '🧩 <b>Запись #${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Событие: ${_escapeHtml(booking.trainingTitle)}\n'
        'Дата: ${formatter.format(booking.startsAt)}\n'
        'Статус: ${_escapeHtml(_statusLabel(booking.status, booking: booking))}\n\n'
        'Выбери действие 👇';
  }

  String chooseAdminBookingEditField(TrainingBooking booking) {
    return '✏️ <b>Что изменить в записи #${booking.id}?</b>';
  }

  String chooseAdminBookingPaymentStatus(TrainingBooking booking) {
    return '💳 <b>Новый статус оплаты</b>\n'
        'Запись #${booking.id}';
  }

  String adminBookingAskUsername(TrainingBooking booking) {
    return '👤 <b>Username пользователя</b>\n'
        'Отправь username для записи #${booking.id} '
        '(можно с @ или без).';
  }

  String invalidUsernameInput() {
    return 'Не смог распознать username.\n'
        'Нужен формат @username или username (без пробелов).';
  }

  String adminBookingUsernameUpdated(TrainingBooking booking) {
    return '✅ <b>Готово</b>\n'
        'Пользователь для записи #${booking.id}: ${_escapeHtml(_userTag(booking))}';
  }

  String adminBookingEventUpdated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '✅ <b>Событие для записи #${booking.id} обновлено</b>\n'
        '${_escapeHtml(booking.trainingTitle)}\n'
        '${formatter.format(booking.startsAt)}';
  }

  String adminBookingPaymentStatusUpdated(TrainingBooking booking) {
    return '✅ <b>Статус записи #${booking.id} обновлен</b>\n'
        '${_escapeHtml(_statusLabel(booking.status, booking: booking))}';
  }

  String adminBookingDeleteConfirm(TrainingBooking booking) {
    return '⚠️ <b>Удалить запись #${booking.id}?</b>\n'
        'Запись перейдет в архив со статусом «Отменена».';
  }

  String adminBookingDeleted(TrainingBooking booking) {
    return '✅ <b>Запись #${booking.id} переведена в архив</b>';
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
    return '✅ <b>Запись #${booking.id} восстановлена</b>';
  }

  String adminBookingRestoreNotAllowed(TrainingBooking booking) {
    return '⛔️ <b>Запись #${booking.id} нельзя восстановить</b>\n'
        'Мероприятие уже прошло.';
  }

  String chooseCreateBookingCategory() {
    return '➕ <b>Создание записи</b>\n'
        'Выбери категорию 👇';
  }

  String chooseCreateBookingEvent(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return 'В выбранной категории нет доступных мероприятий для записи.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>['📌 <b>Выбери мероприятие для новой записи</b>'];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      lines.add(
          '${index + 1}. <b>${_escapeHtml(item.title)}</b> — ${formatter.format(item.startsAt)} '
          '(${_escapeHtml(item.location)}, участники: ${_participantsLimitLabel(item.participantsLimit)})');
    }
    return lines.join('\n');
  }

  String createBookingAskUsername() {
    return '👤 <b>Username для новой записи</b>\n'
        'Введи username пользователя '
        '(можно с @ или без).';
  }

  String chooseCreateBookingPaymentStatus() {
    return '💳 <b>Стартовый статус оплаты</b>\n'
        'Выбери вариант 👇';
  }

  String createBookingPreview({
    required TrainingInfo training,
    required String username,
    required BookingStatus status,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '🔍 <b>Проверь данные новой записи</b>\n'
        'Пользователь: @${_escapeHtml(username)}\n'
        'Событие: ${_escapeHtml(training.title)}\n'
        'Дата: ${formatter.format(training.startsAt)}\n'
        'Локация: ${_escapeHtml(training.location)}\n'
        'Статус: ${_escapeHtml(_statusLabel(status))}';
  }

  String adminBookingCreated(TrainingBooking booking) {
    return '✅ <b>Запись #${booking.id} создана</b>';
  }

  String clubInfoPrivate() {
    return _groupTemplates.clubInfoPrivate();
  }

  String groupFallback({required String? botUsername}) {
    return _groupTemplates.groupFallback(botUsername: botUsername);
  }

  String groupWelcome({
    required String? username,
    required int userId,
    required String? firstName,
  }) {
    return _groupTemplates.groupWelcome(
      username: username,
      userId: userId,
      firstName: firstName,
    );
  }

  String scheduleRefreshDone() {
    return _scheduleTemplates.scheduleRefreshDone();
  }

  String scheduleRefreshFailed() {
    return _scheduleTemplates.scheduleRefreshFailed();
  }

  String scheduleRefreshForbidden() {
    return 'Эта кнопка только для админов 🔒';
  }

  String scheduleDocumentLink() {
    return _scheduleTemplates.scheduleDocumentLink();
  }

  String noUpcomingForBooking() {
    return _scheduleTemplates.noUpcomingForBooking();
  }

  String bookingCreated(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отлично, записал тебя! ✅\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${_bookingLocationLabel(booking)}\n\n'
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
        '📍 Где: ${_bookingLocationLabel(booking)}\n\n'
        'Это бесплатная тренировка, подтверждение оплаты не нужно.';
  }

  String bookingCreatedForWhitelistedTrainer(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Готово, ты записан(а) на тренировку ✅\n'
        'Статус: ${_statusLabel(booking.status, booking: booking)}\n'
        'Номер записи: ${booking.id}\n'
        'Тренировка: ${booking.trainingTitle}\n'
        '🕒 Когда: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${_bookingLocationLabel(booking)}\n\n'
        'Ты в списке тренеров: подтверждение оплаты не требуется, это только информирование о записи.';
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
    return '🔥 ${_groupLowSpotsTitle(training.category)}\n'
        '${training.title}\n'
        '🕒 Когда: ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${_trainingLocationLabel(training)}\n'
        '👥 Свободных мест: $freeSpots из $participantsLimit\n\n'
        '${_groupBookingCta()}';
  }

  String groupTrainingNoSpotsLeft({
    required TrainingInfo training,
    required int participantsLimit,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '⛔️ ${_groupNoSpotsTitle(training.category)}\n'
        'Тренировка: ${training.title}\n'
        '🕒 Когда: ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 Где: ${_trainingLocationLabel(training)}\n'
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
    return '💸 <b>Новое подтверждение оплаты</b>\n\n'
        'Пришла новая заявка на проверку оплаты.\n'
        'Мероприятие: ${_escapeHtml(booking.trainingTitle)}\n'
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
    return '🎁 <b>Новая бесплатная тренировка (каждая 5-я)</b>\n'
        'Пользователь: ${_escapeHtml(_userTagById(userId, username: username))} ($userId)\n'
        'Оплаченных и прошедших тренировок: <b>$completedTrainingsCount</b>\n'
        'Доступно бесплатных тренировок: <b>$availableRewardsCount</b>';
  }

  String everyFifthBonusAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '🎁 <b>Бесплатная запись по правилу «каждая 5-я»</b>\n'
        'Запись: <b>#${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Тренировка: ${_escapeHtml(booking.trainingTitle)}\n'
        'Когда: ${formatter.format(booking.startsAt)}';
  }

  String starterBonusExpiryReminder({required DateTime expiresAt}) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '⏳ Напоминание: бесплатная стартовая тренировка сгорит через 1 день.\n'
        'Используй ее до ${formatter.format(expiresAt)}.';
  }

  String starterBonusAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '🎁 <b>Стартовая бесплатная запись</b>\n'
        'Запись: <b>#${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Тренировка: ${_escapeHtml(booking.trainingTitle)}\n'
        'Когда: ${formatter.format(booking.startsAt)}\n'
        'Формат: бесплатная тренировка за старт';
  }

  String noPendingPayment() {
    return 'Не нашел активной записи со статусом "Ожидает оплату" 🤔\n'
        'Проверь «${MessageCopy.buttonProfile}» или создай новую запись.';
  }

  String profileOverview({
    required int totalBookings,
    required int activeBookings,
    required int visitedBookings,
    required int cancelledBookings,
    required int completedTrainingsCount,
    required int availableEveryFifthRewards,
    required bool starterBonusAvailable,
  }) {
    final progressToNextFree = completedTrainingsCount % 4;
    final trainingsLeftForNextFree = progressToNextFree == 0 ? 4 : 4 - progressToNextFree;
    final rewardsHint = availableEveryFifthRewards > 0
        ? '🎁 <b>Бесплатных по бонусу «каждая 5-я»:</b> <b>$availableEveryFifthRewards</b>'
        : '🎯 <b>До следующей бесплатной:</b> <b>$trainingsLeftForNextFree</b> '
            '(по правилу «каждая 5-я»)';
    final starterHint = starterBonusAvailable
        ? '⚡️ <b>Стартовая бесплатная:</b> доступна'
        : '⚡️ <b>Стартовая бесплатная:</b> недоступна';
    return '👤 <b>Профиль спортсмена DVOR</b>\n\n'
        '📊 <b>Твоя статистика</b>\n'
        '• Всего записей: <b>$totalBookings</b>\n'
        '• Активные: <b>$activeBookings</b>\n'
        '• Посещенные: <b>$visitedBookings</b>\n'
        '• Отмененные: <b>$cancelledBookings</b>\n\n'
        '🏋️ <b>Прогресс лояльности</b>\n'
        '• Тренировок в зачет «каждая 5-я»: <b>$completedTrainingsCount</b>\n'
        '• $rewardsHint\n'
        '• $starterHint\n\n'
        'Нажми «${MessageCopy.buttonProfileBookings}», чтобы открыть список записей и управление ими.';
  }

  String myBookings(
    List<TrainingBooking> bookings, {
    DateTime? now,
  }) {
    final splitPoint = (now ?? DateTime.now()).toLocal();
    final upcoming = bookings.where((booking) => !booking.startsAt.isBefore(splitPoint)).toList();
    final past = bookings.where((booking) => booking.startsAt.isBefore(splitPoint)).toList();
    past.sort((left, right) => right.startsAt.compareTo(left.startsAt));
    final lines = <String>['🗂 <b>Мои записи</b>'];

    if (bookings.isEmpty) {
      lines.addAll(<String>[
        '',
        'У тебя пока нет записей на мероприятия 🙃',
      ]);
      return lines.join('\n');
    }

    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');

    if (upcoming.isNotEmpty) {
      lines.add('\n📌 <b>Актуальные</b>');
      for (final booking in upcoming) {
        lines.add(
          '\n🧩 <b>#${booking.id} ${_escapeHtml(booking.trainingTitle)}</b>\n'
          '🕒 ${_myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
          '💳 <b>${_escapeHtml(_statusLabel(booking.status, booking: booking))}</b>',
        );
      }
    }

    if (past.isNotEmpty) {
      lines.add('\n🗃 <b>Прошедшие</b>');
      for (final booking in past) {
        lines.add(
          '\n🧩 <b>#${booking.id} ${_escapeHtml(booking.trainingTitle)}</b>\n'
          '🕒 ${_myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
          '💳 <b>${_escapeHtml(_statusLabel(booking.status, booking: booking))}</b>',
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
    return 'Перенос доступен только для тренировок и йоги.\n'
        'Для записи #${booking.id} используй другие действия.';
  }

  String bookingCancelNotAvailable(TrainingBooking? booking) {
    if (booking == null) {
      return 'Не нашел запись для отмены. Выбери запись заново.';
    }
    return 'Отмена доступна только для йоги, походов и трейлов.\n'
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
      return 'Сейчас нет ближайших мероприятий для переноса.';
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[
      '🔁 Куда перенести запись #${booking.id}?',
      'Сейчас: ${booking.trainingTitle}',
      '',
      'Выбери новое мероприятие 👇',
    ];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      lines.add(
        '${index + 1}. ${item.title}\n'
        '🕒 ${formatter.format(item.startsAt)}\n'
        '📍 ${item.location} • 👥 ${_participantsLimitLabel(item.participantsLimit)}',
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

  String bookingReschedulePaidToFreeNotAllowed() {
    return 'Эту запись нельзя перенести на бесплатную тренировку.\n'
        'Платную запись можно переносить только на платные слоты.';
  }

  String bookingReschedulePriceMismatchNotAllowed() {
    return 'Эту запись нельзя перенести на тренировку с другой стоимостью.\n'
        'Перенос доступен только между тренировками с одинаковой ценой.';
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

  String yogaCancellationTooLate(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Отменить запись #${booking.id} уже нельзя ⛔️\n'
        'До начала (${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}) '
        'осталось меньше 24 часов.\n\n'
        '${_yogaContactsHint()}';
  }

  String paymentsQueueEmpty() => 'Очередь подтверждения оплат пока пустая ✨';

  String paymentsQueueIntro(int total, {required ActivityCategory category}) {
    return '🧾 <b>Заявки на подтверждение оплаты</b>\n'
        'Категория: <b>${_escapeHtml(_categoryLabel(category))}</b>\n'
        'Всего ожидают проверки: <b>$total</b>.\n'
        'Ниже отправил каждую заявку отдельным сообщением.';
  }

  String paymentsQueueItem(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final paymentType = _paymentTypeLabelFromNote(booking.paymentNote);
    final cleanNote = _cleanPaymentNote(booking.paymentNote);
    final note = cleanNote == null ? '' : '\nКомментарий: ${_escapeHtml(cleanNote)}';
    return '🧾 <b>Заявка #${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Тренировка: ${_escapeHtml(booking.trainingTitle)}\n'
        '🕒 ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 ${_escapeHtml(booking.location)}'
        '${paymentType == null ? '' : '\nТип оплаты: ${_escapeHtml(paymentType)}'}'
        '$note\n\n'
        'Подтверди или отклони оплату кнопками ниже.\n'
        'После решения можно сразу открыть следующую заявку.';
  }

  String trainingParticipants({
    required List<TrainingInfo> trainings,
    required Map<String, List<TrainingBooking>> bookingsByTrainingKey,
    String title = 'Список записавшихся по тренировкам 👥',
    String emptyText = 'Ближайших тренировок пока нет, показывать список не для чего.',
    bool Function(TrainingBooking booking)? isTrainerBooking,
  }) {
    if (trainings.isEmpty) {
      return emptyText;
    }
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final lines = <String>['<b>${_escapeHtml(title)}</b>'];
    final trainerMatcher = isTrainerBooking ?? (_) => false;
    for (var index = 0; index < trainings.length; index++) {
      final training = trainings[index];
      final tags = bookingsByTrainingKey[training.sessionKey] ?? const <TrainingBooking>[];
      final activeTags =
          tags.where((booking) => booking.status != BookingStatus.cancelled).toList();
      final cancelledTags =
          tags.where((booking) => booking.status == BookingStatus.cancelled).toList();
      final activeTrainerTags = activeTags.where(trainerMatcher).toList(growable: false);
      final activeParticipantTags =
          activeTags.where((booking) => !trainerMatcher(booking)).toList(growable: false);
      final cancelledTrainerTags = cancelledTags.where(trainerMatcher).toList(growable: false);
      final cancelledParticipantTags =
          cancelledTags.where((booking) => !trainerMatcher(booking)).toList(growable: false);
      final displayedParticipantsCount =
          training.includeTrainersInParticipants ? activeTags.length : activeParticipantTags.length;
      lines.addAll(<String>[
        '',
        '🏷 <b>${index + 1}. ${_escapeHtml(training.title)}</b>',
        '🕒 ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}',
        '📍 ${_escapeHtml(training.location)}',
        '👥 Участники: $displayedParticipantsCount/${_participantsLimitValueLabel(training.participantsLimit)}',
      ]);
      if (activeTags.isEmpty && cancelledTags.isEmpty) {
        lines.add('• Пока никто не записался');
      } else {
        if (activeParticipantTags.isNotEmpty) {
          lines.add('👤 Участники:');
        }
        for (final booking in activeParticipantTags) {
          lines.add(
            '• ${_escapeHtml(_userTag(booking))} (${_escapeHtml(_participantStatusLabel(booking))})',
          );
        }
        if (activeTrainerTags.isNotEmpty) {
          lines.add('🧑‍🏫 Тренеры:');
        }
        for (final booking in activeTrainerTags) {
          lines.add(
            '• ${_escapeHtml(_userTag(booking))} (${_escapeHtml(_participantStatusLabel(booking))})',
          );
        }
        if (cancelledParticipantTags.isNotEmpty || cancelledTrainerTags.isNotEmpty) {
          lines.add('❌ Отмененные:');
        }
        for (final booking in cancelledParticipantTags) {
          lines.add(
            '• ${_escapeHtml(_userTag(booking))} (${_escapeHtml(_participantStatusLabel(booking))})',
          );
        }
        for (final booking in cancelledTrainerTags) {
          lines.add(
            '• ${_escapeHtml(_userTag(booking))} (${_escapeHtml(_participantStatusLabel(booking))})',
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
      '🏰 <b>Список дворян</b>',
      'Всего записей на тренировки: <b>$totalTrainings</b>',
      'В зачет идут только уже прошедшие по времени тренировки '
          '(<code>starts_at &lt; now</code>).',
      '',
    ];
    for (var index = 0; index < users.length; index++) {
      final user = users[index];
      lines.add(
        '${index + 1}. ${_escapeHtml(_userTagById(user.userId, username: user.username))} (${user.userId}) — '
        '<b>${user.trainingsCount}</b>',
      );
    }
    return lines.join('\n');
  }

  String adminOnlyAction() {
    return 'Это действие доступно только администраторам 🔒';
  }

  String paymentActionUsage() {
    return '📘 <b>Использование команд модерации:</b>\n'
        '<code>/approve_payment &lt;id&gt;</code>\n'
        '<code>/approve_partial_payment &lt;id&gt;</code>\n'
        '<code>/reject_payment &lt;id&gt;</code>\n\n'
        'Например: <code>/approve_partial_payment 42</code>';
  }

  String paymentReviewResultWithNextStep({
    required TrainingBooking booking,
    required int remaining,
  }) {
    final nextStep = remaining > 0
        ? 'Осталось на проверке: $remaining. Нажми «${MessageCopy.buttonPaymentsQueue}», чтобы открыть следующую заявку.'
        : 'Очередь заявок пуста. Можно вернуться в меню.';
    return '✅ <b>Готово! Статус записи #${booking.id} обновлен</b>\n'
        '${_escapeHtml(_statusLabel(booking.status, booking: booking))}\n'
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
    return '😕 <b>Запись #$id не найдена</b>';
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status, booking: booking)} ✅';
  }

  String paymentAlreadyReviewed(int bookingId) {
    return 'ℹ️ <b>Запись #$bookingId уже не в статусе «На проверке»</b>\n'
        'Обнови очередь и проверь актуальный статус.';
  }

  String adminBookingUpdateConflict() {
    return 'Не удалось сохранить изменения: для этого пользователя уже есть запись на выбранное мероприятие.';
  }

  String paymentInstructions(TrainingBooking booking) {
    if (MessageFormatters.isYogaBooking(booking)) {
      return 'Реквизиты для оплаты:\n'
          '• Получатель: Елена П.\n'
          '• Банк: 🟨 Т-БАНК 🟨\n'
          '• Номер телефона: +7(961)313-11-44\n'
          '• ⏳ Если не оплатить в течение 120 минут, запись отменится автоматически.';
    }
    return 'Реквизиты для оплаты:\n'
        '• Получатель: Денис Р.\n'
        '• Банк: 🟦 OZON БАНК 🟦\n'
        '• Номер телефона: +7(995)122-06-15\n'
        '• ⏳ Если не оплатить в течение 120 минут, запись отменится автоматически.';
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
    return '🧾 <b>Модерация оплаты выполнена</b>\n'
        'Запись: <b>#${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Статус: ${_escapeHtml(_statusLabel(booking.status, booking: booking))}\n'
        'Проверил админ: ${_escapeHtml(_userTagById(moderatorUserId, username: moderatorUsername))} ($moderatorUserId)\n'
        'Дальше: при необходимости открой очередь и проверь следующую заявку.';
  }

  String bookingRescheduledAdminNotification({
    required TrainingBooking before,
    required TrainingBooking after,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '🔁 <b>Операционное событие: перенос записи</b>\n'
        'Запись: <b>#${after.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(after))} (${after.userId})\n'
        'Было: ${_escapeHtml(before.trainingTitle)} (${formatter.format(before.startsAt)})\n'
        'Стало: ${_escapeHtml(after.trainingTitle)} (${formatter.format(after.startsAt)})\n'
        'Дальше: проверь состав участников перед ближайшей тренировкой.';
  }

  String bookingCancelledAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '❌ <b>Операционное событие: отмена записи</b>\n'
        'Запись: <b>#${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Событие: ${_escapeHtml(booking.trainingTitle)}\n'
        'Дата: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Дальше: при необходимости свяжись с участником по возврату/перезаписи.';
  }

  String freeBookingCreatedAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '🎁 <b>Операционное событие: новая бесплатная запись</b>\n'
        'Запись: <b>#${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Событие: ${_escapeHtml(booking.trainingTitle)}\n'
        'Дата: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Статус: ${_escapeHtml(_statusLabel(booking.status, booking: booking))}';
  }

  String trainerBookingCreatedAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '🧑‍🏫 <b>Операционное событие: тренер записался</b>\n'
        'Запись: <b>#${booking.id}</b>\n'
        'Пользователь: ${_escapeHtml(_userTag(booking))} (${booking.userId})\n'
        'Событие: ${_escapeHtml(booking.trainingTitle)}\n'
        'Дата: ${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)}\n'
        'Статус: ${_escapeHtml(_statusLabel(booking.status, booking: booking))}';
  }

  String pendingPaymentReminder(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return 'Напоминание об оплате 💸\n'
        'Запись: #${booking.id}\n'
        '${booking.trainingTitle} (${_bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)})\n'
        'Текущий статус: ${_statusLabel(booking.status, booking: booking)}\n\n'
        '${paymentInstructions(booking)}\n\n'
        'После оплаты нажми «${MessageCopy.buttonSubmitPayment}» и отправь в этот чат файл с подтверждением (чек/скрин).\n'
        'Если кнопка не сработала, открой «${MessageCopy.buttonProfile}» и выбери нужную запись.';
  }

  String pendingPaymentExpired(TrainingBooking booking) {
    return '⏰ Время на оплату истекло.\n'
        'Запись #${booking.id} автоматически отменена.\n'
        'Чтобы попасть на мероприятие, оформи новую запись через «${MessageCopy.buttonBookTraining}».';
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
        '${index + 1}. ${item.title}\n'
        '🕒 ${_trainingDateLabel(item, dateTimeFormatter, dateOnlyFormatter)}\n'
        '📍 ${item.location}$feeLabel\n'
        '👥 ${_participantsLimitLabel(item.participantsLimit)}',
      );
    }
    return <String>[
      ...lines,
      eventLines.join('\n\n'),
    ].join('\n');
  }

  String paymentDetailsSent(TrainingBooking booking) {
    if (!MessageFormatters.isOutdoorBooking(booking)) {
      final yogaHint = MessageFormatters.isYogaBooking(booking) ? '\n\n${_yogaContactsHint()}' : '';
      return '${paymentInstructions(booking)}\n\n'
          'Когда переведешь оплату, нажми «${MessageCopy.buttonSubmitPayment}» '
          'и отправь в этот чат файл с подтверждением (чек/скрин) 📎\n\n'
          'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.'
          '$yogaHint';
    }

    return '${paymentInstructions(booking)}\n\n'
        'Правило Outdvor 🚸\n\n'
        '• Предоплата невозвратна при отмене за 7 дней и менее до трейла/похода🦥\n\n'
        'Это не штраф, а уважение к общим расходам на логистику, планирование '
        'тренировки и трансфер. Такие мероприятия любят сильных и решительных. Спасибо за понимание. 💚💪\n'
        '\n\n'
        'Когда переведешь оплату, нажми «${MessageCopy.buttonSubmitPayment}» '
        'и отправь в этот чат файл с подтверждением (чек/скрин) 📎\n\n'
        'ВАЖНО: без файла подтверждения мы не сможем отправить заявку на проверку.';
  }

  String _yogaContactsHint() {
    return 'По вопросам теории и практики можно написать тренеру-йоги.\n'
        'По организационным вопросам: @dvor_support.';
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
      '📈 <b>Экономическая сводка ${_escapeHtml(periodLabel ?? 'по периоду')}</b>',
      'Период: <b>$periodRange</b>',
      '',
      '<b>Финансы:</b>',
      '• Выручка: <b>${_money(summary.totalRevenue)}</b>',
      '• Платных бронирований: <b>${summary.paidBookingsCount}</b>',
      '• Средний чек: <b>${_money(summary.averageCheck)}</b>',
      if (summary.freeBookingsCount > 0)
        '• Бесплатных бронирований: <b>${summary.freeBookingsCount}</b>',
      if (summary.regularFreeBookingsCount > 0)
        '• Бесплатные по цене мероприятия: <b>${summary.regularFreeBookingsCount}</b>',
      if (summary.starterFreeBookingsCount > 0)
        '• Бесплатные стартовые: <b>${summary.starterFreeBookingsCount}</b>',
      if (summary.everyFifthFreeBookingsCount > 0)
        '• Бесплатные по правилу «каждая 5-я»: <b>${summary.everyFifthFreeBookingsCount}</b>',
      if (summary.unknownPriceBookingsCount > 0)
        '• Без цены в данных: <b>${summary.unknownPriceBookingsCount}</b>',
      '',
      '<b>По категориям:</b>',
      if (summary.byCategory.isEmpty) '• Нет оплаченных бронирований с ценой',
      ...summary.byCategory.map(
        (item) => '• ${_escapeHtml(_categoryLabel(item.category))}: '
            '<b>${_money(item.revenue)}</b> (${item.bookingsCount})',
      ),
      '',
      '<b>Топ мероприятий по выручке:</b>',
      if (summary.byEvent.isEmpty) '• Нет данных',
      ...summary.byEvent.map(
        (item) => '• ${_escapeHtml(item.eventTitle)}: '
            '<b>${_money(item.revenue)}</b> (${item.bookingsCount})',
      ),
    ];
    return lines.join('\n');
  }

  String chooseEconomicSummaryPeriod() {
    return '📅 <b>Выбери период для экономической сводки</b>';
  }

  Map<String, Object?> privateMenuKeyboard({
    required bool isAdmin,
    bool canViewParticipantsList = false,
  }) {
    return TelegramKeyboards.privateMenuKeyboard(
      isAdmin: isAdmin,
      canViewParticipantsList: canViewParticipantsList,
    );
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
    required int yoga,
    required int hikes,
    required int trails,
  }) {
    return TelegramKeyboards.categorySelectionKeyboard(
      trainingsLabel: _labelWithCount(MessageCopy.buttonCategoryTrainings, trainings),
      yogaLabel: _labelWithCount(MessageCopy.buttonCategoryYoga, yoga),
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

  Map<String, Object?> profileActionsKeyboard() {
    return TelegramKeyboards.profileActionsKeyboard();
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

  String _trainingLocationLabel(TrainingInfo training) {
    final location = training.location.trim();
    if (_isOutdoorCategory(training.category)) {
      return _escapeHtml(location);
    }
    final locationUrl = training.locationUrl?.trim();
    if (locationUrl != null && locationUrl.isNotEmpty) {
      return _locationAnchor(label: location, url: locationUrl);
    }
    return _locationAnchor(label: location, url: _mapsSearchUrl(location));
  }

  String _bookingLocationLabel(TrainingBooking booking) {
    final location = booking.location.trim();
    if (MessageFormatters.isOutdoorBooking(booking)) {
      return _escapeHtml(location);
    }
    return _locationAnchor(label: location, url: _mapsSearchUrl(location));
  }

  String _locationAnchor({
    required String label,
    required String url,
  }) {
    final escapedUrl = _escapeHtml(url);
    final escapedLabel = _escapeHtml(label);
    return '<a href="$escapedUrl">$escapedLabel</a>';
  }

  String _mapsSearchUrl(String location) {
    final query = Uri.encodeComponent(location);
    return 'https://www.google.com/maps/search/?api=1&query=$query';
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

  String _groupLowSpotsTitle(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'На тренировке почти не осталось мест!',
      ActivityCategory.yoga => 'На йоге почти не осталось мест!',
      ActivityCategory.hikes => 'В походе почти не осталось мест!',
      ActivityCategory.trails => 'На трейле почти не осталось мест!',
    };
  }

  String _groupNoSpotsTitle(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'Места на эту тренировку закончились',
      ActivityCategory.yoga => 'Места на эту йогу закончились',
      ActivityCategory.hikes => 'В походе не осталось мест',
      ActivityCategory.trails => 'На трейле не осталось мест',
    };
  }

  bool _isOutdoorCategory(ActivityCategory category) {
    return category == ActivityCategory.hikes || category == ActivityCategory.trails;
  }

  String? _botDeepLink() {
    final botUsername = _botUsername;
    if (botUsername == null || botUsername.isEmpty) {
      return null;
    }
    return 'https://t.me/$botUsername?start=start';
  }

  String _categoryLabel(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => 'Тренировки',
      ActivityCategory.yoga => 'Йога',
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

  String _participantsLimitValueLabel(int? participantsLimit) {
    if (participantsLimit == null || participantsLimit <= 0) {
      return '∞';
    }
    return '$participantsLimit';
  }

  String _money(int amount) {
    return '$amount ₽';
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

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
