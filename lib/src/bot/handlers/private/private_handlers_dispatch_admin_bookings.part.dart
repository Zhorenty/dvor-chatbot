part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdminBookings on PrivateHandlers {
  Future<bool> _dispatchAdminBookingCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final flowState = ctx.flowState;

    if (userId != null && text != null) {
      if (text.startsWith('/admin_booking_edit ')) {
        final bookingId = _updateRouter.parseCommandId(text);
        if (bookingId != null) {
          final booking = await _resolveAdminBooking(
            bookingId,
            fromFlow: flowState?.selectedBooking,
          );
          if (booking == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(bookingId),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            return true;
          }
          _flowByUserId[userId] = _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingEditField,
            availableTrainings: const <TrainingInfo>[],
            selectedBooking: booking,
          );
          await _sendAdminMessage(
            chatId,
            _templates.chooseAdminBookingEditField(booking),
            replyMarkup: _templates.adminBookingEditFieldsKeyboard(),
          );
          return true;
        }
      }
      if (text.startsWith('/admin_booking_delete ')) {
        final bookingId = _updateRouter.parseCommandId(text);
        if (bookingId != null) {
          final booking = await _resolveAdminBooking(
            bookingId,
            fromFlow: flowState?.selectedBooking,
          );
          if (booking == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(bookingId),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            return true;
          }
          _flowByUserId[userId] = _PrivateFlowState(
            step: _PrivateFlowStep.confirmingAdminBookingDelete,
            availableTrainings: const <TrainingInfo>[],
            selectedBooking: booking,
          );
          await _sendAdminBookingDeleteConfirmCard(chatId: chatId, booking: booking);
          return true;
        }
      }
      if (text.startsWith('/admin_booking_delete_confirm ')) {
        final bookingId = _updateRouter.parseCommandId(text);
        if (bookingId != null) {
          final booking = await _resolveAdminBooking(
            bookingId,
            fromFlow: flowState?.selectedBooking,
          );
          if (booking == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(bookingId),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            return true;
          }
          final archived = await _bookingRepository.adminArchiveBooking(booking.id);
          if (archived == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(booking.id),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            _flowByUserId.remove(userId);
            return true;
          }
          await _openAdminClientNotificationStep(
            chatId: chatId,
            userId: userId,
            action: _AdminClientNotificationAction.bookingDeleted,
            booking: archived,
          );
          return true;
        }
      }
      if (text.startsWith('/admin_booking_delete_abort ')) {
        final bookingId = _updateRouter.parseCommandId(text);
        if (bookingId != null) {
          final booking = await _resolveAdminBooking(
            bookingId,
            fromFlow: flowState?.selectedBooking,
          );
          if (booking == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(bookingId),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            return true;
          }
          _flowByUserId[userId] = _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingAction,
            availableTrainings: const <TrainingInfo>[],
            selectedBooking: booking,
          );
          await _sendAdminBookingActionsCard(chatId: chatId, booking: booking);
          return true;
        }
      }
      if (text.startsWith('/admin_booking_restore ')) {
        final bookingId = _updateRouter.parseCommandId(text);
        if (bookingId != null) {
          final selectedBooking = await _resolveAdminBooking(
            bookingId,
            fromFlow: flowState?.selectedBooking,
          );
          if (selectedBooking == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(bookingId),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            return true;
          }
          if (!_canRestoreBooking(selectedBooking)) {
            await _sendAdminMessage(
              chatId,
              _templates.adminBookingRestoreNotAllowed(selectedBooking),
              replyMarkup: _adminBookingActionsInlineKeyboard(selectedBooking),
            );
            return true;
          }
          final TrainingBooking? restored;
          try {
            restored = await _bookingRepository.adminUpdateBooking(
              bookingId: selectedBooking.id,
              status: BookingStatus.pendingPayment,
            );
          } on BookingConflictException {
            await _sendAdminMessage(
              chatId,
              _templates.adminBookingUpdateConflict(),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            _flowByUserId.remove(userId);
            return true;
          }
          if (restored == null) {
            await _sendAdminMessage(
              chatId,
              _templates.bookingNotFound(selectedBooking.id),
              replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin,
                showReturnToAdminMenu: showReturnToAdminMenu,
              ),
            );
            _flowByUserId.remove(userId);
            return true;
          }
          await _openAdminClientNotificationStep(
            chatId: chatId,
            userId: userId,
            action: _AdminClientNotificationAction.bookingRestored,
            booking: restored,
          );
          return true;
        }
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingManagementAction &&
        text != null) {
      if (text == MessageTemplates.buttonBookingsList ||
          text == MessageTemplates.buttonBackToBookingsList) {
        await _openAdminBookingListSegment(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonCreateBooking ||
          text == MessageTemplates.buttonCreateAnotherBooking) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminCreateCategory,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingListSegment &&
        text != null &&
        !text.startsWith('/')) {
      final archived = _parseBookingSegmentSelection(text);
      if (archived == null) {
        final counters = await _bookingRepository.adminCountBySegment();
        await _sendAdminMessage(
          chatId,
          _templates.chooseBookingListSegment(),
          replyMarkup: _templates.bookingSegmentKeyboard(
            activeCount: counters.active,
            archivedCount: counters.archived,
          ),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingListCategory,
        adminViewingArchived: archived,
        selectedCategory: null,
        availableBookings: const <TrainingBooking>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseBookingManagementCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingListCategory &&
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
      final archived = flowState?.adminViewingArchived ?? false;
      final listedBookings = await _bookingRepository.adminListBookings(
        category: category,
        archived: archived,
      );
      final now = _nowProvider();
      final bookings = _filterBookingsByArchivedSegment(
        listedBookings,
        archived: archived,
        now: now,
      );
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingFromList,
        selectedCategory: category,
        availableBookings: bookings,
        selectedBooking: null,
        adminBookingsPage: 0,
      );
      await _sendAdminBookingListPage(chatId: chatId, userId: userId);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingFromList &&
        text != null &&
        !text.startsWith('/')) {
      if (text == MessageTemplates.buttonBookingsNextPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage + 1,
        );
        await _sendAdminBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonBookingsPreviousPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage - 1,
        );
        await _sendAdminBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      final selectedBookingId = _parseBookingSelectionId(text);
      final bookings = flowState?.availableBookings ?? const <TrainingBooking>[];
      TrainingBooking? selectedBooking;
      for (final booking in bookings) {
        if (booking.id == selectedBookingId) {
          selectedBooking = booking;
          break;
        }
      }
      if (selectedBooking == null) {
        await _sendAdminBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBookingAction,
        selectedBooking: selectedBooking,
      );
      await _sendAdminBookingActionsCard(chatId: chatId, booking: selectedBooking);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingAction &&
        text == MessageTemplates.buttonEditBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      _flowByUserId[userId] =
          flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingEditField);
      await _sendAdminMessage(
        chatId,
        _templates.chooseAdminBookingEditField(selectedBooking),
        replyMarkup: _templates.adminBookingEditFieldsKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingAction &&
        text == MessageTemplates.buttonDeleteBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      _flowByUserId[userId] =
          flowState!.copyWith(step: _PrivateFlowStep.confirmingAdminBookingDelete);
      await _sendAdminBookingDeleteConfirmCard(chatId: chatId, booking: selectedBooking);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingAdminBookingDelete &&
        text != null) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (text == MessageTemplates.buttonCancelDeleteBooking) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingAction);
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingActions(selectedBooking),
          replyMarkup: _adminBookingActionsInlineKeyboard(selectedBooking),
        );
        return true;
      }

      if (text == MessageTemplates.buttonConfirmDeleteBooking) {
        final archived = await _bookingRepository.adminArchiveBooking(selectedBooking.id);
        if (archived == null) {
          await _sendAdminMessage(
            chatId,
            _templates.bookingNotFound(selectedBooking.id),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          _flowByUserId.remove(userId);
          return true;
        }
        await _openAdminClientNotificationStep(
          chatId: chatId,
          userId: userId,
          action: _AdminClientNotificationAction.bookingDeleted,
          booking: archived,
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingAction &&
        text == MessageTemplates.buttonRestoreBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (!_canRestoreBooking(selectedBooking)) {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingRestoreNotAllowed(selectedBooking),
          replyMarkup: _adminBookingActionsInlineKeyboard(selectedBooking),
        );
        return true;
      }
      final TrainingBooking? restored;
      try {
        restored = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          status: BookingStatus.pendingPayment,
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (restored == null) {
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      await _openAdminClientNotificationStep(
        chatId: chatId,
        userId: userId,
        action: _AdminClientNotificationAction.bookingRestored,
        booking: restored,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingEditField &&
        text != null) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingPayment) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingEditStatus);
        await _sendAdminMessage(
          chatId,
          _templates.chooseAdminBookingPaymentStatus(selectedBooking),
          replyMarkup: _templates.bookingPaymentStatusKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingUsername) {
        _flowByUserId[userId] =
            flowState!.copyWith(step: _PrivateFlowStep.enteringAdminBookingUsername);
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingAskUsername(selectedBooking),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonEditBookingEvent) {
        final category = _catalogService.categoryForBooking(selectedBooking);
        final items = _bookableItemsByCategory(category);
        if (items.isEmpty) {
          await _sender.sendMessage(
            chatId,
            _templates.noUpcomingForBooking(),
            replyMarkup: _adminBookingActionsInlineKeyboard(selectedBooking),
          );
          return true;
        }
        _flowByUserId[userId] = flowState!.copyWith(
          step: _PrivateFlowStep.selectingAdminBookingEditEvent,
          availableTrainings: items,
        );
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingEvent(items),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingEditStatus &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBooking = flowState?.selectedBooking;
      final status = _parsePaymentStatusSelection(text);
      if (selectedBooking == null || status == null) {
        await _sendAdminMessage(
          chatId,
          selectedBooking == null
              ? _templates.privateFallback()
              : _templates.chooseAdminBookingPaymentStatus(selectedBooking),
          replyMarkup: selectedBooking == null
              ? _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu)
              : _templates.bookingPaymentStatusKeyboard(),
        );
        if (selectedBooking == null) {
          _flowByUserId.remove(userId);
        }
        return true;
      }
      final TrainingBooking? updated;
      try {
        updated = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          status: status,
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _openAdminClientNotificationStep(
        chatId: chatId,
        userId: userId,
        action: _AdminClientNotificationAction.bookingStatusUpdated,
        booking: updated,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminBookingUsername &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final normalizedUsername = _normalizeUsernameInput(text);
      if (normalizedUsername == null) {
        await _sendAdminMessage(
          chatId,
          _templates.invalidUsernameInput(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      final TrainingBooking? updated;
      try {
        updated = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          userUsername: normalizedUsername,
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _openAdminClientNotificationStep(
        chatId: chatId,
        userId: userId,
        action: _AdminClientNotificationAction.bookingUsernameUpdated,
        booking: updated,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminBookingEditEvent &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final index = _parseTrainingSelectionIndex(text);
      final items = flowState?.availableTrainings ?? const <TrainingInfo>[];
      if (index == null || index < 1 || index > items.length) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingEvent(items),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
      final TrainingBooking? updated;
      try {
        updated = await _bookingRepository.adminUpdateBooking(
          bookingId: selectedBooking.id,
          training: items[index - 1],
        );
      } on BookingConflictException {
        await _sendAdminMessage(
          chatId,
          _templates.adminBookingUpdateConflict(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      if (updated == null) {
        _flowByUserId.remove(userId);
        await _sendAdminMessage(
          chatId,
          _templates.bookingNotFound(selectedBooking.id),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _openAdminClientNotificationStep(
        chatId: chatId,
        userId: userId,
        action: _AdminClientNotificationAction.bookingEventUpdated,
        booking: updated,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminCreateCategory &&
        text != null &&
        !text.startsWith('/')) {
      final category = _parseCategory(text);
      if (category == null) {
        await _sendAdminMessage(
          chatId,
          _templates.unknownCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
        return true;
      }
      final items = _bookableItemsByCategory(category);
      if (items.isEmpty) {
        await _sendAdminMessage(
          chatId,
          _templates.noUpcomingForBooking(),
          replyMarkup: _templates.adminBookingManagementKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminCreateEvent,
        availableTrainings: items,
        selectedCategory: category,
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseCreateBookingEvent(items),
        replyMarkup: _templates.bookingSelectionKeyboard(items),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminCreateEvent &&
        text != null &&
        !text.startsWith('/')) {
      final index = _parseTrainingSelectionIndex(text);
      final items = flowState?.availableTrainings ?? const <TrainingInfo>[];
      if (index == null || index < 1 || index > items.length) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingEvent(items),
          replyMarkup: _templates.bookingSelectionKeyboard(items),
        );
        return true;
      }
      final selectedTraining = items[index - 1];
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.enteringAdminCreateUsername,
        adminCreateTraining: selectedTraining,
      );
      await _sendAdminMessage(
        chatId,
        _templates.createBookingAskUsername(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminCreateUsername &&
        text != null &&
        !text.startsWith('/')) {
      final usernames = _parseUsernameListInput(text);
      if (usernames == null) {
        await _sendAdminMessage(
          chatId,
          _templates.invalidUsernameInput(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminCreateStatus,
        adminCreateUsernames: usernames,
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseCreateBookingPaymentStatus(),
        replyMarkup: _templates.bookingPaymentStatusKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminCreateStatus &&
        text != null &&
        !text.startsWith('/')) {
      final status = _parsePaymentStatusSelection(text);
      final training = flowState?.adminCreateTraining;
      final usernames = flowState?.adminCreateUsernames;
      if (status == null || training == null || usernames == null || usernames.isEmpty) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseCreateBookingPaymentStatus(),
          replyMarkup: _templates.bookingPaymentStatusKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.confirmingAdminCreate,
        adminCreateStatus: status,
      );
      await _sendAdminMessage(
        chatId,
        _templates.createBookingPreview(training: training, usernames: usernames, status: status),
        replyMarkup: _templates.adminCreateBookingConfirmationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingAdminCreate &&
        text != null) {
      if (text == MessageTemplates.buttonCancelCreateBooking) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminBookingManagementAction,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.chooseBookingManagementAction(),
          replyMarkup: _templates.adminBookingManagementKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonConfirmCreateBooking) {
        final training = flowState?.adminCreateTraining;
        final usernames = flowState?.adminCreateUsernames;
        final status = flowState?.adminCreateStatus;
        if (training == null || usernames == null || usernames.isEmpty || status == null) {
          await _sender.sendMessage(
            chatId,
            _templates.privateFallback(),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          _flowByUserId.remove(userId);
          return true;
        }
        if (usernames.length == 1) {
          final TrainingBooking created;
          try {
            created = await _bookingRepository.adminCreateBooking(
              userUsername: usernames.first,
              training: training,
              status: status,
            );
          } on BookingConflictException {
            await _sendAdminMessage(
              chatId,
              _templates.adminBookingUpdateConflict(),
            );
            return true;
          }
          await _openAdminClientNotificationStep(
            chatId: chatId,
            userId: userId,
            action: _AdminClientNotificationAction.bookingCreated,
            booking: created,
          );
        } else {
          final List<TrainingBooking> created = [];
          final List<String> conflicts = [];
          for (final username in usernames) {
            try {
              final booking = await _bookingRepository.adminCreateBooking(
                userUsername: username,
                training: training,
                status: status,
              );
              created.add(booking);
            } on BookingConflictException {
              conflicts.add(username);
            }
          }
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingManagementAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sendAdminMessage(
            chatId,
            _templates.adminBookingsCreatedBatch(created: created, conflicts: conflicts),
            replyMarkup: _templates.adminBookingAfterActionKeyboard(),
          );
        }
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminClientNotificationPreference &&
        text != null) {
      final action = flowState?.adminClientNotificationAction;
      final booking = flowState?.adminClientNotificationBooking;
      if (action == null || booking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (text != MessageTemplates.buttonNotifyClientYes &&
          text != MessageTemplates.buttonNotifyClientNo) {
        await _sendAdminMessage(
          chatId,
          _templates.askAdminClientNotificationPreference(
            booking: booking,
            actionLabel: _adminClientNotificationActionLabel(action),
          ),
          replyMarkup: _templates.adminClientNotificationPreferenceInlineKeyboard(),
        );
        return true;
      }
      if (text == MessageTemplates.buttonNotifyClientYes) {
        final notificationFailureReason =
            await _notifyUserAboutAdminBookingMutation(action: action, booking: booking);
        if (notificationFailureReason != null) {
          await _sendAdminMessage(
            chatId,
            '⚠️ <b>Клиента уведомить не удалось</b>\n'
            'Причина: ${_escapeHtmlForAdmin(notificationFailureReason)}',
          );
        }
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _adminBookingMutationResultText(action: action, booking: booking),
        replyMarkup: _templates.adminBookingAfterActionKeyboard(),
      );
      return true;
    }

    return false;
  }
}
