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

  Map<String, Object?> onboardingNudgeKeyboard() {
    return TelegramKeyboards.onboardingNudgeKeyboard();
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
    bool showCancelBooking = false,
    bool showOutdoorPaymentTypeChoice = false,
    bool showPromoCodeEntry = false,
  }) {
    return TelegramKeyboards.paymentConfirmationKeyboard(
      showStarterBonus: showStarterBonus,
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
    return '👥 <b>Записать друга</b>\n'
        'Выбери категорию мероприятия 👇';
  }

  String chooseBookFriendEvent(List<TrainingInfo> items) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lines = <String>[
      '👥 <b>Записать друга</b>',
      'Выбери мероприятие 👇',
    ];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final price = item.price == null ? '' : ' · ${_trainingPriceLabel(item.price)}';
      lines.add(
        '${index + 1}. <b>${_escapeHtml(item.title)}</b> — ${formatter.format(item.startsAt)}'
        ' (${_escapeHtml(item.location)}$price)',
      );
    }
    return lines.join('\n');
  }

  String askPartyParticipants({required TrainingInfo training}) {
    final unitPrice = training.price ?? 0;
    return '👥 <b>Кого записать?</b>\n'
        'Событие: <b>${_escapeHtml(training.title)}</b>\n'
        'Цена за человека: <b>${_trainingPriceLabel(unitPrice)}</b>\n\n'
        'Напиши Telegram-username с <b>@</b> или ФИО через запятую (или с новой строки).\n'
        'Примеры:\n'
        '• <code>@anna, @ivan</code>\n'
        '• <code>Бабушка Мария, Дедушка Пётр</code>\n'
        '• <code>@anna, Бабушка Мария</code>\n\n'
        'Без @ имя считается гостем (ФИО), а не Telegram-аккаунтом.\n'
        'Можно записать до 5 человек.\n'
        'Свою запись это не создаёт — себя запиши отдельно через «Записаться».';
  }

  String invalidPartyParticipantsInput() {
    return 'Не понял список участников 🤔\n'
        'Telegram-username указывай с <b>@</b>, иначе это будет ФИО гостя.\n'
        'Нельзя указать свой собственный @username.\n'
        'Пример: <code>@anna, Бабушка Мария</code>\n'
        'До 5 человек за раз.';
  }

  String partyParticipantConflict(String label) {
    return '⚠️ ${_escapeHtml(label)} уже записан(а) на это мероприятие.';
  }

  String partyManagerLimitExceeded() {
    return '⚠️ На одно мероприятие можно записать не больше 5 друзей/гостей '
        '(своя запись через «Записаться» не входит в этот лимит).';
  }

  String partyDuplicateParticipant(String label) {
    return '⚠️ ${_escapeHtml(label)} указан(а) в списке больше одного раза.';
  }

  String bookingGroupCreated({
    required List<TrainingBooking> bookings,
    required int unitPrice,
    required int totalPrice,
  }) {
    final first = bookings.first;
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final buffer = StringBuffer()
      ..writeln('✅ <b>Записи созданы (${bookings.length} чел.)</b>')
      ..writeln('Событие: ${_escapeHtml(first.trainingTitle)}')
      ..writeln('Дата: ${formatter.format(first.startsAt)}')
      ..writeln('Локация: ${_escapeHtml(first.location)}')
      ..writeln('')
      ..writeln('<b>Участники:</b>');
    for (final booking in bookings) {
      buffer.writeln('• ${_escapeHtml(booking.participantDisplayLabel)}');
    }
    buffer
      ..writeln('')
      ..writeln(
        'К оплате: <b>${bookings.length} × ${_trainingPriceLabel(unitPrice)} = '
        '${_trainingPriceLabel(totalPrice)}</b>',
      );
    return buffer.toString().trimRight();
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
      return '💳 <b>Реквизиты OUTDVOR</b>\n'
          '• Получатель: <b>Денис Р.</b>\n'
          '• Банк: <b>🟦 OZON БАНК 🟦</b>\n'
          '• Полная сумма за группу: <b>$participantsCount × ${_trainingPriceLabel(unitPrice)} = '
          '${_trainingPriceLabel(totalPrice)}</b>\n'
          '• К оплате сейчас при предоплате: <b>${_trainingPriceLabel(groupPrepayment)}</b> '
          '($prepayPercent% от суммы группы)\n'
          '• Остальные $remainderPercent% — $outdoorFinalPaymentAfter.\n'
          '• <a href="$_sbpPaymentLink">Оплатить через СБП</a> — перейди по ссылке и введи сумму.\n\n'
          '⏳ Если не оплатить в течение <b>30 минут</b> — запись отменится автоматически. '
          'После отмены нужно записаться заново.';
    }
    final base = paymentInstructions(booking);
    final totalLine =
        '• К оплате за группу: <b>$participantsCount × ${_trainingPriceLabel(unitPrice)} = '
        '${_trainingPriceLabel(totalPrice)}</b>\n';
    if (base.contains('• К оплате:')) {
      return base.replaceFirst(RegExp(r'• К оплате:.*\n'), totalLine);
    }
    return '$totalLine$base';
  }

  Map<String, Object?> subscriptionOverviewKeyboard({
    required bool canApply,
    bool isRenewal = false,
  }) {
    return TelegramKeyboards.subscriptionOverviewKeyboard(
      canApply: canApply,
      isRenewal: isRenewal,
    );
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
