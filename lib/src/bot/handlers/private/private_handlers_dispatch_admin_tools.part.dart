part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdminTools on PrivateHandlers {
  Future<bool> _dispatchAdminToolsCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final canRunAdminAction = ctx.canRunAdminAction;
    final flowState = ctx.flowState;
    final message = ctx.message;

    if (await _handleAdminOnboardingMediaCommands(
      chatId: chatId,
      userId: userId,
      text: text,
      message: message,
      isAdmin: isAdmin,
      showReturnToAdminMenu: showReturnToAdminMenu,
      canRunAdminAction: canRunAdminAction,
      flowState: flowState,
    )) {
      return true;
    }

    if (text != null &&
        (text.startsWith('/loyalty_grant ') || text.startsWith('/loyalty_debit '))) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final parts = text.trim().split(RegExp(r'\s+'));
      if (parts.length < 3) {
        await _sendAdminMessage(
          chatId,
          _templates.loyaltyAdminCommandUsage(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final targetUserId = int.tryParse(parts[1]);
      final amount = int.tryParse(parts[2]);
      if (targetUserId == null || amount == null) {
        await _sendAdminMessage(
          chatId,
          _templates.loyaltyAdminCommandUsage(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (amount <= 0 || amount % LoyaltyMath.unit != 0) {
        await _sendAdminMessage(
          chatId,
          _templates.loyaltyAdminAmountInvalid(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final granted = text.startsWith('/loyalty_grant ');
      final result = granted
          ? await _loyaltyService.adminGrant(userId: targetUserId, amount: amount)
          : await _loyaltyService.adminDebit(userId: targetUserId, amount: amount);
      if (!result.applied) {
        await _sendAdminMessage(
          chatId,
          _templates.loyaltyUnavailable(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _sendAdminMessage(
        chatId,
        _templates.loyaltyAdminMutationResult(
          userId: targetUserId,
          amount: amount,
          remaining: result.account.remaining,
          granted: granted,
        ),
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonManageBookings) {
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
        step: _PrivateFlowStep.selectingAdminBookingManagementAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseBookingManagementAction(),
        replyMarkup: _templates.adminBookingManagementKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonSubscriptionsAdmin || text.startsWith('/subscriptions'))) {
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
        step: _PrivateFlowStep.selectingAdminSubscriptionFilter,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionFilterPrompt(),
        replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonAdminTools) {
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
        step: _PrivateFlowStep.selectingAdminToolsAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseAdminToolsAction(),
        replyMarkup: _templates.adminToolsKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonAdminAnalytics || text.startsWith('/analytics'))) {
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
        step: _PrivateFlowStep.selectingAdminAnalyticsAction,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.chooseAdminAnalyticsAction(),
        replyMarkup: _templates.adminAnalyticsKeyboard(),
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonClientMenu) {
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
        _flowByUserId.remove(userId);
        _adminsInClientMode.add(userId);
      }
      await _sendAdminMessage(
        chatId,
        _templates.adminClientMenuOpened(),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: false,
          showReturnToAdminMenu: true,
        ),
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonBroadcast) {
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
      _cancelBroadcastMediaCollection(userId);
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.enteringAdminBroadcastText,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBroadcastPrompt(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminBroadcastText &&
        canRunAdminAction) {
      final broadcastPhoto = extractBroadcastPhoto(message);
      if (broadcastPhoto != null) {
        await _handleAdminBroadcastPhoto(
          chatId: chatId,
          userId: userId,
          flowState: flowState!,
          photo: broadcastPhoto,
        );
        return true;
      }
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminBroadcastText &&
        text != null &&
        !text.startsWith('/')) {
      _cancelBroadcastMediaCollection(userId);
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.selectingAdminBroadcastTarget,
        adminBroadcastText: text,
        adminBroadcastSourceMessages: const <BroadcastMessageRef>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminBroadcastPreview(text),
        replyMarkup: _templates.broadcastTargetKeyboard(hasGroup: _broadcastService.hasGroup),
      );
      return true;
    }

    if (userId != null &&
        text != null &&
        (text == '/broadcast_users' ||
            text == '/broadcast_outdoor' ||
            text == '/broadcast_group' ||
            text == '/broadcast_users_and_group' ||
            text == '/broadcast_cancel')) {
      if (!canRunAdminAction) {
        return false;
      }
      if (flowState?.step != _PrivateFlowStep.selectingAdminBroadcastTarget) {
        return false;
      }
      final broadcastContent = _broadcastContentFromFlow(flowState!);
      _cancelBroadcastMediaCollection(userId);
      _flowByUserId.remove(userId);

      if (text == '/broadcast_cancel' || broadcastContent == null) {
        await _sendAdminMessage(
          chatId,
          _templates.adminBroadcastCancelled(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }

      if (text == '/broadcast_group') {
        final sent = await _broadcastService.broadcastToGroup(broadcastContent);
        await _sendAdminMessage(
          chatId,
          _templates.adminBroadcastGroupOnly(groupSent: sent),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }

      if (text == '/broadcast_users' || text == '/broadcast_outdoor') {
        final audience = text == '/broadcast_outdoor'
            ? BroadcastAudience.outdoorPlus
            : BroadcastAudience.allStarted;
        final result = await _broadcastService.broadcastToUsers(
          broadcastContent,
          audience: audience,
        );
        await _sendAdminMessage(
          chatId,
          _templates.adminBroadcastSent(
            sent: result.sent,
            failed: result.failed,
            total: result.total,
            groupSent: false,
            outdoorPlus: audience == BroadcastAudience.outdoorPlus,
          ),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }

      if (text == '/broadcast_users_and_group') {
        final result = await _broadcastService.broadcastToUsersAndGroup(broadcastContent);
        await _sendAdminMessage(
          chatId,
          _templates.adminBroadcastSent(
            sent: result.sent,
            failed: result.failed,
            total: result.total,
            groupSent: _broadcastService.hasGroup,
          ),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
    }

    if (text != null && text == MessageTemplates.buttonAdminUserSearch) {
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
        step: _PrivateFlowStep.enteringAdminUserSearchQuery,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminUserSearchPrompt(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonAdminRecentActions) {
      if (!canRunAdminAction) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      await _sendRecentBotActions(
        chatId: chatId,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      );
      return true;
    }

    if (text != null && text == MessageTemplates.buttonAdminUserDialog) {
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
        step: _PrivateFlowStep.enteringAdminDialogUsernameQuery,
        availableTrainings: <TrainingInfo>[],
      );
      await _sendAdminMessage(
        chatId,
        _templates.adminUserDialogPrompt(),
        replyMarkup: _templates.simpleNavigationKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminUserSearchQuery &&
        text != null &&
        !text.startsWith('/')) {
      final bookings = await _bookingRepository.adminSearchBookingsByUsername(text);
      _flowByUserId.remove(userId);
      await _sendAdminMessage(
        chatId,
        _templates.adminUserSearchResults(
          bookings,
          query: text,
          now: _nowProvider(),
        ),
        replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
      );
      if (bookings.isNotEmpty) {
        final targetUserId = bookings.first.userId;
        final account = await _loyaltyService.account(targetUserId);
        final recent = await _loyaltyService.recentLedger(targetUserId);
        await _sendAdminMessage(
          chatId,
          _templates.loyaltyAdminOverview(
            userId: targetUserId,
            account: account,
            recent: recent,
          ),
        );
      }
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminDialogUsernameQuery &&
        text != null &&
        !text.startsWith('/')) {
      _flowByUserId.remove(userId);
      await _sendUserDialogByUsername(
        chatId: chatId,
        query: text,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminSubscriptionFilter &&
        text != null) {
      if (text == MessageTemplates.buttonSubscriptionsSearch) {
        _flowByUserId[userId] = flowState!.copyWith(
          step: _PrivateFlowStep.enteringAdminSubscriptionSearchQuery,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionSearchPrompt(),
          replyMarkup: _templates.simpleNavigationKeyboard(),
        );
        return true;
      }
      final filter = switch (text) {
        MessageTemplates.buttonSubscriptionsFilterActive => SubscriptionListFilter.active,
        MessageTemplates.buttonSubscriptionsFilterExpiring => SubscriptionListFilter.expiringSoon,
        MessageTemplates.buttonSubscriptionsFilterPending => SubscriptionListFilter.pending,
        MessageTemplates.buttonSubscriptionsFilterCancelled =>
          SubscriptionListFilter.cancelledOrRejected,
        _ => null,
      };
      if (filter == null) {
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionFilterPrompt(),
          replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
        );
        return true;
      }
      if (filter == SubscriptionListFilter.pending) {
        await _sendAdminSubscriptionPendingQueue(chatId: chatId);
        return true;
      }
      await _sendAdminSubscriptionsList(chatId: chatId, filter: filter);
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminSubscriptionSearchQuery &&
        text != null &&
        !text.startsWith('/')) {
      final items = await _subscriptionRepository.searchSubscriptions(
        text,
        now: _nowProvider(),
      );
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionsList(items, now: _nowProvider()),
        replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
      );
      _flowByUserId[userId] = const _PrivateFlowState(
        step: _PrivateFlowStep.selectingAdminSubscriptionFilter,
        availableTrainings: <TrainingInfo>[],
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate &&
        text != null) {
      final reason = switch (text) {
        MessageTemplates.buttonReasonNotConfirmed => 'Чек не подтвержден',
        MessageTemplates.buttonReasonWrongAmount => 'Сумма не совпадает',
        MessageTemplates.buttonReasonDuplicate => 'Дубликат заявки',
        _ => null,
      };
      if (reason == null) {
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionModerationReasonPrompt(
            isCancel:
                flowState?.subscriptionModerationAction == SubscriptionModerationAction.cancel,
          ),
          replyMarkup: _templates.subscriptionModerationReasonKeyboard(),
        );
        return true;
      }
      _flowByUserId[userId] = flowState!.copyWith(
        step: _PrivateFlowStep.enteringAdminSubscriptionReasonComment,
        subscriptionModerationReason: reason,
      );
      await _sendAdminMessage(
        chatId,
        _templates.subscriptionModerationCommentPrompt(),
        replyMarkup: _templates.subscriptionModerationCommentKeyboard(),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.enteringAdminSubscriptionReasonComment &&
        text != null &&
        !text.startsWith('/')) {
      final action = flowState?.subscriptionModerationAction;
      final requestId = flowState?.subscriptionModerationRequestId;
      final reason = flowState?.subscriptionModerationReason;
      if (action == null || requestId == null || reason == null) {
        _flowByUserId[userId] = const _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminSubscriptionFilter,
          availableTrainings: <TrainingInfo>[],
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionFilterPrompt(),
          replyMarkup: _templates.adminSubscriptionFilterKeyboard(),
        );
        return true;
      }
      final comment = text == MessageTemplates.buttonSkipComment
          ? null
          : text.trim().isEmpty
              ? null
              : text;
      await _applySubscriptionModerationAction(
        chatId: chatId,
        requestId: requestId,
        action: action,
        reason: reason,
        comment: comment,
        isAdmin: isAdmin,
      );
      _flowByUserId.remove(userId);
      return true;
    }

    return false;
  }

  Future<bool> _handleAdminOnboardingMediaCommands({
    required int chatId,
    required int? userId,
    required String? text,
    required Map<String, dynamic>? message,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
    required bool canRunAdminAction,
    required _PrivateFlowState? flowState,
  }) async {
    final inMediaFlow = flowState?.step == _PrivateFlowStep.selectingOnboardingMediaSlot ||
        flowState?.step == _PrivateFlowStep.awaitingOnboardingMediaFile;
    final openedHub = text == MessageTemplates.buttonOnboardingMedia;
    if (!openedHub && !inMediaFlow) {
      return false;
    }
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

    if (openedHub) {
      await _openOnboardingMediaHub(chatId: chatId, userId: userId);
      return true;
    }

    if (flowState?.step == _PrivateFlowStep.selectingOnboardingMediaSlot) {
      final slot = switch (text) {
        MessageTemplates.buttonOnboardingMediaVenue => OnboardingMediaSlot.venue,
        MessageTemplates.buttonOnboardingMediaCameAlone => OnboardingMediaSlot.cameAlone,
        _ => null,
      };
      if (slot == null) {
        await _openOnboardingMediaHub(chatId: chatId, userId: userId);
        return true;
      }
      await _openOnboardingMediaSlot(chatId: chatId, userId: userId, slot: slot);
      return true;
    }

    if (flowState?.step == _PrivateFlowStep.awaitingOnboardingMediaFile) {
      final slot = flowState?.onboardingMediaSlot;
      if (slot == null) {
        await _openOnboardingMediaHub(chatId: chatId, userId: userId);
        return true;
      }
      if (text == MessageTemplates.buttonOnboardingMediaClear) {
        await _onboardingRepository.clearOnboardingMedia(slot);
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.awaitingOnboardingMediaFile,
          availableTrainings: const <TrainingInfo>[],
          onboardingMediaSlot: slot,
        );
        await _sendAdminMessage(
          chatId,
          _templates.adminOnboardingMediaCleared(slot),
          replyMarkup: _templates.adminOnboardingMediaSlotKeyboard(hasMedia: false),
        );
        return true;
      }
      final extracted = extractOnboardingMedia(message);
      if (extracted == null) {
        if (text == MessageTemplates.buttonOnboardingMediaVenue ||
            text == MessageTemplates.buttonOnboardingMediaCameAlone) {
          final nextSlot = text == MessageTemplates.buttonOnboardingMediaVenue
              ? OnboardingMediaSlot.venue
              : OnboardingMediaSlot.cameAlone;
          await _openOnboardingMediaSlot(chatId: chatId, userId: userId, slot: nextSlot);
          return true;
        }
        await _sendAdminMessage(
          chatId,
          _templates.adminOnboardingMediaNeedFile(),
          replyMarkup: _templates.adminOnboardingMediaSlotKeyboard(
            hasMedia: await _onboardingRepository.getOnboardingMedia(slot) != null,
          ),
        );
        return true;
      }
      await _onboardingRepository.upsertOnboardingMedia(
        slot: slot,
        fileId: extracted.fileId,
        kind: extracted.kind,
        updatedAt: _nowProvider(),
        updatedByUserId: userId,
      );
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.awaitingOnboardingMediaFile,
        availableTrainings: const <TrainingInfo>[],
        onboardingMediaSlot: slot,
      );
      await _sendOnboardingMediaIfAny(chatId: chatId, slot: slot);
      await _sendAdminMessage(
        chatId,
        _templates.adminOnboardingMediaSaved(slot: slot, kind: extracted.kind),
        replyMarkup: _templates.adminOnboardingMediaSlotKeyboard(hasMedia: true),
      );
      return true;
    }
    return false;
  }

  Future<void> _openOnboardingMediaHub({
    required int chatId,
    required int userId,
  }) async {
    final assets = await _onboardingRepository.listOnboardingMedia();
    final venueSet = assets.any((item) => item.slot == OnboardingMediaSlot.venue);
    final cameAloneSet = assets.any((item) => item.slot == OnboardingMediaSlot.cameAlone);
    _flowByUserId[userId] = const _PrivateFlowState(
      step: _PrivateFlowStep.selectingOnboardingMediaSlot,
      availableTrainings: <TrainingInfo>[],
    );
    await _sendAdminMessage(
      chatId,
      _templates.adminOnboardingMediaHub(venueSet: venueSet, cameAloneSet: cameAloneSet),
      replyMarkup: _templates.adminOnboardingMediaHubKeyboard(),
    );
  }

  Future<void> _openOnboardingMediaSlot({
    required int chatId,
    required int userId,
    required OnboardingMediaSlot slot,
  }) async {
    final current = await _onboardingRepository.getOnboardingMedia(slot);
    _flowByUserId[userId] = _PrivateFlowState(
      step: _PrivateFlowStep.awaitingOnboardingMediaFile,
      availableTrainings: const <TrainingInfo>[],
      onboardingMediaSlot: slot,
    );
    if (current != null) {
      await _sendOnboardingMediaIfAny(chatId: chatId, slot: slot);
    }
    await _sendAdminMessage(
      chatId,
      _templates.adminOnboardingMediaSlotPrompt(slot: slot, current: current),
      replyMarkup: _templates.adminOnboardingMediaSlotKeyboard(hasMedia: current != null),
    );
  }
}
