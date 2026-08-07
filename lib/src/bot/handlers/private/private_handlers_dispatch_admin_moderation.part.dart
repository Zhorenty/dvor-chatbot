part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdminModeration on PrivateHandlers {
  Future<bool> _dispatchAdminModerationCommands(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final canRunAdminAction = ctx.canRunAdminAction;
    final username = ctx.username;

    if (text != null &&
        (text.startsWith('/approve_payment') ||
            text.startsWith('/approve_partial_payment') ||
            text.startsWith('/reject_payment'))) {
      if (!isAdmin) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId == null) {
        await _sendAdminMessage(
          chatId,
          _templates.paymentActionUsage(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final status = switch (true) {
        _ when text.startsWith('/approve_partial_payment') => BookingStatus.partialPaid,
        _ when text.startsWith('/approve_payment') => BookingStatus.paid,
        _ => BookingStatus.paymentRejected,
      };
      final reviewResult = await _bookingRepository.reviewSubmittedPayment(
        bookingId: bookingId,
        status: status,
      );
      final booking = reviewResult.booking;
      final queueCounters = await _paymentReviewService.queueCounters();
      final category = booking == null ? null : _catalogService.categoryForBooking(booking);
      final remainingInCategory =
          category == null ? 0 : (await _paymentReviewService.queueByCategory(category)).length;
      if (reviewResult.outcome == PaymentReviewOutcome.success && booking != null) {
        await _notifyAboutPaymentReview(
          booking,
          moderatorUserId: userId,
          moderatorUsername: username,
        );
        await _maybeNotifyGroupAboutCapacity(
          _trainingInfoFromBooking(booking),
          bookingStatus: booking.status,
        );
      }
      final successInlineMarkup = reviewResult.outcome == PaymentReviewOutcome.success &&
              remainingInCategory > 0 &&
              category != null
          ? _templates.nextPaymentInQueueInlineKeyboard(
              category: category,
              remaining: remainingInCategory,
            )
          : reviewResult.outcome == PaymentReviewOutcome.success
              ? _templates.openPaymentsQueueInlineKeyboard(total: queueCounters.total)
              : null;
      if (ctx.callbackMessage != null) {
        // editMessageReplyMarkup accepts only inline keyboards.
        await _refreshCallbackMessageMarkup(
          ctx: ctx,
          replyMarkup:
              successInlineMarkup ?? const <String, Object?>{'inline_keyboard': <Object>[]},
        );
      }
      await _sendAdminMessage(
        chatId,
        switch (reviewResult.outcome) {
          PaymentReviewOutcome.success => _templates.paymentReviewResultWithNextStep(
              booking: booking!,
              remaining: remainingInCategory,
            ),
          PaymentReviewOutcome.notFound => _templates.bookingNotFound(bookingId),
          PaymentReviewOutcome.invalidStatus => _templates.paymentAlreadyReviewed(bookingId),
        },
        replyMarkup: successInlineMarkup ??
            _templates.privateMenuKeyboard(
              isAdmin: isAdmin,
              showReturnToAdminMenu: showReturnToAdminMenu,
            ),
      );
      return true;
    }

    if (text != null && text.startsWith('/payments_queue_next')) {
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
      final categoryKey = parts.length >= 2 ? parts[1].trim().toLowerCase() : '';
      final category = switch (categoryKey) {
        'trainings' => ActivityCategory.trainings,
        'hikes' => ActivityCategory.hikes,
        'trails' => ActivityCategory.trails,
        _ => null,
      };
      if (category == null) {
        final counters = await _paymentReviewService.queueCounters();
        await _sendAdminMessage(
          chatId,
          _templates.choosePaymentsQueueCategory(),
          replyMarkup: _templates.paymentsQueueCategorySelectionKeyboard(
            trainings: counters.trainings,
            hikes: counters.hikes,
            trails: counters.trails,
          ),
        );
        return true;
      }
      await _sendPaymentsQueueByCategory(
        chatId: chatId,
        category: category,
        isAdmin: isAdmin,
      );
      return true;
    }

    if (text != null &&
        (text.startsWith('/approve_subscription') ||
            text.startsWith('/reject_subscription') ||
            text.startsWith('/cancel_subscription'))) {
      if (userId == null) {
        return false;
      }
      if (!isAdmin) {
        await _sendAdminMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      final requestId = _updateRouter.parseCommandId(text);
      if (requestId == null) {
        await _sendAdminMessage(
          chatId,
          'Используй команды:\n'
          '<code>/approve_subscription &lt;id&gt;</code>\n'
          '<code>/reject_subscription &lt;id&gt;</code>\n'
          '<code>/cancel_subscription &lt;id&gt;</code>',
          replyMarkup: _templates.privateMenuKeyboard(
              isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
        );
        return true;
      }
      if (text.startsWith('/cancel_subscription')) {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate,
          availableTrainings: const <TrainingInfo>[],
          subscriptionModerationAction: SubscriptionModerationAction.cancel,
          subscriptionModerationRequestId: requestId,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionModerationReasonPrompt(isCancel: true),
          replyMarkup: _templates.subscriptionModerationReasonKeyboard(),
        );
        return true;
      }
      if (text.startsWith('/reject_subscription')) {
        _flowByUserId[userId] = _PrivateFlowState(
          step: _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate,
          availableTrainings: const <TrainingInfo>[],
          subscriptionModerationAction: SubscriptionModerationAction.reject,
          subscriptionModerationRequestId: requestId,
        );
        await _sendAdminMessage(
          chatId,
          _templates.subscriptionModerationReasonPrompt(isCancel: false),
          replyMarkup: _templates.subscriptionModerationReasonKeyboard(),
        );
        return true;
      }
      await _applySubscriptionModerationAction(
        chatId: chatId,
        requestId: requestId,
        action: SubscriptionModerationAction.reject,
        approveDirectly: true,
        reason: null,
        comment: null,
        isAdmin: isAdmin,
      );
      return true;
    }

    return false;
  }
}
