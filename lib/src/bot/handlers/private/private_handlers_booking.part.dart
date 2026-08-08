part of '../private_handlers.dart';

extension PrivateHandlersBookingOps on PrivateHandlers {
  bool _looksLikeTelegramUsername(String value) {
    // Require explicit @ so Latin guest names (Anna, John) are not treated as TG.
    if (!value.trim().startsWith('@')) {
      return false;
    }
    final normalized = value.trim().substring(1);
    // Telegram usernames are 5–32 chars.
    return RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(normalized);
  }

  String _partyParticipantKey(
    BookingParticipantDraft draft, {
    required int managerUserId,
  }) {
    return switch (draft.type) {
      BookingParticipantType.self => 'self:$managerUserId',
      BookingParticipantType.telegram =>
        'tg:${(_normalizeUsernameInput(draft.username ?? '') ?? '').toLowerCase()}',
      BookingParticipantType.guest => 'guest:${(draft.name ?? '').trim().toLowerCase()}',
    };
  }

  BookingParticipantDraft? _findDuplicatePartyParticipant(
    List<BookingParticipantDraft> participants, {
    required int managerUserId,
  }) {
    final seen = <String>{};
    for (final draft in participants) {
      if (!seen.add(_partyParticipantKey(draft, managerUserId: managerUserId))) {
        return draft;
      }
    }
    return null;
  }

  Future<void> _createPartyBookingGroup({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required _PrivateFlowState flowState,
    required TrainingInfo training,
    required List<BookingParticipantDraft> participants,
    required String? username,
  }) async {
    late final BookingGroupCreateResult group;
    try {
      group = await _bookingRepository.createPendingBookingGroup(
        managerUserId: userId,
        managerUsername: username,
        training: training,
        participants: participants,
      );
    } on BookingParticipantsLimitExceededException {
      await _sender.sendMessage(
        chatId,
        _templates.bookingParticipantsLimitExceeded(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
        parseMode: 'HTML',
      );
      return;
    } on BookingManagerLimitExceededException {
      await _sender.sendMessage(
        chatId,
        _templates.partyManagerLimitExceeded(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
        parseMode: 'HTML',
      );
      return;
    } on BookingParticipantConflictException catch (error) {
      final label = error.message.replaceFirst('Participant already booked: ', '');
      await _sender.sendMessage(
        chatId,
        _templates.partyParticipantConflict(label),
        replyMarkup: _templates.simpleNavigationKeyboard(),
        parseMode: 'HTML',
      );
      return;
    } on ArgumentError {
      await _sender.sendMessage(
        chatId,
        _templates.invalidPartyParticipantsInput(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
        parseMode: 'HTML',
      );
      return;
    }

    final unitPrice = training.price ?? 0;
    final totalPrice = group.totalPrice;
    final first = group.bookings.first;

    if (_isFreeActivity(training) || totalPrice <= 0) {
      final paidBookings = <TrainingBooking>[];
      for (final booking in group.bookings) {
        final paid = await _bookingRepository.updateStatus(booking.id, BookingStatus.paid);
        paidBookings.add(paid ?? booking);
      }
      await _maybeNotifyGroupAboutCapacity(
        training,
        bookingStatus: BookingStatus.paid,
      );
      await _notifyAdminAboutBookingGroupCreated(
        bookings: paidBookings,
        unitPrice: unitPrice,
        totalPrice: 0,
      );
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        _templates.bookingGroupCreated(
          bookings: paidBookings,
          unitPrice: unitPrice,
          totalPrice: 0,
        ),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
        parseMode: 'HTML',
      );
      return;
    }

    await _notifyAdminAboutBookingGroupCreated(
      bookings: group.bookings,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );

    _flowByUserId[userId] = flowState.copyWith(
      step: _PrivateFlowStep.paymentConfirmation,
      activeBooking: first,
      activePaymentGroupId: group.paymentGroupId,
      availableTrainings: flowState.availableTrainings,
      starterBonusOffered: false,
      paymentChoice: null,
      partyParticipants: const <BookingParticipantDraft>[],
      partyTraining: null,
    );

    final outdoorPaymentChoice = _shouldShowOutdoorPaymentTypeChoice(first);
    final nextSteps = outdoorPaymentChoice
        ? '<b>Что дальше:</b>\n'
            '1) Оплати по реквизитам выше (сумма за всю группу).\n'
            '2) Выбери тип оплаты: «${MessageTemplates.buttonPayFully}» или '
            '«${MessageTemplates.buttonPayPartially}».\n'
            '3) Пришли файл чека в этот чат 📎'
        : '<b>Что дальше:</b>\n'
            '1) Оплати полную сумму за группу.\n'
            '2) Нажми «${MessageTemplates.buttonSubmitPayment}» и отправь файл чека в этот чат 📎';
    await _sendPayableBookingCard(
      chatId: chatId,
      booking: first,
      text: '${_templates.bookingGroupCreated(
        bookings: group.bookings,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
      )}\n\n'
          '${_templates.paymentInstructionsForGroup(
        booking: first,
        participantsCount: group.bookings.length,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
      )}\n\n'
          '$nextSteps',
      showStarterBonus: false,
      parseMode: 'HTML',
    );
  }

  Future<void> _createOrContinueBooking({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required _PrivateFlowState flowState,
    required TrainingInfo selectedTraining,
    required String? username,
    required Map<String, Object?> onParticipantsLimitReplyMarkup,
  }) async {
    late final BookingCreateResult result;
    try {
      result = await _bookingRepository.createPendingBooking(
        userId: userId,
        userUsername: username,
        training: selectedTraining,
      );
    } on BookingParticipantsLimitExceededException {
      await _sender.sendMessage(
        chatId,
        _templates.bookingParticipantsLimitExceeded(),
        replyMarkup: onParticipantsLimitReplyMarkup,
      );
      return;
    }
    if (_isFreeActivity(selectedTraining)) {
      final paidBooking =
          await _bookingRepository.updateStatus(result.booking.id, BookingStatus.paid);
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
        await _notifyAdminAboutFreeBookingCreated(bookingForResponse);
        await _maybeMarkOnboardingActivation(userId);
        await _sendOutdoorPrepDetails(chatId, bookingForResponse);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedWithoutPayment(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
        parseMode: 'HTML',
      );
      return;
    }
    if (_isWhitelistedTrainerBooking(userId: userId, username: username)) {
      final paidBooking =
          await _bookingRepository.updateStatus(result.booking.id, BookingStatus.paid);
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      _flowByUserId.remove(userId);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
        await _sendOutdoorPrepDetails(chatId, bookingForResponse);
      }
      await _notifyAdminAboutTrainerBookingCreated(bookingForResponse);
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedForWhitelistedTrainer(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
        parseMode: 'HTML',
      );
      return;
    }
    if (await _isDvorTeamMember(username: username)) {
      final paidBooking = await _bookingRepository.updateStatus(
        result.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.dvorTeamFreePaymentNoteMarker,
      );
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      _flowByUserId.remove(userId);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
        await _sendOutdoorPrepDetails(chatId, bookingForResponse);
      }
      await _notifyAdminAboutDvorTeamBookingCreated(bookingForResponse);
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedForDvorTeamMember(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
        parseMode: 'HTML',
      );
      return;
    }
    final proIncludedAvailable = await _hasProIncludedTrainingAvailable(
      userId: userId,
      training: selectedTraining,
      booking: result.booking,
    );
    if (proIncludedAvailable) {
      final paidBooking = await _bookingRepository.updateStatus(
        result.booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.proIncludedTrainingPaymentNoteMarker,
      );
      final bookingForResponse =
          _bookingWithStatus(result.booking, BookingStatus.paid, paidBooking);
      _flowByUserId.remove(userId);
      if (result.created) {
        await _maybeNotifyGroupAboutCapacity(
          selectedTraining,
          bookingStatus: bookingForResponse.status,
        );
        await _sendOutdoorPrepDetails(chatId, bookingForResponse);
      }
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreatedWithoutPayment(bookingForResponse)
            : _templates.bookingAlreadyExists(bookingForResponse),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
        parseMode: 'HTML',
      );
      return;
    }
    final starterBonusOffered = selectedTraining.category == _ActivityCategory.trainings &&
        !selectedTraining.promoRestricted &&
        await _hasAnyFreeTrainingBonusAvailable(userId);
    _flowByUserId[userId] = flowState.copyWith(
      step: _PrivateFlowStep.paymentConfirmation,
      activeBooking: result.booking,
      starterBonusOffered: starterBonusOffered,
      paymentChoice: null,
    );
    if (result.created && MessageFormatters.isOutdoorBooking(result.booking)) {
      await _sender.sendMessage(
        chatId,
        _templates.outdoorBookingRule(result.booking),
        parseMode: 'HTML',
      );
    }
    await _sendPayableBookingCard(
      chatId: chatId,
      booking: result.booking,
      text: result.created
          ? _templates.bookingCreated(result.booking)
          : _templates.bookingAlreadyExists(result.booking),
      showStarterBonus: starterBonusOffered,
      parseMode: 'HTML',
    );
  }

  Future<void> _sendOutdoorPrepDetails(int chatId, TrainingBooking booking) async {
    if (!MessageFormatters.isOutdoorBooking(booking)) {
      return;
    }
    final outdoorItem = _catalogService.outdoorByBooking(booking);
    if (outdoorItem == null) {
      return;
    }
    await _sender.sendMessage(
      chatId,
      _templates.outdoorItineraryDetails(outdoorItem),
      parseMode: 'HTML',
    );
    await _sender.sendMessage(
      chatId,
      _templates.outdoorEquipmentDetails(outdoorItem),
      parseMode: 'HTML',
    );
  }

  Future<void> _sendOutdoorEventSelection({
    required int chatId,
    required List<OutdoorActivityInfo> outdoorItems,
  }) async {
    final bookable = outdoorItems.map(_catalogService.toBookableInfo).toList(growable: false);
    await _sender.sendMessage(
      chatId,
      _templates.chooseTrainingForBooking(bookable),
      replyMarkup: _templates.bookingSelectionKeyboard(bookable),
    );
  }

  Future<void> _openFrankByBastaPromo({
    required int chatId,
    required int? userId,
    required bool isAdmin,
    required bool canViewParticipantsList,
    required bool showReturnToAdminMenu,
  }) async {
    final refreshOk = await _scheduleRepository.refresh();
    if (!refreshOk) {
      l.w('Schedule refresh failed before FRANK BY BASTA promo. Using cached schedule.');
    }
    final frankTraining = FrankByBasta.findIn(
      _scheduleRepository.upcoming(now: _nowProvider(), limit: 200),
    );
    if (userId != null && frankTraining != null) {
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.viewingFrankPromo,
        availableTrainings: <TrainingInfo>[frankTraining],
      );
      await _sender.sendMessage(
        chatId,
        _templates.dvorXFrankPromo(),
        replyMarkup: _templates.dvorXFrankPromoKeyboard(),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      return;
    }
    if (userId != null) {
      _flowByUserId.remove(userId);
    }
    await _sender.sendMessage(
      chatId,
      _templates.dvorXFrankPromo(),
      replyMarkup: _templates.privateMenuKeyboard(
        isAdmin: isAdmin,
        canViewParticipantsList: canViewParticipantsList,
        showReturnToAdminMenu: showReturnToAdminMenu,
      ),
      parseMode: 'HTML',
      disableWebPagePreview: true,
    );
    await _sender.sendMessage(
      chatId,
      _templates.dvorXFrankPromoUnavailable(),
      replyMarkup: _templates.privateMenuKeyboard(
        isAdmin: isAdmin,
        canViewParticipantsList: canViewParticipantsList,
        showReturnToAdminMenu: showReturnToAdminMenu,
      ),
    );
  }

  Future<void> _openBookingByCategory({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required _ActivityCategory category,
    required bool fromSchedulePreview,
    String? messageText,
    String? parseMode,
    bool disableWebPagePreview = false,
  }) async {
    if (_isOutdoorCategory(category)) {
      final outdoorItems = _catalogService.outdoorItems(category);
      if (outdoorItems.isEmpty) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.noUpcomingForBooking(),
          replyMarkup:
              _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
        );
        return;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingOutdoorDetailEvent,
        availableTrainings: const <TrainingInfo>[],
        selectedCategory: category,
        bookingFromSchedulePreview: fromSchedulePreview,
      );
      await _sendOutdoorEventSelection(chatId: chatId, outdoorItems: outdoorItems);
      return;
    }
    final upcoming = _bookableItemsByCategory(category);
    if (upcoming.isEmpty) {
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        _templates.noUpcomingForBooking(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
      );
      return;
    }
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingTraining,
      availableTrainings: upcoming,
      selectedCategory: category,
      bookingFromSchedulePreview: fromSchedulePreview,
    );
    await _sender.sendMessage(
      chatId,
      messageText ?? _templates.chooseTrainingForBooking(upcoming),
      replyMarkup: _templates.bookingSelectionKeyboard(upcoming),
      parseMode: parseMode,
      disableWebPagePreview: disableWebPagePreview,
    );
  }

  List<TrainingInfo> _participantItemsByCategory(_ActivityCategory category) {
    return _catalogService.participantItems(category);
  }

  _ActivityCategory? _parseCategory(String text) {
    return _catalogService.parseCategory(text);
  }

  Future<void> _openMyBookingListSegment({
    required int chatId,
    required int userId,
  }) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 100);
    if (bookings.isEmpty) {
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        'У тебя пока нет записей на мероприятия 🙃',
        replyMarkup: _templates.profileActionsKeyboard(),
      );
      return;
    }
    final now = _nowProvider();
    final currentCount =
        bookings.where((booking) => !_isArchivedBookingAt(booking, now: now)).length;
    final pastCount = bookings.length - currentCount;
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingBookingListSegment,
      availableTrainings: const <TrainingInfo>[],
      availableBookings: bookings,
    );
    await _sender.sendMessage(
      chatId,
      _templates.chooseMyBookingsSegment(),
      replyMarkup: _templates.myBookingSegmentKeyboard(
        currentCount: currentCount,
        pastCount: pastCount,
      ),
      parseMode: 'HTML',
    );
  }

  Future<void> _sendMyBookingListPage({
    required int chatId,
    required int userId,
  }) async {
    final flowState = _flowByUserId[userId];
    if (flowState == null || flowState.step != _PrivateFlowStep.selectingBookingToManage) {
      return;
    }
    final now = _nowProvider();
    final allBookings = _filterBookingsByArchivedSegment(
      flowState.availableBookings,
      archived: flowState.adminViewingArchived,
      now: now,
    );
    final maxPage = _maxMyBookingsPage(allBookings);
    final page = flowState.adminBookingsPage.clamp(0, maxPage);
    final start = page * PrivateHandlers._myBookingsPageSize;
    final end = (start + PrivateHandlers._myBookingsPageSize).clamp(0, allBookings.length);
    final pageBookings = allBookings.sublist(start, end);
    _flowByUserId[userId] = flowState.copyWith(
      adminBookingsPage: page,
      availableBookings: allBookings,
    );
    await _sender.sendMessage(
      chatId,
      _templates.chooseMyBookingFromList(
        pageBookings,
        past: flowState.adminViewingArchived,
        page: page + 1,
        totalPages: maxPage + 1,
        totalCount: allBookings.length,
      ),
      replyMarkup: allBookings.isEmpty
          ? _templates.myBookingSegmentKeyboard(currentCount: 0, pastCount: 0)
          : _templates.myBookingSelectionKeyboard(
              pageBookings,
              hasPreviousPage: page > 0,
              hasNextPage: page < maxPage,
            ),
      parseMode: 'HTML',
    );
  }

  int _maxMyBookingsPage(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 0;
    }
    return (bookings.length - 1) ~/ PrivateHandlers._myBookingsPageSize;
  }

  List<TrainingBooking> _filterBookingsByArchivedSegment(
    List<TrainingBooking> bookings, {
    required bool archived,
    required DateTime now,
  }) {
    return bookings
        .where(
          (booking) => archived == _isArchivedBookingAt(booking, now: now),
        )
        .toList(growable: false);
  }

  bool _isArchivedBookingAt(TrainingBooking booking, {required DateTime now}) {
    return booking.startsAt.isBefore(now) || booking.status == BookingStatus.cancelled;
  }

  bool _isArchivedTrainingAt(TrainingInfo training, {required DateTime now}) {
    return training.startsAt.isBefore(now);
  }

  bool _isOutdoorCategory(_ActivityCategory category) {
    return _bookingPolicyService.isOutdoorCategory(category);
  }

  Map<String, Object?> _bookingActionsInlineKeyboard(TrainingBooking? booking) {
    if (booking == null) {
      return _templates.simpleNavigationKeyboard();
    }
    final canContinuePayment = _isPayableForProof(booking);
    return _templates.bookingActionsInlineKeyboard(
      bookingId: booking.id,
      canReschedule: _bookingPolicyService.canReschedule(booking),
      canCancel: _canCancelBookingByPolicy(booking),
      canRepeat: !canContinuePayment && booking.status != BookingStatus.partialPaid,
      canCompletePayment: false,
      canContinuePayment: canContinuePayment,
    );
  }

  Future<void> _sendBookingActionsCard({
    required int chatId,
    required TrainingBooking booking,
  }) async {
    await _sender.sendMessage(
      chatId,
      _templates.bookingActions(booking),
      replyMarkup: _bookingActionsInlineKeyboard(booking),
      parseMode: 'HTML',
    );
    await _sender.sendMessage(
      chatId,
      _templates.paymentCardNavHint(),
      replyMarkup: _templates.simpleNavigationKeyboard(),
    );
  }

  Future<void> _sendBookingCancelConfirmCard({
    required int chatId,
    required TrainingBooking booking,
  }) async {
    await _sender.sendMessage(
      chatId,
      _templates.bookingCancelConfirm(booking),
      replyMarkup: _templates.bookingCancelConfirmInlineKeyboard(booking.id),
      parseMode: 'HTML',
    );
    await _sender.sendMessage(
      chatId,
      _templates.paymentCardNavHint(),
      replyMarkup: _templates.simpleNavigationKeyboard(),
    );
  }

  Future<TrainingBooking?> _findUserBooking(int userId, int bookingId) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 100);
    for (final booking in bookings) {
      if (booking.id == bookingId) {
        return booking;
      }
    }
    return null;
  }

  Future<void> _maybeNotifyGroupAboutCapacity(
    TrainingInfo training, {
    required BookingStatus bookingStatus,
  }) async {
    if (!_isCapacityConfirmedBookingStatus(bookingStatus)) {
      return;
    }
    final targetChatId = _targetChatId;
    final participantsLimit = training.participantsLimit;
    if (targetChatId == null || participantsLimit == null || participantsLimit <= 0) {
      return;
    }

    final activeBookings = await _bookingRepository.listByTrainingKeys(
      <String>{training.sessionKey},
      limit: participantsLimit,
    );
    final confirmedBookings = activeBookings
        .where((booking) => _isCapacityConfirmedBookingStatus(booking.status))
        .toList();
    final participantsCount = _countParticipantsForTraining(
      bookings: confirmedBookings,
      training: training,
    );
    final freeSpots = participantsLimit - participantsCount;
    if (freeSpots <= 0) {
      if (_fullCapacityNotifiedTrainingKeys.contains(training.sessionKey)) {
        return;
      }
      try {
        final sent = await _groupAnnouncements.publish(
          chatId: targetChatId,
          type: GroupAnnouncementType.noSpots,
          text: _templates.groupTrainingNoSpotsLeft(
            training: training,
            participantsLimit: participantsLimit,
          ),
          parseMode: 'HTML',
        );
        if (sent) {
          _fullCapacityNotifiedTrainingKeys.add(training.sessionKey);
          _lowCapacityNotifiedTrainingKeys.add(training.sessionKey);
        }
      } on Object catch (error, stackTrace) {
        l.w('Failed to notify group about full training capacity: $error', stackTrace);
      }
      return;
    }

    final freeShare = freeSpots / participantsLimit;
    if (freeShare >= 0.3 || _lowCapacityNotifiedTrainingKeys.contains(training.sessionKey)) {
      return;
    }

    try {
      final sent = await _groupAnnouncements.publish(
        chatId: targetChatId,
        type: GroupAnnouncementType.lowSpots,
        text: _templates.groupTrainingLowSpots(
          training: training,
          freeSpots: freeSpots,
          participantsLimit: participantsLimit,
        ),
        parseMode: 'HTML',
      );
      if (sent) {
        _lowCapacityNotifiedTrainingKeys.add(training.sessionKey);
      }
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify group about low training capacity: $error', stackTrace);
    }
  }

  int _countParticipantsForTraining({
    required List<TrainingBooking> bookings,
    required TrainingInfo training,
  }) {
    if (training.includeTrainersInParticipants) {
      return bookings.length;
    }
    return bookings.where((booking) => !_isWhitelistedTrainerBookingByBooking(booking)).length;
  }

  bool _isWhitelistedTrainerBooking({
    required int userId,
    required String? username,
  }) {
    return isTrainerBookingWhitelisted(userId: userId, username: username);
  }

  Future<bool> _isDvorTeamMember({required String? username}) async {
    final refreshOk = await _dvorTeamRepository.refresh();
    if (!refreshOk) {
      l.w('Dvor team refresh failed before free-booking check. Using cached usernames.');
    }
    return _dvorTeamRepository.containsUsername(username);
  }

  bool _isWhitelistedTrainerBookingByBooking(TrainingBooking booking) {
    // Guest FIO seats are never trainers. For telegram/self, use participant
    // identity — manager fields would mis-classify a whole party.
    if (booking.participantType == BookingParticipantType.guest) {
      return false;
    }
    final participantUserId = booking.participantUserId ?? booking.userId;
    final participantUsername = booking.participantUsername ?? booking.userUsername;
    return _isWhitelistedTrainerBooking(
      userId: participantUserId,
      username: participantUsername,
    );
  }

  bool _isCapacityConfirmedBookingStatus(BookingStatus status) {
    return status == BookingStatus.paid ||
        status == BookingStatus.partialPaid ||
        status == BookingStatus.freeTraining;
  }

  bool _shouldNotifyAdminAboutBookingCancellation(TrainingBooking booking) {
    return _isCapacityConfirmedBookingStatus(booking.status);
  }

  TrainingInfo _trainingInfoFromBooking(TrainingBooking booking) {
    return TrainingInfo(
      title: booking.trainingTitle,
      startsAt: booking.startsAt,
      location: booking.location,
      category: _catalogService.categoryForBooking(booking),
    );
  }

  bool _canCancelBookingByPolicy(TrainingBooking booking) {
    return _bookingPolicyService.canCancel(booking, now: _nowProvider());
  }

  String _cancellationTooLateText(
    TrainingBooking booking, {
    required _ActivityCategory category,
  }) {
    if (category == _ActivityCategory.trainings) {
      return _templates.freeTrainingCancellationTooLate(booking);
    }
    return _templates.outdoorCancellationTooLate(booking);
  }

  _EconomicSummaryRange? _parseEconomicSummaryRangeCommand(String text) {
    if (!text.startsWith('/economic_summary')) {
      return null;
    }
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    return switch (parts[1].toLowerCase()) {
      'current_week' || 'current-week' || 'cw' => _EconomicSummaryRange.currentWeek,
      'previous_week' ||
      'prev_week' ||
      'previous-week' ||
      'prev-week' ||
      'pw' =>
        _EconomicSummaryRange.previousWeek,
      'current_month' || 'current-month' || 'cm' => _EconomicSummaryRange.currentMonth,
      'previous_month' ||
      'prev_month' ||
      'previous-month' ||
      'prev-month' ||
      'pm' =>
        _EconomicSummaryRange.previousMonth,
      _ => null,
    };
  }

  _EconomicSummaryRange? _parseEconomicSummaryRangeText(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('текущ') && normalized.contains('недел')) {
      return _EconomicSummaryRange.currentWeek;
    }
    if (normalized.contains('прошл') && normalized.contains('недел')) {
      return _EconomicSummaryRange.previousWeek;
    }
    if (normalized.contains('текущ') && normalized.contains('месяц')) {
      return _EconomicSummaryRange.currentMonth;
    }
    if (normalized.contains('прошл') && normalized.contains('месяц')) {
      return _EconomicSummaryRange.previousMonth;
    }
    return null;
  }

  BroadcastContent? _broadcastContentFromFlow(_PrivateFlowState flowState) {
    final sourceMessages = flowState.adminBroadcastSourceMessages;
    if (sourceMessages.isNotEmpty) {
      final sorted = List<BroadcastMessageRef>.from(sourceMessages)
        ..sort((left, right) => left.messageId.compareTo(right.messageId));
      return BroadcastContent.media(sorted);
    }
    final text = flowState.adminBroadcastText?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return BroadcastContent.text(text);
  }
}
