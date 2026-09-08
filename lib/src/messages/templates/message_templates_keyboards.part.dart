part of '../message_templates.dart';

extension MessageTemplatesKeyboards on MessageTemplates {
  Map<String, Object?> privateMenuKeyboard({
    required bool isAdmin,
    bool canViewParticipantsList = false,
    bool showReturnToAdminMenu = false,
  }) {
    return TelegramKeyboards.privateMenuKeyboard(
      isAdmin: isAdmin,
      canViewParticipantsList: canViewParticipantsList,
      showReturnToAdminMenu: showReturnToAdminMenu,
    );
  }

  Map<String, Object?> onboardingContinueKeyboard() {
    return TelegramKeyboards.onboardingContinueKeyboard();
  }

  Map<String, Object?> onboardingQuizGoalKeyboard() {
    return TelegramKeyboards.onboardingQuizGoalKeyboard();
  }

  Map<String, Object?> onboardingQuizExperienceKeyboard() {
    return TelegramKeyboards.onboardingQuizExperienceKeyboard();
  }

  Map<String, Object?> onboardingTrackKeyboard() {
    return TelegramKeyboards.onboardingTrackKeyboard();
  }

  Map<String, Object?> onboardingMapCtaKeyboard({required bool outdoorTrack}) {
    return TelegramKeyboards.onboardingMapCtaKeyboard(outdoorTrack: outdoorTrack);
  }

  Map<String, Object?> onboardingNudgeKeyboard({bool quizIncomplete = false}) {
    return TelegramKeyboards.onboardingNudgeKeyboard(quizIncomplete: quizIncomplete);
  }

  Map<String, Object?> onboardingActivationKeyboard() {
    return TelegramKeyboards.onboardingActivationKeyboard();
  }

  Map<String, Object?> trainingFeedbackKeyboard() {
    return TelegramKeyboards.trainingFeedbackKeyboard();
  }

  Map<String, Object?> trainingFeedbackCommentKeyboard() {
    return TelegramKeyboards.trainingFeedbackCommentKeyboard();
  }

  Map<String, Object?> adminToolsKeyboard() {
    return TelegramKeyboards.adminToolsKeyboard();
  }

  Map<String, Object?> adminOnboardingMediaHubKeyboard() {
    return TelegramKeyboards.adminOnboardingMediaHubKeyboard();
  }

  Map<String, Object?> adminOnboardingMediaSlotKeyboard({required bool hasMedia}) {
    return TelegramKeyboards.adminOnboardingMediaSlotKeyboard(hasMedia: hasMedia);
  }

  Map<String, Object?> adminAnalyticsKeyboard() {
    return TelegramKeyboards.adminAnalyticsKeyboard();
  }

  Map<String, Object?> bookingSelectionKeyboard(List<TrainingInfo> items) {
    return TelegramKeyboards.bookingSelectionKeyboard(items);
  }

  Map<String, Object?> categorySelectionKeyboard() {
    return TelegramKeyboards.categorySelectionKeyboard();
  }

  Map<String, Object?> scheduleCategoryActionsKeyboard({
    bool showOutdoorActions = false,
  }) {
    return TelegramKeyboards.scheduleCategoryActionsKeyboard(
      showOutdoorActions: showOutdoorActions,
    );
  }

  Map<String, Object?> coachingStaffActionsKeyboard() {
    return TelegramKeyboards.coachingStaffActionsKeyboard();
  }

  Map<String, Object?> trainerSelectionKeyboard(List<TrainerInfo> trainers) {
    return TelegramKeyboards.trainerSelectionKeyboard(trainers);
  }

  Map<String, Object?> outdoorSelectionKeyboard(List<OutdoorActivityInfo> items) {
    return TelegramKeyboards.outdoorSelectionKeyboard(items);
  }

  Map<String, Object?> outdoorDetailTypeKeyboard() {
    return TelegramKeyboards.outdoorDetailTypeKeyboard();
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
    bool showLoyaltySpend = false,
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
    bool showPromoCodeEntry = false,
  }) {
    return TelegramKeyboards.paymentConfirmationKeyboard(
      showStarterBonus: showStarterBonus,
      showLoyaltySpend: showLoyaltySpend,
      showCancelBooking: showCancelBooking,
      showOutdoorPaymentTypeChoice: showOutdoorPaymentTypeChoice,
      showPromoCodeEntry: showPromoCodeEntry,
    );
  }

  Map<String, Object?> simpleNavigationKeyboard() {
    return TelegramKeyboards.simpleNavigationKeyboard();
  }

  Map<String, Object?> profileActionsKeyboard() {
    return TelegramKeyboards.profileActionsKeyboard();
  }

  String chooseBookFriendCategory() {
    return RichHtml.screen(
      title: 'Записать друга',
      lead: 'Выбери категорию мероприятия.',
    );
  }

  String chooseBookFriendEvent(List<TrainingInfo> items) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Записать друга'))
      ..write(RichHtml.paragraph('Выбери мероприятие.'));
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      buffer.write(
        RichHtml.table(
          <(String, String)>[
            ('${index + 1}', item.title),
            ('Когда', formatter.format(item.startsAt)),
            ('Где', item.location),
            if (item.price != null) ('Цена', _trainingPriceLabel(item.price)),
          ],
        ),
      );
    }
    return buffer.toString();
  }

  String askPartyParticipants({required TrainingInfo training}) {
    final unitPrice = training.price ?? 0;
    return '${RichHtml.heading('Кого записать?')}'
        '${RichHtml.table(
      <(String, String)>[
        ('Событие', training.title),
        ('Цена за человека', _trainingPriceLabel(unitPrice)),
      ],
    )}'
        '${RichHtml.paragraph(
      'Напиши Telegram-username с @ или ФИО через запятую (или с новой строки).',
    )}'
        '${RichHtml.paragraph('Примеры:')}'
        '${RichHtml.paragraph('<code>@anna, @ivan</code>', alreadyEscaped: true)}'
        '${RichHtml.paragraph('<code>Бабушка Мария, Дедушка Пётр</code>', alreadyEscaped: true)}'
        '${RichHtml.paragraph('<code>@anna, Бабушка Мария</code>', alreadyEscaped: true)}'
        '${RichHtml.bullets(
      <String>[
        'Без @ имя считается гостем (ФИО), а не Telegram-аккаунтом.',
        'Можно записать до 5 человек.',
        'Свою запись это не создаёт — себя запиши отдельно через «Записаться».',
      ],
    )}';
  }

  String invalidPartyParticipantsInput() {
    return '${RichHtml.heading('Не понял список участников')}'
        '${RichHtml.paragraph(
      'Telegram-username указывай с @, иначе это будет ФИО гостя.',
    )}'
        '${RichHtml.paragraph('Нельзя указать свой собственный @username.')}'
        '${RichHtml.paragraph('<code>@anna, Бабушка Мария</code>', alreadyEscaped: true)}'
        '${RichHtml.paragraph('До 5 человек за раз.')}';
  }

  String partyParticipantConflict(String label) {
    return RichHtml.screen(
      title: 'Уже есть запись',
      lead: '$label — уже есть запись на это мероприятие.',
    );
  }

  String partyManagerLimitExceeded() {
    return '⚠️ На одно мероприятие можно записать не больше 5 друзей/гостей '
        '(своя запись через «Записаться» не входит в этот лимит).';
  }

  String partyDuplicateParticipant(String label) {
    return RichHtml.screen(
      title: 'Повтор в списке',
      lead: '$label повторяется в списке.',
    );
  }

  String bookingGroupCreated({
    required List<TrainingBooking> bookings,
    required int unitPrice,
    required int totalPrice,
  }) {
    final first = bookings.first;
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return '${RichHtml.heading('Записи созданы (${bookings.length} чел.)')}'
        '${RichHtml.table(
      <(String, String)>[
        ('Событие', first.trainingTitle),
        ('Дата', formatter.format(first.startsAt)),
        ('Локация', first.location),
        (
          'К оплате',
          '${bookings.length} × ${_trainingPriceLabel(unitPrice)} = ${_trainingPriceLabel(totalPrice)}',
        ),
      ],
    )}'
        '${RichHtml.details(
      summary: 'Участники',
      body: RichHtml.bullets(
        bookings.map((booking) => booking.participantDisplayLabel).toList(growable: false),
      ),
      alreadyEscaped: true,
    )}';
  }

  String paymentInstructionsForGroup({
    required TrainingBooking booking,
    required int participantsCount,
    required int unitPrice,
    required int totalPrice,
  }) {
    if (MessageFormatters.isOutdoorBooking(booking)) {
      final outdoorFinalPaymentAfter = _outdoorFinalPaymentAfterLabel(booking);
      final prepayPercent =
          MessageFormatters.resolveOutdoorPrepayPercent(booking.trainingPrepayPercent);
      final remainderPercent = MessageFormatters.outdoorRemainderPercent(prepayPercent);
      final groupPrepayment = totalPrice <= 0
          ? 0
          : MessageFormatters.outdoorPrepaymentAmount(totalPrice, prepayPercent: prepayPercent);
      return '💳 <h3>Реквизиты OUTDVOR</h3>'
          '${RichHtml.table(
        <(String, String)>[
          ('Получатель', 'Денис Р.'),
          ('Банк', 'Ozon Банк'),
          (
            'Полная сумма за группу',
            '$participantsCount × ${_trainingPriceLabel(unitPrice)} = ${_trainingPriceLabel(totalPrice)}',
          ),
          (
            'К оплате сейчас при предоплате',
            '${_trainingPriceLabel(groupPrepayment)} ($prepayPercent% от суммы группы)',
          ),
          ('Остаток', 'Остальные $remainderPercent% — $outdoorFinalPaymentAfter.'),
        ],
      )}'
          '${RichHtml.paragraph(
        '<a href="$_sbpPaymentLink">${MessageCopy.buttonPaySbp}</a> — '
        'перейди по ссылке и введи сумму.',
        alreadyEscaped: true,
      )}'
          '${RichHtml.paragraph(
        'На перевод 30 минут. Если не оплатить, запись отменится автоматически. '
        'После отмены нужно записаться заново.',
      )}';
    }
    return '💳 <h3>Реквизиты для оплаты</h3>'
        '${RichHtml.table(
      <(String, String)>[
        ('Получатель', 'Денис Р.'),
        ('Банк', 'Ozon Банк'),
        (
          'К оплате за группу',
          '$participantsCount × ${_trainingPriceLabel(unitPrice)} = ${_trainingPriceLabel(totalPrice)}',
        ),
        if (booking.promoCode != null)
          (
            'Промокод',
            '${booking.promoCode!} · −${booking.promoDiscountPercent ?? 0}%',
          ),
      ],
    )}'
        '${RichHtml.paragraph(
      '<a href="$_sbpPaymentLink">${MessageCopy.buttonPaySbp}</a> — ссылка: <code>$_sbpPaymentLink</code>',
      alreadyEscaped: true,
    )}'
        '${RichHtml.paragraph(
      'На перевод 30 минут. Если не оплатить, запись отменится автоматически. '
      'После отмены нужно записаться заново.',
    )}';
  }

  Map<String, Object?> subscriptionOverviewKeyboard({
    required bool canApply,
    bool isRenewal = false,
    bool showIndividual = false,
  }) {
    return TelegramKeyboards.subscriptionOverviewKeyboard(
      canApply: canApply,
      isRenewal: isRenewal,
      showIndividual: showIndividual,
    );
  }

  Map<String, Object?> boxingCardPlanKeyboard() {
    return TelegramKeyboards.boxingCardPlanKeyboard();
  }

  Map<String, Object?> subscriptionPaymentKeyboard({bool showLoyaltySpend = false}) {
    return TelegramKeyboards.subscriptionPaymentKeyboard(showLoyaltySpend: showLoyaltySpend);
  }

  Map<String, Object?> adminSubscriptionFilterKeyboard() {
    return TelegramKeyboards.adminSubscriptionFilterKeyboard();
  }

  Map<String, Object?> subscriptionModerationReasonKeyboard() {
    return TelegramKeyboards.subscriptionModerationReasonKeyboard();
  }

  Map<String, Object?> subscriptionModerationCommentKeyboard() {
    return TelegramKeyboards.subscriptionModerationCommentKeyboard();
  }

  Map<String, Object?> bookingManagementSelectionKeyboard(List<TrainingBooking> bookings) {
    return TelegramKeyboards.bookingManagementSelectionKeyboard(bookings);
  }

  Map<String, Object?> myBookingSelectionKeyboard(
    List<TrainingBooking> bookings, {
    required bool hasPreviousPage,
    required bool hasNextPage,
  }) {
    return TelegramKeyboards.myBookingSelectionKeyboard(
      bookings,
      hasPreviousPage: hasPreviousPage,
      hasNextPage: hasNextPage,
    );
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
    bool canCompletePayment = false,
    bool canContinuePayment = false,
  }) {
    return TelegramKeyboards.bookingActionsKeyboard(
      canReschedule: canReschedule,
      canCancel: canCancel,
      canRepeat: canRepeat,
      canCompletePayment: canCompletePayment,
      canContinuePayment: canContinuePayment,
    );
  }

  Map<String, Object?> bookingCancelConfirmKeyboard() {
    return TelegramKeyboards.bookingCancelConfirmKeyboard();
  }

  Map<String, Object?> adminBookingManagementKeyboard() {
    return TelegramKeyboards.adminBookingManagementKeyboard();
  }

  Map<String, Object?> adminSubscriptionsMenuKeyboard() {
    return TelegramKeyboards.adminSubscriptionsMenuKeyboard();
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

  Map<String, Object?> myBookingSegmentKeyboard({
    required int currentCount,
    required int pastCount,
  }) {
    return TelegramKeyboards.myBookingSegmentKeyboard(
      currentCount: currentCount,
      pastCount: pastCount,
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

  Map<String, Object?> adminClientNotificationPreferenceKeyboard() {
    return TelegramKeyboards.adminClientNotificationPreferenceKeyboard();
  }

  Map<String, Object?> bookingPaymentStatusKeyboard() {
    return TelegramKeyboards.bookingPaymentStatusKeyboard();
  }

  Map<String, Object?> economicSummaryPeriodKeyboard() {
    return TelegramKeyboards.economicSummaryPeriodKeyboard();
  }

  Map<String, Object?> adminScheduleNavKeyboard() {
    return TelegramKeyboards.adminScheduleNavKeyboard();
  }

  Map<String, Object?> adminScheduleRootInlineKeyboard() {
    return TelegramKeyboards.adminScheduleRootInlineKeyboard();
  }

  Map<String, Object?> adminScheduleListInlineKeyboard({
    required String categoryCode,
    required List<String> itemLabels,
    required int page,
    required int pageSize,
    required int totalCount,
  }) {
    return TelegramKeyboards.adminScheduleListInlineKeyboard(
      categoryCode: categoryCode,
      itemLabels: itemLabels,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  Map<String, Object?> adminScheduleEventInlineKeyboard({
    required String categoryCode,
    required int index,
    bool showTrainingToggles = false,
    bool includeTrainers = false,
    bool promoRestricted = false,
    bool confirmingDelete = false,
  }) {
    return TelegramKeyboards.adminScheduleEventInlineKeyboard(
      categoryCode: categoryCode,
      index: index,
      showTrainingToggles: showTrainingToggles,
      includeTrainers: includeTrainers,
      promoRestricted: promoRestricted,
      confirmingDelete: confirmingDelete,
    );
  }

  Map<String, Object?> adminScheduleFieldsInlineKeyboard(List<(String, String)> fields) {
    return TelegramKeyboards.adminScheduleFieldsInlineKeyboard(fields);
  }

  Map<String, Object?> adminScheduleSkipInlineKeyboard({
    bool showSkip = true,
    List<String> extraLabels = const <String>[],
    List<String> extraCallbacks = const <String>[],
  }) {
    return TelegramKeyboards.adminScheduleSkipInlineKeyboard(
      showSkip: showSkip,
      extraLabels: extraLabels,
      extraCallbacks: extraCallbacks,
    );
  }

  Map<String, Object?> adminScheduleBoolInlineKeyboard({required bool optional}) {
    return TelegramKeyboards.adminScheduleBoolInlineKeyboard(optional: optional);
  }

  Map<String, Object?> adminScheduleCoachInlineKeyboard(
    List<String> names, {
    required bool optional,
  }) {
    return TelegramKeyboards.adminScheduleCoachInlineKeyboard(names, optional: optional);
  }

  Map<String, Object?> adminSchedulePreviewInlineKeyboard() {
    return TelegramKeyboards.adminSchedulePreviewInlineKeyboard();
  }
}
