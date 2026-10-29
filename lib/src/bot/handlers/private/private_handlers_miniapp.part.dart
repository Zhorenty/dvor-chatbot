part of '../private_handlers.dart';

/// Mini App bridge: the Go API calls these through the internal HTTP bridge so
/// booking and cancellation run through the same bot flows (payment card,
/// admin notifications, BOXING CARD, team and trainer rules) as chat buttons.
extension PrivateHandlersMiniApp on PrivateHandlers {
  static final RegExp _htmlTag = RegExp('<[^>]+>');

  Map<String, Object?> miniAppSchedule() {
    final events = <Map<String, Object?>>[];
    for (final training in _catalogService.bookableItems(_ActivityCategory.trainings, limit: 40)) {
      events.add(_miniAppEventJson(training));
    }
    for (final category in const [_ActivityCategory.hikes, _ActivityCategory.trails]) {
      for (final outdoor in _catalogService.outdoorItems(category)) {
        final training = _catalogService.toBookableInfo(outdoor);
        events.add(
          _miniAppEventJson(training)
            ..addAll(<String, Object?>{
              'endsAt': _miniAppInstant(outdoor.dateTo),
              'description': _miniAppText(outdoor.description),
              'equipment': _miniAppText(outdoor.equipment),
              'itinerary': _miniAppText(outdoor.itinerary),
            }),
        );
      }
    }
    return <String, Object?>{
      'events': events,
      'generatedAt': _nowProvider().toUtc().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> miniAppScheduleWithSeats() async {
    final schedule = miniAppSchedule();
    final events = schedule['events']! as List<Map<String, Object?>>;
    for (final event in events) {
      final training = _miniAppFindTraining(event['key']! as String);
      if (training == null || (training.participantsLimit ?? 0) <= 0) {
        continue;
      }
      event['taken'] = await _bookingRepository.countActiveParticipants(training);
    }
    return schedule;
  }

  Future<Map<String, Object?>> miniAppBookings(int userId) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 40);
    return <String, Object?>{
      'bookings': bookings.map(_miniAppBookingJson).toList(growable: false),
    };
  }

  Future<Map<String, Object?>> miniAppBook({
    required int userId,
    required String? username,
    required String sessionKey,
  }) async {
    final training = _miniAppFindTraining(sessionKey);
    if (training == null) {
      return const <String, Object?>{'outcome': 'not_found'};
    }
    final before = await _miniAppFindOwnBooking(userId, sessionKey);
    final wasActive = before != null && _miniAppIsActive(before);
    if (!wasActive && await _miniAppIsFull(training, userId: userId, username: username)) {
      return const <String, Object?>{'outcome': 'full'};
    }
    final isAdmin = _adminUserIds.contains(userId) && !_adminsInClientMode.contains(userId);
    try {
      await _createOrContinueBooking(
        chatId: userId,
        userId: userId,
        isAdmin: isAdmin,
        flowState: const _PrivateFlowState(
          step: _PrivateFlowStep.selectingBookingCategory,
          availableTrainings: <TrainingInfo>[],
        ),
        selectedTraining: training,
        username: username,
        onParticipantsLimitReplyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: false,
        ),
      );
    } on TelegramApiException catch (error, stackTrace) {
      // The booking row is already written; the chat card is best effort.
      l.w('Mini App booking: failed to message user $userId: $error', stackTrace);
    }
    final after = await _miniAppFindOwnBooking(userId, sessionKey);
    if (after == null || !_miniAppIsActive(after)) {
      return const <String, Object?>{'outcome': 'full'};
    }
    return <String, Object?>{
      'outcome': wasActive ? 'exists' : 'created',
      'booking': _miniAppBookingJson(after),
    };
  }

  Future<Map<String, Object?>> miniAppCancel({
    required int userId,
    required int bookingId,
  }) async {
    final booking = await _findUserBooking(userId, bookingId);
    if (booking == null || !_miniAppIsActive(booking)) {
      return const <String, Object?>{'outcome': 'not_found'};
    }
    if (!_canCancelBookingByPolicy(booking)) {
      final category = _catalogService.categoryForBooking(booking);
      return <String, Object?>{
        'outcome': 'too_late',
        'message': _miniAppText(_cancellationTooLateText(booking, category: category)),
      };
    }
    final cancelResult = await _bookingRepository.cancelBooking(
      userId: userId,
      bookingId: booking.id,
    );
    _flowByUserId.remove(userId);
    final cancelledBooking = cancelResult.booking;
    if (cancelResult.outcome != BookingActionOutcome.success || cancelledBooking == null) {
      return const <String, Object?>{'outcome': 'not_found'};
    }
    final cancelled = await _finalizeBoxingCardCancel(booking);
    final refund = await _refundLoyaltyForBooking(booking);
    try {
      if (_shouldNotifyAdminAboutBookingCancellation(booking)) {
        await _notifyAdminAboutBookingCancelled(booking, refundPeaks: refund.peaks);
      }
      await _sendScreen(
        userId,
        _templates.bookingCancelled(
          cancelled ?? cancelledBooking,
          refundPeaks: refund.peaks,
          loyaltyRemaining: refund.remaining,
        ),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: false, showReturnToAdminMenu: false),
      );
    } on TelegramApiException catch (error, stackTrace) {
      l.w('Mini App cancel: failed to message user $userId: $error', stackTrace);
    }
    return <String, Object?>{
      'outcome': 'cancelled',
      'refundPeaks': refund.peaks,
      'booking': _miniAppBookingJson(cancelled ?? cancelledBooking),
    };
  }

  /// Every bookable catalog item the Mini App shows, trainings first.
  List<TrainingInfo> _miniAppCatalogItems() {
    return <TrainingInfo>[
      ..._catalogService.bookableItems(_ActivityCategory.trainings, limit: 40),
      for (final category in const [_ActivityCategory.hikes, _ActivityCategory.trails])
        for (final outdoor in _catalogService.outdoorItems(category))
          _catalogService.toBookableInfo(outdoor),
    ];
  }

  TrainingInfo? _miniAppFindTraining(String sessionKey) {
    for (final training in _miniAppCatalogItems()) {
      if (training.sessionKey == sessionKey) {
        return training;
      }
    }
    return null;
  }

  Future<TrainingBooking?> _miniAppFindOwnBooking(int userId, String sessionKey) async {
    final bookings = await _bookingRepository.listUserBookings(userId, limit: 100);
    for (final booking in bookings) {
      if (booking.trainingKey == sessionKey &&
          booking.participantType == BookingParticipantType.self) {
        return booking;
      }
    }
    return null;
  }

  Future<bool> _miniAppIsFull(
    TrainingInfo training, {
    required int userId,
    required String? username,
  }) async {
    final limit = training.participantsLimit;
    if (limit == null || limit <= 0) {
      return false;
    }
    if (!training.includeTrainersInParticipants &&
        isTrainerBookingWhitelisted(userId: userId, username: username)) {
      return false;
    }
    return await _bookingRepository.countActiveParticipants(training) >= limit;
  }

  bool _miniAppIsActive(TrainingBooking booking) {
    return booking.status != BookingStatus.cancelled &&
        booking.status != BookingStatus.paymentRejected;
  }

  Map<String, Object?> _miniAppEventJson(TrainingInfo training) {
    return <String, Object?>{
      'key': training.sessionKey,
      // Club highlights the bot also pins to the chat menu (FeaturedTrainings).
      'featured': FeaturedTrainings.events.any((f) => sameFeaturedSlot(training, f)),
      'category': training.category.name,
      'title': training.title,
      'startsAt': _miniAppInstant(training.startsAt),
      'endsAt': training.endsAt == null ? null : _miniAppInstant(training.endsAt!),
      'location': training.location,
      'locationUrl': training.locationUrl,
      'price': training.price,
      'prepayPercent': training.prepayPercent,
      'limit': training.participantsLimit,
      'coach': training.coach,
      'notes': _miniAppText(training.notes),
      'promoRestricted': training.promoRestricted,
    };
  }

  Map<String, Object?> _miniAppBookingJson(TrainingBooking booking) {
    return <String, Object?>{
      'id': booking.id,
      'key': booking.trainingKey,
      'category': _catalogService.categoryForBooking(booking).name,
      'title': booking.trainingTitle,
      'startsAt': _miniAppInstant(booking.startsAt),
      'location': booking.location,
      'locationUrl': booking.locationUrl,
      'status': booking.status.dbValue,
      'price': booking.trainingPrice,
      'prepayPercent': booking.trainingPrepayPercent,
      'participant': booking.isManagedForOther ? booking.participantDisplayLabel : null,
      'canCancel': _miniAppIsActive(booking) && _canCancelBookingByPolicy(booking),
      'boxingCard': MessageFormatters.isBoxingCardPaymentNote(booking.paymentNote),
      'attendance': booking.attendance?.name,
    };
  }

  /// Schedule times are club wall-clock values (Sheets, no zone). The API
  /// speaks real UTC instants, so shift by the club offset.
  String _miniAppInstant(DateTime wallClock) {
    return DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
    ).subtract(Duration(hours: _timezoneOffsetHours)).toIso8601String();
  }

  String? _miniAppText(String? html) {
    final trimmed = html?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed
        .replaceAll(_htmlTag, '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
  }
}

/// Mini App mode (`MINIAPP_ONLY`): members use the app; the chat keeps
/// notifications, payment-card buttons, receipts sent as photos and
/// feedback replies. Admins and trainers keep the full chat.
extension PrivateHandlersMiniAppOnly on PrivateHandlers {
  /// Reply-menu entries that now live in the app. Inline buttons on old
  /// messages that map to these open the app instead of a chat flow.
  static const Set<String> _movedMenuTexts = <String>{
    MessageCopy.buttonTrainings,
    MessageCopy.buttonBookTraining,
    MessageCopy.buttonBookFriend,
    MessageCopy.buttonCoachingStaff,
    MessageCopy.buttonProfile,
    MessageCopy.buttonProfileBookings,
    MessageCopy.buttonSubscription,
    MessageCopy.buttonReferralProgram,
    MessageCopy.buttonHelp,
    MessageCopy.buttonMainMenu,
  };

  /// Returns true when the update was answered here and must not reach the
  /// chat flows.
  Future<bool> _handleMiniAppOnly({
    required int chatId,
    required int userId,
    required String? text,
    required String? firstName,
    required bool isCallback,
    required bool hasPaymentProof,
    required bool hasFlow,
  }) async {
    if (text != null && text.startsWith('/start')) {
      await _miniAppOnlyStart(chatId: chatId, userId: userId, text: text, firstName: firstName);
      return true;
    }
    if (isCallback) {
      if (text != null && _movedMenuTexts.contains(text)) {
        await _sendScreen(
          chatId,
          _templates.miniAppWelcome(firstName: firstName),
          replyMarkup: _templates.openMiniAppKeyboard(),
        );
        return true;
      }
      return false;
    }
    // Receipts sent as photos and replies inside an open chat flow (promo
    // code, feedback) keep working as before.
    if (hasPaymentProof || hasFlow) {
      return false;
    }
    // Also clears the old reply-keyboard menu from the chat.
    await _sendScreen(
      chatId,
      _templates.miniAppMovedHint(),
      replyMarkup: const <String, Object?>{'remove_keyboard': true},
    );
    return true;
  }

  Future<void> _miniAppOnlyStart({
    required int chatId,
    required int userId,
    required String text,
    required String? firstName,
  }) async {
    final now = _nowProvider();
    final parts = text.trim().split(RegExp(r'\s+'));
    final payload = parts.length > 1 ? parts[1].trim().toLowerCase() : null;
    final inviterId =
        payload != null && payload.startsWith('ref_') ? int.tryParse(payload.substring(4)) : null;
    if (inviterId != null && inviterId != userId) {
      await _onboardingRepository.registerReferralAttribution(
        inviteeUserId: userId,
        inviterUserId: inviterId,
        attributedAt: now,
      );
    }
    _flowByUserId.remove(userId);
    await _handleStartCleanup(userId);
    await _onboardingService.ensureStarted(
      userId,
      startedAt: now,
      entryType: inviterId != null ? OnboardingEntryType.referral : null,
    );
    final starterBonusAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
    await _handleStartLoyalty(
      userId: userId,
      chatId: chatId,
      starterBonusAvailable: starterBonusAvailable,
    );
    await _sendScreen(
      chatId,
      _templates.miniAppWelcome(firstName: firstName),
      replyMarkup: _templates.openMiniAppKeyboard(),
    );
  }
}
