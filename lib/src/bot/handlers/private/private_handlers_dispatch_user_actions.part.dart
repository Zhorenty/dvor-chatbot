part of '../private_handlers.dart';

extension PrivateHandlersDispatchUserActions on PrivateHandlers {
  Future<bool> _dispatchUserActionCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final canRunAdminAction = ctx.canRunAdminAction;
    final canRunParticipantsAction = ctx.canRunParticipantsAction;
    final isWhitelistedTrainer = ctx.isWhitelistedTrainer;
    final flowState = ctx.flowState;

    if (text != null && text == MessageTemplates.buttonCancelBooking) {
      if (userId == null) {
        return false;
      }
      TrainingBooking? targetBooking;
      if (flowState?.step == _PrivateFlowStep.paymentConfirmation) {
        targetBooking = flowState?.activeBooking;
      } else if (flowState?.step == _PrivateFlowStep.selectingBookingAction ||
          flowState?.step == _PrivateFlowStep.confirmingBookingCancel) {
        targetBooking = flowState?.selectedBooking;
      }
      if (targetBooking == null) {
        await _sender.sendMessage(
          chatId,
          'Чтобы отменить запись, открой её в «${MessageTemplates.buttonProfile}» → '
          '«${MessageTemplates.buttonProfileBookings}».',
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      final category = _catalogService.categoryForBooking(targetBooking);
      if (!_bookingPolicyService.supportsCancellationForBooking(targetBooking)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelNotAvailable(targetBooking),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (!_canCancelBookingByPolicy(targetBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(targetBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
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

    if (text != null &&
        (text == MessageTemplates.buttonSubmitPayment || text.startsWith('/paid'))) {
      if (userId == null) {
        return false;
      }
      final pinnedBookingId = _parsePaidCommandBookingId(text);
      if (pinnedBookingId != null) {
        final opened = await _openPaymentFlowForBookingId(
          chatId: chatId,
          userId: userId,
          bookingId: pinnedBookingId,
        );
        if (!opened) {
          await _sender.sendMessage(
            chatId,
            _templates.noPendingPayment(),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
        }
        return true;
      }
      if (flowState?.step != _PrivateFlowStep.paymentConfirmation) {
        final opened = await _openPendingPaymentFlow(
          chatId: chatId,
          userId: userId,
        );
        if (!opened) {
          await _sender.sendMessage(
            chatId,
            _templates.noPendingPayment(),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
        }
        return true;
      }
      final activeBooking = flowState?.activeBooking;
      final needsPaymentChoice = activeBooking != null &&
          _shouldShowOutdoorPaymentTypeChoice(activeBooking) &&
          flowState?.paymentChoice == null;
      await _sendPaymentFlowRePrompt(
        chatId: chatId,
        flowState: flowState!,
        text: needsPaymentChoice
            ? _templates.chooseOutdoorPaymentType(
                prepayPercent: activeBooking.trainingPrepayPercent,
              )
            : _templates.paymentProofRequired(),
        parseMode: needsPaymentChoice ? 'HTML' : null,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        text != null &&
        text == MessageTemplates.buttonEnterPromoCode) {
      if (flowState == null) {
        return false;
      }
      final activeBooking = flowState.activeBooking;
      if (!_shouldShowPromoCodeEntry(activeBooking)) {
        await _sendPaymentFlowRePrompt(
          chatId: chatId,
          flowState: flowState,
          text: _templates.promoCodeUnavailable(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState.copyWith(step: _PrivateFlowStep.enteringPromoCode);
      await _sender.sendMessage(
        chatId,
        _templates.promoCodeEntryPrompt(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringPromoCode &&
        text != null &&
        !text.startsWith('/') &&
        text != MessageTemplates.buttonBack &&
        text != MessageTemplates.buttonMainMenu) {
      final currentFlow = flowState!;
      final activeBooking = currentFlow.activeBooking;
      if (activeBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _promoCodeRepository.refresh();
      final promo = _promoCodeRepository.findByCode(text.trim());
      final category = _catalogService.categoryForBooking(activeBooking);
      if (promo == null || !promo.appliesTo(category)) {
        _flowByUserId[userId] = currentFlow.copyWith(step: _PrivateFlowStep.paymentConfirmation);
        await _sendPaymentFlowRePrompt(
          chatId: chatId,
          flowState: currentFlow,
          text: promo == null
              ? _templates.promoCodeInvalid()
              : _templates.promoCodeNotApplicableToCategory(),
        );
        return true;
      }
      if (promo.singleUse && await _bookingRepository.isPromoCodeUsed(promo.code, userId)) {
        _flowByUserId[userId] = currentFlow.copyWith(step: _PrivateFlowStep.paymentConfirmation);
        await _sendPaymentFlowRePrompt(
          chatId: chatId,
          flowState: currentFlow,
          text: _templates.promoCodeAlreadyUsed(),
        );
        return true;
      }
      final originalPrice = activeBooking.trainingPrice ?? 0;
      final discountedPrice = promo.discountPercent >= 100
          ? 0
          : (originalPrice * (100 - promo.discountPercent) / 100).round();
      final updatedBooking = await _bookingRepository.applyPromoCode(
        bookingId: activeBooking.id,
        code: promo.code,
        discountPercent: promo.discountPercent,
        discountedPrice: discountedPrice,
      );
      if (updatedBooking == null) {
        _flowByUserId[userId] = currentFlow.copyWith(step: _PrivateFlowStep.paymentConfirmation);
        await _sendPaymentFlowRePrompt(
          chatId: chatId,
          flowState: currentFlow,
          text: _templates.promoCodeInvalid(),
        );
        return true;
      }
      await _notifyAdminAboutPromoCodeApplied(updatedBooking);
      if (promo.discountPercent >= 100) {
        await _maybeNotifyGroupAboutCapacity(
          _trainingInfoFromBooking(updatedBooking),
          bookingStatus: updatedBooking.status,
        );
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.promoCodeAppliedFree(updatedBooking, originalPrice: originalPrice),
          parseMode: 'HTML',
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      _flowByUserId[userId] = currentFlow.copyWith(
        step: _PrivateFlowStep.paymentConfirmation,
        activeBooking: updatedBooking,
      );
      await _sendPayableBookingCard(
        chatId: chatId,
        booking: updatedBooking,
        text: _templates.promoCodeApplied(updatedBooking, originalPrice: originalPrice),
        showStarterBonus: currentFlow.starterBonusOffered,
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        text != null &&
        !text.startsWith('/')) {
      final activeBooking = flowState!.activeBooking;
      final needsPaymentChoice = activeBooking != null &&
          _shouldShowOutdoorPaymentTypeChoice(activeBooking) &&
          flowState.paymentChoice == null;
      await _sendPaymentFlowRePrompt(
        chatId: chatId,
        flowState: flowState,
        text: needsPaymentChoice
            ? _templates.chooseOutdoorPaymentType(
                prepayPercent: activeBooking.trainingPrepayPercent,
              )
            : _templates.paymentProofRequired(),
        parseMode: needsPaymentChoice ? 'HTML' : null,
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonRefreshSchedule || text.startsWith('/refresh_schedule'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.scheduleRefreshForbidden(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final scheduleRefreshOk = await _scheduleRepository.refresh(force: true);
      final trainersRefreshOk = await _trainerDirectoryRepository.refresh(force: true);
      if (!trainersRefreshOk) {
        l.w('Trainer directory refresh failed during /refresh_schedule.');
      }
      final dvorTeamRefreshOk = await _dvorTeamRepository.refresh(force: true);
      if (!dvorTeamRefreshOk) {
        l.w('Dvor team refresh failed during /refresh_schedule.');
      }
      final promoCodesRefreshOk = await _promoCodeRepository.refresh(force: true);
      if (!promoCodesRefreshOk) {
        l.w('Promo codes refresh failed during /refresh_schedule.');
      }
      final refreshOk =
          scheduleRefreshOk && trainersRefreshOk && dvorTeamRefreshOk && promoCodesRefreshOk;
      await _sendAdminMessage(
        chatId,
        refreshOk ? _templates.scheduleRefreshDone() : _templates.scheduleRefreshFailed(),
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
      );
      await _sendAdminMessage(chatId, _templates.scheduleDocumentLink());
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonPaymentsQueue || text.startsWith('/payments_queue'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingPaymentsQueueCategory,
        availableTrainings: <TrainingInfo>[],
      );
      final counters = await _paymentReviewService.queueCounters();
      await _sendAdminMessage(
        chatId,
        _templates.choosePaymentsQueueCategory(),
        replyMarkup: _templates.paymentsQueueCategorySelectionKeyboard(
          trainings: counters.trainings,
          hikes: counters.hikes,
          trails: counters.trails,
        ),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonEconomicSummary || text.startsWith('/economic_summary'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      final range = _parseEconomicSummaryRangeCommand(text);
      if (range != null) {
        await _sendEconomicSummary(chatId: chatId, isAdmin: isAdmin, range: range);
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingEconomicSummaryPeriod,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseEconomicSummaryPeriod(),
        replyMarkup: _templates.economicSummaryPeriodKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonFunnelAnalytics ||
            text.startsWith('/funnel_analytics') ||
            text.startsWith('/onboarding_analytics'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId != null) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminAnalyticsAction,
          availableTrainings: <TrainingInfo>[],
        );
      }
      await _sendFunnelAnalytics(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonFeedbackAnalytics ||
            text.startsWith('/feedback_analytics'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId != null) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminAnalyticsAction,
          availableTrainings: <TrainingInfo>[],
        );
      }
      await _sendFeedbackAnalytics(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonBookingAnalytics ||
            text.startsWith('/booking_analytics'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId != null) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminAnalyticsAction,
          availableTrainings: <TrainingInfo>[],
        );
      }
      await _sendBookingAnalytics(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonLoyaltyAnalytics ||
            text.startsWith('/loyalty_analytics'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId != null) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminAnalyticsAction,
          availableTrainings: <TrainingInfo>[],
        );
      }
      await _sendLoyaltyAnalytics(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonSubscriptionAnalytics ||
            text.startsWith('/subscription_analytics'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId != null) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminAnalyticsAction,
          availableTrainings: <TrainingInfo>[],
        );
      }
      await _sendSubscriptionAnalytics(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingEconomicSummaryPeriod &&
        text != null &&
        !text.startsWith('/')) {
      final range = _parseEconomicSummaryRangeText(text);
      if (range == null) {
        await _sendAdminMessage(
          chatId,
          _templates.chooseEconomicSummaryPeriod(),
          replyMarkup: _templates.economicSummaryPeriodKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminAnalyticsAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendEconomicSummary(chatId: chatId, isAdmin: isAdmin, range: range);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonParticipantsList ||
            text.startsWith('/participants_list'))) {
      if (!canRunParticipantsAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (userId == null) {
        return false;
      }
      if (isWhitelistedTrainer && !canRunAdminAction) {
        _flowByUserId.remove(userId);
        await _sendParticipantsByCategory(
          chatId: chatId,
          category: _ActivityCategory.trainings,
          isAdmin: isAdmin,
          canViewParticipantsList: canRunParticipantsAction,
        );
        return true;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingParticipantsCategory,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseParticipantsCategory(),
        replyMarkup: _templates.categorySelectionKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonNoblesList || text.startsWith('/nobles_list'))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _sendNoblesList(chatId: chatId, isAdmin: isAdmin);
      return true;
    }

    return false;
  }
}
