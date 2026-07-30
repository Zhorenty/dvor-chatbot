part of '../private_handlers.dart';

extension PrivateHandlersDispatchUserProfile on PrivateHandlers {
  Future<bool> _dispatchUserProfileCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final flowState = ctx.flowState;
    final paymentProof = ctx.paymentProof;
    final username = ctx.username;

    if (text != null && (text == MessageTemplates.buttonProfile || text.startsWith('/profile'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: username,
      );
      final now = _nowProvider();
      final bookings = await _bookingRepository.listUserBookings(userId);
      final everyFifthProgress = await _bookingRepository.getEveryFifthRewardProgress(
        userId,
        now: now,
      );
      final referralProgress = await _bookingRepository.getReferralRewardProgress(
        userId,
        now: now,
      );
      final starterBonusAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
      final subscriptionSnapshot = await _subscriptionRepository.getUserSnapshot(userId, now: now);
      final membership = subscriptionSnapshot.membership;
      final remainingProTrainings = await _proIncludedTrainingRemainingCount(
        userId: userId,
        membership: membership,
      );
      final activeBookings = bookings
          .where(
            (booking) =>
                booking.status != BookingStatus.cancelled && !booking.startsAt.isBefore(now),
          )
          .toList(growable: false);
      final visitedBookings = bookings
          .where(
            (booking) =>
                booking.status != BookingStatus.cancelled && booking.startsAt.isBefore(now),
          )
          .toList(growable: false);
      final cancelledBookings =
          bookings.where((booking) => booking.status == BookingStatus.cancelled).length;
      await _sender.sendMessage(
        chatId,
        _templates.profileOverview(
          totalBookings: bookings.length,
          activeBookings: activeBookings.length,
          visitedBookings: visitedBookings.length,
          cancelledBookings: cancelledBookings,
          completedTrainingsCount: everyFifthProgress.qualifiedTrainingsCount,
          availableEveryFifthRewards: everyFifthProgress.availableRewardsCount,
          successfulReferralsCount: referralProgress.qualifiedReferralsCount,
          availableReferralRewards: referralProgress.availableRewardsCount,
          starterBonusAvailable: starterBonusAvailable,
          membershipLevel: membership.level,
          subscriptionActiveUntil: membership.activeUntil,
          subscriptionRemainingProTrainings: remainingProTrainings,
          subscriptionRequestStatusLine:
              _templates.subscriptionStatusLineFromSnapshot(subscriptionSnapshot),
          subscriptionTotalApprovedCount: subscriptionSnapshot.totalApprovedCount,
          subscriptionCurrentPeriodStart: subscriptionSnapshot.latestActiveRequest?.activeFrom,
          now: now,
        ),
        replyMarkup: _templates.profileActionsKeyboard(),
        parseMode: 'HTML',
      );
      _flowByUserId.remove(userId);
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonReferralProgram || text.startsWith('/referral'))) {
      if (userId == null) {
        return false;
      }
      final referralProgress = await _bookingRepository.getReferralRewardProgress(
        userId,
        now: _nowProvider(),
      );
      await _sender.sendMessage(
        chatId,
        _templates.referralProgramOverview(
          userId: userId,
          successfulReferralsCount: referralProgress.qualifiedReferralsCount,
          availableReferralRewards: referralProgress.availableRewardsCount,
        ),
        replyMarkup: _templates.profileActionsKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonProfileBookings || text.startsWith('/my_bookings'))) {
      if (userId == null) {
        return false;
      }
      await _maybeNotifyEveryFifthRewardUnlocked(
        userId: userId,
        chatId: chatId,
        username: username,
      );
      final bookings = await _bookingRepository.listUserBookings(userId);
      if (bookings.isEmpty) {
        await _sender.sendMessage(
          chatId,
          'У тебя пока нет записей на мероприятия 🙃',
          replyMarkup: _templates.profileActionsKeyboard(),
        );
        return true;
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
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingListSegment &&
        text != null &&
        !text.startsWith('/')) {
      final past = _parseMyBookingSegmentSelection(text);
      if (past == null) {
        final selectedBookingId = _parseBookingSelectionId(text);
        if (selectedBookingId != null) {
          final now = _nowProvider();
          final currentBookings = flowState!.availableBookings
              .where((booking) => !_isArchivedBookingAt(booking, now: now))
              .toList(growable: false);
          TrainingBooking? selectedBooking;
          for (final booking in currentBookings) {
            if (booking.id == selectedBookingId) {
              selectedBooking = booking;
              break;
            }
          }
          if (selectedBooking != null) {
            _flowByUserId[userId] = flowState.copyWith(
              step: _PrivateFlowStep.selectingBookingAction,
              adminViewingArchived: false,
              availableBookings: currentBookings,
              selectedBooking: selectedBooking,
            );
            await _sender.sendMessage(
              chatId,
              _templates.bookingActions(selectedBooking),
              replyMarkup: _bookingActionsKeyboard(selectedBooking),
            );
            return true;
          }
        }
        await _openMyBookingListSegment(chatId: chatId, userId: userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingBookingToManage,
        adminViewingArchived: past,
        selectedBooking: null,
        adminBookingsPage: 0,
      );
      await _sendMyBookingListPage(chatId: chatId, userId: userId);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingToManage &&
        text != null &&
        !text.startsWith('/')) {
      if (text == MessageTemplates.buttonBookingsNextPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage + 1,
        );
        await _sendMyBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonBookingsPreviousPage) {
        _flowByUserId[userId] = flowState!.copyWith(
          adminBookingsPage: flowState.adminBookingsPage - 1,
        );
        await _sendMyBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      final currentFlow = flowState!;
      final selectedBookingId = _parseBookingSelectionId(text);
      TrainingBooking? selectedBooking;
      for (final booking in currentFlow.availableBookings) {
        if (booking.id == selectedBookingId) {
          selectedBooking = booking;
          break;
        }
      }
      if (selectedBooking == null) {
        await _sendMyBookingListPage(chatId: chatId, userId: userId);
        return true;
      }
      _flowByUserId[userId] = currentFlow.copyWith(
        step: _PrivateFlowStep.selectingBookingAction,
        selectedBooking: selectedBooking,
      );
      await _sender.sendMessage(
        chatId,
        _templates.bookingActions(selectedBooking),
        replyMarkup: _bookingActionsKeyboard(selectedBooking),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonRescheduleBooking) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null || !_bookingPolicyService.canReschedule(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingRescheduleNotAvailable(selectedBooking),
          replyMarkup: _templates.bookingActionsKeyboard(
            canReschedule: false,
            canCancel: selectedBooking != null &&
                _isOutdoorCategory(_catalogService.categoryForBooking(selectedBooking)),
            canRepeat: selectedBooking != null,
          ),
        );
        return true;
      }
      final trainings =
          _bookableItemsByCategory(_catalogService.categoryForBooking(selectedBooking));
      if (trainings.isEmpty) {
        await _sender.sendMessage(
          chatId,
          _templates.chooseTrainingForReschedule(const <TrainingInfo>[], booking: selectedBooking),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingRescheduleTraining,
        availableTrainings: trainings,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseTrainingForReschedule(trainings, booking: selectedBooking),
        replyMarkup: _templates.bookingSelectionKeyboard(trainings),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonCancelBooking) {
      final selectedBooking = flowState?.selectedBooking;
      final category =
          selectedBooking == null ? null : _catalogService.categoryForBooking(selectedBooking);
      if (selectedBooking == null ||
          category == null ||
          !_bookingPolicyService.supportsCancellationForBooking(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingCancelNotAvailable(selectedBooking),
          replyMarkup: _bookingActionsKeyboard(selectedBooking),
        );
        return true;
      }
      if (!_canCancelBookingByPolicy(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(selectedBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        _flowByUserId.remove(userId);
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.confirmingBookingCancel,
        selectedBooking: selectedBooking,
      );
      await _sender.sendMessage(
        chatId,
        _templates.bookingCancelConfirm(selectedBooking),
        replyMarkup: _templates.bookingCancelConfirmKeyboard(),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingBookingCancel &&
        text == MessageTemplates.buttonKeepBooking) {
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
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingBookingAction,
      );
      await _sender.sendMessage(
        chatId,
        _templates.bookingActions(selectedBooking),
        replyMarkup: _bookingActionsKeyboard(selectedBooking),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingBookingCancel &&
        text == MessageTemplates.buttonConfirmCancelBooking) {
      final selectedBooking = flowState?.selectedBooking;
      final category =
          selectedBooking == null ? null : _catalogService.categoryForBooking(selectedBooking);
      if (selectedBooking == null || category == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (!_canCancelBookingByPolicy(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _cancellationTooLateText(selectedBooking, category: category),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
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
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.bookingNotFound(selectedBooking.id),
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        text == MessageTemplates.buttonCompletePayment) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.partialPaidRemainderOffline(selectedBooking),
        replyMarkup: _bookingActionsKeyboard(selectedBooking),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingPendingPaymentBooking &&
        text != null &&
        !text.startsWith('/')) {
      final selectedBookingId = _parseBookingSelectionId(text);
      final pending = flowState?.availableBookings ?? const <TrainingBooking>[];
      TrainingBooking? selectedBooking;
      if (selectedBookingId != null) {
        for (final booking in pending) {
          if (booking.id == selectedBookingId) {
            selectedBooking = booking;
            break;
          }
        }
      }
      if (selectedBooking == null || !_isPayableForProof(selectedBooking)) {
        await _sender.sendMessage(
          chatId,
          _templates.choosePendingPaymentBooking(pending),
          replyMarkup: _templates.bookingManagementSelectionKeyboard(pending),
        );
        return true;
      }
      await _openPaymentFlowForBooking(
        chatId: chatId,
        userId: userId,
        booking: selectedBooking,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingBookingAction &&
        (text == MessageTemplates.buttonRepeatBooking ||
            text == MessageTemplates.buttonContinuePayment)) {
      final selectedBooking = flowState?.selectedBooking;
      if (selectedBooking == null) {
        await _sender.sendMessage(
          chatId,
          _templates.privateFallback(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (text == MessageTemplates.buttonContinuePayment || _isPayableForProof(selectedBooking)) {
        if (!_isPayableForProof(selectedBooking)) {
          await _sender.sendMessage(
            chatId,
            selectedBooking.status == BookingStatus.partialPaid
                ? _templates.partialPaidRemainderOffline(selectedBooking)
                : _templates.bookingActions(selectedBooking),
            replyMarkup: _bookingActionsKeyboard(selectedBooking),
          );
          return true;
        }
        await _openPaymentFlowForBooking(
          chatId: chatId,
          userId: userId,
          booking: selectedBooking,
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

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingRescheduleTraining &&
        text != null &&
        !text.startsWith('/')) {
      final currentFlow = flowState!;
      final selectedBooking = currentFlow.selectedBooking;
      if (selectedBooking == null) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          'Вернул в главное меню 👇',
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > currentFlow.availableTrainings.length) {
        await _sender.sendMessage(
          chatId,
          _bookingHandler.unknownSelectionText(),
          replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
        );
        return true;
      }
      final targetTraining = currentFlow.availableTrainings[index - 1];
      if (targetTraining.sessionKey == selectedBooking.trainingKey) {
        await _sender.sendMessage(
          chatId,
          _templates.bookingRescheduleSameTraining(),
          replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
        );
        return true;
      }
      try {
        _bookingPolicyService.ensureReschedulePaymentTypeAllowed(
          booking: selectedBooking,
          targetTraining: targetTraining,
        );
      } on ReschedulePaymentTypeViolationException catch (error) {
        final message = switch (error.violation) {
          ReschedulePaymentTypeViolation.freeToPaid =>
            _templates.bookingRescheduleFreeToPaidNotAllowed(),
          ReschedulePaymentTypeViolation.paidToFree =>
            _templates.bookingReschedulePaidToFreeNotAllowed(),
          ReschedulePaymentTypeViolation.priceMismatch =>
            _templates.bookingReschedulePriceMismatchNotAllowed(),
        };
        await _sender.sendMessage(
          chatId,
          message,
          replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
        );
        return true;
      }
      final before = selectedBooking;
      final result = await _bookingRepository.rescheduleBooking(
        userId: userId,
        bookingId: selectedBooking.id,
        training: targetTraining,
      );
      switch (result.outcome) {
        case BookingRescheduleOutcome.success:
          _flowByUserId.remove(userId);
          final after = result.booking ?? before;
          await _notifyAdminAboutBookingRescheduled(before: before, after: after);
          await _sender.sendMessage(
            chatId,
            _templates.bookingRescheduled(from: before, to: after),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case BookingRescheduleOutcome.notFound:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            _templates.bookingNotFound(selectedBooking.id),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case BookingRescheduleOutcome.conflict:
          await _sender.sendMessage(
            chatId,
            _templates.bookingRescheduleConflict(),
            replyMarkup: _templates.bookingSelectionKeyboard(currentFlow.availableTrainings),
          );
          return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        text != null &&
        (text == MessageTemplates.buttonPayFully || text == MessageTemplates.buttonPayPartially)) {
      final currentFlow = flowState!;
      final booking = currentFlow.activeBooking;
      if (booking == null || !_isOutdoorCategory(_catalogService.categoryForBooking(booking))) {
        await _sender.sendMessage(
          chatId,
          _templates.paymentProofRequired(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: currentFlow.starterBonusOffered,
            showCancelBooking: booking != null && _canCancelBookingByPolicy(booking),
            showOutdoorPaymentTypeChoice:
                booking != null && _shouldShowOutdoorPaymentTypeChoice(booking),
            showPromoCodeEntry: _shouldShowPromoCodeEntry(booking),
          ),
        );
        return true;
      }
      final selectedChoice =
          text == MessageTemplates.buttonPayPartially ? PaymentChoice.partial : PaymentChoice.full;
      _flowByUserId[userId] = currentFlow.copyWith(paymentChoice: selectedChoice);
      await _sender.sendMessage(
        chatId,
        _templates.paymentProofRequired(),
        replyMarkup: _templates.paymentConfirmationKeyboard(
          showStarterBonus: currentFlow.starterBonusOffered,
          showCancelBooking: _canCancelBookingByPolicy(booking),
          showOutdoorPaymentTypeChoice: true,
          showPromoCodeEntry: _shouldShowPromoCodeEntry(booking),
        ),
      );
      return true;
    }

    if (userId != null &&
        text != null &&
        (text == MessageTemplates.buttonPayFully || text == MessageTemplates.buttonPayPartially) &&
        flowState?.step != _PrivateFlowStep.paymentConfirmation) {
      final opened = await _openPendingPaymentFlow(chatId: chatId, userId: userId);
      if (!opened) {
        await _sender.sendMessage(
          chatId,
          _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final restoredFlow = _flowByUserId[userId];
      final booking = restoredFlow?.activeBooking;
      if (restoredFlow?.step == _PrivateFlowStep.paymentConfirmation &&
          booking != null &&
          _shouldShowOutdoorPaymentTypeChoice(booking)) {
        final selectedChoice = text == MessageTemplates.buttonPayPartially
            ? PaymentChoice.partial
            : PaymentChoice.full;
        _flowByUserId[userId] = restoredFlow!.copyWith(paymentChoice: selectedChoice);
        await _sender.sendMessage(
          chatId,
          _templates.paymentProofRequired(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: restoredFlow.starterBonusOffered,
            showCancelBooking: _canCancelBookingByPolicy(booking),
            showOutdoorPaymentTypeChoice: true,
            showPromoCodeEntry: _shouldShowPromoCodeEntry(booking),
          ),
        );
      }
      return true;
    }

    if (text == MessageTemplates.buttonSubscribeApply ||
        text == MessageTemplates.buttonRenewSubscription) {
      if (userId == null) {
        return false;
      }
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.confirmingSubscriptionPayment,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.subscriptionPaymentInstructions(),
        replyMarkup: _templates.subscriptionOverviewKeyboard(canApply: true),
        parseMode: 'HTML',
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingSubscriptionPayment &&
        paymentProof != null) {
      final submitResult = await _subscriptionRepository.submitPaymentRequest(
        userId: userId,
        userUsername: username,
        note: paymentProof.caption,
        paymentProofChatId: paymentProof.fromChatId,
        paymentProofMessageId: paymentProof.messageId,
        requestedAt: _nowProvider(),
      );
      _flowByUserId.remove(userId);
      switch (submitResult.outcome) {
        case SubmitSubscriptionRequestOutcome.created:
          final request = submitResult.request;
          if (request != null) {
            await _notifyAdminAboutSubscriptionSubmitted(request);
          }
          await _sender.sendMessage(
            chatId,
            _templates.subscriptionPaymentSubmitted(),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case SubmitSubscriptionRequestOutcome.alreadyPending:
          await _sender.sendMessage(
            chatId,
            _templates.subscriptionAlreadyPending(),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.confirmingSubscriptionPayment &&
        text != null &&
        !text.startsWith('/')) {
      await _sender.sendMessage(
        chatId,
        _templates.subscriptionPaymentProofRequired(),
        replyMarkup: _templates.subscriptionOverviewKeyboard(canApply: true),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        paymentProof != null) {
      final currentFlow = flowState!;
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        bookingId: currentFlow.activeBooking?.id,
        note: _composePaymentNote(
          caption: paymentProof.caption,
          choice: currentFlow.paymentChoice,
        ),
        paymentProofChatId: paymentProof.fromChatId,
        paymentProofMessageId: paymentProof.messageId,
      );
      if (booking != null) {
        await _notifyAdminAboutPaymentSubmitted(booking);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        booking == null ? _templates.noPendingPayment() : _templates.paymentSubmitted(booking),
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
      );
      return true;
    }

    if (userId != null && paymentProof != null && flowState == null) {
      final payable = await _listPayableBookings(userId);
      if (payable.isEmpty) {
        final bookings = await _bookingRepository.listUserBookings(userId, limit: 20);
        final alreadySubmitted = bookings.any(
          (item) => item.status == BookingStatus.paymentSubmitted,
        );
        await _sender.sendMessage(
          chatId,
          alreadySubmitted
              ? _templates.paymentSubmittedAlreadyPending()
              : _templates.noPendingPayment(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (payable.length > 1) {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingPendingPaymentBooking,
          availableTrainings: const <TrainingInfo>[],
          availableBookings: payable,
        );
        await _sender.sendMessage(
          chatId,
          _templates.choosePendingPaymentBooking(payable),
          replyMarkup: _templates.bookingManagementSelectionKeyboard(payable),
        );
        return true;
      }
      final target = payable.first;
      if (_shouldShowOutdoorPaymentTypeChoice(target)) {
        await _openPaymentFlowForBooking(chatId: chatId, userId: userId, booking: target);
        await _sender.sendMessage(
          chatId,
          _templates.chooseOutdoorPaymentType(),
          parseMode: 'HTML',
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: _flowByUserId[userId]?.starterBonusOffered ?? false,
            showCancelBooking: _canCancelBookingByPolicy(target),
            showOutdoorPaymentTypeChoice: true,
            showPromoCodeEntry: _shouldShowPromoCodeEntry(target),
          ),
        );
        return true;
      }
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        bookingId: target.id,
        note: paymentProof.caption,
        paymentProofChatId: paymentProof.fromChatId,
        paymentProofMessageId: paymentProof.messageId,
      );
      if (booking != null) {
        await _notifyAdminAboutPaymentSubmitted(booking);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        booking == null ? _templates.noPendingPayment() : _templates.paymentSubmitted(booking),
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
      );
      return true;
    }

    if (text != null &&
        text == MessageTemplates.buttonUseStarterBonus &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation) {
      if (userId == null || flowState == null) {
        return false;
      }
      final activeBooking = flowState.activeBooking;
      final canUseBonus = flowState.starterBonusOffered &&
          activeBooking != null &&
          _catalogService.categoryForBooking(activeBooking) == _ActivityCategory.trainings;
      if (!canUseBonus) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusUnavailable(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: flowState.starterBonusOffered,
            showCancelBooking: activeBooking != null && _canCancelBookingByPolicy(activeBooking),
            showOutdoorPaymentTypeChoice:
                activeBooking != null && _shouldShowOutdoorPaymentTypeChoice(activeBooking),
            showPromoCodeEntry: _shouldShowPromoCodeEntry(activeBooking),
          ),
        );
        return true;
      }
      final bonusType = await _resolveFreeTrainingBonusType(userId);
      if (bonusType == null) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusUnavailable(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: flowState.starterBonusOffered,
            showCancelBooking: _canCancelBookingByPolicy(activeBooking),
            showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(activeBooking),
            showPromoCodeEntry: _shouldShowPromoCodeEntry(activeBooking),
          ),
        );
        return true;
      }
      final updated = switch (bonusType) {
        _FreeTrainingBonusType.starter => await _applyStarterBonus(activeBooking, userId),
        _FreeTrainingBonusType.referral => await _applyReferralBonus(activeBooking),
        _FreeTrainingBonusType.everyFifth => await _applyEveryFifthBonus(activeBooking),
      };
      if (updated == null) {
        await _sender.sendMessage(
          chatId,
          _templates.starterBonusUnavailable(),
          replyMarkup: _templates.paymentConfirmationKeyboard(
            showStarterBonus: flowState.starterBonusOffered,
            showCancelBooking: _canCancelBookingByPolicy(activeBooking),
            showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(activeBooking),
            showPromoCodeEntry: _shouldShowPromoCodeEntry(activeBooking),
          ),
        );
        return true;
      }
      final booking = updated;
      if (bonusType == _FreeTrainingBonusType.starter) {
        await _notifyAdminAboutStarterBonusApplied(booking);
      } else if (bonusType == _FreeTrainingBonusType.referral) {
        await _notifyAdminAboutReferralBonusApplied(booking);
      } else {
        await _notifyAdminAboutEveryFifthBonusApplied(booking);
      }
      await _maybeNotifyGroupAboutCapacity(
        _trainingInfoFromBooking(booking),
        bookingStatus: booking.status,
      );
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        switch (bonusType) {
          _FreeTrainingBonusType.starter => _templates.starterBonusApplied(booking),
          _FreeTrainingBonusType.referral => _templates.referralBonusApplied(booking),
          _FreeTrainingBonusType.everyFifth => _templates.everyFifthBonusApplied(booking),
        },
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
      );
      await _maybeMarkOnboardingActivation(userId);
      return true;
    }

    return false;
  }
}
