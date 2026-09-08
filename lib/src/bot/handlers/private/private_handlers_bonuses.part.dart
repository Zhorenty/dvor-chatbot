part of '../private_handlers.dart';

extension PrivateHandlersBonusesOps on PrivateHandlers {
  Future<void> _notifyAdminAboutStarterBonusApplied(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.starterBonusAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about starter bonus booking: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutPromoCodeApplied(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.promoCodeAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about promo code booking: $error', stackTrace);
    }
  }

  Future<bool> _hasAnyFreeTrainingBonusAvailable(int userId) {
    return _onboardingRepository.hasStarterBonusAvailable(userId);
  }

  Future<bool> _hasBoxingCardIncludedTrainingAvailable({
    required int userId,
    required TrainingInfo training,
    required TrainingBooking booking,
  }) async {
    if (training.category != ActivityCategory.trainings) {
      return false;
    }
    if (!isBoxingTrainingTitle(training.title)) {
      return false;
    }
    if (_isFreeActivity(training)) {
      return false;
    }
    if (booking.status != BookingStatus.pendingPayment) {
      return false;
    }
    final now = _nowProvider();
    final membership = await _subscriptionRepository.getMembership(userId, now: now);
    if (!BoxingCardLedger.isActiveBoxingCard(membership, now: now)) {
      return false;
    }
    if (!BoxingCardLedger.trainingStartsInsidePeriod(training: training, membership: membership)) {
      return false;
    }
    final remaining = await _boxingCardRemainingGroupCount(
      userId: userId,
      membership: membership,
    );
    return (remaining ?? 0) > 0;
  }

  Future<int?> _boxingCardRemainingGroupCount({
    required int userId,
    required SubscriptionMembership membership,
  }) async {
    final plan = membership.plan;
    final activeUntil = membership.activeUntil;
    if (!BoxingCardLedger.isActiveBoxingCard(membership, now: _nowProvider()) ||
        plan == null ||
        activeUntil == null) {
      return null;
    }
    final from = BoxingCardLedger.periodStart(membership, now: _nowProvider());
    final bookings = await _bookingRepository.listUserBookingsByPaymentNotes(
      userId: userId,
      paymentNotes: <String>{
        MessageFormatters.boxingCardIncludedPaymentNoteMarker,
        MessageFormatters.proIncludedTrainingPaymentNoteMarker,
        MessageFormatters.boxingCardLateCancelPaymentNoteMarker,
      },
      startsFromInclusive: from,
      startsToExclusive: activeUntil,
    );
    final used = BoxingCardLedger.usedGroupSlots(
      bookings: bookings,
      userId: userId,
      periodStart: from,
      periodEnd: activeUntil,
    );
    return BoxingCardLedger.remainingGroupSlots(plan: plan, used: used);
  }

  Future<bool> _isBoxingCardIndividualAvailable({
    required SubscriptionMembership membership,
  }) async {
    final requestId = membership.requestId;
    if (!BoxingCardLedger.isActiveBoxingCard(membership, now: _nowProvider()) ||
        requestId == null) {
      return false;
    }
    if (await _subscriptionRepository.hasApprovedIndividualInPeriod(
      subscriptionRequestId: requestId,
    )) {
      return false;
    }
    if (await _subscriptionRepository.hasPendingIndividualInPeriod(
      subscriptionRequestId: requestId,
    )) {
      return false;
    }
    return true;
  }

  Future<bool> _isBoxingCardIndividualUsed(SubscriptionMembership membership) async {
    final requestId = membership.requestId;
    if (requestId == null) {
      return false;
    }
    return _subscriptionRepository.hasApprovedIndividualInPeriod(
      subscriptionRequestId: requestId,
    );
  }

  bool _isFreeActivity(TrainingInfo training) {
    final price = training.price;
    return price != null && price <= 0;
  }

  TrainingBooking _bookingWithStatus(
    TrainingBooking fallback,
    BookingStatus status,
    TrainingBooking? candidate,
  ) {
    if (candidate != null) {
      return candidate;
    }
    return TrainingBooking(
      id: fallback.id,
      userId: fallback.userId,
      userUsername: fallback.userUsername,
      trainingKey: fallback.trainingKey,
      trainingTitle: fallback.trainingTitle,
      startsAt: fallback.startsAt,
      location: fallback.location,
      locationUrl: fallback.locationUrl,
      status: status,
      trainingPrice: fallback.trainingPrice,
      paymentNote: fallback.paymentNote,
      paymentProofChatId: fallback.paymentProofChatId,
      paymentProofMessageId: fallback.paymentProofMessageId,
      createdAt: fallback.createdAt,
      updatedAt: fallback.updatedAt,
    );
  }

  Future<_FreeTrainingBonusType?> _resolveFreeTrainingBonusType(int userId) async {
    final starterAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
    if (starterAvailable) {
      return _FreeTrainingBonusType.starter;
    }
    return null;
  }

  Future<TrainingBooking?> _applyStarterBonus(TrainingBooking booking, int userId) async {
    final consumed = await _onboardingRepository.consumeStarterBonus(
      userId,
      consumedAt: _nowProvider(),
    );
    if (!consumed) {
      return null;
    }
    try {
      return _bookingRepository.updateStatus(
        booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.starterBonusPaymentNoteMarker,
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to apply starter bonus payment status for booking ${booking.id}: $error',
          stackTrace);
      await _onboardingRepository.rollbackStarterBonusConsumption(
        userId,
        rollbackAt: _nowProvider(),
      );
      return null;
    }
  }

  Future<void> _notifyAdminAboutBookingRescheduled({
    required TrainingBooking before,
    required TrainingBooking after,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.bookingRescheduledAdminNotification(before: before, after: after),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about booking reschedule: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutBookingCancelled(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.bookingCancelledAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about booking cancellation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutFreeBookingCreated(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.freeBookingCreatedAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about free booking creation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutBookingGroupCreated({
    required List<TrainingBooking> bookings,
    required int unitPrice,
    required int totalPrice,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null || bookings.isEmpty) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.bookingGroupCreatedAdminNotification(
          bookings: bookings,
          unitPrice: unitPrice,
          totalPrice: totalPrice,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about booking group creation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutTrainerBookingCreated(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.trainerBookingCreatedAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about trainer booking creation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutDvorTeamBookingCreated(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.dvorTeamBookingCreatedAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about dvor team booking creation: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutOutdoorInterest({
    required int userId,
    required String? username,
    required OutdoorActivityInfo activity,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.outdoorInterestAdminNotification(
          userId: userId,
          username: username,
          activity: activity,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about outdoor interest: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutSubscriptionInterest({
    required int userId,
    required String? username,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.subscriptionInterestAdminNotification(
          userId: userId,
          username: username,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about subscription interest: $error', stackTrace);
    }
  }

  Future<void> _openBoxingCardOverview({
    required int chatId,
    required int userId,
    String? username,
    bool notifyAdminInterest = false,
  }) async {
    final now = _nowProvider();
    final membership = await _subscriptionRepository.getMembership(userId, now: now);
    final remainingGroup = await _boxingCardRemainingGroupCount(
      userId: userId,
      membership: membership,
    );
    final snapshot = await _subscriptionRepository.getUserSnapshot(userId, now: now);
    final canApply = snapshot.latestPending == null;
    final isRenewal = BoxingCardLedger.isActiveBoxingCard(membership, now: now);
    final showIndividual = await _isBoxingCardIndividualAvailable(membership: membership);
    if (notifyAdminInterest && !isRenewal && snapshot.latestPending == null) {
      await _notifyAdminAboutSubscriptionInterest(
        userId: userId,
        username: username,
      );
    }
    _flowByUserId[userId] = const _PrivateFlowState(
      step: _PrivateFlowStep.viewingSubscriptionOverview,
      availableTrainings: <TrainingInfo>[],
    );
    await _sendScreen(
      chatId,
      _templates.subscriptionOverview(
        membershipLevel: membership.level,
        plan: membership.plan,
        activeUntil: membership.activeUntil,
        remainingGroupTrainings: remainingGroup,
        individualUsed: await _isBoxingCardIndividualUsed(membership),
      ),
      replyMarkup: _templates.subscriptionOverviewKeyboard(
        canApply: canApply,
        isRenewal: isRenewal,
        showIndividual: showIndividual,
      ),
    );
  }

  Future<bool> _canOfferLoyaltySpend({
    required int userId,
    required TrainingBooking booking,
  }) async {
    if (booking.status != BookingStatus.pendingPayment &&
        booking.status != BookingStatus.paymentRejected) {
      return false;
    }
    if (await _loyaltyService.hasEntry(LoyaltyKeys.spendBooking(booking.id))) {
      return false;
    }
    final training = _catalogService.trainingInfoForBooking(booking);
    if (training?.promoRestricted == true) {
      return false;
    }
    final price = booking.trainingPrice ?? training?.price ?? 0;
    if (price <= 0) {
      return false;
    }
    if (_isWhitelistedTrainerBooking(userId: userId, username: booking.userUsername) ||
        await _isDvorTeamMember(username: booking.userUsername)) {
      return false;
    }
    final balance = await _loyaltyService.availableBalance(userId, now: _nowProvider());
    if (balance <= 0) {
      return false;
    }
    final already = await _loyaltyService.peaksSpentOnBooking(booking.id);
    final category = _catalogService.categoryForBooking(booking);
    final target = category == ActivityCategory.trainings
        ? LoyaltySpendTarget.training
        : LoyaltySpendTarget.outdoor;
    final quote = _loyaltyService.quoteSpend(
      target: target,
      priceRub: price,
      balance: balance,
      alreadySpent: already,
    );
    return quote.peaks > 0;
  }

  Future<LoyaltySpendQuote> _loyaltyQuoteForBooking({
    required int userId,
    required TrainingBooking booking,
  }) async {
    final price = booking.trainingPrice ?? 0;
    final balance = await _loyaltyService.availableBalance(userId, now: _nowProvider());
    final already = await _loyaltyService.peaksSpentOnBooking(booking.id);
    final category = _catalogService.categoryForBooking(booking);
    final target = category == ActivityCategory.trainings
        ? LoyaltySpendTarget.training
        : LoyaltySpendTarget.outdoor;
    return _loyaltyService.quoteSpend(
      target: target,
      priceRub: price,
      balance: balance,
      alreadySpent: already,
    );
  }

  Future<void> _handleStartLoyalty({
    required int userId,
    required int chatId,
    required bool starterBonusAvailable,
  }) async {
    final now = _nowProvider();
    final credited = await _loyaltyService.credit(
      userId: userId,
      amount: LoyaltyMath.startBonusPeaks,
      reason: LoyaltyLedgerReason.start,
      idempotencyKey: LoyaltyKeys.start(userId),
      now: now,
    );
    await _loyaltyService.touchActivity(userId, now: now);
    if (!credited.applied) {
      return;
    }
    await _sendScreen(
      chatId,
      _templates.loyaltyStartCredited(starterBonusAvailable: starterBonusAvailable),
    );
  }

  Future<void> _refundLoyaltyForBooking(TrainingBooking booking) async {
    final spent = await _loyaltyService.peaksSpentOnBooking(booking.id);
    if (spent <= 0) {
      return;
    }
    await _loyaltyService.refund(
      userId: booking.userId,
      amount: spent,
      idempotencyKey: LoyaltyKeys.refundBooking(booking.id),
      now: _nowProvider(),
      bookingId: booking.id,
    );
  }

  Future<bool> _applyLoyaltySpendToBooking({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
    required TrainingBooking booking,
  }) async {
    final quote = await _loyaltyQuoteForBooking(userId: userId, booking: booking);
    if (quote.peaks <= 0) {
      await _sendScreen(chatId, _templates.loyaltyUnavailable());
      return true;
    }
    final result = await _loyaltyService.debit(
      userId: userId,
      amount: quote.peaks,
      reason: LoyaltyLedgerReason.spend,
      idempotencyKey: LoyaltyKeys.spendBooking(booking.id),
      now: _nowProvider(),
      bookingId: booking.id,
    );
    if (!result.applied) {
      await _sendScreen(chatId, _templates.loyaltyUnavailable());
      return true;
    }
    final category = _catalogService.categoryForBooking(booking);
    final outdoor = category == ActivityCategory.hikes || category == ActivityCategory.trails;
    if (!outdoor && quote.coversFully) {
      final paid = await _bookingRepository.updateStatus(
        booking.id,
        BookingStatus.paid,
        paymentNote: MessageFormatters.loyaltyPeaksPaymentNoteMarker,
      );
      _flowByUserId.remove(userId);
      await _maybeNotifyGroupAboutCapacity(
        _trainingInfoFromBooking(paid ?? booking),
        bookingStatus: BookingStatus.paid,
      );
      await _sendScreen(
        chatId,
        _templates.loyaltySpendApplied(
          peaks: quote.peaks,
          remainderRub: 0,
          coversFully: true,
        ),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }
    final live = (await _bookingRepository.listUserBookings(userId, limit: 50))
        .where((item) => item.id == booking.id)
        .firstOrNull;
    final current = live ?? booking;
    _flowByUserId[userId] = (_flowByUserId[userId] ??
            _PrivateFlowState(
              step: _PrivateFlowStep.paymentConfirmation,
              availableTrainings: const <TrainingInfo>[],
              activeBooking: current,
            ))
        .copyWith(
      step: _PrivateFlowStep.paymentConfirmation,
      activeBooking: current,
      loyaltySpendOffered: false,
    );
    await _sendPayableBookingCard(
      chatId: chatId,
      booking: current,
      text: outdoor
          ? _templates.loyaltyOutdoorSpendApplied(
              peaks: quote.peaks,
              remainderRub: quote.remainderRub,
            )
          : _templates.loyaltySpendApplied(
              peaks: quote.peaks,
              remainderRub: quote.remainderRub,
              coversFully: false,
            ),
      showStarterBonus: false,
      showLoyaltySpend: false,
    );
    return true;
  }

  Future<void> _creditFeedbackLoyalty({
    required int userId,
    required int bookingId,
    required int chatId,
  }) async {
    final result = await _loyaltyService.credit(
      userId: userId,
      amount: LoyaltyMath.feedbackPeaks,
      reason: LoyaltyLedgerReason.feedback,
      idempotencyKey: LoyaltyKeys.feedback(bookingId),
      now: _nowProvider(),
      bookingId: bookingId,
    );
    if (!result.applied) {
      return;
    }
    await _sendScreen(
      chatId,
      _templates.loyaltyCredited(
        amount: LoyaltyMath.feedbackPeaks,
        remaining: result.account.remaining,
        reason: LoyaltyLedgerReason.feedback,
      ),
    );
  }

  Future<LoyaltySpendQuote> _loyaltyQuoteForCard({
    required int userId,
    required BoxingCardPlan plan,
  }) async {
    final balance = await _loyaltyService.availableBalance(userId, now: _nowProvider());
    final already = await _loyaltyService.peaksSpentOnPendingCard(userId);
    return _loyaltyService.quoteSpend(
      target: LoyaltySpendTarget.boxingCard,
      priceRub: plan.priceRub,
      balance: balance,
      alreadySpent: already,
    );
  }

  Future<void> _refundPendingCardLoyalty(int userId) async {
    final spent = await _loyaltyService.peaksSpentOnPendingCard(userId);
    if (spent <= 0) {
      return;
    }
    await _loyaltyService.refund(
      userId: userId,
      amount: spent,
      idempotencyKey: LoyaltyKeys.pendingCardRefund(userId),
      now: _nowProvider(),
    );
  }

  Future<void> _accrueBoxingCardLoyalty(SubscriptionRequest request) async {
    final plan = request.plan;
    if (plan == null) {
      return;
    }
    final spent = await _loyaltyService.peaksSpentOnPendingCard(request.userId);
    final paidRub = LoyaltyMath.remainderRub(priceRub: plan.priceRub, peaksSpent: spent);
    final amount = _loyaltyService.quoteCardEarn(paidRub);
    if (amount <= 0) {
      return;
    }
    final result = await _loyaltyService.credit(
      userId: request.userId,
      amount: amount,
      reason: LoyaltyLedgerReason.boxingCard,
      idempotencyKey: LoyaltyKeys.boxingCard(request.id),
      now: _nowProvider(),
      subscriptionRequestId: request.id,
    );
    if (!result.applied) {
      return;
    }
    await _sendScreen(
      request.userId,
      _templates.loyaltyCredited(
        amount: amount,
        remaining: result.account.remaining,
        reason: LoyaltyLedgerReason.boxingCard,
      ),
    );
  }

  Future<bool> _applyLoyaltySpendToCard({
    required int chatId,
    required int userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
    required BoxingCardPlan plan,
    required String? username,
  }) async {
    final quote = await _loyaltyQuoteForCard(userId: userId, plan: plan);
    if (quote.peaks <= 0) {
      await _sendScreen(chatId, _templates.loyaltyUnavailable());
      return true;
    }
    final result = await _loyaltyService.debit(
      userId: userId,
      amount: quote.peaks,
      reason: LoyaltyLedgerReason.spend,
      idempotencyKey: LoyaltyKeys.pendingCardSpend(userId),
      now: _nowProvider(),
    );
    if (!result.applied) {
      await _sendScreen(chatId, _templates.loyaltyUnavailable());
      return true;
    }
    if (quote.coversFully) {
      final activated = await _subscriptionRepository.activateFromLoyaltyPeaks(
        userId: userId,
        userUsername: username,
        plan: plan,
        activatedAt: _nowProvider(),
      );
      _flowByUserId.remove(userId);
      if (activated.outcome == SubmitSubscriptionRequestOutcome.alreadyPending) {
        await _refundPendingCardLoyalty(userId);
        await _sendScreen(
          chatId,
          _templates.subscriptionAlreadyPending(),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        return true;
      }
      await _loyaltyService.touchActivity(userId, now: _nowProvider());
      await _sendScreen(
        chatId,
        _templates.loyaltyCardSpendApplied(
          peaks: quote.peaks,
          remainderRub: 0,
          coversFully: true,
        ),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }
    _flowByUserId[userId] = (_flowByUserId[userId] ??
            _PrivateFlowState(
              step: _PrivateFlowStep.confirmingSubscriptionPayment,
              availableTrainings: const <TrainingInfo>[],
              selectedBoxingCardPlan: plan,
            ))
        .copyWith(
      step: _PrivateFlowStep.confirmingSubscriptionPayment,
      selectedBoxingCardPlan: plan,
      loyaltySpendOffered: false,
    );
    await _sendScreen(
      chatId,
      '${_templates.loyaltyCardSpendApplied(
        peaks: quote.peaks,
        remainderRub: quote.remainderRub,
        coversFully: false,
      )}\n\n${_templates.subscriptionPaymentInstructions(
        plan: plan,
        remainderRub: quote.remainderRub,
      )}',
      replyMarkup: _templates.subscriptionPaymentKeyboard(showLoyaltySpend: false),
    );
    return true;
  }
}
