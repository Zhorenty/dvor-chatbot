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

  Future<void> _notifyAdminAboutEveryFifthBonusApplied(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.everyFifthBonusAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about every-fifth bonus booking: $error', stackTrace);
    }
  }

  Future<void> _notifyAdminAboutReferralBonusApplied(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.referralBonusAdminNotification(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about referral bonus booking: $error', stackTrace);
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

  Future<bool> _hasAnyFreeTrainingBonusAvailable(int userId) async {
    final starterAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
    if (starterAvailable) {
      return true;
    }
    final referralProgress = await _bookingRepository.getReferralRewardProgress(
      userId,
      now: _nowProvider(),
    );
    if (referralProgress.availableRewardsCount > 0) {
      return true;
    }
    final progress = await _bookingRepository.getEveryFifthRewardProgress(
      userId,
      now: _nowProvider(),
    );
    return progress.availableRewardsCount > 0;
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
    final referralProgress = await _bookingRepository.getReferralRewardProgress(
      userId,
      now: _nowProvider(),
    );
    if (referralProgress.availableRewardsCount > 0) {
      return _FreeTrainingBonusType.referral;
    }
    final progress = await _bookingRepository.getEveryFifthRewardProgress(
      userId,
      now: _nowProvider(),
    );
    if (progress.availableRewardsCount > 0) {
      return _FreeTrainingBonusType.everyFifth;
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

  Future<TrainingBooking?> _applyEveryFifthBonus(TrainingBooking booking) async {
    return _bookingRepository.updateStatus(
      booking.id,
      BookingStatus.paid,
      paymentNote: MessageFormatters.everyFifthBonusPaymentNoteMarker,
    );
  }

  Future<TrainingBooking?> _applyReferralBonus(TrainingBooking booking) async {
    return _bookingRepository.updateStatus(
      booking.id,
      BookingStatus.paid,
      paymentNote: MessageFormatters.referralBonusPaymentNoteMarker,
    );
  }

  Future<void> _maybeNotifyEveryFifthRewardUnlocked({
    required int userId,
    required int chatId,
    required String? username,
  }) async {
    final progress = await _bookingRepository.getEveryFifthRewardProgress(
      userId,
      now: _nowProvider(),
    );
    final earnedRewards = progress.earnedRewardsCount;
    if (earnedRewards <= 0 || progress.availableRewardsCount <= 0) {
      return;
    }
    final lastNotified = await _onboardingRepository.getEveryFifthLastNotifiedRewards(userId);
    if (earnedRewards <= lastNotified) {
      return;
    }
    try {
      await _sender.sendMessage(
        chatId,
        _templates.everyFifthBonusUnlockedUser(
          completedTrainingsCount: progress.qualifiedTrainingsCount,
          availableRewardsCount: progress.availableRewardsCount,
        ),
      );
      await _onboardingRepository.setEveryFifthLastNotifiedRewards(
        userId,
        rewardsCount: earnedRewards,
        updatedAt: _nowProvider(),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about every-fifth reward unlock: $error', stackTrace);
    }
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.everyFifthBonusUnlockedAdmin(
          userId: userId,
          username: username,
          completedTrainingsCount: progress.qualifiedTrainingsCount,
          availableRewardsCount: progress.availableRewardsCount,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about every-fifth reward unlock: $error', stackTrace);
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
    await _sender.sendMessage(
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
      parseMode: 'HTML',
    );
  }
}
