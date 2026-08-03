part of '../private_handlers.dart';

extension PrivateHandlersAdminOps on PrivateHandlers {
  Future<void> _sendParticipantsByCategory({
    required int chatId,
    required _ActivityCategory category,
    required bool isAdmin,
    required bool canViewParticipantsList,
  }) async {
    final trainings = _participantItemsByCategory(category);
    final activeBookings = await _bookingRepository.adminListBookings(
      category: category,
      archived: false,
      limit: 500,
    );
    final archivedBookings = await _bookingRepository.adminListBookings(
      category: category,
      archived: true,
      limit: 500,
    );
    final segmentBookings = <TrainingBooking>[
      ...activeBookings,
      ...archivedBookings,
    ];
    final trainingsByKey = <String, TrainingInfo>{
      for (final training in trainings) training.sessionKey: training,
    };
    final scheduleBySignature = <String, List<TrainingInfo>>{};
    for (final training in trainings) {
      scheduleBySignature
          .putIfAbsent(_trainingSignature(training), () => <TrainingInfo>[])
          .add(training);
    }
    for (final candidates in scheduleBySignature.values) {
      candidates.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    }
    final now = _nowProvider();
    for (final booking in segmentBookings) {
      final targetTrainingKey = _resolveParticipantsTrainingKey(
        booking: booking,
        trainingsByKey: trainingsByKey,
        trainingsBySignature: scheduleBySignature,
        now: now,
      );
      if (targetTrainingKey != booking.trainingKey ||
          trainingsByKey.containsKey(booking.trainingKey)) {
        continue;
      }
      trainingsByKey.putIfAbsent(
        booking.trainingKey,
        () => TrainingInfo(
          title: booking.trainingTitle,
          startsAt: booking.startsAt,
          location: booking.location,
          category: category,
        ),
      );
    }
    final mergedTrainings = trainingsByKey.values.toList(growable: false)
      ..sort((left, right) => left.startsAt.compareTo(right.startsAt));
    final visibleTrainings = mergedTrainings
        .where((training) => !_isArchivedTrainingAt(training, now: now))
        .toList(growable: false);
    final queryKeys = <String>{
      ...trainingsByKey.keys,
      ...segmentBookings.map((booking) => booking.trainingKey),
    };
    final bookings = queryKeys.isEmpty
        ? const <TrainingBooking>[]
        : await _bookingRepository.listByTrainingKeys(
            queryKeys,
            limit: 1000,
            includeCancelled: true,
          );
    final byTraining = <String, List<TrainingBooking>>{};
    for (final booking in bookings) {
      final targetTrainingKey = _resolveParticipantsTrainingKey(
        booking: booking,
        trainingsByKey: trainingsByKey,
        trainingsBySignature: scheduleBySignature,
        now: now,
      );
      byTraining.putIfAbsent(targetTrainingKey, () => <TrainingBooking>[]).add(booking);
    }
    final normalizedByTraining = <String, List<TrainingBooking>>{};
    for (final entry in byTraining.entries) {
      normalizedByTraining[entry.key] = _deduplicateParticipantBookings(entry.value);
    }

    final copy = _scheduleHandler.participantsCopy(category);

    await _sendAdminMessage(
      chatId,
      _templates.trainingParticipants(
        trainings: visibleTrainings,
        bookingsByTrainingKey: normalizedByTraining,
        title: copy.title,
        emptyText: copy.emptyText,
        isTrainerBooking: _isWhitelistedTrainerBookingByBooking,
        showTrainers: true,
      ),
      replyMarkup: _templates.privateMenuKeyboard(
        isAdmin: isAdmin,
        canViewParticipantsList: canViewParticipantsList,
        showReturnToAdminMenu: false,
      ),
    );
  }

  String _resolveParticipantsTrainingKey({
    required TrainingBooking booking,
    required Map<String, TrainingInfo> trainingsByKey,
    required Map<String, List<TrainingInfo>> trainingsBySignature,
    required DateTime now,
  }) {
    if (trainingsByKey.containsKey(booking.trainingKey)) {
      return booking.trainingKey;
    }
    final candidates = trainingsBySignature[_bookingSignature(booking)];
    if (candidates == null || candidates.isEmpty) {
      return booking.trainingKey;
    }
    final candidate = _nearestTrainingByStartsAt(candidates, booking.startsAt);
    final bookingIsArchived = _isArchivedBookingAt(booking, now: now);
    final candidateIsArchived = _isArchivedTrainingAt(candidate, now: now);
    if (bookingIsArchived != candidateIsArchived) {
      return booking.trainingKey;
    }
    final dayDistance = (candidate.startsAt.difference(booking.startsAt).inHours).abs();
    if (dayDistance > 24 * 21) {
      return booking.trainingKey;
    }
    return candidate.sessionKey;
  }

  TrainingInfo _nearestTrainingByStartsAt(
    List<TrainingInfo> candidates,
    DateTime target,
  ) {
    var best = candidates.first;
    var bestDistance = (best.startsAt.difference(target).inMinutes).abs();
    for (var index = 1; index < candidates.length; index++) {
      final candidate = candidates[index];
      final distance = (candidate.startsAt.difference(target).inMinutes).abs();
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  List<TrainingBooking> _deduplicateParticipantBookings(List<TrainingBooking> bookings) {
    if (bookings.length < 2) {
      return bookings;
    }
    final bestByIdentity = <String, TrainingBooking>{};
    for (final booking in bookings) {
      final identity = _participantIdentity(booking);
      final existing = bestByIdentity[identity];
      if (existing == null) {
        bestByIdentity[identity] = booking;
        continue;
      }
      if (_shouldReplaceParticipant(existing: existing, candidate: booking)) {
        bestByIdentity[identity] = booking;
      }
    }
    final deduplicated = bestByIdentity.values.toList(growable: false)
      ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    return deduplicated;
  }

  bool _shouldReplaceParticipant({
    required TrainingBooking existing,
    required TrainingBooking candidate,
  }) {
    final existingCancelled = existing.status == BookingStatus.cancelled;
    final candidateCancelled = candidate.status == BookingStatus.cancelled;
    if (existingCancelled && !candidateCancelled) {
      return true;
    }
    if (!existingCancelled && candidateCancelled) {
      return false;
    }
    return candidate.updatedAt.isAfter(existing.updatedAt);
  }

  String _participantIdentity(TrainingBooking booking) {
    // Party/"book a friend" rows share manager user_id. Identity must be keyed by
    // the actual participant, otherwise the whole group collapses to one line.
    switch (booking.participantType) {
      case BookingParticipantType.self:
        return 'self:${booking.managerUserId}';
      case BookingParticipantType.telegram:
        final participantUserId = booking.participantUserId;
        if (participantUserId != null) {
          return 'tg-id:$participantUserId';
        }
        final username = booking.participantUsername?.trim().toLowerCase();
        if (username != null && username.isNotEmpty) {
          return 'tg:${username.startsWith('@') ? username.substring(1) : username}';
        }
        return 'tg-row:${booking.id}';
      case BookingParticipantType.guest:
        final name = booking.participantName?.trim().toLowerCase();
        if (name != null && name.isNotEmpty) {
          return 'guest:${booking.managerUserId}:$name';
        }
        return 'guest-row:${booking.id}';
    }
  }

  String _trainingSignature(TrainingInfo training) {
    final normalizedTitle = training.title.trim().toLowerCase();
    if (_isOutdoorCategory(training.category)) {
      return normalizedTitle;
    }
    return '$normalizedTitle|${training.location.trim().toLowerCase()}';
  }

  String _bookingSignature(TrainingBooking booking) {
    final normalizedTitle = booking.trainingTitle.trim().toLowerCase();
    if (MessageFormatters.isOutdoorBooking(booking)) {
      return normalizedTitle;
    }
    return '$normalizedTitle|${booking.location.trim().toLowerCase()}';
  }

  Future<void> _sendNoblesList({
    required int chatId,
    required bool isAdmin,
  }) async {
    final result = await _noblesListService.buildStats();
    await _sendAdminMessage(
      chatId,
      _templates.noblesList(result.users, totalTrainings: result.totalTrainings),
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
    );
  }

  Future<void> _sendEconomicSummary({
    required int chatId,
    required bool isAdmin,
    required _EconomicSummaryRange range,
  }) async {
    final now = _nowProvider();
    final period = switch (range) {
      _EconomicSummaryRange.currentWeek => _economicSummaryService.currentWeeklyPeriod(now),
      _EconomicSummaryRange.previousWeek =>
        _economicSummaryService.latestCompletedWeeklyPeriod(now),
      _EconomicSummaryRange.currentMonth => _economicSummaryService.currentMonthlyPeriod(now),
      _EconomicSummaryRange.previousMonth =>
        _economicSummaryService.latestCompletedMonthlyPeriod(now),
    };
    final summary = await _economicSummaryService.buildSummary(period);
    await _sendAdminMessage(
      chatId,
      _templates.economicSummary(summary, periodLabel: range.label),
      replyMarkup: _templates.adminAnalyticsKeyboard(),
    );
  }

  Future<void> _sendFunnelAnalytics({
    required int chatId,
    required bool isAdmin,
  }) async {
    final analytics = await _onboardingRepository.getFunnelAnalytics(
      now: _nowProvider(),
    );
    await _sendAdminMessage(
      chatId,
      _templates.funnelAnalyticsOnboarding(analytics),
      replyMarkup: _templates.adminAnalyticsKeyboard(),
    );
  }

  Future<void> _sendFeedbackAnalytics({
    required int chatId,
    required bool isAdmin,
  }) async {
    final analytics = await _onboardingRepository.getFunnelAnalytics(
      now: _nowProvider(),
    );
    await _sendAdminMessage(
      chatId,
      _templates.funnelAnalyticsFeedback(analytics),
      replyMarkup: _templates.adminAnalyticsKeyboard(),
    );
  }

  Future<void> _sendBookingAnalytics({
    required int chatId,
    required bool isAdmin,
  }) async {
    final analytics = await _adminAnalyticsService.buildBookingAnalytics(
      now: _nowProvider(),
    );
    await _sendAdminMessage(
      chatId,
      _templates.bookingAnalytics(analytics),
      replyMarkup: _templates.adminAnalyticsKeyboard(),
    );
  }

  Future<void> _sendLoyaltyAnalytics({
    required int chatId,
    required bool isAdmin,
  }) async {
    final analytics = await _adminAnalyticsService.buildLoyaltyAnalytics(
      now: _nowProvider(),
    );
    await _sendAdminMessage(
      chatId,
      _templates.loyaltyAnalytics(analytics),
      replyMarkup: _templates.adminAnalyticsKeyboard(),
    );
  }

  Future<void> _sendSubscriptionAnalytics({
    required int chatId,
    required bool isAdmin,
  }) async {
    final analytics = await _adminAnalyticsService.buildSubscriptionAnalytics(
      now: _nowProvider(),
    );
    await _sendAdminMessage(
      chatId,
      _templates.subscriptionAnalytics(analytics),
      replyMarkup: _templates.adminAnalyticsKeyboard(),
    );
  }

  List<BookingParticipantDraft>? _parsePartyParticipantsInput(
    String text, {
    String? managerUsername,
  }) {
    final parts = text
        .split(RegExp(r'[,;\n]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty || parts.length > maxManagedGuestsPerEvent) {
      return null;
    }
    final normalizedManager = _normalizeUsernameInput(managerUsername ?? '')?.toLowerCase();
    final drafts = <BookingParticipantDraft>[];
    for (final part in parts) {
      if (_looksLikeTelegramUsername(part)) {
        final username = _normalizeUsernameInput(part);
        if (username == null) {
          return null;
        }
        if (normalizedManager != null && username.toLowerCase() == normalizedManager) {
          // Manager cannot book themselves as a managed @friend seat.
          return null;
        }
        drafts.add(BookingParticipantDraft.telegram(username: username));
        continue;
      }
      if (part.length > 40) {
        return null;
      }
      drafts.add(BookingParticipantDraft.guest(name: part));
    }
    return drafts;
  }

  Future<void> _openAdminBookingListSegment({
    required int chatId,
    required int userId,
  }) async {
    final counters = await _bookingRepository.adminCountBySegment();
    _flowByUserId[userId] = const _PrivateFlowState(
      step: _PrivateFlowStep.selectingAdminBookingListSegment,
      availableTrainings: <TrainingInfo>[],
    );
    await _sendAdminMessage(
      chatId,
      _templates.chooseBookingListSegment(),
      replyMarkup: _templates.bookingSegmentKeyboard(
        activeCount: counters.active,
        archivedCount: counters.archived,
      ),
    );
  }

  Future<void> _sendAdminBookingListPage({
    required int chatId,
    required int userId,
  }) async {
    final flowState = _flowByUserId[userId];
    if (flowState == null || flowState.step != _PrivateFlowStep.selectingAdminBookingFromList) {
      return;
    }
    final now = _nowProvider();
    final allBookings = _filterBookingsByArchivedSegment(
      flowState.availableBookings,
      archived: flowState.adminViewingArchived,
      now: now,
    );
    final maxPage = _maxAdminBookingsPage(allBookings);
    final page = flowState.adminBookingsPage.clamp(0, maxPage);
    final start = page * PrivateHandlers._adminBookingsPageSize;
    final end = (start + PrivateHandlers._adminBookingsPageSize).clamp(0, allBookings.length);
    final pageBookings = allBookings.sublist(start, end);
    _flowByUserId[userId] =
        flowState.copyWith(adminBookingsPage: page, availableBookings: allBookings);
    await _sendAdminMessage(
      chatId,
      _templates.chooseAdminBookingFromList(
        pageBookings,
        archived: flowState.adminViewingArchived,
        category: flowState.selectedCategory,
        page: page + 1,
        totalPages: maxPage + 1,
        totalCount: allBookings.length,
      ),
      replyMarkup: allBookings.isEmpty
          ? _templates.adminBookingManagementKeyboard()
          : _templates.adminBookingSelectionKeyboard(
              pageBookings,
              hasPreviousPage: page > 0,
              hasNextPage: page < maxPage,
            ),
    );
  }

  int _maxAdminBookingsPage(List<TrainingBooking> bookings) {
    if (bookings.isEmpty) {
      return 0;
    }
    return (bookings.length - 1) ~/ PrivateHandlers._adminBookingsPageSize;
  }

  Map<String, Object?> _adminBookingActionsKeyboard(TrainingBooking booking) {
    return _templates.adminBookingActionsKeyboard(canRestore: _canRestoreBooking(booking));
  }

  Future<void> _openAdminClientNotificationStep({
    required int chatId,
    required int userId,
    required _AdminClientNotificationAction action,
    required TrainingBooking booking,
  }) async {
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.selectingAdminClientNotificationPreference,
      availableTrainings: const <TrainingInfo>[],
      adminClientNotificationAction: action,
      adminClientNotificationBooking: booking,
    );
    await _sendAdminMessage(
      chatId,
      _templates.askAdminClientNotificationPreference(
        booking: booking,
        actionLabel: _adminClientNotificationActionLabel(action),
      ),
      replyMarkup: _templates.adminClientNotificationPreferenceKeyboard(),
    );
  }

  String _adminClientNotificationActionLabel(_AdminClientNotificationAction action) {
    return switch (action) {
      _AdminClientNotificationAction.bookingCreated => 'запись создана',
      _AdminClientNotificationAction.bookingDeleted => 'запись удалена',
      _AdminClientNotificationAction.bookingRestored => 'запись восстановлена',
      _AdminClientNotificationAction.bookingStatusUpdated => 'статус оплаты изменен',
      _AdminClientNotificationAction.bookingUsernameUpdated => 'пользователь обновлен',
      _AdminClientNotificationAction.bookingEventUpdated => 'мероприятие изменено',
    };
  }

  String _adminBookingMutationResultText({
    required _AdminClientNotificationAction action,
    required TrainingBooking booking,
  }) {
    return switch (action) {
      _AdminClientNotificationAction.bookingCreated => _templates.adminBookingCreated(booking),
      _AdminClientNotificationAction.bookingDeleted => _templates.adminBookingDeleted(booking),
      _AdminClientNotificationAction.bookingRestored => _templates.adminBookingRestored(booking),
      _AdminClientNotificationAction.bookingStatusUpdated =>
        _templates.adminBookingPaymentStatusUpdated(booking),
      _AdminClientNotificationAction.bookingUsernameUpdated =>
        _templates.adminBookingUsernameUpdated(booking),
      _AdminClientNotificationAction.bookingEventUpdated =>
        _templates.adminBookingEventUpdated(booking),
    };
  }

  bool _canRestoreBooking(TrainingBooking booking) {
    if (booking.status != BookingStatus.cancelled) {
      return false;
    }
    return booking.startsAt.isAfter(_nowProvider());
  }

  Future<int> _sendAdminMessage(
    int chatId,
    String text, {
    bool disableNotification = true,
    bool disableWebPagePreview = false,
    Map<String, Object?>? replyMarkup,
  }) {
    return _sender.sendMessage(
      chatId,
      text,
      disableNotification: disableNotification,
      disableWebPagePreview: disableWebPagePreview,
      replyMarkup: replyMarkup,
      parseMode: 'HTML',
    );
  }

  Future<void> _sendAdminSubscriptionsList({
    required int chatId,
    SubscriptionListFilter filter = SubscriptionListFilter.active,
  }) async {
    final now = _nowProvider();
    final active = await _subscriptionRepository.listSubscriptionsByFilter(
      filter: filter,
      now: now,
      limit: 200,
    );
    await _sendAdminMessage(
      chatId,
      _templates.subscriptionsList(active, now: now),
      replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
    );
    for (final request in active) {
      if (filter == SubscriptionListFilter.active ||
          filter == SubscriptionListFilter.expiringSoon) {
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionActiveItem(request),
          replyMarkup: _templates.subscriptionCancelInlineKeyboard(request.id),
        );
        continue;
      }
      final until = request.activeUntil == null ? '—' : request.activeUntil!.toIso8601String();
      final reason = request.moderationReason?.trim();
      final comment = request.moderationComment?.trim();
      await _sendAdminMessage(
        chatId,
        '🧾 <b>Абонемент #${request.id}</b>\n'
        'Пользователь: ${request.userId}\n'
        'Статус: <b>${request.status.dbValue}</b>\n'
        'До: $until'
        '${(reason ?? '').isEmpty ? '' : '\nПричина: $reason'}'
        '${(comment ?? '').isEmpty ? '' : '\nКомментарий: $comment'}',
      );
    }
  }

  Future<void> _sendAdminSubscriptionPendingQueue({
    required int chatId,
  }) async {
    final queue = await _subscriptionRepository.listPendingRequests(limit: 200);
    if (queue.isEmpty) {
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionPendingQueueEmpty(),
        replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
      );
      return;
    }
    await _sendAdminMessage(
      chatId,
      _templates.subscriptionPendingQueueIntro(queue.length),
      replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
    );
    for (final request in queue) {
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionPendingQueueItem(request),
        replyMarkup: _templates.subscriptionDecisionInlineKeyboard(request.id),
      );
      final proofChatId = request.paymentProofChatId;
      final proofMessageId = request.paymentProofMessageId;
      if (proofChatId == null || proofMessageId == null) {
        continue;
      }
      try {
        await _sender.copyMessage(
          chatId,
          fromChatId: proofChatId,
          messageId: proofMessageId,
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to copy subscription proof for request #${request.id}: $error', stackTrace);
      }
    }
  }

  Future<void> _notifyAdminAboutSubscriptionSubmitted(SubscriptionRequest request) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.subscriptionPendingQueueItem(request),
        replyMarkup: _templates.subscriptionDecisionInlineKeyboard(request.id),
      );
      final proofChatId = request.paymentProofChatId;
      final proofMessageId = request.paymentProofMessageId;
      if (proofChatId != null && proofMessageId != null) {
        await _sender.copyMessage(
          adminChatId,
          fromChatId: proofChatId,
          messageId: proofMessageId,
        );
      }
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about subscription request: $error', stackTrace);
    }
  }

  Future<void> _applySubscriptionModerationAction({
    required int chatId,
    required int requestId,
    required SubscriptionModerationAction action,
    required bool isAdmin,
    bool approveDirectly = false,
    String? reason,
    String? comment,
  }) async {
    if (approveDirectly) {
      final review = await _subscriptionRepository.reviewPendingRequestWithReason(
        requestId: requestId,
        approve: true,
        reviewedAt: _nowProvider(),
      );
      final remaining = (await _subscriptionRepository.listPendingRequests(limit: 500)).length;
      await _sendAdminMessage(
        chatId,
        switch (review.outcome) {
          ReviewSubscriptionRequestOutcome.success =>
            _templates.subscriptionReviewResultWithNextStep(
              request: review.request!,
              remaining: remaining,
            ),
          ReviewSubscriptionRequestOutcome.notFound => '😕 <b>Заявка #$requestId не найдена</b>',
          ReviewSubscriptionRequestOutcome.invalidStatus =>
            'ℹ️ <b>Заявка #$requestId уже обработана</b>',
        },
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
      );
      if (review.outcome == ReviewSubscriptionRequestOutcome.success && review.request != null) {
        await _notifyUserAboutSubscriptionDecision(review.request!);
      }
      return;
    }

    if (action == SubscriptionModerationAction.reject) {
      final review = await _subscriptionRepository.reviewPendingRequestWithReason(
        requestId: requestId,
        approve: false,
        reviewedAt: _nowProvider(),
        reason: reason,
        comment: comment,
      );
      final remaining = (await _subscriptionRepository.listPendingRequests(limit: 500)).length;
      await _sendAdminMessage(
        chatId,
        switch (review.outcome) {
          ReviewSubscriptionRequestOutcome.success =>
            _templates.subscriptionReviewResultWithNextStep(
              request: review.request!,
              remaining: remaining,
            ),
          ReviewSubscriptionRequestOutcome.notFound => '😕 <b>Заявка #$requestId не найдена</b>',
          ReviewSubscriptionRequestOutcome.invalidStatus =>
            'ℹ️ <b>Заявка #$requestId уже обработана</b>',
        },
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
      );
      if (review.outcome == ReviewSubscriptionRequestOutcome.success && review.request != null) {
        await _notifyUserAboutSubscriptionDecision(review.request!);
      }
      return;
    }

    final cancelResult = await _subscriptionRepository.cancelActiveSubscription(
      requestId: requestId,
      cancelledAt: _nowProvider(),
      reason: reason,
      comment: comment,
    );
    await _sendAdminMessage(
      chatId,
      switch (cancelResult.outcome) {
        CancelSubscriptionOutcome.success =>
          _templates.subscriptionCancelResult(cancelResult.request!),
        CancelSubscriptionOutcome.notFound => '😕 <b>Абонемент #$requestId не найден</b>',
        CancelSubscriptionOutcome.invalidStatus => 'ℹ️ <b>Абонемент #$requestId уже не активен</b>',
      },
      replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin, showReturnToAdminMenu: false),
    );
    if (cancelResult.outcome == CancelSubscriptionOutcome.success && cancelResult.request != null) {
      try {
        await _sender.sendMessage(
          cancelResult.request!.userId,
          _templates.subscriptionCancelledForUser(
            reason: reason,
            comment: comment,
          ),
          parseMode: 'HTML',
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to notify user about subscription cancel: $error', stackTrace);
      }
    }
  }

  Future<void> _notifyUserAboutSubscriptionDecision(SubscriptionRequest request) async {
    try {
      if (request.status == SubscriptionRequestStatus.active) {
        await _sender.sendMessage(
          request.userId,
          _templates.subscriptionApprovedForUser(
            activeUntil: request.activeUntil ?? _nowProvider(),
          ),
          parseMode: 'HTML',
        );
        return;
      }
      await _sender.sendMessage(
        request.userId,
        _templates.subscriptionRejectedForUser(
          reason: request.moderationReason,
          comment: request.moderationComment,
        ),
        parseMode: 'HTML',
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about subscription review: $error', stackTrace);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingDeleted(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return 'Невалидный userId у записи: ${booking.userId}.';
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingDeletedForUser(booking),
      );
      return null;
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking deletion: $error', stackTrace);
      return _notificationFailureReason(error);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingMutation({
    required _AdminClientNotificationAction action,
    required TrainingBooking booking,
  }) async {
    switch (action) {
      case _AdminClientNotificationAction.bookingCreated:
        return _notifyUserAboutAdminBookingCreated(booking);
      case _AdminClientNotificationAction.bookingDeleted:
        return _notifyUserAboutAdminBookingDeleted(booking);
      case _AdminClientNotificationAction.bookingRestored:
        return _notifyUserAboutAdminBookingRestored(booking);
      case _AdminClientNotificationAction.bookingStatusUpdated:
        return _notifyUserAboutAdminBookingStatusUpdated(booking);
      case _AdminClientNotificationAction.bookingUsernameUpdated:
        return _notifyUserAboutAdminBookingUsernameUpdated(booking);
      case _AdminClientNotificationAction.bookingEventUpdated:
        return _notifyUserAboutAdminBookingEventUpdated(booking);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingCreated(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return 'Невалидный userId у записи: ${booking.userId}.';
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingCreatedForUser(booking),
      );
      return null;
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking creation: $error', stackTrace);
      return _notificationFailureReason(error);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingRestored(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return 'Невалидный userId у записи: ${booking.userId}.';
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingRestoredForUser(booking),
      );
      return null;
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking restoration: $error', stackTrace);
      return _notificationFailureReason(error);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingStatusUpdated(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return 'Невалидный userId у записи: ${booking.userId}.';
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingPaymentStatusUpdatedForUser(booking),
      );
      return null;
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking status update: $error', stackTrace);
      return _notificationFailureReason(error);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingUsernameUpdated(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return 'Невалидный userId у записи: ${booking.userId}.';
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingUsernameUpdatedForUser(booking),
      );
      return null;
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking username update: $error', stackTrace);
      return _notificationFailureReason(error);
    }
  }

  Future<String?> _notifyUserAboutAdminBookingEventUpdated(TrainingBooking booking) async {
    if (booking.userId <= 0) {
      return 'Невалидный userId у записи: ${booking.userId}.';
    }
    try {
      await _sender.sendMessage(
        booking.userId,
        _templates.adminBookingEventUpdatedForUser(booking),
      );
      return null;
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about admin booking event update: $error', stackTrace);
      return _notificationFailureReason(error);
    }
  }

  String _notificationFailureReason(Object error) {
    if (error is TelegramApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _escapeHtmlForAdmin(String value) => escapeHtml(value);

  Future<void> _handleAdminBroadcastPhoto({
    required int chatId,
    required int userId,
    required _PrivateFlowState flowState,
    required ({int fromChatId, int messageId, String? mediaGroupId}) photo,
  }) async {
    final mediaGroupId = photo.mediaGroupId;
    final nextRef = BroadcastMessageRef(
      fromChatId: photo.fromChatId,
      messageId: photo.messageId,
    );

    if (mediaGroupId == null) {
      _cancelBroadcastMediaCollection(userId);
      _flowByUserId[userId] = flowState.copyWith(
        step: _PrivateFlowStep.selectingAdminBroadcastTarget,
        adminBroadcastText: null,
        adminBroadcastSourceMessages: <BroadcastMessageRef>[nextRef],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBroadcastMediaPreview(photoCount: 1),
        replyMarkup: _templates.broadcastTargetKeyboard(hasGroup: _broadcastService.hasGroup),
      );
      return;
    }

    final activeGroupId = _broadcastActiveMediaGroupIds[userId];
    final isNewGroup = activeGroupId != mediaGroupId;
    final existing = isNewGroup
        ? <BroadcastMessageRef>[]
        : List<BroadcastMessageRef>.from(flowState.adminBroadcastSourceMessages);
    if (!existing.any((item) => item.messageId == nextRef.messageId)) {
      existing.add(nextRef);
    }
    _broadcastActiveMediaGroupIds[userId] = mediaGroupId;
    _flowByUserId[userId] = flowState.copyWith(
      step: _PrivateFlowStep.enteringAdminBroadcastText,
      adminBroadcastText: null,
      adminBroadcastSourceMessages: existing,
    );

    _broadcastMediaFinalizeTimers[userId]?.cancel();
    _broadcastMediaFinalizeTimers[userId] = Timer(const Duration(milliseconds: 700), () {
      unawaited(
        _finalizeAdminBroadcastMedia(
          chatId: chatId,
          userId: userId,
        ),
      );
    });

    if (isNewGroup) {
      await _sendAdminMessage(
        chatId,
        _templates.adminBroadcastMediaCollecting(photoCount: existing.length),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
    }
  }

  Future<void> _finalizeAdminBroadcastMedia({
    required int chatId,
    required int userId,
  }) async {
    _broadcastMediaFinalizeTimers.remove(userId);
    _broadcastActiveMediaGroupIds.remove(userId);
    final flowState = _flowByUserId[userId];
    if (flowState == null || flowState.step != _PrivateFlowStep.enteringAdminBroadcastText) {
      return;
    }
    final sourceMessages = List<BroadcastMessageRef>.from(flowState.adminBroadcastSourceMessages)
      ..sort((left, right) => left.messageId.compareTo(right.messageId));
    if (sourceMessages.isEmpty) {
      return;
    }
    _flowByUserId[userId] = flowState.copyWith(
      step: _PrivateFlowStep.selectingAdminBroadcastTarget,
      adminBroadcastText: null,
      adminBroadcastSourceMessages: sourceMessages,
    );
    await _sendAdminMessage(
      chatId,
      _templates.adminBroadcastMediaPreview(photoCount: sourceMessages.length),
      replyMarkup: _templates.broadcastTargetKeyboard(hasGroup: _broadcastService.hasGroup),
    );
  }

  void _cancelBroadcastMediaCollection(int userId) {
    _broadcastMediaFinalizeTimers.remove(userId)?.cancel();
    _broadcastActiveMediaGroupIds.remove(userId);
  }

  Future<void> _sendRecentBotActions({
    required int chatId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
  }) async {
    final entries = await _conversationLogRepository.recentActions(
      limit: 40,
      excludePeerIds: _adminUserIds,
    );
    await _sendAdminMessage(
      chatId,
      _templates.adminRecentBotActions(entries),
      replyMarkup: _templates.privateMenuKeyboard(
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      ),
    );
  }

  Future<void> _sendUserDialogByUsername({
    required int chatId,
    required String query,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
  }) async {
    final resolvedUserId = await _resolveDialogPeerUserId(query);
    if (resolvedUserId == null) {
      await _sendAdminMessage(
        chatId,
        _templates.adminUserDialogNotFound(query),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return;
    }

    final entries = await _conversationLogRepository.dialogForUserId(
      resolvedUserId,
      limit: 40,
    );
    final username = entries.map((entry) => entry.peerUsername).whereType<String>().firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => normalizeTelegramUsername(query) ?? query,
        );
    await _sendAdminMessage(
      chatId,
      _templates.adminUserDialogHeader(
        query: query,
        userId: resolvedUserId,
        username: username,
        entriesCount: entries.length,
      ),
      replyMarkup: _templates.privateMenuKeyboard(
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      ),
    );
    if (entries.isEmpty) {
      return;
    }

    var forwarded = 0;
    var fallback = 0;
    for (final entry in entries) {
      final messageId = entry.telegramMessageId;
      if (entry.canForward && messageId != null) {
        try {
          await _sender.copyMessage(
            chatId,
            fromChatId: entry.chatId,
            messageId: messageId,
          );
          forwarded += 1;
          continue;
        } on Object catch (error, stackTrace) {
          l.w(
            'Failed to copy dialog message ${entry.chatId}#$messageId: $error',
            stackTrace,
          );
        }
      }
      await _sendAdminMessage(
        chatId,
        _templates.adminUserDialogFallbackLine(entry),
      );
      fallback += 1;
    }
    await _sendAdminMessage(
      chatId,
      _templates.adminUserDialogFooter(forwarded: forwarded, fallback: fallback),
    );
  }

  Future<int?> _resolveDialogPeerUserId(String query) async {
    final fromLog = await _conversationLogRepository.resolveUserIdByUsername(query);
    if (fromLog != null && fromLog > 0) {
      return fromLog;
    }
    final bookings = await _bookingRepository.adminSearchBookingsByUsername(query);
    for (final booking in bookings) {
      if (booking.userId > 0) {
        return booking.userId;
      }
    }
    return null;
  }
}
