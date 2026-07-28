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

      if (text == '/broadcast_users') {
        final result = await _broadcastService.broadcastToUsers(broadcastContent);
        await _sendAdminMessage(
          chatId,
          _templates.adminBroadcastSent(
            sent: result.sent,
            failed: result.failed,
            total: result.total,
            groupSent: false,
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
}
