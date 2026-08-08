part of '../private_handlers.dart';

extension PrivateHandlersDispatchUserBooking on PrivateHandlers {
  Future<bool> _dispatchUserBookingCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final canRunParticipantsAction = ctx.canRunParticipantsAction;
    final flowState = ctx.flowState;
    final username = ctx.username;

    if (text != null && (text == MessageTemplates.buttonBookTraining || text.startsWith('/book'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: username,
      );
      if (flowState?.step == _PrivateFlowStep.viewingFrankPromo &&
          flowState!.availableTrainings.isNotEmpty) {
        final selectedTraining = flowState.availableTrainings.first;
        await _createOrContinueBooking(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          flowState: flowState,
          selectedTraining: selectedTraining,
          username: username,
          onParticipantsLimitReplyMarkup: _templates.dvorXFrankPromoKeyboard(),
        );
        return true;
      }
      if (flowState?.step == _PrivateFlowStep.selectingOutdoorDetailType &&
          flowState?.selectedOutdoorActivity != null) {
        final selectedTraining =
            _catalogService.toBookableInfo(flowState!.selectedOutdoorActivity!);
        await _createOrContinueBooking(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          flowState: flowState,
          selectedTraining: selectedTraining,
          username: username,
          onParticipantsLimitReplyMarkup: _templates.outdoorDetailTypeKeyboard(),
        );
        return true;
      }
      final scheduleCategoryContext = flowState?.step == _PrivateFlowStep.viewingScheduleCategory
          ? flowState?.selectedCategory
          : null;
      if (scheduleCategoryContext != null) {
        await _openBookingByCategory(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          category: scheduleCategoryContext,
          fromSchedulePreview: true,
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookingCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseBookingCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonBookFriend || text.startsWith('/book_friend'))) {
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookFriendCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseBookFriendCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    // TODO(subscription): вернуть обработчик кнопки абонемента в профиле.
    // if (text == MessageTemplates.buttonSubscription) {
    //   if (userId == null) {
    //     return false;
    //   }
    //   final now = _nowProvider();
    //   final membership = await _subscriptionRepository.getMembership(
    //     userId,
    //     now: now,
    //   );
    //   final remainingProTrainings = await _proIncludedTrainingRemainingCount(
    //     userId: userId,
    //     membership: membership,
    //   );
    //   final snapshot = await _subscriptionRepository.getUserSnapshot(userId, now: now);
    //   final canApply = snapshot.latestPending == null;
    //   final isRenewal = membership.level == MembershipLevel.pro;
    //   _flowByUserId[userId] = const _PrivateFlowState(
    //     step: _PrivateFlowStep.viewingSubscriptionOverview,
    //     availableTrainings: <TrainingInfo>[],
    //   );
    //   await _sender.sendMessage(
    //     chatId,
    //     _templates.subscriptionOverview(
    //       membershipLevel: membership.level,
    //       activeUntil: membership.activeUntil,
    //       remainingProTrainings: remainingProTrainings,
    //     ),
    //     replyMarkup: _templates.subscriptionOverviewKeyboard(
    //       canApply: canApply,
    //       isRenewal: isRenewal,
    //     ),
    //     parseMode: 'HTML',
    //   );
    //   return true;
    // }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.viewingCoachingStaff &&
        text == MessageTemplates.buttonCoachDetails) {
      final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
      if (trainers.isEmpty) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.coachingStaff(trainers),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          parseMode: 'HTML',
          disableWebPagePreview: true,
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(step: _PrivateFlowStep.selectingTrainerProfile);
      await _sender.sendMessage(
        chatId,
        _templates.chooseTrainerProfile(trainers),
        replyMarkup: _templates.trainerSelectionKeyboard(trainers),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.viewingCoachingStaff &&
        text != null &&
        !text.startsWith('/')) {
      final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
      await _sender.sendMessage(
        chatId,
        _templates.coachingStaff(trainers),
        replyMarkup: _templates.coachingStaffActionsKeyboard(),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingTrainerProfile &&
        text != null &&
        !text.startsWith('/')) {
      final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
      final index = _parseTrainerSelectionIndex(text);
      if (index == null || index < 1 || index > trainers.length) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownTrainerSelection(),
          replyMarkup: _templates.trainerSelectionKeyboard(trainers),
        );
        return true;
      }
      final trainer = trainers[index - 1];
      await _sender.sendMessage(
        chatId,
        _templates.trainerProfile(trainer),
        replyMarkup: _templates.trainerSelectionKeyboard(trainers),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.viewingScheduleCategory &&
        (text == MessageTemplates.buttonOutdoorEquipment ||
            text == MessageTemplates.buttonOutdoorItinerary)) {
      final category = flowState?.selectedCategory;
      if (category == null || !_isOutdoorCategory(category)) {
        return true;
      }
      final outdoorItems = _catalogService.outdoorItems(category);
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingOutdoorDetailEvent,
        selectedOutdoorActivity: null,
        outdoorDetailType: null,
      );
      await _sendOutdoorEventSelection(chatId: chatId, outdoorItems: outdoorItems);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingOutdoorDetailEvent &&
        text != null &&
        !text.startsWith('/')) {
      final category = flowState?.selectedCategory;
      if (category == null || !_isOutdoorCategory(category)) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final outdoorItems = _catalogService.outdoorItems(category);
      final bookable = outdoorItems.map(_catalogService.toBookableInfo).toList(growable: false);
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > outdoorItems.length) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownOutdoorSelection(),
          replyMarkup: _templates.bookingSelectionKeyboard(bookable),
        );
        return true;
      }
      final selectedOutdoor = outdoorItems[index - 1];
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingOutdoorDetailType,
        selectedOutdoorActivity: selectedOutdoor,
      );
      await _notifyAdminAboutOutdoorInterest(
        userId: userId,
        username: username,
        activity: selectedOutdoor,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseOutdoorDetailType(selectedOutdoor),
        replyMarkup: _templates.outdoorDetailTypeKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingOutdoorDetailType &&
        text != null &&
        !text.startsWith('/')) {
      final selectedOutdoor = flowState?.selectedOutdoorActivity;
      if (selectedOutdoor == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownOutdoorSelection(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonOutdoorEquipment) {
        await _sender.sendMessage(
          chatId,
          _templates.outdoorEquipmentDetails(selectedOutdoor),
          replyMarkup: _templates.outdoorDetailTypeKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      if (text == MessageTemplates.buttonOutdoorItinerary) {
        await _sender.sendMessage(
          chatId,
          _templates.outdoorItineraryDetails(selectedOutdoor),
          replyMarkup: _templates.outdoorDetailTypeKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.chooseOutdoorDetailType(selectedOutdoor),
        replyMarkup: _templates.outdoorDetailTypeKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingScheduleCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      if (_isOutdoorCategory(category)) {
        final outdoorItems = _catalogService.outdoorItems(category);
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingOutdoorDetailEvent,
          availableTrainings: const <TrainingInfo>[],
          selectedCategory: category,
          bookingFromSchedulePreview: true,
        );
        await _refreshTrainerDirectoryForSchedule();
        await _sender.sendMessage(
          chatId,
          _scheduleTextByCategory(category),
          parseMode: 'HTML',
          disableWebPagePreview: true,
        );
        await _sendOutdoorEventSelection(chatId: chatId, outdoorItems: outdoorItems);
      } else {
        await _refreshTrainerDirectoryForSchedule();
        await _openBookingByCategory(
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          category: category,
          fromSchedulePreview: true,
          messageText: '${_scheduleTextByCategory(category)}\n\n\n'
              '<b>Что дальше:</b>\n'
              '${_templates.bookingSelectionPrompt()}',
          parseMode: 'HTML',
          disableWebPagePreview: true,
        );
      }
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      await _openBookingByCategory(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        category: category,
        fromSchedulePreview: false,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingParticipantsCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      _flowByUserId.remove(userId);
      await _sendParticipantsByCategory(
        chatId: chatId,
        category: category,
        isAdmin: isAdmin,
        canViewParticipantsList: canRunParticipantsAction,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingPaymentsQueueCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        final counters = await _paymentReviewService.queueCounters();
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.paymentsQueueCategorySelectionKeyboard(
            trainings: counters.trainings,
            hikes: counters.hikes,
            trails: counters.trails,
          ),
        );
        return true;
      }
      _flowByUserId.remove(userId);
      await _sendPaymentsQueueByCategory(
        chatId: chatId,
        category: category,
        isAdmin: isAdmin,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingTraining &&
        text != null &&
        !text.startsWith('/')) {
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > flowState!.availableTrainings.length) {
        await _sender.sendMessage(
          chatId,
          _bookingHandler.unknownSelectionText(),
          replyMarkup: _templates.bookingSelectionKeyboard(flowState!.availableTrainings),
        );
        return true;
      }
      final selectedTraining = flowState.availableTrainings[index - 1];

      await _createOrContinueBooking(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        flowState: flowState,
        selectedTraining: selectedTraining,
        username: username,
        onParticipantsLimitReplyMarkup:
            _templates.bookingSelectionKeyboard(flowState.availableTrainings),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookFriendCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sender.sendMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final items = _bookableItemsByCategory(category);
      if (items.isEmpty) {
        await _sender.sendMessage(
          chatId,
          _templates.noUpcomingForBooking(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookFriendEvent,
        availableTrainings: items,
        selectedCategory: category,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseBookFriendEvent(items),
        replyMarkup: _templates.bookingSelectionKeyboard(items),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookFriendEvent &&
        text != null &&
        !text.startsWith('/')) {
      final index = _parseTrainingSelectionIndex(text);
      final items = flowState?.availableTrainings ?? const <TrainingInfo>[];
      if (index == null || index < 1 || index > items.length) {
        await _sender.sendMessage(
          chatId,
          _bookingHandler.unknownSelectionText(),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
      final selectedTraining = items[index - 1];
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.enteringPartyParticipants,
        partyTraining: selectedTraining,
        partyParticipants: const <BookingParticipantDraft>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.askPartyParticipants(training: selectedTraining),
        replyMarkup: _templates.simpleNavigationKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringPartyParticipants &&
        text != null &&
        !text.startsWith('/')) {
      final training = flowState?.partyTraining;
      if (training == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          'Вернул в главное меню 👇',
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final participants = _parsePartyParticipantsInput(text, managerUsername: username);
      if (participants == null) {
        await _sender.sendMessage(
          chatId,
          _templates.invalidPartyParticipantsInput(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      if (participants.length > maxManagedGuestsPerEvent) {
        await _sender.sendMessage(
          chatId,
          _templates.partyManagerLimitExceeded(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      final duplicate = _findDuplicatePartyParticipant(participants, managerUserId: userId);
      if (duplicate != null) {
        await _sender.sendMessage(
          chatId,
          _templates.partyDuplicateParticipant(duplicate.displayLabel),
          replyMarkup: _templates.simpleNavigationKeyboard(),
          parseMode: 'HTML',
        );
        return true;
      }
      await _createPartyBookingGroup(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        flowState: flowState!,
        training: training,
        participants: participants,
        username: username,
      );
      return true;
    }

    return false;
  }
}
