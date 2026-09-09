part of '../message_templates.dart';

extension MessageTemplatesContent on MessageTemplates {
  String trainings(
    List<TrainingInfo> items, {
    List<TrainerInfo> trainers = const <TrainerInfo>[],
  }) {
    return _scheduleTemplates.trainings(items, trainers: trainers);
  }

  String hikes(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.hikes(items);
  }

  String trails(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.trails(items);
  }

  String hikesEquipment(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.hikesEquipment(items);
  }

  String trailsEquipment(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.trailsEquipment(items);
  }

  String hikesItinerary(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.hikesItinerary(items);
  }

  String trailsItinerary(List<OutdoorActivityInfo> items) {
    return _scheduleTemplates.trailsItinerary(items);
  }

  String outdoorPostPaymentRecap(OutdoorActivityInfo item) {
    return _scheduleTemplates.outdoorPostPaymentRecap(item);
  }

  String chooseOutdoorEventForDetails(ActivityCategory category) {
    return _scheduleTemplates.chooseOutdoorEventForDetails(category);
  }

  String chooseOutdoorDetailType(OutdoorActivityInfo item) {
    return _scheduleTemplates.chooseOutdoorDetailType(item);
  }

  String unknownOutdoorSelection() {
    return _scheduleTemplates.unknownOutdoorSelection();
  }

  String outdoorEquipmentDetails(OutdoorActivityInfo item) {
    return _scheduleTemplates.outdoorEquipmentDetails(item);
  }

  String outdoorItineraryDetails(OutdoorActivityInfo item) {
    return _scheduleTemplates.outdoorItineraryDetails(item);
  }

  String chooseScheduleCategory() {
    return _scheduleTemplates.chooseScheduleCategory();
  }

  String coachingStaff(List<TrainerInfo> trainers) {
    return _scheduleTemplates.coachingStaff(trainers);
  }

  String chooseTrainerProfile(List<TrainerInfo> trainers) {
    return _scheduleTemplates.chooseTrainerProfile(trainers);
  }

  String trainerProfile(TrainerInfo trainer) {
    return _scheduleTemplates.trainerProfile(trainer);
  }

  String unknownTrainerSelection() {
    return _scheduleTemplates.unknownTrainerSelection();
  }

  String chooseBookingCategory() {
    return RichHtml.screen(
      title: 'Запись',
      lead: 'Выбери категорию для записи.',
    );
  }

  String unknownCategory() {
    return RichHtml.screen(
      title: 'Не понял категорию',
      lead: 'Тренировки, походы или трейлы — кнопками внизу.',
    );
  }

  String chooseParticipantsCategory() {
    return RichHtml.screen(
      title: 'Список записавшихся',
      lead: 'Выбери категорию ниже.',
    );
  }

  String choosePaymentsQueueCategory() {
    return RichHtml.screen(
      title: 'Очередь заявок на оплату',
      lead: 'Выбери категорию ниже.',
      paragraphs: <String>[
        'После проверки каждой заявки можно сразу перейти к следующей.',
      ],
    );
  }

  String chooseBookingManagementAction() {
    return RichHtml.screen(
      title: 'Управление записями',
      lead: 'Выбери действие кнопками внизу.',
    );
  }

  String chooseBookingListSegment() {
    return RichHtml.screen(
      title: 'Какой список открыть?',
      lead: '«Актуальные» — текущие записи, «Прошедшие» — завершённые и отменённые.',
    );
  }

  String chooseBookingManagementCategory() {
    return RichHtml.screen(
      title: 'Категория мероприятий',
      lead: 'Выбери категорию для управления.',
    );
  }

  String chooseAdminBookingFromList(
    List<TrainingBooking> bookings, {
    required bool archived,
    ActivityCategory? category,
    required int page,
    required int totalPages,
    required int totalCount,
  }) {
    final segmentLabel = archived ? 'Прошедшие' : 'Актуальные';
    final categoryLabel = category == null ? 'не выбрана' : _categoryLabel(category);
    if (bookings.isEmpty) {
      return RichHtml.screen(
        title: 'Список пуст для выбранных фильтров',
        rows: <(String, String)>[
          ('Сегмент', segmentLabel),
          ('Категория', categoryLabel),
        ],
      );
    }
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Список записей для управления'))
      ..write(
        RichHtml.table(
          <(String, String)>[
            ('Фильтр', '$segmentLabel • $categoryLabel'),
            ('Страница', '$page/$totalPages'),
            ('Всего записей', '$totalCount'),
          ],
        ),
      )
      ..write(RichHtml.paragraph('Записи на текущей странице:'));
    for (var index = 0; index < bookings.length; index++) {
      final booking = bookings[index];
      buffer.write(
        RichHtml.details(
          summary: '${index + 1}. #${booking.id} ${booking.trainingTitle}',
          body: RichHtml.table(
            <(String, String)>[
              ..._adminBookingIdentityRows(booking),
              ('Когда', dateFormatter.format(booking.startsAt)),
              ('Статус', _statusLabel(booking.status, booking: booking)),
            ],
          ),
          alreadyEscaped: true,
        ),
      );
    }
    buffer
      ..write(RichHtml.paragraph('Выбери запись кнопкой ниже.'))
      ..write(
        RichHtml.paragraph(
          'Чтобы сменить фильтры, нажми «${MessageCopy.buttonBack}».',
        ),
      );
    return buffer.toString();
  }

  String adminBookingActions(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Запись #${booking.id}',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Событие', booking.trainingTitle),
        ('Дата', formatter.format(booking.startsAt)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
      paragraphs: <String>['Выбери действие кнопками в сообщении.'],
    );
  }

  String chooseAdminBookingEditField(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Что изменить в записи #${booking.id}?',
    );
  }

  String chooseAdminBookingPaymentStatus(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Новый статус оплаты',
      lead: 'Запись #${booking.id}',
    );
  }

  String adminBookingAskUsername(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Username пользователя',
      lead: 'Отправь username для записи #${booking.id} (можно с @ или без).',
    );
  }

  String invalidUsernameInput() {
    return RichHtml.screen(
      title: 'Не распознал username',
      lead: 'Нужен формат @username или username (без пробелов).',
    );
  }

  String adminBookingUsernameUpdated(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Готово',
      lead: 'Пользователь для записи #${booking.id}: ${_userTag(booking)}',
    );
  }

  String adminBookingEventUpdated(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Событие для записи #${booking.id} обновлено',
      paragraphs: <String>[
        booking.trainingTitle,
        formatter.format(booking.startsAt),
      ],
    );
  }

  String adminBookingPaymentStatusUpdated(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Статус записи #${booking.id} обновлен',
      lead: _statusLabel(booking.status, booking: booking),
    );
  }

  String adminBookingDeleteConfirm(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Удалить запись #${booking.id}?',
      lead: 'Запись перейдет в архив со статусом «Отменена».',
    );
  }

  String adminBookingDeleted(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Запись #${booking.id} переведена в архив',
    );
  }

  String adminBookingDeletedForUser(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Запись #${booking.id} отменили',
      paragraphs: <String>[
        booking.trainingTitle,
        _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter),
        'Если есть вопросы — @dvor_support.',
      ],
    );
  }

  String adminBookingRestoredForUser(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Запись #${booking.id} восстановили',
      paragraphs: <String>[
        booking.trainingTitle,
        _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter),
      ],
    );
  }

  String adminBookingPaymentStatusUpdatedForUser(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Статус записи #${booking.id} обновили',
      lead: 'Новый статус: ${_statusLabel(booking.status, booking: booking)}',
    );
  }

  String adminBookingUsernameUpdatedForUser(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Данные пользователя в записи #${booking.id} обновили',
      lead: 'Теперь запись привязана к: ${_userTag(booking)} (${booking.userId}).',
    );
  }

  String adminBookingEventUpdatedForUser(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Администратор изменил мероприятие для твоей записи #${booking.id}',
      paragraphs: <String>[
        booking.trainingTitle,
        _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter),
      ],
    );
  }

  String adminBookingCreatedForUser(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Администратор создал для тебя запись #${booking.id}',
      paragraphs: <String>[
        booking.trainingTitle,
        _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter),
        'Статус: ${_statusLabel(booking.status, booking: booking)}',
      ],
    );
  }

  String adminBookingRestored(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Запись #${booking.id} восстановлена',
    );
  }

  String adminBookingRestoreNotAllowed(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Запись #${booking.id} нельзя восстановить',
      lead: 'Мероприятие уже прошло.',
    );
  }

  String chooseCreateBookingCategory() {
    return RichHtml.screen(
      title: 'Создание записи',
      lead: 'Выбери категорию.',
    );
  }

  String chooseCreateBookingEvent(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return RichHtml.screen(
        title: 'Нет мероприятий',
        lead: 'В выбранной категории нет доступных мероприятий для записи.',
      );
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer()..write(RichHtml.heading('Выбери мероприятие для новой записи'));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('${index + 1}', item.title),
            ('Когда', formatter.format(item.startsAt)),
            ('Где', item.location),
            ('Участники', _participantsLimitLabel(item.participantsLimit)),
          ],
        ),
      );
    }
    return buffer.toString();
  }

  String createBookingAskUsername() {
    return RichHtml.screen(
      title: 'Username для новой записи',
      lead: 'Введи username пользователя (можно с @ или без).',
      paragraphs: <String>[
        'Чтобы записать несколько человек сразу, перечисли username через запятую: user1, user2, user3',
      ],
    );
  }

  String chooseCreateBookingPaymentStatus() {
    return RichHtml.screen(
      title: 'Стартовый статус оплаты',
      lead: 'Выбери вариант.',
    );
  }

  String createBookingPreview({
    required TrainingInfo training,
    required List<String> usernames,
    required BookingStatus status,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final usersLine = usernames.map((u) => '@$u').join(', ');
    final title = usernames.length == 1
        ? 'Проверь данные новой записи'
        : 'Проверь данные новых записей (${usernames.length} чел.)';
    return RichHtml.screen(
      title: title,
      rows: <(String, String)>[
        ('Пользователи', usersLine),
        ('Событие', training.title),
        ('Дата', formatter.format(training.startsAt)),
        ('Локация', training.location),
        ('Статус', _statusLabel(status)),
      ],
    );
  }

  String adminBookingsCreatedBatch({
    required List<TrainingBooking> created,
    required List<String> conflicts,
  }) {
    final buffer = StringBuffer();
    if (created.isNotEmpty) {
      buffer.write(RichHtml.heading('Записи созданы (${created.length} чел.)'));
      buffer.write(
        RichHtml.bullets(
          created.map((b) => '#${b.id} — ${_userTag(b)}').toList(growable: false),
        ),
      );
    }
    if (conflicts.isNotEmpty) {
      buffer.write(
          RichHtml.heading('Конфликт (уже есть запись): ${conflicts.length} чел.', level: 3));
      buffer.write(
        RichHtml.bullets(
          conflicts.map((u) => '@$u').toList(growable: false),
        ),
      );
    }
    return buffer.toString();
  }

  String adminBookingCreated(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Запись #${booking.id} создана',
    );
  }

  String askAdminClientNotificationPreference({
    required TrainingBooking booking,
    required String actionLabel,
  }) {
    return RichHtml.screen(
      title: 'Уведомить клиента?',
      lead: 'Запись #${booking.id}: $actionLabel',
    );
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

  String groupTrainingTodayPromo({
    required TrainingInfo training,
    bool isToday = true,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final when = isToday ? 'Сегодня' : 'Завтра';
    final notes = training.notes?.trim();
    return '${RichHtml.heading('$when: ${training.title}')}'
        '${RichHtml.paragraph('🕒 ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}')}'
        '${RichHtml.paragraph('📍 ${_trainingLocationLabel(training)}', alreadyEscaped: true)}'
        '${notes == null || notes.isEmpty ? '' : RichHtml.paragraph('📝 ${_escapeHtml(notes)}', alreadyEscaped: true)}'
        '${RichHtml.paragraph('Запись в боте, в пару тапов')}'
        '${RichHtml.paragraph(_groupBookingCta(), alreadyEscaped: true)}';
  }

  String groupScheduleBroadcast({
    required List<TrainingInfo> trainings,
    required int weekday,
  }) {
    return _groupTemplates.groupScheduleBroadcast(
      trainings: trainings,
      weekday: weekday,
    );
  }

  String groupReferralBroadcast() {
    return _groupTemplates.groupReferralBroadcast();
  }

  String scheduleRefreshDone({bool exportQueued = false}) {
    return _scheduleTemplates.scheduleRefreshDone(exportQueued: exportQueued);
  }

  String scheduleRefreshFailed({bool exportQueued = false}) {
    return _scheduleTemplates.scheduleRefreshFailed(exportQueued: exportQueued);
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
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Запись создана'))
      ..write(RichHtml.paragraph('Отлично, записал тебя.'))
      ..write(
        RichHtml.table(
          <(String, String)>[
            ('Статус', _escapeHtml(_statusLabel(booking.status, booking: booking))),
            ('Номер', '#${booking.id}'),
            ('Событие', _escapeHtml(_bookingTitleLine(booking))),
            ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
            ('📍 Где', _bookingLocationLabel(booking)),
          ],
          alreadyEscaped: true,
        ),
      )
      ..write(paymentDetailsSent(booking));
    return buffer.toString();
  }

  String bookingSlotPrepNotes({required String trainingTitle, required String notes}) {
    return 'Что взять на «${_escapeHtml(trainingTitle)}»:\n${_escapeHtml(notes)}';
  }

  String bookingCreatedWithoutPayment(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Запись создана',
      lead: 'Отлично, записал тебя.',
      rows: <(String, String)>[
        ('Статус', _escapeHtml(_statusLabel(booking.status, booking: booking))),
        ('Номер', '#${booking.id}'),
        ('Событие', _escapeHtml(booking.trainingTitle)),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('📍 Где', _bookingLocationLabel(booking)),
      ],
      paragraphs: <String>['Это бесплатная тренировка, чек не нужен.'],
      alreadyEscaped: true,
    );
  }

  String bookingCreatedForWhitelistedTrainer(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Запись создана',
      lead: 'Ты в тренерском штабе DVOR — слот без оплаты.',
      rows: <(String, String)>[
        ('Статус', _escapeHtml(_statusLabel(booking.status, booking: booking))),
        ('Номер', '#${booking.id}'),
        ('Событие', _escapeHtml(booking.trainingTitle)),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('📍 Где', _bookingLocationLabel(booking)),
      ],
      alreadyEscaped: true,
    );
  }

  String bookingCreatedForDvorTeamMember(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Запись создана',
      lead: 'Ты в команде DVOR — слот без оплаты.',
      rows: <(String, String)>[
        ('Статус', _escapeHtml(_statusLabel(booking.status, booking: booking))),
        ('Номер', '#${booking.id}'),
        ('Событие', _escapeHtml(booking.trainingTitle)),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('📍 Где', _bookingLocationLabel(booking)),
      ],
      alreadyEscaped: true,
    );
  }

  String bookingAlreadyExists(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Уже на слоте',
      lead: 'Эта тренировка уже в твоих записях.',
      rows: <(String, String)>[
        ('Номер', '#${booking.id}'),
        ('Статус', _statusLabel(booking.status, booking: booking)),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
      ],
    );
  }

  String bookingParticipantsLimitExceeded() {
    return RichHtml.screen(
      title: 'Мест нет',
      lead: 'На этом слоте свободных мест больше нет.',
      paragraphs: <String>['Другое мероприятие — в расписании.'],
    );
  }

  String groupTrainingLowSpots({
    required TrainingInfo training,
    required int freeSpots,
    required int participantsLimit,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '${RichHtml.heading(_groupLowSpotsTitle(training.category))}'
        '${RichHtml.paragraph(training.title)}'
        '${RichHtml.paragraph('🕒 Когда: ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}')}'
        '${RichHtml.paragraph('📍 Где: ${_trainingLocationLabel(training)}', alreadyEscaped: true)}'
        '${RichHtml.paragraph('👥 Свободных мест: $freeSpots из $participantsLimit')}'
        '${RichHtml.paragraph(_groupBookingCta(), alreadyEscaped: true)}';
  }

  String groupTrainingNoSpotsLeft({
    required TrainingInfo training,
    required int participantsLimit,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '${RichHtml.heading(_groupNoSpotsTitle(training.category))}'
        '${RichHtml.paragraph(training.title)}'
        '${RichHtml.paragraph('🕒 Когда: ${_trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)}')}'
        '${RichHtml.paragraph('📍 Где: ${_trainingLocationLabel(training)}', alreadyEscaped: true)}'
        '${RichHtml.paragraph('👥 Участников: $participantsLimit/$participantsLimit')}'
        '${RichHtml.paragraph('Другие слоты — в боте.')}'
        '${RichHtml.paragraph(_groupBookingCta(), alreadyEscaped: true)}';
  }

  String paymentSubmitted(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Чек на проверке',
      lead: 'Чек отправил на проверку.',
      rows: <(String, String)>[
        ('Номер записи', '${booking.id}'),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
      paragraphs: <String>['Дальше: дождись ответа — бот напишет сам.'],
    );
  }

  String chooseOutdoorPaymentType({int? prepayPercent}) {
    final percent = MessageFormatters.resolveOutdoorPrepayPercent(prepayPercent);
    return RichHtml.screen(
      title: 'Тип оплаты',
      lead: 'Выбери тип оплаты.',
      bullets: <String>[
        '«${MessageCopy.buttonPayFully}» — полная сумма',
        '«${MessageCopy.buttonPayPartially}» — предоплата $percent%',
      ],
      paragraphs: <String>[
        'После выбора пришли файл с подтверждением оплаты (документ или фото чека).',
      ],
    );
  }

  String paymentSubmittedAdminNotification(
    TrainingBooking booking, {
    List<TrainingBooking> groupBookings = const <TrainingBooking>[],
  }) {
    final organizer = _userTagById(booking.managerUserId, username: booking.userUsername);
    final members = groupBookings.isNotEmpty ? groupBookings : <TrainingBooking>[booking];
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Новое подтверждение оплаты'))
      ..write(RichHtml.paragraph('Пришла новая заявка на проверку оплаты.'))
      ..write(
        RichHtml.table(
          <(String, String)>[
            ('Мероприятие', booking.trainingTitle),
            ('Организатор', '$organizer (${booking.managerUserId})'),
            if (members.length > 1) ('Участников', '${members.length}'),
          ],
        ),
      );
    if (members.length > 1) {
      final total = members.fold<int>(0, (sum, item) => sum + (item.trainingPrice ?? 0));
      final unit = booking.trainingPrice ?? 0;
      buffer
        ..write(
          RichHtml.details(
            summary: 'Участники',
            body: RichHtml.bullets(
              members
                  .map((member) => '#${member.id} ${member.participantDisplayLabel}')
                  .toList(growable: false),
            ),
            alreadyEscaped: true,
          ),
        )
        ..write(
          RichHtml.paragraph(
            'К оплате: ${members.length} × ${_trainingPriceLabel(unit)} = ${_trainingPriceLabel(total)}',
          ),
        )
        ..write(RichHtml.paragraph('Пакетная оплата: подтверждение закроет все записи группы.'));
    } else {
      buffer.write(RichHtml.table(_adminBookingIdentityRows(booking)));
    }
    buffer.write(RichHtml.paragraph('Нажми кнопку ниже, чтобы открыть очередь заявок.'));
    return buffer.toString();
  }

  String starterBonusApplied(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Бесплатная тренировка активирована',
      lead: 'Готово, стартовый бонус применён.',
      rows: <(String, String)>[
        ('Запись', '#${booking.id}'),
        ('Тренировка', booking.trainingTitle),
        ('🕒 Когда', formatter.format(booking.startsAt)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
    );
  }

  String starterBonusUnavailable() {
    return 'Стартовый бонус уже недоступен. Продолжай запись по стандартному сценарию оплаты 💪';
  }

  String promoCodeEntryPrompt() {
    return 'Введи текст промокода 🎟\n'
        'Отправь его следующим сообщением или нажми «${MessageCopy.buttonBack}», чтобы отменить.';
  }

  String promoCodeUnavailable() {
    return 'Промокод сейчас недоступен для этой записи.';
  }

  String promoCodeInvalid() {
    return 'Такого промокода не нашел или он больше не действует 🤔\n'
        'Проверь текст и попробуй еще раз, либо продолжи оплату без промокода.';
  }

  String promoCodeNotApplicableToCategory() {
    return 'Этот промокод не действует для выбранного типа мероприятий.\n'
        'Проверь условия промокода или продолжи оплату без него.';
  }

  String promoCodeAlreadyUsed() {
    return 'Этот промокод уже был использован и больше не действует 🙅\n'
        'Попробуй другой промокод или продолжи оплату без него.';
  }

  String promoCodeApplied(TrainingBooking booking, {required int originalPrice}) {
    final percent = booking.promoDiscountPercent ?? 0;
    final newPrice = booking.trainingPrice ?? 0;
    return '${RichHtml.screen(
      title: 'Промокод применён',
      rows: <(String, String)>[
        ('Промокод', booking.promoCode ?? ''),
        ('Скидка', '−$percent%'),
        ('Было', _trainingPriceLabel(originalPrice)),
        ('К оплате', _trainingPriceLabel(newPrice)),
      ],
    )}${paymentDetailsSent(booking)}';
  }

  String promoCodeAppliedFree(TrainingBooking booking, {required int originalPrice}) {
    return RichHtml.screen(
      title: 'Промокод применён',
      lead: 'Запись #${booking.id} бесплатна, подтверждение оплаты не нужно.',
      rows: <(String, String)>[
        ('Промокод', booking.promoCode ?? ''),
        ('Скидка', '−100%'),
        ('Было', _trainingPriceLabel(originalPrice)),
      ],
    );
  }

  String loyaltyCredited({
    required int amount,
    required int remaining,
    required LoyaltyLedgerReason reason,
  }) {
    final reasonText = switch (reason) {
      LoyaltyLedgerReason.start => 'за старт бота',
      LoyaltyLedgerReason.training => 'за тренировку',
      LoyaltyLedgerReason.feedback => 'за отзыв',
      LoyaltyLedgerReason.hike => 'за поход',
      LoyaltyLedgerReason.trail => 'за трейл',
      LoyaltyLedgerReason.referral => 'за приглашение',
      LoyaltyLedgerReason.boxingCard => 'за бокс-карту',
      LoyaltyLedgerReason.refund => 'возврат',
      LoyaltyLedgerReason.adminGrant => 'начисление',
      LoyaltyLedgerReason.migration => 'перенос',
      LoyaltyLedgerReason.expire ||
      LoyaltyLedgerReason.spend ||
      LoyaltyLedgerReason.adminDebit =>
        '',
    };
    final reasonSuffix = reasonText.isEmpty ? '' : ' $reasonText';
    return RichHtml.screen(
      title: 'Вершинки',
      lead: '+$amount ⛰️$reasonSuffix. Баланс: $remaining.',
      paragraphs: <String>[
        'Живут 45 дней, срок обновляется, когда ты записываешься или стартуешь бота.',
      ],
    );
  }

  String loyaltyStartCredited({required bool starterBonusAvailable}) {
    return RichHtml.screen(
      title: 'Вершинки',
      lead: '+1000 ⛰️ за первый старт бота.',
      paragraphs: <String>[
        'Живут 45 дней, срок обновляется от записи, оплаты, отзыва и /start.',
        if (starterBonusAvailable)
          'Стартовая бесплатная тренировка по-прежнему отдельно — '
              'её можно взять кнопкой «${MessageCopy.buttonUseStarterBonus}».',
      ],
    );
  }

  String loyaltyExpiryReminder({
    required int remaining,
    required DateTime expiresAt,
  }) {
    final day = DateFormat('dd.MM').format(expiresAt.toLocal());
    return RichHtml.screen(
      title: 'Вершинки',
      lead: '$remaining ⛰️ сгорят $day, если не будет записи или другой активности.',
      paragraphs: <String>['Можно списать при следующей записи.'],
    );
  }

  String loyaltyExpired({
    required int burned,
    required int remaining,
  }) {
    return RichHtml.screen(
      title: 'Вершинки',
      lead: 'Сгорели $burned ⛰️. Баланс: $remaining.',
    );
  }

  String loyaltySpendApplied({
    required int peaks,
    required int remainderRub,
    required bool coversFully,
  }) {
    if (coversFully) {
      return RichHtml.screen(
        title: 'Вершинки списаны',
        lead: 'Списал $peaks ⛰️. Запись оплачена, чек не нужен.',
        rows: <(String, String)>[('Статус', 'оплачено')],
      );
    }
    return RichHtml.screen(
      title: 'Вершинки списаны',
      lead: 'Списал $peaks ⛰️. К оплате: $remainderRub ₽.',
      paragraphs: <String>['Дальше: переведи остаток и пришли чек в этот чат.'],
    );
  }

  String loyaltyOutdoorSpendApplied({
    required int peaks,
    required int remainderRub,
  }) {
    return RichHtml.screen(
      title: 'Вершинки списаны',
      lead: 'Скидка $peaks ⛰️ (не полная оплата). К оплате: $remainderRub ₽.',
      paragraphs: <String>['Дальше: переведи остаток и пришли чек в этот чат.'],
    );
  }

  String loyaltySpendQuoteLine({
    required int peaks,
    required int remainderRub,
    required bool outdoor,
  }) {
    if (outdoor) {
      return RichHtml.paragraph('Списать $peaks ⛰️ — скидка до 30%, остаток $remainderRub ₽.');
    }
    if (remainderRub <= 0) {
      return RichHtml.paragraph('Списать $peaks ⛰️ — закроет запись целиком, без чека.');
    }
    return RichHtml.paragraph('Списать $peaks ⛰️, остаток $remainderRub ₽.');
  }

  String loyaltyCardSpendApplied({
    required int peaks,
    required int remainderRub,
    required bool coversFully,
  }) {
    if (coversFully) {
      return RichHtml.screen(
        title: 'Вершинки списаны',
        lead: 'Списал $peaks ⛰️. Карта активна, чек не нужен.',
      );
    }
    return RichHtml.screen(
      title: 'Вершинки списаны',
      lead: 'Списал $peaks ⛰️. К оплате: $remainderRub ₽.',
      paragraphs: <String>['Дальше: переведи остаток и пришли чек в этот чат.'],
    );
  }

  String loyaltyUnavailable() {
    return RichHtml.screen(
      title: 'Вершинки',
      lead: 'Сейчас списать вершинки нельзя.',
      paragraphs: <String>[
        'Проверь баланс в профиле или дождись, пока запись будет ждать оплату.',
      ],
    );
  }

  String loyaltyAdminCommandUsage() {
    return RichHtml.screen(
      title: 'Формат',
      lead: '/loyalty_grant userId 50 или /loyalty_debit userId 50',
    );
  }

  String loyaltyAdminOverview({
    required int userId,
    required LoyaltyAccount account,
    required List<LoyaltyLedgerEntry> recent,
  }) {
    final expires = account.expiresAt();
    final expiresLabel = expires == null ? '—' : DateFormat('dd.MM.yyyy').format(expires.toLocal());
    final ledgerBody = recent.isEmpty
        ? RichHtml.paragraph('пусто')
        : RichHtml.bullets(recent.map(_loyaltyLedgerLine).toList(growable: false));
    return '${RichHtml.screen(
      title: 'Вершинки',
      rows: <(String, String)>[
        ('Пользователь', 'id $userId'),
        ('Баланс', '${account.remaining}'),
        ('Сгорают', expiresLabel),
      ],
    )}${RichHtml.details(
      summary: 'Лента',
      body: ledgerBody,
      alreadyEscaped: true,
    )}${RichHtml.paragraph(
      '<code>/loyalty_grant $userId 50</code>',
      alreadyEscaped: true,
    )}${RichHtml.paragraph(
      '<code>/loyalty_debit $userId 50</code>',
      alreadyEscaped: true,
    )}';
  }

  String loyaltyAdminMutationResult({
    required int userId,
    required int amount,
    required int remaining,
    required bool granted,
  }) {
    final verb = granted ? 'Начислил' : 'Списал';
    return RichHtml.screen(
      title: 'Вершинки',
      lead: '$verb $amount ⛰️ пользователю $userId. Баланс: $remaining.',
    );
  }

  String loyaltyAdminAmountInvalid() {
    return 'Сумма должна быть кратна 50 ⛰️.';
  }

  String referralBonusAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Бесплатная запись по реферальной программе',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Тренировка', booking.trainingTitle),
        ('Когда', formatter.format(booking.startsAt)),
      ],
    );
  }

  String starterBonusExpiryReminder({required DateTime expiresAt}) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Стартовый бонус',
      lead: 'Бесплатная тренировка за старт действует до ${formatter.format(expiresAt)}.',
      paragraphs: <String>[
        'Чтобы использовать — «${MessageCopy.buttonBookTraining}», '
            'затем «${MessageCopy.buttonUseStarterBonus}».',
      ],
    );
  }

  String starterBonusAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Стартовая бесплатная запись',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Тренировка', booking.trainingTitle),
        ('Когда', formatter.format(booking.startsAt)),
        ('Формат', 'бесплатная тренировка за старт'),
      ],
    );
  }

  String promoCodeAdminNotification(TrainingBooking booking) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Применён промокод',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Тренировка', booking.trainingTitle),
        ('Когда', formatter.format(booking.startsAt)),
        (
          'Промокод',
          '${booking.promoCode ?? ''} (−${booking.promoDiscountPercent ?? 0}%)',
        ),
        ('Сумма к оплате', _trainingPriceLabel(booking.trainingPrice)),
      ],
    );
  }

  String noPendingPayment() {
    return 'Не нашел активной записи, по которой можно отправить оплату 🤔\n'
        'Проверь «${MessageCopy.buttonProfile}» или создай новую запись.\n'
        'Если запись уже отменилась по таймеру — оформи её заново.';
  }

  String paymentSubmittedAlreadyPending() {
    return 'Уже получил подтверждение оплаты — заявка на проверке ✅\n'
        'Дождись результата модерации, бот сообщит автоматически.';
  }

  String choosePendingPaymentBooking(List<TrainingBooking> bookings) {
    return 'У тебя несколько записей, ожидающих оплату 💸\n'
        'Выбери, по какой отправить подтверждение 👇';
  }

  String partialPaidRemainderOffline(TrainingBooking booking) {
    final outdoorFinalPaymentAfter = _outdoorFinalPaymentAfterLabel(booking);
    return 'Предоплату по записи #${booking.id} уже зафиксировали 🟡\n'
        'Остаток вносится офлайн $outdoorFinalPaymentAfter — через бота доплата не нужна.\n'
        'Если есть вопросы: @dvor_support.';
  }

  String profileOverview({
    required int totalBookings,
    required int activeBookings,
    required int visitedBookings,
    required int cancelledBookings,
    required int loyaltyRemaining,
    DateTime? loyaltyExpiresAt,
    required List<LoyaltyLedgerEntry> loyaltyRecent,
    required int successfulReferralsCount,
    required bool starterBonusAvailable,
    required MembershipLevel membershipLevel,
    BoxingCardPlan? subscriptionPlan,
    DateTime? subscriptionActiveUntil,
    int? subscriptionRemainingGroupTrainings,
    bool subscriptionIndividualUsed = false,
    String? subscriptionRequestStatusLine,
    required int subscriptionTotalApprovedCount,
    DateTime? subscriptionCurrentPeriodStart,
    DateTime? now,
  }) {
    final starterHint = starterBonusAvailable ? 'доступна' : 'нет';
    final untilLabel = subscriptionActiveUntil == null
        ? null
        : DateFormat('dd.MM.yyyy').format(subscriptionActiveUntil.toLocal());
    final plan = subscriptionPlan;
    final subscriptionHint = membershipLevel == MembershipLevel.boxingCard && plan != null
        ? '${plan.displayName}${untilLabel == null ? '' : ' до $untilLabel'}'
        : 'нет';
    final remainingGroupText = membershipLevel == MembershipLevel.boxingCard &&
            subscriptionRemainingGroupTrainings != null &&
            plan != null
        ? ' • групповые: <b>${subscriptionRemainingGroupTrainings.clamp(0, plan.groupQuota)}/${plan.groupQuota}</b>'
        : '';
    final individualText = membershipLevel == MembershipLevel.boxingCard
        ? ' • индивидуалка: <b>${subscriptionIndividualUsed ? '1/1' : '0/1'}</b>'
        : '';
    final requestStatusText =
        subscriptionRequestStatusLine == null ? '' : '\n• Заявка: $subscriptionRequestStatusLine';
    final expiresLabel = loyaltyExpiresAt == null
        ? 'нет срока, пока баланс 0'
        : 'до ${DateFormat('dd.MM').format(loyaltyExpiresAt.toLocal())}';
    final ledgerLines =
        loyaltyRecent.isEmpty ? 'пока пусто' : loyaltyRecent.map(_loyaltyLedgerLine).join('\n');
    return RichHtml.screen(
      title: 'Профиль DVOR',
      rows: <(String, String)>[
        ('Вершинки', '$loyaltyRemaining · 2 ⛰️ = 1 ₽ · $expiresLabel'),
        ('Стартовая', starterHint),
        ('Бокс-карта', '$subscriptionHint$remainingGroupText$individualText$requestStatusText'),
        (
          'Записи',
          'всего $totalBookings · актуальные $activeBookings · были $visitedBookings · отмены $cancelledBookings'
        ),
        ('Рефералка', '$successfulReferralsCount приглашений'),
      ],
      alreadyEscaped: true,
      detailsSummary: 'Как копить и списать',
      detailsBody: 'первый /start — 1000.\n'
          'Платная тренировка — от цены (350→200, 500→250).\n'
          'Отзыв — 50. Поход/трейл — 10% от оплаты.\n'
          'Друг прошёл первую платную — 1000. Бокс-карта — 10% от ₽.\n'
          'Списать: тренировка и карта — хоть целиком; поход/трейл — скидка до 30%.\n'
          'Последние операции:\n$ledgerLines',
    );
  }

  String _loyaltyLedgerLine(LoyaltyLedgerEntry entry) {
    final date = DateFormat('dd.MM').format(entry.createdAt.toLocal());
    final signed = entry.amount > 0 ? '+${entry.amount}' : '${entry.amount}';
    final reason = switch (entry.reason) {
      LoyaltyLedgerReason.start => 'за /start',
      LoyaltyLedgerReason.training => 'за тренировку',
      LoyaltyLedgerReason.feedback => 'за отзыв',
      LoyaltyLedgerReason.hike => 'за поход',
      LoyaltyLedgerReason.trail => 'за трейл',
      LoyaltyLedgerReason.referral => 'за приглашение',
      LoyaltyLedgerReason.boxingCard => 'за бокс-карту',
      LoyaltyLedgerReason.expire => 'сгорание',
      LoyaltyLedgerReason.spend => 'списание',
      LoyaltyLedgerReason.refund => 'возврат',
      LoyaltyLedgerReason.adminGrant => 'начисление',
      LoyaltyLedgerReason.adminDebit => 'списание',
      LoyaltyLedgerReason.migration => 'перенос',
    };
    return '$date · $signed ⛰️ $reason';
  }

  String? referralLink(int userId) => _botReferralLink(userId);

  String referralProgramOverview({
    required int userId,
    required int successfulReferralsCount,
  }) {
    final link = _botReferralLink(userId);
    final linkLine = link == null
        ? 'Ссылка недоступна: бот пока не смог определить username.'
        : '<code>$link</code>';
    return RichHtml.screen(
      title: 'Реферальная программа DVOR',
      bullets: <String>[
        'Отправь другу свою ссылку',
        'Друг заходит в бота по ней',
        'Друг прошёл первую платную тренировку — тебе 1000 ⛰️',
      ],
      paragraphs: <String>[
        'Твоя ссылка: $linkLine',
        'Успешных приглашений: $successfulReferralsCount',
      ],
      alreadyEscaped: true,
    );
  }

  String subscriptionOverview({
    required MembershipLevel membershipLevel,
    BoxingCardPlan? plan,
    DateTime? activeUntil,
    int? remainingGroupTrainings,
    bool individualUsed = false,
  }) {
    if (membershipLevel == MembershipLevel.boxingCard && plan != null) {
      final untilLabel =
          activeUntil == null ? '—' : DateFormat('dd.MM.yyyy').format(activeUntil.toLocal());
      final groupLimit = plan.groupQuota;
      final remaining = (remainingGroupTrainings ?? 0).clamp(0, groupLimit);
      return RichHtml.screen(
        title: 'DVOR BOXING CARD',
        rows: <(String, String)>[
          ('Тариф', plan.displayName),
          ('Сгорает', untilLabel),
          ('Групповые', '$remaining/$groupLimit'),
          ('Индивидуальная', individualUsed ? '1/1' : '0/1'),
        ],
        paragraphs: <String>[
          'Списывается на слот с BOX или БОКС в названии. Сила и забег — нет.',
        ],
      );
    }
    return RichHtml.screen(
      title: 'DVOR BOXING CARD',
      lead: 'Абонемент на групповой бокс. 30 дней с активации.',
      rows: <(String, String)>[
        ('БАЗА', '3 500 ₽ · 4 групповые + 1 индивидуальная'),
        ('УДАР', '4 700 ₽ · 8 групповых + 1 индивидуальная'),
      ],
      detailsSummary: 'Что не покрывает',
      detailsBody: 'Сила, забег, походы и трейлы — обычная оплата. Пропуск не переносится. '
          'Перенос — за сутки и только на другой бокс.',
    );
  }

  String boxingCardPlanChoice() {
    return RichHtml.screen(
      title: 'Тариф BOXING CARD',
      lead: 'Выбери тариф.',
      rows: <(String, String)>[
        ('БАЗА', '3 500 ₽, 4 групповые + 1 индивидуальная'),
        ('УДАР', '4 700 ₽, 8 групповых + 1 индивидуальная'),
      ],
      paragraphs: <String>['30 дней с активации.'],
    );
  }

  String subscriptionPaymentInstructions({
    required BoxingCardPlan plan,
    int? remainderRub,
  }) {
    final amount = _formatRub(remainderRub ?? plan.priceRub);
    return '${RichHtml.heading('Оформление BOXING CARD')}'
        '${RichHtml.table(
      <(String, String)>[
        ('Тариф', plan.displayName),
        ('Сумма', _formatRub(plan.priceRub)),
        if (remainderRub != null && remainderRub < plan.priceRub)
          ('Остаток после вершинок', amount),
        ('Срок', '30 дней с активации'),
        ('Получатель', 'Денис Р.'),
        ('Банк', 'Ozon Банк'),
      ],
    )}'
        '${RichHtml.paragraph(
      '<a href="$_sbpPaymentLink">${MessageCopy.buttonPaySbp}</a> — '
      'перейди по ссылке и введи <code>${_escapeHtml(amount)}</code>.',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      'После оплаты отправь в этот чат файл с подтверждением (документ/фото чека).',
    )}';
  }

  String _formatRub(int amount) {
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        );
    return '$formatted ₽';
  }

  String subscriptionPaymentProofRequired() {
    return RichHtml.screen(
      title: 'Заявка на бокс-карту',
      lead: 'Чтобы отправить заявку на бокс-карту:',
      bullets: <String>[
        'Выбери тариф.',
        'Пришли файл с подтверждением оплаты (документ/фото).',
        'Дождись проверки.',
      ],
    );
  }

  String subscriptionPaymentSubmitted() {
    return RichHtml.screen(
      title: 'Заявка на проверке',
      lead: 'Заявка на бокс-карту на проверке.',
      paragraphs: <String>[
        'Как подтвердят оплату — карта станет активной на 30 дней.',
      ],
    );
  }

  String subscriptionAlreadyPending() {
    return 'Заявка на бокс-карту уже на проверке.\n'
        'Ожидай подтверждения.';
  }

  String subscriptionAlreadyActive({DateTime? activeUntil}) {
    final until = activeUntil == null ? '' : ' до ${DateFormat('dd.MM.yyyy').format(activeUntil)}';
    return 'У тебя уже активна бокс-карта$until.';
  }

  String chooseAdminSubscriptionsAction() {
    return subscriptionFilterPrompt();
  }

  String chooseAdminToolsAction() {
    return RichHtml.screen(
      title: 'Инструменты',
      lead: 'Записи, синхронизация, абонементы, онбординг-видео и клиентское меню.',
    );
  }

  String adminOnboardingMediaHub({
    required bool venueSet,
    required bool cameAloneSet,
  }) {
    return RichHtml.screen(
      title: 'Онбординг-видео',
      rows: <(String, String)>[
        ('Площадка', '${_mediaStatus(venueSet)} — после первой записи'),
        ('Пришёл один', '${_mediaStatus(cameAloneSet)} — на карте клуба после квиза'),
      ],
      paragraphs: <String>[
        'Пустой слот человек не видит.',
        'Выбери слот и пришли видео или кружок.',
      ],
    );
  }

  String adminOnboardingMediaSlotPrompt({
    required OnboardingMediaSlot slot,
    required OnboardingMediaAsset? current,
  }) {
    final currentLabel = current == null
        ? 'пусто'
        : current.kind == OnboardingMediaKind.videoNote
            ? 'кружок'
            : 'видео';
    return RichHtml.screen(
      title: 'Слот онбординг-видео',
      rows: <(String, String)>[
        ('Слот', _onboardingMediaSlotLabel(slot)),
        ('Сейчас', currentLabel),
      ],
      paragraphs: <String>[
        'Пришли видео или кружок следующим сообщением — заменит текущий.',
        _onboardingMediaSlotPlacement(slot),
      ],
    );
  }

  String adminOnboardingMediaSaved({
    required OnboardingMediaSlot slot,
    required OnboardingMediaKind kind,
  }) {
    final kindLabel = kind == OnboardingMediaKind.videoNote ? 'кружок' : 'видео';
    return 'Сохранил. ${_onboardingMediaSlotLabel(slot)}: $kindLabel.\n'
        '${_onboardingMediaSlotPlacement(slot)}';
  }

  String adminOnboardingMediaCleared(OnboardingMediaSlot slot) {
    return 'Слот «${_onboardingMediaSlotLabel(slot)}» пустой.';
  }

  String adminOnboardingMediaNeedFile() {
    return 'Нужно видео или кружок. Фото и файлы сюда не подходят.';
  }

  String _mediaStatus(bool set) => set ? 'есть' : 'пусто';

  String _onboardingMediaSlotLabel(OnboardingMediaSlot slot) {
    return switch (slot) {
      OnboardingMediaSlot.venue => 'Площадка',
      OnboardingMediaSlot.cameAlone => 'Пришёл один',
    };
  }

  String _onboardingMediaSlotPlacement(OnboardingMediaSlot slot) {
    return switch (slot) {
      OnboardingMediaSlot.venue => 'Новичок увидит после первой записи.',
      OnboardingMediaSlot.cameAlone => 'Новичок увидит на карте клуба после квиза.',
    };
  }

  String chooseAdminAnalyticsAction() {
    return RichHtml.screen(
      title: 'Аналитика',
      lead: 'Выбери сегмент: воронка, фидбэк, экономика, бронирования, бонусы или абонементы.',
    );
  }

  String adminClientMenuOpened() {
    return RichHtml.screen(
      title: 'Клиентское меню',
      lead: 'Можно пользоваться ботом как обычный пользователь.',
      paragraphs: <String>[
        'Вернуться: «${MessageCopy.buttonAdminMenu}» или «${MessageCopy.buttonMainMenu}».',
      ],
    );
  }

  String subscriptionsList(List<SubscriptionRequest> items, {required DateTime now}) {
    final _ = now;
    if (items.isEmpty) {
      return RichHtml.screen(
        title: 'Список абонементов',
        lead: 'По выбранному фильтру ничего не найдено.',
      );
    }
    final formatter = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Список абонементов'))
      ..write(RichHtml.paragraph('Всего: ${items.length}'));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final until = item.activeUntil;
      final untilLabel = until == null ? '—' : formatter.format(until);
      final statusLabel = switch (item.status) {
        SubscriptionRequestStatus.active =>
          item.plan == null ? 'карта активна' : '${item.plan!.displayName} активен',
        SubscriptionRequestStatus.paymentSubmitted => 'На проверке',
        SubscriptionRequestStatus.cancelled => 'Отменён',
        SubscriptionRequestStatus.rejected => 'Отклонён',
      };
      buffer.write(
        RichHtml.details(
          summary: '${index + 1}. ${_userTagById(item.userId, username: item.userUsername)}',
          body: RichHtml.table(
            <(String, String)>[
              (
                'Пользователь',
                '${_userTagById(item.userId, username: item.userUsername)} (${item.userId})'
              ),
              ('Статус', statusLabel),
              ('До', untilLabel),
            ],
          ),
          alreadyEscaped: true,
        ),
      );
    }
    return buffer.toString();
  }

  String subscriptionActiveItem(SubscriptionRequest request) {
    final until = request.activeUntil == null
        ? 'не задано'
        : DateFormat('dd.MM.yyyy').format(request.activeUntil!);
    final planLabel = request.plan?.displayName ?? 'без тарифа';
    return RichHtml.screen(
      title: 'Бокс-карта #${request.id}',
      rows: <(String, String)>[
        (
          'Пользователь',
          '${_userTagById(request.userId, username: request.userUsername)} (${request.userId})',
        ),
        ('Тариф', planLabel),
        ('Активна до', until),
      ],
      paragraphs: <String>['Можно отменить карту кнопкой ниже.'],
    );
  }

  String subscriptionPendingQueueIntro(int total) {
    return RichHtml.screen(
      title: 'Заявки на абонемент',
      lead: 'Ожидают проверки: $total.',
      paragraphs: <String>['Ниже отправил каждую заявку отдельным сообщением.'],
    );
  }

  String subscriptionPendingQueueEmpty() {
    return RichHtml.screen(
      title: 'Заявки на абонемент',
      lead: 'Очередь пуста.',
    );
  }

  String subscriptionPendingQueueItem(SubscriptionRequest request) {
    final created = DateFormat('dd.MM.yyyy HH:mm').format(request.createdAt);
    final note = request.paymentNote?.trim();
    final plan = request.plan;
    return RichHtml.screen(
      title: 'Заявка #${request.id}',
      rows: <(String, String)>[
        (
          'Пользователь',
          '${_userTagById(request.userId, username: request.userUsername)} (${request.userId})',
        ),
        if (plan != null) ('Тариф', '${plan.displayName} · ${_formatRub(plan.priceRub)}'),
        ('Отправлена', created),
        if (note != null && note.isNotEmpty) ('Комментарий', note),
      ],
      paragraphs: <String>['Подтверди или отклони заявку кнопками ниже.'],
    );
  }

  String subscriptionReviewResultWithNextStep({
    required SubscriptionRequest request,
    required int remaining,
  }) {
    final status = request.status == SubscriptionRequestStatus.active
        ? 'Бокс-карта активирована'
        : 'Отклонено';
    final nextStep = remaining > 0
        ? 'Осталось заявок: $remaining. Открой «${MessageCopy.buttonSubscriptionsAdmin}» → «${MessageCopy.buttonSubscriptionsFilterPending}», чтобы проверить следующую.'
        : 'Очередь пустая.';
    return RichHtml.screen(
      title: 'Заявка #${request.id} обработана',
      lead: status,
      paragraphs: <String>[nextStep],
    );
  }

  String subscriptionCancelResult(SubscriptionRequest request) {
    return RichHtml.screen(
      title: 'Абонемент #${request.id} отменен',
      rows: <(String, String)>[
        (
          'Пользователь',
          '${_userTagById(request.userId, username: request.userUsername)} (${request.userId})',
        ),
      ],
    );
  }

  String subscriptionStatusLineFromSnapshot(SubscriptionUserSnapshot snapshot) {
    if (snapshot.latestPending != null) {
      return 'На проверке';
    }
    final activeUntil = snapshot.membership.activeUntil;
    if (snapshot.membership.level == MembershipLevel.boxingCard && activeUntil != null) {
      return 'Активен до ${DateFormat('dd.MM.yyyy').format(activeUntil)}';
    }
    final rejected = snapshot.latestRejectedOrCancelled;
    if (rejected != null) {
      final reason = rejected.moderationReason?.trim();
      final comment = rejected.moderationComment?.trim();
      if ((reason ?? '').isNotEmpty || (comment ?? '').isNotEmpty) {
        final suffix = <String>[
          if ((reason ?? '').isNotEmpty) reason!,
          if ((comment ?? '').isNotEmpty) comment!,
        ].join(' — ');
        return 'Отклонен ($suffix)';
      }
      return 'Отклонен';
    }
    return 'Нет активной заявки';
  }

  String subscriptionFilterPrompt() {
    return RichHtml.screen(
      title: 'Абонементы',
      lead:
          'Выбери фильтр или поиск. «${MessageCopy.buttonSubscriptionsFilterPending}» — очередь на модерацию.',
    );
  }

  String subscriptionSearchPrompt() {
    return '🔎 Введи запрос для поиска абонемента:\n'
        '• <code>@username</code>\n'
        '• <code>userId</code>\n'
        '• <code>номер заявки</code>';
  }

  String subscriptionModerationReasonPrompt({required bool isCancel}) {
    return isCancel ? 'Выбери причину отмены абонемента.' : 'Выбери причину отклонения заявки.';
  }

  String subscriptionModerationCommentPrompt() {
    return 'Добавь комментарий для клиента или нажми «${MessageCopy.buttonSkipComment}».';
  }

  String subscriptionApprovedForUser({
    required DateTime activeUntil,
    BoxingCardPlan? plan,
  }) {
    return RichHtml.screen(
      title: 'Оплату подтвердили',
      rows: <(String, String)>[
        if (plan != null) ('Тариф', plan.displayName),
        ('Карта до', DateFormat('dd.MM.yyyy').format(activeUntil)),
      ],
      paragraphs: <String>[
        'Запись: «${MessageCopy.buttonBookTraining}» → слот с BOX или БОКС в названии.',
      ],
    );
  }

  String subscriptionRejectedForUser({String? reason, String? comment}) {
    final details = <String>[
      if ((reason ?? '').trim().isNotEmpty) 'Причина: ${_escapeHtml(reason!.trim())}',
      if ((comment ?? '').trim().isNotEmpty) 'Комментарий: ${_escapeHtml(comment!.trim())}',
    ];
    return 'Заявка на бокс-карту отклонена.\n'
        '${details.isEmpty ? '' : '${details.join('\n')}\n'}'
        'Проверь оплату/чек и отправь новую заявку: «${MessageCopy.buttonSubscription}» → '
        '«${MessageCopy.buttonSubscribeApply}».';
  }

  String subscriptionCancelledForUser({String? reason, String? comment}) {
    final details = <String>[
      if ((reason ?? '').trim().isNotEmpty) 'Причина: ${_escapeHtml(reason!.trim())}',
      if ((comment ?? '').trim().isNotEmpty) 'Комментарий: ${_escapeHtml(comment!.trim())}',
    ];
    return 'Текущую бокс-карту отменили.\n'
        '${details.isEmpty ? '' : '${details.join('\n')}\n'}'
        'Оформить снова: «${MessageCopy.buttonSubscription}» → '
        '«${MessageCopy.buttonSubscribeApply}».';
  }

  String subscriptionRenewalReminder({
    required DateTime activeUntil,
    required int daysBefore,
    int? remainingGroup,
    int groupQuota = 0,
    bool individualUsed = false,
  }) {
    final until = DateFormat('dd.MM.yyyy').format(activeUntil);
    return RichHtml.screen(
      title: 'Бокс-карта',
      rows: <(String, String)>[
        ('Карта до', until),
        if (remainingGroup != null && groupQuota > 0) ('Групповые', '$remainingGroup/$groupQuota'),
        if (remainingGroup != null && groupQuota > 0)
          ('Индивидуалка', individualUsed ? '1/1' : '0/1'),
      ],
      paragraphs: <String>[
        'Продлить? «${MessageCopy.buttonSubscription}» → «${MessageCopy.buttonRenewSubscription}».',
      ],
    );
  }

  String subscriptionExpiryPromo() {
    return '30 дней прошли, остаток сгорел.\n'
        'Оформить снова: «${MessageCopy.buttonSubscription}» → '
        '«${MessageCopy.buttonSubscribeApply}».';
  }

  String boxingCardVisitDebited({
    required int remaining,
    required int quota,
  }) {
    return RichHtml.screen(
      title: 'Занятие засчитано',
      rows: <(String, String)>[
        ('Осталось групповых', '$remaining/$quota'),
      ],
    );
  }

  String boxingCardIndividualReminder({required DateTime activeUntil}) {
    return RichHtml.screen(
      title: 'Индивидуальная ещё не закрыта',
      rows: <(String, String)>[
        ('Карта до', DateFormat('dd.MM.yyyy').format(activeUntil)),
      ],
      paragraphs: <String>[
        'Напиши удобные дни и время в «${MessageCopy.buttonSubscription}» → '
            '«${MessageCopy.buttonIndividualSession}».',
      ],
    );
  }

  String boxingCardBookingCreated({
    required TrainingBooking booking,
    required int remaining,
    required int quota,
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Запись создана',
      lead: 'Отлично, записал тебя.',
      rows: <(String, String)>[
        ('Групповые', 'списано с карты · осталось $remaining/$quota'),
        ('Номер записи', '${booking.id}'),
        ('Тренировка', _escapeHtml(booking.trainingTitle)),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('📍 Где', _bookingLocationLabel(booking)),
      ],
      alreadyEscaped: true,
    );
  }

  String boxingCardCancelConfirm(TrainingBooking booking, {required bool burnsSlot}) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final consequence = burnsSlot
        ? 'До старта меньше 24 часов. Если отменишь, слот сгорит и не вернётся в остаток.'
        : 'Отмена вернёт слот в остаток карты.';
    return RichHtml.screen(
      title: 'Отменить запись #${booking.id}?',
      rows: <(String, String)>[
        ('Событие', booking.trainingTitle),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
      ],
      paragraphs: <String>[consequence],
    );
  }

  String boxingCardRescheduleTooLate() {
    return 'Перенос недоступен: до старта меньше 24 часов.\n'
        'Отмена сейчас сожжёт слот.';
  }

  String boxingCardRescheduleTargetNotBoxing() {
    return 'С карты можно перенести только на другой слот бокса.';
  }

  String boxingCardIndividualPrompt() {
    return RichHtml.screen(
      title: 'Индивидуальная',
      lead: 'Напиши удобные дни и время одним сообщением.',
      paragraphs: <String>['Заявку отправлю тренеру.'],
    );
  }

  String boxingCardIndividualSubmitted() {
    return RichHtml.screen(
      title: 'Заявка у тренера',
      lead: 'Напишем в личку.',
    );
  }

  String boxingCardIndividualAlreadyPending() {
    return RichHtml.screen(
      title: 'Заявка уже у тренера',
      lead: 'Напишем в личку, когда подтвердят.',
    );
  }

  String boxingCardIndividualQuotaUsed() {
    return RichHtml.screen(
      title: 'Индивидуальная закрыта',
      lead: 'Индивидуальная в этом периоде уже закрыта.',
    );
  }

  String boxingCardIndividualNeedActiveCard() {
    return RichHtml.screen(
      title: 'Нужна активная карта',
      lead: 'Индивидуальная доступна при активной бокс-карте.',
    );
  }

  String boxingCardIndividualAdminNotification(IndividualSessionRequest request) {
    return RichHtml.screen(
      title: 'Заявка на индивидуальную #${request.id}',
      rows: <(String, String)>[
        (
          'Пользователь',
          '${_userTagById(request.userId, username: request.userUsername)} (${request.userId})',
        ),
        ('Карта', '#${request.subscriptionRequestId}'),
      ],
      detailsSummary: 'Удобное время',
      detailsBody: request.preferredTimes,
    );
  }

  String boxingCardIndividualApprovedForUser() {
    return RichHtml.screen(
      title: 'Индивидуальную подтвердили',
      lead: 'Квота 1/1 закрыта.',
      paragraphs: <String>[
        'Детали времени — в личке от тренера, если ещё не написали.',
      ],
    );
  }

  String boxingCardIndividualRejectedForUser({String? comment}) {
    final extra = (comment ?? '').trim();
    return RichHtml.screen(
      title: 'Заявку отклонили',
      lead: 'Заявку на индивидуальную отклонили.',
      paragraphs: extra.isEmpty ? const <String>[] : <String>[extra],
    );
  }

  String chooseMyBookingsSegment() {
    return RichHtml.screen(
      title: 'Мои записи',
      lead: 'Выбери список ниже: «Актуальные» или «Прошедшие».',
    );
  }

  String myBookings(
    List<TrainingBooking> bookings, {
    DateTime? now,
  }) {
    final splitPoint = (now ?? DateTime.now()).toLocal();
    final upcoming = bookings.where((booking) => !booking.startsAt.isBefore(splitPoint)).toList();
    final past = bookings.where((booking) => booking.startsAt.isBefore(splitPoint)).toList();
    past.sort((left, right) => right.startsAt.compareTo(left.startsAt));

    if (bookings.isEmpty) {
      return RichHtml.screen(
        title: 'Записи',
        lead: 'Пока нет записей на мероприятия.',
      );
    }

    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer()..write(RichHtml.heading('Записи'));

    void writeSegment(String summary, List<TrainingBooking> items) {
      if (items.isEmpty) {
        return;
      }
      final details = StringBuffer();
      for (final booking in items) {
        details.write(
          RichHtml.table(
            <(String, String)>[
              ('Запись', '#${booking.id} ${booking.trainingTitle}'),
              if (booking.isManagedForOther) ('Участник', booking.participantDisplayLabel),
              ('🕒 Когда', _myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
              ('Статус', _statusLabel(booking.status, booking: booking)),
            ],
          ),
        );
      }
      buffer.write(
        RichHtml.details(
          summary: summary,
          body: details.toString(),
          alreadyEscaped: true,
        ),
      );
    }

    writeSegment('Актуальные', upcoming);
    writeSegment('Прошедшие', past);
    return buffer.toString();
  }

  String chooseMyBookingFromList(
    List<TrainingBooking> bookings, {
    required bool past,
    required int page,
    required int totalPages,
    required int totalCount,
  }) {
    final segmentLabel = past ? 'Прошедшие' : 'Актуальные';
    if (bookings.isEmpty) {
      return RichHtml.screen(
        title: 'В этом списке пока пусто',
        rows: <(String, String)>[('Сегмент', segmentLabel)],
      );
    }
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Мои записи'))
      ..write(
        RichHtml.table(
          <(String, String)>[
            ('Фильтр', segmentLabel),
            ('Страница', '$page/$totalPages'),
            ('Всего записей', '$totalCount'),
          ],
        ),
      )
      ..write(RichHtml.paragraph('Записи на текущей странице:'));
    for (var index = 0; index < bookings.length; index++) {
      final booking = bookings[index];
      buffer.write(
        RichHtml.details(
          summary: '${index + 1}. #${booking.id} ${booking.trainingTitle}',
          body: RichHtml.table(
            <(String, String)>[
              if (booking.isManagedForOther) ('Участник', booking.participantDisplayLabel),
              ('🕒 Когда', _myBookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
              ('Статус', _statusLabel(booking.status, booking: booking)),
            ],
          ),
          alreadyEscaped: true,
        ),
      );
    }
    buffer
      ..write(RichHtml.paragraph('Выбери запись кнопкой ниже.'))
      ..write(
        RichHtml.paragraph(
          'Чтобы сменить сегмент, нажми «${MessageCopy.buttonBack}».',
        ),
      );
    return buffer.toString();
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
    return 'Самостоятельно отменить платную тренировку нельзя.\n'
        'Для записи #${booking.id} напиши в поддержку: @dvor_support.\n'
        'Отмена доступна самостоятельно для бесплатных тренировок, походов и трейлов.';
  }

  String bookingCancelConfirm(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Отменить запись #${booking.id}?',
      rows: <(String, String)>[
        ('Событие', booking.trainingTitle),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
      ],
      paragraphs: <String>['Подтверди отмену кнопкой ниже.'],
    );
  }

  String freeTrainingCancellationTooLate(TrainingBooking booking) {
    return 'Отменить запись #${booking.id} уже нельзя ⛔️\n'
        'Если проблема остаётся — напиши @dvor_support.';
  }

  String bookingActions(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final hint = switch (booking.status) {
      BookingStatus.pendingPayment ||
      BookingStatus.paymentRejected =>
        'Подсказка: «${MessageCopy.buttonContinuePayment}» откроет оплату по этой записи.',
      BookingStatus.partialPaid =>
        'Подсказка: предоплата уже внесена. Остаток — офлайн после события.',
      _ => 'Подсказка: «${MessageCopy.buttonRepeatBooking}» откроет похожие события.',
    };
    return RichHtml.screen(
      title: 'Запись #${booking.id}',
      rows: <(String, String)>[
        ('Событие', booking.trainingTitle),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
      bullets: <String>[
        'Перенос — только тренировки на слот той же цены.',
        'Отмена outdoor — за 7+ дней, бесплатные — всегда.',
        'Платные тренировки — через @dvor_support.',
      ],
      paragraphs: <String>[
        'Выбери действие.',
        hint,
      ],
    );
  }

  String chooseTrainingForReschedule(List<TrainingInfo> items, {required TrainingBooking booking}) {
    if (items.isEmpty) {
      return RichHtml.screen(
        title: 'Перенос записи',
        lead: 'Сейчас нет ближайших мероприятий для переноса.',
      );
    }
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Куда перенести запись #${booking.id}?'))
      ..write(RichHtml.paragraph('Сейчас: ${booking.trainingTitle}'))
      ..write(RichHtml.paragraph('Выбери новое мероприятие.'));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('${index + 1}', item.title),
            ('🕒 Когда', formatter.format(item.startsAt)),
            ('📍 Где', item.location),
            ('Участники', _participantsLimitLabel(item.participantsLimit)),
          ],
        ),
      );
    }
    return buffer.toString();
  }

  String bookingRescheduled({
    required TrainingBooking from,
    required TrainingBooking to,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Запись перенесена',
      lead: 'Готово! Запись #${to.id} перенесена.',
      rows: <(String, String)>[
        ('Было', '${from.trainingTitle} (${formatter.format(from.startsAt)})'),
        ('Стало', '${to.trainingTitle} (${formatter.format(to.startsAt)})'),
        ('Статус оплаты', _statusLabel(to.status)),
      ],
    );
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
    return RichHtml.screen(
      title: 'Запись отменена',
      rows: <(String, String)>[
        ('Номер', '#${booking.id}'),
        ('Событие', booking.trainingTitle),
        ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
    );
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
    return RichHtml.screen(
      title: 'Заявки на подтверждение оплаты',
      rows: <(String, String)>[
        ('Категория', _categoryLabel(category)),
        ('Всего ожидают проверки', '$total'),
      ],
      paragraphs: <String>['Показываю следующую заявку.'],
    );
  }

  String paymentReviewResultWithNextStep({
    required TrainingBooking booking,
    required int remaining,
  }) {
    final nextStep = remaining > 0
        ? 'Осталось на проверке: $remaining. Нажми «Следующая заявка», чтобы открыть следующую.'
        : 'Очередь заявок пуста. Можно вернуться в меню.';
    return RichHtml.screen(
      title: 'Статус записи #${booking.id} обновлен',
      lead: _statusLabel(booking.status, booking: booking),
      paragraphs: <String>[nextStep],
    );
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

  List<List<RichMessageButton>> paymentDecisionRichButtons(
    int bookingId, {
    bool approvePartial = false,
  }) {
    return TelegramKeyboards.paymentDecisionRichButtons(
      bookingId,
      approvePartial: approvePartial,
    );
  }

  Map<String, Object?> paymentCardInlineKeyboard(
    int bookingId, {
    required bool showStarterBonus,
    bool showLoyaltySpend = false,
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
    bool showPromoCodeEntry = false,
  }) {
    return TelegramKeyboards.paymentCardInlineKeyboard(
      bookingId,
      showStarterBonus: showStarterBonus,
      showLoyaltySpend: showLoyaltySpend,
      showCancelBooking: showCancelBooking,
      showOutdoorPaymentTypeChoice: showOutdoorPaymentTypeChoice,
      showPromoCodeEntry: showPromoCodeEntry,
    );
  }

  List<List<RichMessageButton>> paymentCardRichButtons(
    int bookingId, {
    required bool showStarterBonus,
    bool showLoyaltySpend = false,
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
    bool showPromoCodeEntry = false,
  }) {
    return TelegramKeyboards.paymentCardRichButtons(
      bookingId,
      showStarterBonus: showStarterBonus,
      showLoyaltySpend: showLoyaltySpend,
      showCancelBooking: showCancelBooking,
      showOutdoorPaymentTypeChoice: showOutdoorPaymentTypeChoice,
      showPromoCodeEntry: showPromoCodeEntry,
    );
  }

  Map<String, Object?> bookingCancelConfirmInlineKeyboard(int bookingId) {
    return TelegramKeyboards.bookingCancelConfirmInlineKeyboard(bookingId);
  }

  List<List<RichMessageButton>> bookingCancelConfirmRichButtons(int bookingId) {
    return TelegramKeyboards.bookingCancelConfirmRichButtons(bookingId);
  }

  Map<String, Object?> bookingActionsInlineKeyboard({
    required int bookingId,
    required bool canReschedule,
    required bool canCancel,
    required bool canRepeat,
    bool canCompletePayment = false,
    bool canContinuePayment = false,
  }) {
    return TelegramKeyboards.bookingActionsInlineKeyboard(
      bookingId: bookingId,
      canReschedule: canReschedule,
      canCancel: canCancel,
      canRepeat: canRepeat,
      canCompletePayment: canCompletePayment,
      canContinuePayment: canContinuePayment,
    );
  }

  List<List<RichMessageButton>> bookingActionsRichButtons({
    required int bookingId,
    required bool canReschedule,
    required bool canCancel,
    required bool canRepeat,
    bool canCompletePayment = false,
    bool canContinuePayment = false,
  }) {
    return TelegramKeyboards.bookingActionsRichButtons(
      bookingId: bookingId,
      canReschedule: canReschedule,
      canCancel: canCancel,
      canRepeat: canRepeat,
      canCompletePayment: canCompletePayment,
      canContinuePayment: canContinuePayment,
    );
  }

  Map<String, Object?> trainingFeedbackInlineKeyboard(int bookingId) {
    return TelegramKeyboards.trainingFeedbackInlineKeyboard(bookingId);
  }

  Map<String, Object?> ctaBookInlineKeyboard({
    String buttonLabel = MessageCopy.buttonBookTraining,
  }) {
    return TelegramKeyboards.ctaBookInlineKeyboard(buttonLabel: buttonLabel);
  }

  Map<String, Object?> urlCtaInlineKeyboard({
    required String label,
    required String url,
  }) {
    return TelegramKeyboards.urlCtaInlineKeyboard(label: label, url: url);
  }

  Map<String, Object?> referralActionsInlineKeyboard(String link) {
    return TelegramKeyboards.referralActionsInlineKeyboard(link);
  }

  Map<String, Object?> adminBookingActionsInlineKeyboard(
    int bookingId, {
    required bool canRestore,
  }) {
    return TelegramKeyboards.adminBookingActionsInlineKeyboard(
      bookingId,
      canRestore: canRestore,
    );
  }

  List<List<RichMessageButton>> adminBookingActionsRichButtons(
    int bookingId, {
    required bool canRestore,
  }) {
    return TelegramKeyboards.adminBookingActionsRichButtons(
      bookingId,
      canRestore: canRestore,
    );
  }

  Map<String, Object?> adminBookingDeleteConfirmInlineKeyboard(int bookingId) {
    return TelegramKeyboards.adminBookingDeleteConfirmInlineKeyboard(bookingId);
  }

  Map<String, Object?> adminClientNotificationPreferenceInlineKeyboard() {
    return TelegramKeyboards.adminClientNotificationPreferenceInlineKeyboard();
  }

  String paymentCardNavHint() {
    return privateMenuHint();
  }

  Map<String, Object?>? groupWelcomeUrlKeyboard() {
    final link = _botStartDeepLink();
    if (link == null) {
      return null;
    }
    return urlCtaInlineKeyboard(label: 'Открыть бота', url: link);
  }

  Map<String, Object?> groupInviteUrlKeyboard() {
    return urlCtaInlineKeyboard(
      label: MessageCopy.buttonOpenGroup,
      url: MessageCopy.dvorGroupInviteUrl,
    );
  }

  Map<String, Object?>? groupBookUrlKeyboard() {
    final link = _botDeepLink();
    if (link == null) {
      return null;
    }
    return urlCtaInlineKeyboard(label: MessageCopy.buttonBookTraining, url: link);
  }

  Map<String, Object?> pendingPaymentReminderKeyboard(int bookingId) {
    return TelegramKeyboards.pendingPaymentReminderKeyboard(bookingId);
  }

  Map<String, Object?> openPaymentsQueueInlineKeyboard({required int total}) {
    return TelegramKeyboards.openPaymentsQueueInlineKeyboard(
      buttonLabel: _labelWithCount(MessageCopy.buttonPaymentsQueue, total),
    );
  }

  Map<String, Object?> nextPaymentInQueueInlineKeyboard({
    required ActivityCategory category,
    required int remaining,
  }) {
    return TelegramKeyboards.nextPaymentInQueueInlineKeyboard(
      category: category,
      remaining: remaining,
    );
  }

  String paymentsQueueItem(
    TrainingBooking booking, {
    List<TrainingBooking> groupBookings = const <TrainingBooking>[],
  }) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final paymentType = _paymentTypeLabelFromNote(booking.paymentNote);
    final cleanNote = _cleanPaymentNote(booking.paymentNote);
    final members = groupBookings.isNotEmpty ? groupBookings : <TrainingBooking>[booking];
    final organizer = _userTagById(booking.managerUserId, username: booking.userUsername);
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Заявка #${booking.id}'))
      ..write(
        RichHtml.table(
          <(String, String)>[
            ('Организатор', '$organizer (${booking.managerUserId})'),
            if (members.length == 1 && booking.isManagedForOther)
              ('Участник', booking.participantDisplayLabel),
            ('Тренировка', booking.trainingTitle),
            ('🕒 Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
            ('📍 Где', booking.location),
            if (paymentType != null) ('Тип оплаты', paymentType),
            if (cleanNote != null && cleanNote.isNotEmpty) ('Комментарий', cleanNote),
          ],
        ),
      );
    if (members.length > 1) {
      final total = members.fold<int>(0, (sum, item) => sum + (item.trainingPrice ?? 0));
      final unit = booking.trainingPrice ?? 0;
      buffer.write(
        RichHtml.details(
          summary: 'Участники (${members.length})',
          body: RichHtml.bullets(
            members
                .map((member) => '#${member.id} ${member.participantDisplayLabel}')
                .toList(growable: false),
          ),
          alreadyEscaped: true,
        ),
      );
      buffer.write(
        RichHtml.paragraph(
          'К оплате: ${members.length} × ${_trainingPriceLabel(unit)} = ${_trainingPriceLabel(total)}',
        ),
      );
      buffer.write(RichHtml.paragraph('Группа оплаты: подтверждение закроет все записи пакета.'));
    }
    buffer
      ..write(RichHtml.paragraph('Подтверди или отклони оплату кнопками ниже.'))
      ..write(RichHtml.paragraph('После решения можно сразу открыть следующую заявку.'));
    return buffer.toString();
  }

  String trainingParticipants({
    required List<TrainingInfo> trainings,
    required Map<String, List<TrainingBooking>> bookingsByTrainingKey,
    String title = 'Список записавшихся по тренировкам 👥',
    String emptyText = 'Ближайших тренировок пока нет, показывать список не для чего.',
    bool Function(TrainingBooking booking)? isTrainerBooking,
    bool showTrainers = true,
  }) {
    if (trainings.isEmpty) {
      return RichHtml.screen(
        title: title,
        lead: emptyText,
      );
    }
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer()..write(RichHtml.heading(title));
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
      final detail = StringBuffer()
        ..write(
          RichHtml.table(
            <(String, String)>[
              ('🕒 Когда', _trainingDateLabel(training, dateTimeFormatter, dateOnlyFormatter)),
              ('📍 Где', training.location),
              (
                'Участники',
                '$displayedParticipantsCount/${_participantsLimitValueLabel(training.participantsLimit)}',
              ),
            ],
          ),
        );
      if (activeTags.isEmpty && cancelledTags.isEmpty) {
        detail.write(RichHtml.paragraph('Пока никто не записался'));
      } else {
        if (activeParticipantTags.isNotEmpty) {
          detail.write(
            RichHtml.details(
              summary: 'Участники',
              body: RichHtml.bullets(
                activeParticipantTags
                    .map(
                      (booking) => '${_userTag(booking)} (${_participantStatusLabel(booking)})',
                    )
                    .toList(growable: false),
              ),
              alreadyEscaped: true,
            ),
          );
        }
        if (showTrainers && activeTrainerTags.isNotEmpty) {
          detail.write(
            RichHtml.details(
              summary: 'Тренеры',
              body: RichHtml.bullets(
                activeTrainerTags
                    .map(
                      (booking) => '${_userTag(booking)} (${_participantStatusLabel(booking)})',
                    )
                    .toList(growable: false),
              ),
              alreadyEscaped: true,
            ),
          );
        }
        final cancelled = <TrainingBooking>[
          ...cancelledParticipantTags,
          if (showTrainers) ...cancelledTrainerTags,
        ];
        if (cancelled.isNotEmpty) {
          detail.write(
            RichHtml.details(
              summary: 'Отменённые',
              body: RichHtml.bullets(
                cancelled
                    .map(
                      (booking) => '${_userTag(booking)} (${_participantStatusLabel(booking)})',
                    )
                    .toList(growable: false),
              ),
              alreadyEscaped: true,
            ),
          );
        }
      }
      buffer.write(
        RichHtml.details(
          summary: '${index + 1}. ${training.title}',
          body: detail.toString(),
          alreadyEscaped: true,
        ),
      );
    }
    return buffer.toString();
  }

  String noblesList(
    List<({int userId, String? username, int trainingsCount})> users, {
    int totalTrainings = 0,
  }) {
    if (users.isEmpty) {
      return RichHtml.screen(
        title: 'Список дворян',
        lead: 'Пока нет данных по записям, список дворян пуст.',
      );
    }
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Список дворян'))
      ..write(RichHtml.paragraph('Всего записей на тренировки: $totalTrainings'))
      ..write(
        RichHtml.paragraph(
          'В зачёт идут только уже прошедшие по времени тренировки '
          '(<code>starts_at &lt; now</code>).',
          alreadyEscaped: true,
        ),
      );
    for (var index = 0; index < users.length; index++) {
      final user = users[index];
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            (
              '${index + 1}',
              '${_userTagById(user.userId, username: user.username)} (${user.userId})',
            ),
            ('Тренировок', '${user.trainingsCount}'),
          ],
        ),
      );
    }
    return buffer.toString();
  }

  String adminOnlyAction() {
    return 'Это действие доступно только администраторам 🔒';
  }

  String adminUserSearchPrompt() {
    return RichHtml.screen(
      title: 'Поиск по пользователю',
      lead: 'Введи никнейм (с @ или без).',
    );
  }

  String adminRecentBotActions(List<ConversationLogEntry> entries) {
    if (entries.isEmpty) {
      return RichHtml.screen(
        title: 'Последние действия бота',
        lead: 'Пока пусто. Лог появляется после сообщений пользователей и ответов бота '
            '(история до включения логирования недоступна).',
      );
    }
    final dateFormatter = DateFormat('dd.MM HH:mm');
    final lines = <String>[];
    for (final entry in entries) {
      final who = entry.peerUsername == null || entry.peerUsername!.isEmpty
          ? 'id ${entry.peerUserId}'
          : '@${entry.peerUsername}';
      final arrow = entry.direction == ConversationDirection.inbound ? '⬅️' : '➡️';
      final preview = entry.textPreview?.trim();
      final body = (preview == null || preview.isEmpty)
          ? _conversationContentLabel(entry.contentType)
          : preview;
      lines.add('${dateFormatter.format(entry.occurredAt)} $arrow $who · $body');
    }
    return '${RichHtml.heading('Последние действия бота')}'
        '${RichHtml.paragraph('До ${entries.length} записей.')}'
        '${RichHtml.details(
      summary: 'Последние сообщения',
      body: RichHtml.bullets(lines),
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph('Только сообщения после включения логирования.')}';
  }

  String adminUserDialogPrompt() {
    return RichHtml.screen(
      title: 'Диалог с пользователем',
      lead: 'Введи никнейм (с @ или без). Бот покажет сохранённую переписку '
          'и попробует переслать исходные сообщения.',
    );
  }

  String adminUserDialogNotFound(String query) {
    return RichHtml.screen(
      title: 'Диалог не найден',
      lead: 'Пользователь «$query» не найден в логе переписки и в записях.',
      paragraphs: <String>[
        'Нужен @username, с которым уже был диалог после включения логирования.',
      ],
    );
  }

  String adminUserDialogHeader({
    required String query,
    required int userId,
    required String? username,
    required int entriesCount,
  }) {
    final tag = username == null || username.isEmpty ? 'id $userId' : '@$username';
    if (entriesCount == 0) {
      return RichHtml.screen(
        title: 'Диалог: $tag',
        rows: <(String, String)>[
          ('id', '$userId'),
          ('Запрос', query),
        ],
        paragraphs: <String>['Сохранённых сообщений пока нет.'],
      );
    }
    return RichHtml.screen(
      title: 'Диалог: $tag',
      rows: <(String, String)>[
        ('id', '$userId'),
        ('Сообщений в логе', '$entriesCount'),
      ],
      paragraphs: <String>[
        'Ниже — пересылка, где возможно, иначе текстовый fallback.',
      ],
    );
  }

  String adminUserDialogFallbackLine(ConversationLogEntry entry) {
    final dateFormatter = DateFormat('dd.MM HH:mm');
    final arrow = entry.direction == ConversationDirection.inbound ? '⬅️ user' : '➡️ bot';
    final preview = entry.textPreview?.trim();
    final body = (preview == null || preview.isEmpty)
        ? _conversationContentLabel(entry.contentType)
        : preview;
    return RichHtml.paragraph('${dateFormatter.format(entry.occurredAt)} $arrow · $body');
  }

  String adminUserDialogFooter({
    required int forwarded,
    required int fallback,
  }) {
    return RichHtml.screen(
      title: 'Диалог',
      lead: 'Готово: переслано $forwarded, текстом $fallback.',
    );
  }

  String _conversationContentLabel(ConversationContentType type) {
    return switch (type) {
      ConversationContentType.text => '[текст]',
      ConversationContentType.photo => '[фото]',
      ConversationContentType.document => '[документ]',
      ConversationContentType.video => '[видео]',
      ConversationContentType.copy => '[копия сообщения]',
      ConversationContentType.other => '[сообщение]',
    };
  }

  String adminUserSearchResults(
    List<TrainingBooking> bookings, {
    required String query,
    required DateTime now,
  }) {
    if (bookings.isEmpty) {
      return RichHtml.screen(
        title: 'Поиск',
        lead: 'По запросу «$query» записей не найдено.',
      );
    }
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');

    final total = bookings.length;
    final cancelled = bookings.where((b) => b.status == BookingStatus.cancelled).length;
    final rejected = bookings.where((b) => b.status == BookingStatus.paymentRejected).length;
    final active = bookings
        .where(
          (b) =>
              b.status != BookingStatus.cancelled &&
              b.status != BookingStatus.paymentRejected &&
              !b.startsAt.isBefore(now),
        )
        .length;
    final past = bookings
        .where(
          (b) =>
              b.status != BookingStatus.cancelled &&
              b.status != BookingStatus.paymentRejected &&
              b.startsAt.isBefore(now),
        )
        .length;

    final username = bookings.first.userUsername ?? query;
    final stats = <String>[
      'Всего записей: $total',
      if (active > 0) 'Предстоящие: $active',
      if (past > 0) 'Прошедшие: $past',
      if (cancelled > 0) 'Отменённые: $cancelled',
      if (rejected > 0) 'Отклонённые: $rejected',
    ];
    final bookingLines = bookings.map((booking) {
      final dateLabel = _bookingDateLabel(booking, dateFormatter, dateOnlyFormatter);
      final statusEmoji = _bookingStatusEmoji(booking.status);
      return '$statusEmoji #${booking.id} — ${booking.trainingTitle} ($dateLabel) · '
          '${_statusLabel(booking.status, booking: booking)}';
    }).toList(growable: false);
    return '${RichHtml.heading('Пользователь: @$username')}'
        '${RichHtml.details(
      summary: 'Статистика',
      body: RichHtml.bullets(stats),
      alreadyEscaped: true,
    )}'
        '${RichHtml.details(
      summary: 'Записи',
      body: RichHtml.bullets(bookingLines),
      alreadyEscaped: true,
    )}';
  }

  String _bookingStatusEmoji(BookingStatus status) {
    return switch (status) {
      BookingStatus.paid => '✅',
      BookingStatus.freeTraining => '🎁',
      BookingStatus.partialPaid => '🟡',
      BookingStatus.pendingPayment => '⏳',
      BookingStatus.paymentSubmitted => '🧾',
      BookingStatus.paymentRejected => '❌',
      BookingStatus.cancelled => '🚫',
    };
  }

  String paymentActionUsage() {
    return '${RichHtml.heading('Команды модерации')}'
        '${RichHtml.paragraph(
      '<code>/approve_payment &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      '<code>/approve_partial_payment &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      '<code>/reject_payment &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      'Например: <code>/approve_partial_payment 42</code>',
      alreadyEscaped: true,
    )}';
  }

  String subscriptionCommandUsage() {
    return '${RichHtml.heading('Команды модерации')}'
        '${RichHtml.paragraph(
      '<code>/approve_subscription &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      '<code>/reject_subscription &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      '<code>/cancel_subscription &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}';
  }

  String individualSessionCommandUsage() {
    return '${RichHtml.heading('Команды модерации')}'
        '${RichHtml.paragraph(
      '<code>/approve_individual &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      '<code>/reject_individual &lt;id&gt;</code>',
      alreadyEscaped: true,
    )}';
  }

  Map<String, Object?> subscriptionDecisionInlineKeyboard(int requestId) {
    return TelegramKeyboards.subscriptionDecisionInlineKeyboard(requestId);
  }

  Map<String, Object?> individualSessionDecisionInlineKeyboard(int requestId) {
    return TelegramKeyboards.individualSessionDecisionInlineKeyboard(requestId);
  }

  Map<String, Object?> subscriptionCancelInlineKeyboard(int requestId) {
    return TelegramKeyboards.subscriptionCancelInlineKeyboard(requestId);
  }

  String bookingNotFound(int id) {
    return RichHtml.screen(
      title: 'Запись #$id не найдена',
    );
  }

  String bookingStatusUpdated(TrainingBooking booking) {
    return 'Готово! Статус записи #${booking.id} обновлен: ${_statusLabel(booking.status, booking: booking)} ✅';
  }

  String paymentAlreadyReviewed(int bookingId) {
    return RichHtml.screen(
      title: 'Запись #$bookingId уже не в статусе «На проверке»',
      lead: 'Обнови очередь и проверь актуальный статус.',
    );
  }

  String adminBookingUpdateConflict() {
    return 'Не удалось сохранить изменения: для этого пользователя уже есть запись на выбранное мероприятие.';
  }

  String paymentInstructions(TrainingBooking booking) {
    final outdoorFinalPaymentAfter = _outdoorFinalPaymentAfterLabel(booking);
    if (MessageFormatters.isOutdoorBooking(booking)) {
      final prepayPercent =
          MessageFormatters.resolveOutdoorPrepayPercent(booking.trainingPrepayPercent);
      final remainderPercent = MessageFormatters.outdoorRemainderPercent(prepayPercent);
      return '💳 <h3>Реквизиты OUTDVOR</h3>'
          '${RichHtml.table(
        <(String, String)>[
          ('Получатель', 'Денис Р.'),
          ('Банк', 'Ozon Банк'),
          (
            'К оплате сейчас:',
            '${_outdoorPrepaymentAmountLabel(booking)} ($prepayPercent% предоплата)',
          ),
          ('Остаток', 'Остальные $remainderPercent% — $outdoorFinalPaymentAfter.'),
        ],
        alreadyEscaped: true,
      )}'
          '${RichHtml.paragraph('<a href="$_sbpPaymentLink">${MessageCopy.buttonPaySbp}</a> — ссылка: <code>$_sbpPaymentLink</code>', alreadyEscaped: true)}'
          '${RichHtml.paragraph('На перевод 30 минут. Если не оплатить, запись отменится автоматически. После отмены нужно записаться заново.')}';
    }
    return '💳 <h3>Реквизиты для оплаты</h3>'
        '${RichHtml.table(
      <(String, String)>[
        ('Получатель', 'Денис Р.'),
        ('Банк', 'Ozon Банк'),
        ('Сумма', _trainingPriceLabel(booking.trainingPrice)),
        if (booking.promoCode != null)
          (
            'Промокод',
            '${_escapeHtml(booking.promoCode!)} · −${booking.promoDiscountPercent ?? 0}%',
          ),
      ],
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph('<a href="$_sbpPaymentLink">${MessageCopy.buttonPaySbp}</a> — ссылка: <code>$_sbpPaymentLink</code>', alreadyEscaped: true)}'
        '${RichHtml.paragraph('На перевод 30 минут. Если не оплатить, запись отменится автоматически. После отмены нужно записаться заново.')}';
  }

  String outdoorBookingRule(TrainingBooking booking) {
    final outdoorFinalPaymentAfter = _outdoorFinalPaymentAfterLabel(booking);
    final prepayPercent =
        MessageFormatters.resolveOutdoorPrepayPercent(booking.trainingPrepayPercent);
    final remainderPercent = MessageFormatters.outdoorRemainderPercent(prepayPercent);
    return RichHtml.screen(
      title: 'Правило OUTDVOR',
      bullets: <String>[
        'Предоплата невозвратна при отмене за 7 дней и менее до старта.',
        'Сначала вносится $prepayPercent% предоплаты, оставшиеся $remainderPercent% — '
            'офлайн $outdoorFinalPaymentAfter.',
      ],
    );
  }

  String paymentApprovedForUser(TrainingBooking booking) {
    if (booking.status == BookingStatus.partialPaid) {
      final outdoorFinalPaymentAfter = _outdoorFinalPaymentAfterLabel(booking);
      return RichHtml.screen(
        title: 'Предоплата подтверждена',
        rows: <(String, String)>[
          ('Запись', '#${booking.id}'),
          ('Статус', _statusLabel(booking.status, booking: booking)),
        ],
        paragraphs: <String>['Остаток вносится офлайн $outdoorFinalPaymentAfter.'],
      );
    }
    if (!MessageFormatters.isOutdoorBooking(booking)) {
      return RichHtml.screen(
        title: 'Оплату подтвердили',
        lead: 'Место за тобой.',
        rows: <(String, String)>[
          ('Запись', '#${booking.id}'),
          ('Статус', _statusLabel(booking.status, booking: booking)),
        ],
      );
    }

    return RichHtml.screen(
      title: 'Полная оплата подтверждена',
      lead: 'Место за тобой.',
      paragraphs: <String>['Дальше: чат поездки — напишем отдельно.'],
    );
  }

  String paymentRejectedForUser(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Оплату отклонили',
      rows: <(String, String)>[
        ('Запись', '#${booking.id}'),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
      paragraphs: <String>[
        'Проверь детали платежа и отправь подтверждение еще раз.',
        'Если нужен комментарий по отклонению, напиши саппорту @dvor_support.',
      ],
    );
  }

  String paymentReviewAdminNotification({
    required TrainingBooking booking,
    required int moderatorUserId,
    String? moderatorUsername,
  }) {
    return RichHtml.screen(
      title: 'Модерация оплаты выполнена',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Статус', _statusLabel(booking.status, booking: booking)),
        (
          'Проверил админ',
          '${_userTagById(moderatorUserId, username: moderatorUsername)} ($moderatorUserId)',
        ),
      ],
      paragraphs: <String>[
        'Дальше: при необходимости открой очередь и проверь следующую заявку.',
      ],
    );
  }

  String bookingRescheduledAdminNotification({
    required TrainingBooking before,
    required TrainingBooking after,
  }) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return RichHtml.screen(
      title: 'Операционное событие: перенос записи',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(after),
        ('Запись', '#${after.id}'),
        ('Было', '${before.trainingTitle} (${formatter.format(before.startsAt)})'),
        ('Стало', '${after.trainingTitle} (${formatter.format(after.startsAt)})'),
      ],
      paragraphs: <String>[
        'Дальше: проверь состав участников перед ближайшей тренировкой.',
      ],
    );
  }

  String bookingCancelledAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Операционное событие: отмена записи',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Событие', booking.trainingTitle),
        ('Дата', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
      ],
      paragraphs: <String>[
        'Дальше: при необходимости свяжись с участником по возврату/перезаписи.',
      ],
    );
  }

  String freeBookingCreatedAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Операционное событие: новая бесплатная запись',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Событие', booking.trainingTitle),
        ('Дата', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
    );
  }

  String bookingGroupCreatedAdminNotification({
    required List<TrainingBooking> bookings,
    required int unitPrice,
    required int totalPrice,
  }) {
    final first = bookings.first;
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final organizer = _userTagById(first.managerUserId, username: first.userUsername);
    return '${RichHtml.heading('Операционное событие: запись друга/гостей')}'
        '${RichHtml.table(
      <(String, String)>[
        ('Организатор', '$organizer (${first.managerUserId})'),
        ('Событие', first.trainingTitle),
        ('Дата', _bookingDateLabel(first, dateTimeFormatter, dateOnlyFormatter)),
        ('Участников', '${bookings.length}'),
        (
          'К оплате',
          '${bookings.length} × ${_trainingPriceLabel(unitPrice)} = ${_trainingPriceLabel(totalPrice)}',
        ),
      ],
    )}'
        '${RichHtml.details(
      summary: 'Участники',
      body: RichHtml.bullets(
        bookings
            .map(
              (booking) => '#${booking.id} ${booking.participantDisplayLabel} '
                  '(${_statusLabel(booking.status, booking: booking)})',
            )
            .toList(growable: false),
      ),
      alreadyEscaped: true,
    )}';
  }

  String trainerBookingCreatedAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Операционное событие: тренер записался',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Событие', booking.trainingTitle),
        ('Дата', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
    );
  }

  String dvorTeamBookingCreatedAdminNotification(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return RichHtml.screen(
      title: 'Операционное событие: участник команды DVOR записался',
      rows: <(String, String)>[
        ..._adminBookingIdentityRows(booking),
        ('Запись', '#${booking.id}'),
        ('Событие', booking.trainingTitle),
        ('Дата', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
    );
  }

  String outdoorInterestAdminNotification({
    required int userId,
    required String? username,
    required OutdoorActivityInfo activity,
  }) {
    final typeLabel = activity.type == OutdoorActivityType.hike ? 'походом' : 'трейлом';
    final location = activity.location?.trim();
    return RichHtml.screen(
      title: 'Кто-то заинтересовался $typeLabel',
      rows: <(String, String)>[
        ('Пользователь', '${_userTagById(userId, username: username)} ($userId)'),
        ('Событие', activity.title),
        ('Дата', MessageFormatters.outdoorDateLabel(activity.dateFrom, activity.dateTo)),
        if (location != null && location.isNotEmpty) ('Локация', location),
      ],
      paragraphs: <String>['Пока только открыл карточку — записи ещё нет.'],
    );
  }

  String subscriptionInterestAdminNotification({
    required int userId,
    required String? username,
  }) {
    return RichHtml.screen(
      title: 'Кто-то заинтересовался абонементом',
      rows: <(String, String)>[
        ('Пользователь', '${_userTagById(userId, username: username)} ($userId)'),
      ],
      paragraphs: <String>['Пока только открыл бокс-карту — заявки ещё нет.'],
    );
  }

  String pendingPaymentReminder(TrainingBooking booking) {
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    return '${RichHtml.heading('Напоминание об оплате')}'
        '${RichHtml.table(
      <(String, String)>[
        ('Запись', '#${booking.id}'),
        ('Событие', booking.trainingTitle),
        ('Когда', _bookingDateLabel(booking, dateTimeFormatter, dateOnlyFormatter)),
        ('Статус', _statusLabel(booking.status, booking: booking)),
      ],
    )}'
        '${paymentInstructions(booking)}'
        '${RichHtml.heading('Что дальше', level: 3)}'
        '${RichHtml.bullets(
      <String>[
        'После оплаты нажми «${MessageCopy.buttonSubmitPayment}» и отправь в этот чат файл с подтверждением (чек/скрин).',
        'Если кнопка не сработала, открой «${MessageCopy.buttonProfile}» и выбери нужную запись.',
      ],
    )}';
  }

  String pendingPaymentExpired(TrainingBooking booking) {
    return RichHtml.screen(
      title: 'Время на оплату истекло',
      lead: 'Запись #${booking.id} автоматически отменена.',
      paragraphs: <String>[
        'Чтобы попасть на мероприятие, оформи новую запись через «${MessageCopy.buttonBookTraining}».',
      ],
    );
  }

  String chooseTrainingForBooking(List<TrainingInfo> items) {
    if (items.isEmpty) {
      return noUpcomingForBooking();
    }
    final dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final dateOnlyFormatter = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer()..write(bookingSelectionPrompt());
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('${index + 1}', item.title),
            ('🕒 Когда', _trainingDateLabel(item, dateTimeFormatter, dateOnlyFormatter)),
            ('📍 Где', item.location),
            if (item.price != null) ('Взнос', _trainingPriceLabel(item.price)),
            ('Участники', _participantsLimitLabel(item.participantsLimit)),
          ],
        ),
      );
    }
    return buffer.toString();
  }

  String bookingSelectionPrompt() {
    return RichHtml.screen(
      title: 'Запись',
      lead: 'Выбери мероприятие для записи.',
      paragraphs: <String>[
        'Подсказка: отправь номер из списка или нажми кнопку с событием.',
      ],
    );
  }

  String paymentDetailsSent(TrainingBooking booking) {
    if (booking.status == BookingStatus.partialPaid) {
      return partialPaidRemainderOffline(booking);
    }
    if (!MessageFormatters.isOutdoorBooking(booking)) {
      return '${paymentInstructions(booking)}'
          '${RichHtml.heading('Что дальше', level: 3)}'
          '${RichHtml.bullets(
        <String>[
          'Оплати по реквизитам выше.',
          'Нажми «${MessageCopy.buttonSubmitPayment}» и отправь файл чека (документ/фото) в этот чат 📎',
          'Без файла подтверждения заявка не уйдёт на проверку.',
        ],
      )}';
    }

    return '${paymentInstructions(booking)}'
        '${RichHtml.heading('Что дальше', level: 3)}'
        '${RichHtml.bullets(
      <String>[
        'Оплати по реквизитам выше.',
        'Выбери тип оплаты: «${MessageCopy.buttonPayFully}» или «${MessageCopy.buttonPayPartially}».',
        'Пришли файл чека (документ/фото) в этот чат 📎',
        'Без файла подтверждения заявка не уйдёт на проверку.',
      ],
    )}';
  }

  String groupPaymentNextSteps({required bool outdoor}) {
    if (outdoor) {
      return '${RichHtml.heading('Что дальше', level: 3)}'
          '${RichHtml.bullets(
        <String>[
          'Оплати по реквизитам выше (сумма за всю группу).',
          'Выбери тип оплаты: «${MessageCopy.buttonPayFully}» или «${MessageCopy.buttonPayPartially}».',
          'Пришли файл чека в этот чат 📎',
        ],
      )}';
    }
    return '${RichHtml.heading('Что дальше', level: 3)}'
        '${RichHtml.bullets(
      <String>[
        'Оплати полную сумму за группу.',
        'Нажми «${MessageCopy.buttonSubmitPayment}» и отправь файл чека в этот чат 📎',
      ],
    )}';
  }

  String paymentProofRequired() {
    return 'Чтобы отправить заявку на проверку:\n'
        '1) Пришли файл с подтверждением оплаты (документ или фото чека).\n'
        '2) Дождись ответа — бот напишет сам.';
  }

  String paymentProofUnavailableHint(TrainingBooking booking) {
    return 'Не удалось подгрузить файл подтверждения для записи #${booking.id}.\n'
        'Проверь заявку в личке пользователя: ${_userTag(booking)} (${booking.userId}).';
  }

  String economicSummary(EconomicSummary summary, {String? periodLabel}) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final periodRange =
        '${dateFormatter.format(summary.period.startInclusive)} — ${dateFormatter.format(summary.period.endExclusive.subtract(const Duration(days: 1)))}';
    final finance = <String>[
      'Выручка: ${_money(summary.totalRevenue)}',
      'Полностью оплаченных бронирований: ${summary.paidBookingsCount}',
      if (summary.partialPaidBookingsCount > 0)
        'Предоплат: ${summary.partialPaidBookingsCount} (на сумму ${_money(summary.partialPaidRevenue)})',
      'Средний чек: ${_money(summary.averageCheck)}',
      if (summary.freeBookingsCount > 0) 'Бесплатных бронирований: ${summary.freeBookingsCount}',
      if (summary.regularFreeBookingsCount > 0)
        'Бесплатные по цене мероприятия: ${summary.regularFreeBookingsCount}',
      if (summary.starterFreeBookingsCount > 0)
        'Бесплатные стартовые: ${summary.starterFreeBookingsCount}',
      if (summary.unknownPriceBookingsCount > 0)
        'Без цены в данных: ${summary.unknownPriceBookingsCount}',
    ];
    final categories = summary.byCategory.isEmpty
        ? <String>['Нет оплаченных бронирований с ценой']
        : summary.byCategory
            .map((item) =>
                '${_categoryLabel(item.category)}: ${_money(item.revenue)} (${item.bookingsCount})')
            .toList(growable: false);
    final events = summary.byEvent.isEmpty
        ? <String>['Нет данных']
        : summary.byEvent
            .map((item) => '${item.eventTitle}: ${_money(item.revenue)} (${item.bookingsCount})')
            .toList(growable: false);
    return '${RichHtml.heading('Экономическая сводка ${periodLabel ?? 'по периоду'}')}'
        '${RichHtml.paragraph('Период: $periodRange')}'
        '${RichHtml.detailsBlocks(
      <(String, String)>[
        ('Финансы', RichHtml.bullets(finance)),
        ('По категориям', RichHtml.bullets(categories)),
        ('Топ мероприятий по выручке', RichHtml.bullets(events)),
      ],
      alreadyEscaped: true,
    )}';
  }

  String funnelAnalyticsOnboarding(FunnelAnalytics analytics) {
    final generated = DateFormat('dd.MM.yyyy HH:mm').format(analytics.generatedAt.toLocal());
    final started = analytics.funnelUsers;
    final pathBody = StringBuffer()
      ..write(
        RichHtml.bullets(
          <String>[
            _funnelStepLine(
              index: 1,
              title: 'Начали квиз',
              count: analytics.funnelUsers,
              startCount: started,
            ),
            _funnelStepLine(
              index: 2,
              title: 'Ответили, что сейчас важнее',
              count: analytics.quizGoalAnsweredCount,
              previousCount: analytics.funnelUsers,
              startCount: started,
            ),
            _funnelStepLine(
              index: 3,
              title: 'Указали опыт',
              count: analytics.quizExperienceAnsweredCount,
              previousCount: analytics.quizGoalAnsweredCount,
              startCount: started,
            ),
            _funnelStepLine(
              index: 4,
              title: 'Выбрали формат и увидели карту клуба',
              count: analytics.trackChosenCount,
              previousCount: analytics.quizExperienceAnsweredCount,
              startCount: started,
            ),
            _funnelStepLine(
              index: 5,
              title: 'Первая тренировка (активация)',
              count: analytics.activationsTotal,
              previousCount: analytics.trackChosenCount,
              startCount: started,
            ),
          ],
        ),
      )
      ..write(
        RichHtml.paragraph(
          'Пропуск квиза сразу ведёт на шаг 4, поэтому шаги 2–3 могут быть меньше шага 4.',
        ),
      );
    final activationBody = StringBuffer()
      ..write(
        RichHtml.paragraph(
          'Активация — первая подтверждённая запись: оплата, бонус или слот команды.',
        ),
      )
      ..write(
        RichHtml.bullets(
          <String>[
            'Всего: ${analytics.activationsTotal}',
            'За 7 дней: ${analytics.activationsLast7Days}',
            'За 30 дней: ${analytics.activationsLast30Days}',
            'Дошли за 21 день от старта квиза: ${_percentOrDash(analytics.activationRate21Days)}',
            'Среднее время до первой тренировки: ${_daysOrDash(analytics.avgTimeToValueDays)}',
            'С карты клуба до записи: ${_percentOrDash(analytics.mapToActivationRate)}',
            'Сейчас на паузе «нужно больше времени»: ${analytics.snoozeActiveNow}',
          ],
        ),
      );
    final nowBody = StringBuffer()
      ..write(RichHtml.paragraph('Снимок, не воронка: на каком шаге человек в этот момент.'))
      ..write(
        RichHtml.bullets(
          _orderedCountLines(
            analytics.phaseCounts,
            order: const <String>[
              'phase1_quiz',
              'phase1_track',
              'phase1_map',
              'phase2_activation',
              'paused',
              'phase3_integration',
              'phase4_completion',
              'completed',
              'returning',
              'not_started',
              'legacy_skipped',
              'null',
            ],
            labelOf: _onboardingPhaseLabel,
          ),
        ),
      );
    final quizBody = StringBuffer()
      ..write(RichHtml.paragraph('Цель'))
      ..write(
        RichHtml.bullets(
          _orderedCountLines(
            analytics.quizGoalCounts,
            order: const <String>['form_strength', 'endurance_run', 'outdoor_hikes', 'unknown'],
            labelOf: _quizGoalLabel,
            total: analytics.quizGoalAnsweredCount,
          ),
        ),
      )
      ..write(RichHtml.paragraph('Опыт'))
      ..write(
        RichHtml.bullets(
          _orderedCountLines(
            analytics.quizExperienceCounts,
            order: const <String>['beginner', 'returning', 'regular'],
            labelOf: _quizExperienceLabel,
            total: analytics.quizExperienceAnsweredCount,
          ),
        ),
      )
      ..write(RichHtml.paragraph('Формат старта'))
      ..write(
        RichHtml.bullets(
          _orderedCountLines(
            analytics.trackCounts,
            order: const <String>['one_off', 'outdoor'],
            labelOf: _trackLabel,
            total: analytics.trackChosenCount,
          ),
        ),
      );
    final nudgeBody = StringBuffer()
      ..write(RichHtml.paragraph('Каждое уходит один раз. Число — скольким людям бот уже дожимал.'))
      ..write(RichHtml.bullets(_nudgeCountLines(analytics.nudgeKeyCounts)));
    return '${RichHtml.heading('Воронка онбординга')}'
        '${RichHtml.paragraph('Срез: $generated')}'
        '${RichHtml.paragraph(
      'Как читать: в «Пути новичка» число — сколько людей дошли до шага. '
      '% — доля от тех, кто начал квиз. Шаг считается пройденным, даже если человек уже ушёл дальше.',
    )}'
        '${RichHtml.detailsBlocks(
      <(String, String)>[
        (
          'Коротко',
          RichHtml.bullets(
            <String>[
              'Нажали Start когда-либо: ${analytics.startedUsersTotal}',
              'Из них в новой воронке: ${analytics.funnelUsers}',
              'Старые пользователи без квиза: ${analytics.legacyUsers}',
              'Новых Start за 7 дней: ${analytics.startedLast7Days}',
              'Новых Start за 30 дней: ${analytics.startedLast30Days}',
            ],
          ),
        ),
        ('Путь новичка', pathBody.toString()),
        ('Первая тренировка', activationBody.toString()),
        ('Где люди сейчас', nowBody.toString()),
        (
          'Откуда пришли',
          RichHtml.bullets(
            _orderedCountLines(
              analytics.entryTypeCounts,
              order: const <String>[
                'group',
                'referral',
                'cold',
                'returning',
                'legacy',
                'unknown',
              ],
              labelOf: _entryTypeLabel,
              total: analytics.startedUsersTotal,
            ),
          ),
        ),
        ('Что выбрали в квизе', quizBody.toString()),
        ('Напоминания', nudgeBody.toString()),
      ],
      alreadyEscaped: true,
    )}';
  }

  String funnelAnalyticsFeedback(FunnelAnalytics analytics) {
    final responseRate = analytics.feedbackResponseRate;
    final sessions = analytics.topFeedbackSessions.isEmpty
        ? <String>['Пока нет']
        : analytics.topFeedbackSessions
            .map(
              (session) => '${session.trainingTitle} — ${session.responses} '
                  '(👍${session.greatCount} / 🙂${session.okCount} / 👎${session.weakCount})',
            )
            .toList(growable: false);
    final comments = analytics.recentFeedbackComments.isEmpty
        ? <String>['Пока нет']
        : analytics.recentFeedbackComments.map((item) {
            final date = DateFormat('dd.MM HH:mm').format(item.submittedAt.toLocal());
            final comment = (item.comment ?? '').trim();
            final short = comment.length > 160 ? '${comment.substring(0, 157)}…' : comment;
            return '$date · ${_feedbackRatingLabel(item.rating)} · ${item.trainingTitle} — $short';
          }).toList(growable: false);
    return '${RichHtml.heading('Анонимный фидбэк')}'
        '${RichHtml.detailsBlocks(
      <(String, String)>[
        (
          'Сводка',
          RichHtml.bullets(
            <String>[
              'Запросов отправлено: ${analytics.feedbackRequestsSent}',
              'Ответов: ${analytics.feedbackResponses}',
              'Response rate: ${_percentOrDash(responseRate)}',
              'Пропусков: ${analytics.feedbackSkipped}',
              'Комментариев: ${analytics.feedbackCommentsCount}',
            ],
          ),
        ),
        (
          'Оценки',
          RichHtml.bullets(_mapLines(analytics.feedbackRatingCounts, _feedbackRatingLabel))
        ),
        ('Топ занятий по отзывам', RichHtml.bullets(sessions)),
        ('Последние комментарии (анонимно)', RichHtml.bullets(comments)),
      ],
      alreadyEscaped: true,
    )}';
  }

  String bookingAnalytics(BookingAnalytics analytics) {
    final generated = DateFormat('dd.MM.yyyy HH:mm').format(analytics.generatedAt.toLocal());
    return '${RichHtml.heading('Аналитика бронирований')}'
        '${RichHtml.paragraph('Срез: $generated')}'
        '${RichHtml.detailsBlocks(
      <(String, String)>[
        (
          'Объём',
          RichHtml.bullets(
            <String>[
              'Всего записей: ${analytics.totalBookings}',
              'Создано за 7д: ${analytics.createdLast7Days}',
              'Создано за 30д: ${analytics.createdLast30Days}',
              'Уникальных пользователей с подтверждёнными: ${analytics.uniqueUsersWithConfirmed}',
              'С промокодом: ${analytics.promoCodeBookingsCount}',
            ],
          ),
        ),
        (
          'Воронка оплаты (сейчас)',
          RichHtml.bullets(
            <String>[
              'Ожидает оплату: ${analytics.pendingPaymentCount}',
              'На проверке: ${analytics.paymentSubmittedCount}',
              'Предстоящие подтверждённые: ${analytics.upcomingConfirmedCount}',
              'Прошедшие подтверждённые: ${analytics.pastConfirmedCount}',
            ],
          ),
        ),
        (
          'Динамика',
          RichHtml.bullets(
            <String>[
              'Подтверждено за 7д: ${analytics.confirmedLast7Days}',
              'Подтверждено за 30д: ${analytics.confirmedLast30Days}',
              'Отменено за 7д: ${analytics.cancelledLast7Days}',
              'Отменено за 30д: ${analytics.cancelledLast30Days}',
              'Конверсия за 30д: ${_percentOrDash(analytics.conversionRate30Days)}',
            ],
          ),
        ),
        ('Статусы (все)', RichHtml.bullets(_mapLines(analytics.statusCounts, _bookingStatusLabel))),
        (
          'Подтверждённые по категориям',
          RichHtml.bullets(_mapLines(analytics.confirmedByCategory, _activityCategoryLabel)),
        ),
      ],
      alreadyEscaped: true,
    )}';
  }

  String loyaltyAnalytics(LoyaltyAnalytics analytics) {
    final generated = DateFormat('dd.MM.yyyy HH:mm').format(analytics.generatedAt.toLocal());
    final cancelLines = <String>[
      '30д: записали ${analytics.starterBonusBookedLast30Days}, '
          'отменили ${analytics.starterBonusCancelledLast30Days}'
          '${_ratioOrEmpty(analytics.starterBonusCancelRate30Days)}',
      '90д: записали ${analytics.starterBonusBookedLast90Days}, '
          'отменили ${analytics.starterBonusCancelledLast90Days}'
          '${_ratioOrEmpty(analytics.starterBonusCancelRate90Days)}',
    ];
    for (final entry in analytics.starterBonusCancelledByCategoryLast30Days.entries) {
      if (entry.value <= 0) {
        continue;
      }
      cancelLines.add('30д ${entry.key}: отмен ${entry.value}');
    }
    return '${RichHtml.heading('Вершинки')}'
        '${RichHtml.paragraph('Срез: $generated')}'
        '${RichHtml.detailsBlocks(
      <(String, String)>[
        (
          'Вершинки',
          RichHtml.bullets(
            <String>[
              'Начислено: ${analytics.peaksEarned}',
              'Списано: ${analytics.peaksSpent}',
              'Сгорело: ${analytics.peaksExpired}',
              'На балансах: ${analytics.peaksRemaining}',
            ],
          ),
        ),
        (
          'Стартовый бонус',
          RichHtml.bullets(
            <String>[
              'Доступен: ${analytics.starterBonusAvailable}',
              'Использован: ${analytics.starterBonusConsumed}',
            ],
          ),
        ),
        (
          'Рефералы',
          RichHtml.bullets(
            <String>[
              'Атрибуций всего: ${analytics.referralAttributionsTotal}',
              'За 30д: ${analytics.referralAttributionsLast30Days}',
            ],
          ),
        ),
        (
          'Бесплатные тренировки (стартовый бонус)',
          RichHtml.bullets(
            <String>['Стартовый бонус: ${analytics.freeByStarterCount}'],
          ),
        ),
        ('Отмены стартового бонуса', RichHtml.bullets(cancelLines)),
      ],
      alreadyEscaped: true,
    )}';
  }

  String subscriptionAnalytics(SubscriptionAnalytics analytics) {
    final generated = DateFormat('dd.MM.yyyy HH:mm').format(analytics.generatedAt.toLocal());
    return '${RichHtml.heading('Сводка абонементов')}'
        '${RichHtml.paragraph('Срез: $generated')}'
        '${RichHtml.detailsBlocks(
      <(String, String)>[
        (
          'Абонементы',
          RichHtml.bullets(
            <String>[
              'Активные сейчас: ${analytics.activeCount}',
              'БАЗА: ${analytics.activeBazaCount} · УДАР: ${analytics.activeUdarCount}',
              'Скоро истекают (≤7д): ${analytics.expiringSoonCount}',
              'На проверке: ${analytics.pendingCount}',
              'Отменённые / отклонённые: ${analytics.cancelledOrRejectedCount}',
              'Всего когда-либо approved (active rows): ${analytics.approvedTotal}',
            ],
          ),
        ),
      ],
      alreadyEscaped: true,
    )}';
  }

  List<String> _mapLines(Map<String, int> counts, String Function(String) label) {
    if (counts.isEmpty) {
      return const <String>['Нет данных'];
    }
    return counts.entries.map((e) => '${label(e.key)}: ${e.value}').toList(growable: false);
  }

  String _funnelStepLine({
    required int index,
    required String title,
    required int count,
    required int startCount,
    int? previousCount,
  }) {
    final parts = <String>['$index. $title — $count'];
    if (startCount > 0) {
      parts.add('${_shareOf(count, startCount)} от старта');
    }
    if (previousCount != null && previousCount > 0 && count <= previousCount) {
      parts.add('${_shareOf(count, previousCount)} от предыдущего');
    }
    return parts.join(' · ');
  }

  List<String> _orderedCountLines(
    Map<String, int> counts, {
    required List<String> order,
    required String Function(String) labelOf,
    int? total,
  }) {
    if (counts.isEmpty) {
      return const <String>['Пока нет'];
    }
    final seen = <String>{};
    final lines = <String>[];
    for (final key in order) {
      final value = counts[key];
      if (value == null) {
        continue;
      }
      seen.add(key);
      lines.add(_countShareLine(labelOf(key), value, total));
    }
    final remaining = counts.entries.where((entry) => !seen.contains(entry.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in remaining) {
      lines.add(_countShareLine(labelOf(entry.key), entry.value, total));
    }
    return lines;
  }

  String _countShareLine(String label, int value, int? total) {
    if (total == null || total <= 0) {
      return '$label: $value';
    }
    return '$label: $value (${_shareOf(value, total)})';
  }

  List<String> _nudgeCountLines(Map<String, int> counts) {
    if (counts.isEmpty) {
      return const <String>['Пока нет'];
    }
    const order = <String>[
      'p1_30m',
      'p1_2h',
      'p1_6h',
      'p1_24h',
      'p2_d2',
      'p2_d5',
      'p2_d7',
      'group_invite_1',
      'group_invite_2',
      'group_invite_3',
    ];
    return _orderedCountLines(
      counts,
      order: order,
      labelOf: _onboardingNudgeLabel,
    );
  }

  String _shareOf(int part, int total) {
    if (total <= 0) {
      return '—';
    }
    return '${(part * 100 / total).toStringAsFixed(0)}%';
  }

  String _percentOrDash(double? value) {
    if (value == null) {
      return '—';
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _ratioOrEmpty(double? value) {
    if (value == null) {
      return '';
    }
    return ' (${(value * 100).toStringAsFixed(0)}%)';
  }

  String _daysOrDash(double? value) {
    if (value == null) {
      return '—';
    }
    return '${value.toStringAsFixed(1)} дн';
  }

  String _onboardingPhaseLabel(String raw) {
    return switch (raw) {
      'legacy_skipped' => 'старые пользователи, без квиза',
      'phase1_quiz' => 'квиз: приветствие или цель',
      'phase1_track' => 'квиз: выбор формата',
      'phase1_map' => 'карта клуба',
      'phase2_activation' => 'ждут первую запись',
      'phase3_integration' => 'первая тренировка уже есть',
      'phase4_completion' => 'завершение (экран пока не используется)',
      'completed' => 'воронка закрыта (экран пока не используется)',
      'paused' => 'пауза «нужно больше времени»',
      'returning' => 'вернулись позже',
      'not_started' => 'ещё не начали',
      'null' => 'фаза не проставлена',
      _ => raw,
    };
  }

  String _entryTypeLabel(String raw) {
    return switch (raw) {
      'group' => 'из группы',
      'cold' => 'напрямую в личку',
      'referral' => 'по реферальной ссылке',
      'returning' => 'вернулись',
      'legacy' => 'были в боте до воронки',
      'unknown' => 'не указан',
      _ => raw,
    };
  }

  String _onboardingNudgeLabel(String raw) {
    return switch (raw) {
      'p1_30m' => 'через 30 минут: дожать квиз',
      'p1_2h' => 'через 2 часа: дожать квиз',
      'p1_6h' => 'через 6 часов: предложить помощь',
      'p1_24h' => 'через сутки: показать расписание',
      'p2_d2' => 'день 2: записаться',
      'p2_d5' => 'день 5: попробовать другой формат',
      'p2_d7' => 'день 7: записаться, иначе поддержка',
      'group_invite_1' => 'приглашение в группу: первое',
      'group_invite_2' => 'приглашение в группу: второе',
      'group_invite_3' => 'приглашение в группу: третье',
      _ => raw,
    };
  }

  String _quizGoalLabel(String raw) {
    return switch (raw) {
      'form_strength' => 'форма / сила',
      'endurance_run' => 'выносливость / бег',
      'outdoor_hikes' => 'outdoor / походы',
      'unknown' => 'пока не знаю',
      _ => raw,
    };
  }

  String _quizExperienceLabel(String raw) {
    return switch (raw) {
      'beginner' => 'новичок',
      'returning' => 'был перерыв',
      'regular' => 'регулярно',
      _ => raw,
    };
  }

  String _trackLabel(String raw) {
    return switch (raw) {
      'one_off' => 'разовая тренировка',
      'outdoor' => 'outdoor / походы',
      _ => raw,
    };
  }

  String _feedbackRatingLabel(String raw) {
    return switch (raw) {
      'great' => 'отлично',
      'ok' => 'нормально',
      'weak' => 'слабо',
      'skipped' => 'пропуск',
      _ => raw,
    };
  }

  String _bookingStatusLabel(String raw) {
    return switch (raw) {
      'pending_payment' => 'ожидает оплату',
      'payment_submitted' => 'на проверке',
      'partial_paid' => 'предоплата',
      'paid' => 'оплачено',
      'free_training' => 'бесплатная',
      'payment_rejected' => 'оплата отклонена',
      'cancelled' => 'отменено',
      _ => raw,
    };
  }

  String _activityCategoryLabel(String raw) {
    return switch (raw) {
      'trainings' => 'тренировки',
      'hikes' => 'походы',
      'trails' => 'трейлы',
      _ => raw,
    };
  }

  String chooseEconomicSummaryPeriod() {
    return RichHtml.screen(
      title: 'Экономическая сводка',
      lead: 'Выбери период для экономической сводки.',
    );
  }

  String adminBroadcastPrompt() {
    return RichHtml.screen(
      title: 'Рассылка',
      lead: 'Отправь текст и/или фото для рассылки.',
      paragraphs: <String>[
        'Можно прислать одно фото или альбом (несколько фото).',
        'Подпись к фото сохранится. Для текста поддерживается HTML: '
            '<code>&lt;b&gt;</code>, <code>&lt;i&gt;</code>, <code>&lt;code&gt;</code> и т.д.',
        'Нажми «${MessageCopy.buttonMainMenu}», чтобы отменить.',
      ],
      alreadyEscaped: true,
    );
  }

  String adminBroadcastPreview(String text) {
    return '${RichHtml.heading('Предпросмотр сообщения')}'
        '${RichHtml.paragraph(text, alreadyEscaped: true)}'
        '${RichHtml.paragraph('Выбери, куда отправить рассылку.')}';
  }

  String adminBroadcastMediaPreview({required int photoCount}) {
    final photosLabel = photoCount == 1 ? '1 фото' : '$photoCount фото';
    return RichHtml.screen(
      title: 'Предпросмотр рассылки',
      lead: 'Будет отправлено: $photosLabel (как в сообщении выше, с подписью если она была).',
      paragraphs: <String>['Выбери, куда отправить рассылку.'],
    );
  }

  String adminBroadcastMediaCollecting({required int photoCount}) {
    final photosLabel = photoCount == 1 ? '1 фото' : '$photoCount фото';
    return RichHtml.screen(
      title: 'Рассылка',
      lead: 'Получено: $photosLabel.',
      paragraphs: <String>[
        'Если это альбом — дождись загрузки всех фото, затем появится выбор получателей.',
      ],
    );
  }

  String adminBroadcastSent({
    required int sent,
    required int failed,
    required int total,
    required bool groupSent,
    bool outdoorPlus = false,
  }) {
    final delivery = failed > 0
        ? 'Пользователям: $sent из $total доставлено, не доставлено: $failed.'
        : 'Пользователям: $sent из $total доставлено.';
    return RichHtml.screen(
      title: 'Рассылка завершена',
      paragraphs: <String>[
        if (outdoorPlus) 'Сегмент: направление outdoor.',
        delivery,
        if (groupSent) 'В группу: отправлено.',
      ],
    );
  }

  String adminBroadcastGroupOnly({required bool groupSent}) {
    if (groupSent) {
      return RichHtml.screen(
        title: 'Рассылка',
        lead: 'Сообщение отправлено в группу.',
      );
    }
    return RichHtml.screen(
      title: 'Рассылка',
      lead: 'Группа не настроена или не удалось отправить сообщение в группу.',
    );
  }

  String adminBroadcastCancelled() {
    return RichHtml.screen(
      title: 'Рассылка отменена',
    );
  }

  String adminBroadcastNoUsers() {
    return RichHtml.screen(
      title: 'Нет пользователей для рассылки',
      lead: 'Только пользователи, начавшие диалог с ботом (/start), получат сообщения.',
    );
  }

  Map<String, Object?> broadcastTargetKeyboard({required bool hasGroup}) {
    return TelegramKeyboards.broadcastTargetKeyboard(hasGroup: hasGroup);
  }
}
