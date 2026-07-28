part of '../private_handlers.dart';

extension PrivateHandlersPaymentOps on PrivateHandlers {
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
      await _sender.sendMessage(
        booking.userId,
        isApproved
            ? _templates.paymentApprovedForUser(booking)
            : _templates.paymentRejectedForUser(booking),
      );
      if (isApproved) {
        await _sendOutdoorPrepDetails(booking.userId, booking);
        await _maybeMarkOnboardingActivation(booking.userId);
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
    await _sender.sendMessage(
      chatId,
      _templates.paymentDetailsSent(booking),
      parseMode: 'HTML',
      replyMarkup: _templates.paymentConfirmationKeyboard(
        showStarterBonus: starterBonusOffered,
        showCancelBooking: _canCancelBookingByPolicy(booking),
        showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(booking),
        showPromoCodeEntry: _shouldShowPromoCodeEntry(booking),
      ),
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
    if (target == null || target.status != BookingStatus.pendingPayment) {
      return false;
    }
    await _openPaymentFlowForBooking(chatId: chatId, userId: userId, booking: target);
    return true;
  }

  Future<bool> _openPendingPaymentFlow({
    required int chatId,
    required int userId,
  }) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 20);
    final pending = bookings.where((item) => item.status == BookingStatus.pendingPayment).toList();
    if (pending.isEmpty) {
      return false;
    }
    pending.sort((left, right) {
      final byCreated = right.createdAt.compareTo(left.createdAt);
      if (byCreated != 0) {
        return byCreated;
      }
      return right.id.compareTo(left.id);
    });
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

  Future<TrainingBooking?> _resolveLatestPendingPaymentBooking(int userId) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 20);
    final pending = bookings.where((item) => item.status == BookingStatus.pendingPayment).toList();
    if (pending.isEmpty) {
      return null;
    }
    pending.sort((left, right) {
      final byCreated = right.createdAt.compareTo(left.createdAt);
      if (byCreated != 0) {
        return byCreated;
      }
      return right.id.compareTo(left.id);
    });
    return pending.first;
  }

  int? _parsePaidCommandBookingId(String text) {
    final match = RegExp(r'^/paid(?:@\w+)?\s+(\d+)\s*$').firstMatch(text.trim());
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }
}
