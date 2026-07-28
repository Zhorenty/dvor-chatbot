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

  Future<bool> _hasProIncludedTrainingAvailable({
    required int userId,
    required TrainingInfo training,
    required TrainingBooking booking,
  }) async {
    if (training.category != ActivityCategory.trainings) {
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
    final remaining = await _proIncludedTrainingRemainingCount(
      userId: userId,
      membership: membership,
    );
    return (remaining ?? 0) > 0;
  }

  Future<int?> _proIncludedTrainingRemainingCount({
    required int userId,
    required SubscriptionMembership membership,
  }) async {
    final activeUntil = membership.activeUntil;
    if (membership.level != MembershipLevel.pro || activeUntil == null) {
      return null;
    }
    final periodStart = activeUntil.subtract(const Duration(days: 30));
    final paidBookings = await _bookingRepository.listPaidBookingsInRange(
      fromInclusive: periodStart,
      toExclusive: activeUntil.add(const Duration(seconds: 1)),
    );
    final usedIncludedTrainings = paidBookings
        .where(
          (item) =>
              item.userId == userId &&
              item.paymentNote == MessageFormatters.proIncludedTrainingPaymentNoteMarker,
        )
        .length;
    final remaining = PrivateHandlers._proIncludedTrainingsPerPeriod - usedIncludedTrainings;
    return remaining < 0 ? 0 : remaining;
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
}
