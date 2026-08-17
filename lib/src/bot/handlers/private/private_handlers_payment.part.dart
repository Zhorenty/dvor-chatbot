part of '../private_handlers.dart';

extension PrivateHandlersPaymentOps on PrivateHandlers {
  Future<void> _sendPayableBookingCard({
    required int chatId,
    required TrainingBooking booking,
    required String text,
    required bool showStarterBonus,
    String? parseMode,
  }) async {
    await _sender.sendMessage(
      chatId,
      text,
      parseMode: parseMode,
      replyMarkup: _templates.paymentCardInlineKeyboard(
        booking.id,
        showStarterBonus: showStarterBonus,
        showCancelBooking: _canCancelBookingByPolicy(booking),
        showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(booking),
        showPromoCodeEntry: _shouldShowPromoCodeEntry(booking),
      ),
    );
    await _sender.sendMessage(
      chatId,
      _templates.paymentCardNavHint(),
      replyMarkup: _templates.simpleNavigationKeyboard(),
    );
  }

  Future<void> _sendPaymentFlowRePrompt({
    required int chatId,
    required _PrivateFlowState flowState,
    required String text,
    String? parseMode,
  }) async {
    final booking = flowState.activeBooking;
    if (booking != null) {
      await _sendPayableBookingCard(
        chatId: chatId,
        booking: booking,
        text: text,
        showStarterBonus: flowState.starterBonusOffered,
        parseMode: parseMode,
      );
      return;
    }
    await _sender.sendMessage(
      chatId,
      text,
      parseMode: parseMode,
      replyMarkup: _templates.paymentConfirmationKeyboard(
        showStarterBonus: flowState.starterBonusOffered,
        showCancelBooking: false,
        showOutdoorPaymentTypeChoice: false,
        showPromoCodeEntry: false,
      ),
    );
  }

  Future<void> _sendPaymentsQueueByCategory({
    required int chatId,
    required _ActivityCategory category,
    required bool isAdmin,
  }) async {
    final filtered = await _paymentReviewService.queueByCategory(category);
    if (filtered.isEmpty) {
      await _sender.sendMessage(
        chatId,
        _templates.paymentsQueueEmpty(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
      );
      return;
    }

    await _sendAdminMessage(
      chatId,
      _templates.paymentsQueueIntro(filtered.length, category: category),
    );
    await _sendPaymentsQueueItem(chatId: chatId, booking: filtered.first);
  }

  Future<void> _sendPaymentsQueueItem({
    required int chatId,
    required TrainingBooking booking,
  }) async {
    final proofChatId = booking.paymentProofChatId;
    final proofMessageId = booking.paymentProofMessageId;
    if (proofChatId != null && proofMessageId != null) {
      try {
        await _sender.copyMessage(
          chatId,
          fromChatId: proofChatId,
          messageId: proofMessageId,
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to copy payment proof for booking ${booking.id}: $error', stackTrace);
        await _sendAdminMessage(
          chatId,
          _templates.paymentProofUnavailableHint(booking),
        );
      }
    }
    final groupBookings = await _groupBookingsFor(booking);
    await _sendAdminMessage(
      chatId,
      _templates.paymentsQueueItem(
        booking,
        groupBookings: groupBookings,
      ),
      replyMarkup: _templates.paymentDecisionInlineKeyboard(
        booking.id,
        approvePartial: _hasPartialPaymentChoice(booking.paymentNote),
      ),
    );
  }

  Future<List<TrainingBooking>> _groupBookingsFor(TrainingBooking booking) async {
    final groupId = booking.paymentGroupId?.trim();
    if (groupId == null || groupId.isEmpty) {
      return <TrainingBooking>[booking];
    }
    final group = await _bookingRepository.listBookingsByPaymentGroup(groupId);
    if (group.isEmpty) {
      return <TrainingBooking>[booking];
    }
    return group;
  }

  Future<void> _notifyAdminAboutPaymentSubmitted(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      final counters = await _paymentReviewService.queueCounters();
      final groupBookings = await _groupBookingsFor(booking);
      await _sendAdminMessage(
        adminChatId,
        _templates.paymentSubmittedAdminNotification(
          booking,
          groupBookings: groupBookings,
        ),
        replyMarkup: _templates.openPaymentsQueueInlineKeyboard(total: counters.total),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment submission: $error', stackTrace);
    }
  }

  Future<void> _notifyAboutPaymentReview(
    TrainingBooking booking, {
    required int? moderatorUserId,
    String? moderatorUsername,
  }) async {
    try {
      final isApproved =
          booking.status == BookingStatus.paid || booking.status == BookingStatus.partialPaid;
      if (isApproved) {
        await _sender.sendMessage(
          booking.userId,
          _templates.paymentApprovedForUser(booking),
        );
        await _sendOutdoorPrepDetails(booking.userId, booking);
        await _maybeMarkOnboardingActivation(booking.userId);
      } else {
        final starterBonusOffered =
            _catalogService.categoryForBooking(booking) == _ActivityCategory.trainings &&
                !(_catalogService.trainingInfoForBooking(booking)?.promoRestricted ?? false) &&
                await _hasAnyFreeTrainingBonusAvailable(booking.userId);
        _flowByUserId[booking.userId] = _PrivateFlowState(
          step: _PrivateFlowStep.paymentConfirmation,
          availableTrainings: const <TrainingInfo>[],
          activeBooking: booking,
          starterBonusOffered: starterBonusOffered,
          paymentChoice: null,
        );
        await _sendPayableBookingCard(
          chatId: booking.userId,
          booking: booking,
          text: _templates.paymentRejectedForUser(booking),
          showStarterBonus: starterBonusOffered,
        );
      }
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about payment review: $error', stackTrace);
    }

    final adminChatId = _adminChatId;
    if (adminChatId == null || moderatorUserId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.paymentReviewAdminNotification(
          booking: booking,
          moderatorUserId: moderatorUserId,
          moderatorUsername: moderatorUsername,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment review: $error', stackTrace);
    }
  }

  bool _shouldShowOutdoorPaymentTypeChoice(TrainingBooking booking) {
    return _bookingPolicyService.shouldShowOutdoorPaymentTypeChoice(booking);
  }

  bool _shouldShowPromoCodeEntry(TrainingBooking? booking) {
    if (booking == null || booking.promoCode != null) {
      return false;
    }
    final price = booking.trainingPrice;
    if (price == null || price <= 0) return false;
    final training = _catalogService.trainingInfoForBooking(booking);
    return training?.promoRestricted != true;
  }

  String? _composePaymentNote({
    required String? caption,
    required PaymentChoice? choice,
  }) {
    final normalizedCaption = caption?.trim();
    final marker = switch (choice) {
      PaymentChoice.full => PrivateHandlers._paymentChoiceFullMarker,
      PaymentChoice.partial => PrivateHandlers._paymentChoicePartialMarker,
      null => null,
    };
    if (marker == null) {
      return normalizedCaption;
    }
    if (normalizedCaption == null || normalizedCaption.isEmpty) {
      return marker;
    }
    return '$marker\n$normalizedCaption';
  }

  bool _hasPartialPaymentChoice(String? paymentNote) {
    if (paymentNote == null || paymentNote.isEmpty) {
      return false;
    }
    return paymentNote.startsWith(PrivateHandlers._paymentChoicePartialMarker);
  }

  Future<void> _openPaymentFlowForBooking({
    required int chatId,
    required int userId,
    required TrainingBooking booking,
  }) async {
    if (booking.status == BookingStatus.partialPaid) {
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        _templates.partialPaidRemainderOffline(booking),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return;
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
    await _sendPayableBookingCard(
      chatId: chatId,
      booking: booking,
      text: _templates.paymentDetailsSent(booking),
      showStarterBonus: starterBonusOffered,
      parseMode: 'HTML',
    );
  }

  Future<bool> _openPaymentFlowForBookingId({
    required int chatId,
    required int userId,
    required int bookingId,
  }) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 50);
    TrainingBooking? target;
    for (final booking in bookings) {
      if (booking.id == bookingId) {
        target = booking;
        break;
      }
    }
    if (target == null || !_isPayableForProof(target)) {
      return false;
    }
    await _openPaymentFlowForBooking(chatId: chatId, userId: userId, booking: target);
    return true;
  }

  Future<bool> _openPendingPaymentFlow({
    required int chatId,
    required int userId,
  }) async {
    final pending = await _listPayableBookings(userId);
    if (pending.isEmpty) {
      return false;
    }
    if (pending.length == 1) {
      await _openPaymentFlowForBooking(chatId: chatId, userId: userId, booking: pending.first);
      return true;
    }
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingPendingPaymentBooking,
      availableTrainings: const <TrainingInfo>[],
      availableBookings: pending,
    );
    await _sender.sendMessage(
      chatId,
      _templates.choosePendingPaymentBooking(pending),
      replyMarkup: _templates.bookingManagementSelectionKeyboard(pending),
    );
    return true;
  }

  Future<List<TrainingBooking>> _listPayableBookings(int userId) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 100);
    final pending = bookings.where(_isPayableForProof).toList();
    pending.sort((left, right) {
      final byCreated = right.createdAt.compareTo(left.createdAt);
      if (byCreated != 0) {
        return byCreated;
      }
      return right.id.compareTo(left.id);
    });
    // One picker entry per payment group (manager pays once for the party).
    final seenGroups = <String>{};
    final deduped = <TrainingBooking>[];
    for (final booking in pending) {
      final groupId = booking.paymentGroupId?.trim();
      if (groupId != null && groupId.isNotEmpty) {
        if (!seenGroups.add(groupId)) {
          continue;
        }
      }
      deduped.add(booking);
    }
    return deduped;
  }

  bool _isPayableForProof(TrainingBooking booking) {
    return booking.status == BookingStatus.pendingPayment ||
        booking.status == BookingStatus.paymentRejected;
  }

  int? _parsePaidCommandBookingId(String text) {
    final match = RegExp(r'^/paid(?:@\w+)?\s+(\d+)\s*$').firstMatch(text.trim());
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  bool _shouldRecoverOrphanPaymentProof(_PrivateFlowState? flowState) {
    if (flowState == null) {
      return true;
    }
    // Only reclaim proofs from leftover browse/booking steps. Never steal media
    // from admin broadcast, onboarding, feedback, or other dedicated flows.
    return switch (flowState.step) {
      _PrivateFlowStep.selectingOutdoorDetailType ||
      _PrivateFlowStep.selectingOutdoorDetailEvent ||
      _PrivateFlowStep.selectingBookingCategory ||
      _PrivateFlowStep.selectingBookFriendCategory ||
      _PrivateFlowStep.selectingBookFriendEvent ||
      _PrivateFlowStep.enteringPartyParticipants ||
      _PrivateFlowStep.selectingTraining ||
      _PrivateFlowStep.viewingScheduleCategory ||
      _PrivateFlowStep.selectingScheduleCategory ||
      _PrivateFlowStep.selectingParticipantsCategory ||
      _PrivateFlowStep.selectingPendingPaymentBooking ||
      _PrivateFlowStep.enteringPromoCode ||
      _PrivateFlowStep.viewingCoachingStaff ||
      _PrivateFlowStep.selectingTrainerProfile =>
        true,
      _ => false,
    };
  }

  Future<void> _submitStoredPaymentProof({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
    required int? bookingId,
    required PaymentChoice? choice,
    required int proofChatId,
    required int proofMessageId,
    required String? caption,
  }) async {
    final booking = await _bookingRepository.submitPaymentForLatestPending(
      userId,
      bookingId: bookingId,
      note: _composePaymentNote(caption: caption, choice: choice),
      paymentProofChatId: proofChatId,
      paymentProofMessageId: proofMessageId,
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
  }
}
