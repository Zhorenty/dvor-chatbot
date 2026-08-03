part of '../private_handlers.dart';

extension PrivateHandlersDispatchInlineCallbacks on PrivateHandlers {
  Future<bool> _dispatchInlineCallbackCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final flowState = ctx.flowState;

    if (text == null || userId == null) {
      return false;
    }

    if (text.startsWith('/cancel_booking_confirm')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final selectedBooking = await _findUserBooking(userId, bookingId) ??
          (flowState?.selectedBooking?.id == bookingId ? flowState?.selectedBooking : null);
      if (selectedBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingNotFound(bookingId),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
          parseMode: 'HTML',
        );
        return true;
      }
      final category = _catalogService.categoryForBooking(selectedBooking);
      if (!_canCancelBookingByPolicy(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(selectedBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      final cancelResult = await _bookingRepository.cancelBooking(
        userId: userId,
        bookingId: selectedBooking.id,
      );
      _flowByUserId.remove(userId);
      if (cancelResult.outcome == BookingActionOutcome.success && cancelResult.booking != null) {
        if (_shouldNotifyAdminAboutBookingCancellation(selectedBooking)) {
          await _notifyAdminAboutBookingCancelled(selectedBooking);
        }
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelled(cancelResult.booking!),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.bookingNotFound(selectedBooking.id),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
        parseMode: 'HTML',
      );
      return true;
    }

    if (text.startsWith('/cancel_booking_keep')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final booking = await _findUserBooking(userId, bookingId);
      if (booking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingNotFound(bookingId),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
          parseMode: 'HTML',
        );
        return true;
      }
      if (_isPayableForProof(booking)) {
        await _openPaymentFlowForBooking(chatId: chatId, userId: userId, booking: booking);
        return true;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookingAction,
        availableTrainings: const <TrainingInfo>[],
        selectedBooking: booking,
      );
      await _sendBookingActionsCard(chatId: chatId, booking: booking);
      return true;
    }

    if (text.startsWith('/cancel_booking ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final targetBooking = await _findUserBooking(userId, bookingId);
      if (targetBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingNotFound(bookingId),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
          parseMode: 'HTML',
        );
        return true;
      }
      final category = _catalogService.categoryForBooking(targetBooking);
      if (!_bookingPolicyService.supportsCancellationForBooking(targetBooking)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelNotAvailable(targetBooking),
          replyMarkup: _bookingActionsInlineKeyboard(targetBooking),
        );
        return true;
      }
      if (!_canCancelBookingByPolicy(targetBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(targetBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      _flowByUserId[userId] = (flowState ??
              const _PrivateFlowState(
                step: _PrivateFlowStep.confirmingBookingCancel,
                availableTrainings: <TrainingInfo>[],
              ))
          .copyWith(
        step: _PrivateFlowStep.confirmingBookingCancel,
        selectedBooking: targetBooking,
        activeBooking: targetBooking,
      );
      await _sendBookingCancelConfirmCard(chatId: chatId, booking: targetBooking);
      return true;
    }

    if (text.startsWith('/paid_full ') || text.startsWith('/paid_partial ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final opened = await _openPaymentFlowForBookingId(
        chatId: chatId,
        userId: userId,
        bookingId: bookingId,
      );
      if (!opened) {
        await _sender.sendMessage(
          chatId,
          _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      final choice = text.startsWith('/paid_partial ') ? PaymentChoice.partial : PaymentChoice.full;
      final currentFlow = _flowByUserId[userId];
      if (currentFlow?.step == _PrivateFlowStep.paymentConfirmation) {
        _flowByUserId[userId] = currentFlow!.copyWith(paymentChoice: choice);
        await _sendPaymentFlowRePrompt(
          chatId: chatId,
          flowState: currentFlow.copyWith(paymentChoice: choice),
          text: _templates.paymentProofRequired(),
        );
      }
      return true;
    }

    if (text.startsWith('/use_bonus ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final booking = await _findUserBooking(userId, bookingId);
      if (booking == null || !_isPayableForProof(booking)) {
        await _sender.sendMessage(
          chatId,
          _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      final starterBonusOffered =
          _catalogService.categoryForBooking(booking) == _ActivityCategory.trainings &&
              !(_catalogService.trainingInfoForBooking(booking)?.promoRestricted ?? false) &&
              await _hasAnyFreeTrainingBonusAvailable(userId);
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.paymentConfirmation,
        availableTrainings: const <TrainingInfo>[],
        activeBooking: booking,
        starterBonusOffered: starterBonusOffered,
        paymentChoice: null,
      );
      return _dispatchUserProfileCommands(
        PrivateRequestContext(
          chatId: chatId,
          userId: userId,
          text: MessageTemplates.buttonUseStarterBonus,
          isAdmin: isAdmin,
          isConfiguredAdmin: ctx.isConfiguredAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
          canRunAdminAction: ctx.canRunAdminAction,
          canRunParticipantsAction: ctx.canRunParticipantsAction,
          isYogaTrainer: ctx.isYogaTrainer,
          isWhitelistedTrainer: ctx.isWhitelistedTrainer,
          flowState: _flowByUserId[userId],
          paymentProof: null,
          username: ctx.username,
          message: ctx.message,
          callbackMessage: ctx.callbackMessage,
        ),
      );
    }

    if (text.startsWith('/enter_promo ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final opened = await _openPaymentFlowForBookingId(
        chatId: chatId,
        userId: userId,
        bookingId: bookingId,
      );
      if (!opened) {
        await _sender.sendMessage(
          chatId,
          _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      final currentFlow = _flowByUserId[userId];
      if (currentFlow?.step == _PrivateFlowStep.paymentConfirmation &&
          _shouldShowPromoCodeEntry(currentFlow?.activeBooking)) {
        _flowByUserId[userId] = currentFlow!.copyWith(step: _PrivateFlowStep.enteringPromoCode);
        await _sender.sendMessage(
          chatId,
          _templates.promoCodeEntryPrompt(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
      }
      return true;
    }

    if (text.startsWith('/reschedule_booking ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final selectedBooking = await _findUserBooking(userId, bookingId);
      if (selectedBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingNotFound(bookingId),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
          parseMode: 'HTML',
        );
        return true;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingBookingAction,
        availableTrainings: const <TrainingInfo>[],
        selectedBooking: selectedBooking,
      );
      return _dispatchUserProfileCommands(
        PrivateRequestContext(
          chatId: chatId,
          userId: userId,
          text: MessageTemplates.buttonRescheduleBooking,
          isAdmin: isAdmin,
          isConfiguredAdmin: ctx.isConfiguredAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
          canRunAdminAction: ctx.canRunAdminAction,
          canRunParticipantsAction: ctx.canRunParticipantsAction,
          isYogaTrainer: ctx.isYogaTrainer,
          isWhitelistedTrainer: ctx.isWhitelistedTrainer,
          flowState: _flowByUserId[userId],
          paymentProof: null,
          username: ctx.username,
          message: ctx.message,
          callbackMessage: ctx.callbackMessage,
        ),
      );
    }

    if (text.startsWith('/repeat_booking ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        return false;
      }
      final selectedBooking = await _findUserBooking(userId, bookingId);
      if (selectedBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingNotFound(bookingId),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
          parseMode: 'HTML',
        );
        return true;
      }
      await _openBookingByCategory(
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        category: _catalogService.categoryForBooking(selectedBooking),
        fromSchedulePreview: false,
      );
      return true;
    }

    return false;
  }
}
