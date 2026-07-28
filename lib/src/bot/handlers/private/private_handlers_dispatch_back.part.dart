part of '../private_handlers.dart';

extension PrivateHandlersDispatchBack on PrivateHandlers {
  Future<bool> _dispatchBackNavigation(PrivateRequestContext ctx) async {
    final chatId = ctx.chatId;
    final userId = ctx.userId;
    final text = ctx.text;
    final isAdmin = ctx.isAdmin;
    final showReturnToAdminMenu = ctx.showReturnToAdminMenu;
    final flowState = ctx.flowState;

    if (text == MessageTemplates.buttonBack) {
      if (userId == null) {
        return false;
      }
      switch (flowState?.step) {
        case _PrivateFlowStep.selectingScheduleCategory:
        case _PrivateFlowStep.viewingCoachingStaff:
        case _PrivateFlowStep.selectingBookingCategory:
        case _PrivateFlowStep.selectingBookFriendCategory:
        case _PrivateFlowStep.selectingParticipantsCategory:
        case _PrivateFlowStep.selectingPaymentsQueueCategory:
        case _PrivateFlowStep.viewingSubscriptionOverview:
        case _PrivateFlowStep.selectingBookingListSegment:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case _PrivateFlowStep.selectingEconomicSummaryPeriod:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminAnalyticsAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseAdminAnalyticsAction(),
            replyMarkup: _templates.adminAnalyticsKeyboard(),
            parseMode: 'HTML',
          );
          return true;
        case _PrivateFlowStep.selectingAdminAnalyticsAction:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminToolsAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseAdminToolsAction(),
            replyMarkup: _templates.adminToolsKeyboard(),
            parseMode: 'HTML',
          );
          return true;
        case _PrivateFlowStep.selectingBookFriendEvent:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingBookFriendCategory,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookFriendCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
            parseMode: 'HTML',
          );
          return true;
        case _PrivateFlowStep.enteringPartyParticipants:
          final items = flowState?.availableTrainings ?? const <TrainingInfo>[];
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingBookFriendEvent,
            partyParticipants: const <BookingParticipantDraft>[],
            partyTraining: null,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookFriendEvent(items),
            replyMarkup: _templates.bookingSelectionKeyboard(items),
            parseMode: 'HTML',
          );
          return true;
        case _PrivateFlowStep.selectingTrainerProfile:
          final trainers = flowState?.availableTrainers ?? const <TrainerInfo>[];
          _flowByUserId[userId] = flowState!.copyWith(step: _PrivateFlowStep.viewingCoachingStaff);
          await _sender.sendMessage(
            chatId,
            _templates.coachingStaff(trainers),
            replyMarkup: _templates.coachingStaffActionsKeyboard(),
            parseMode: 'HTML',
            disableWebPagePreview: true,
          );
          return true;
        case _PrivateFlowStep.selectingOutdoorDetailEvent:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingScheduleCategory,
            selectedOutdoorActivity: null,
            outdoorDetailType: null,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseScheduleCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingOutdoorDetailType:
          final selectedCategory = flowState?.selectedCategory;
          if (selectedCategory == null || !_isOutdoorCategory(selectedCategory)) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          final outdoorItems = _catalogService.outdoorItems(selectedCategory);
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingOutdoorDetailEvent,
            selectedOutdoorActivity: null,
            outdoorDetailType: null,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseOutdoorEventForDetails(selectedCategory),
            replyMarkup: _templates.outdoorSelectionKeyboard(outdoorItems),
          );
          return true;
        case _PrivateFlowStep.viewingScheduleCategory:
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingScheduleCategory);
          await _sender.sendMessage(
            chatId,
            _templates.chooseScheduleCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingTraining:
          final selectedCategory = flowState?.selectedCategory;
          if (selectedCategory != null && flowState?.bookingFromSchedulePreview == true) {
            _flowByUserId[userId] = flowState!.copyWith(
              step: _PrivateFlowStep.selectingScheduleCategory,
              availableTrainings: const <TrainingInfo>[],
            );
            await _sender.sendMessage(
              chatId,
              _templates.chooseScheduleCategory(),
              replyMarkup: _templates.categorySelectionKeyboard(),
            );
            return true;
          }
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingBookingCategory,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.paymentConfirmation:
          final items = flowState!.availableTrainings;
          _flowByUserId[userId] = flowState.copyWith(step: _PrivateFlowStep.selectingTraining);
          await _sender.sendMessage(
            chatId,
            _templates.chooseTrainingForBooking(items),
            replyMarkup: _templates.bookingSelectionKeyboard(items),
          );
          return true;
        case _PrivateFlowStep.enteringPromoCode:
          final activeBooking = flowState!.activeBooking;
          if (activeBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          _flowByUserId[userId] = flowState.copyWith(step: _PrivateFlowStep.paymentConfirmation);
          await _sender.sendMessage(
            chatId,
            _templates.paymentProofRequired(),
            replyMarkup: _templates.paymentConfirmationKeyboard(
              showStarterBonus: flowState.starterBonusOffered,
              showCancelBooking: _canCancelBookingByPolicy(activeBooking),
              showOutdoorPaymentTypeChoice: _shouldShowOutdoorPaymentTypeChoice(activeBooking),
              showPromoCodeEntry: _shouldShowPromoCodeEntry(activeBooking),
            ),
          );
          return true;
        case _PrivateFlowStep.confirmingSubscriptionPayment:
          final now = _nowProvider();
          final membership = await _subscriptionRepository.getMembership(
            userId,
            now: now,
          );
          final remainingProTrainings = await _proIncludedTrainingRemainingCount(
            userId: userId,
            membership: membership,
          );
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.viewingSubscriptionOverview,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.subscriptionOverview(
              membershipLevel: membership.level,
              activeUntil: membership.activeUntil,
              remainingProTrainings: remainingProTrainings,
            ),
            replyMarkup: _templates.subscriptionOverviewKeyboard(
              canApply: true,
              isRenewal: membership.level == MembershipLevel.pro,
            ),
            parseMode: 'HTML',
          );
          return true;
        case _PrivateFlowStep.selectingBookingAction:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingBookingToManage,
            selectedBooking: null,
          );
          await _sendMyBookingListPage(chatId: chatId, userId: userId);
          return true;
        case _PrivateFlowStep.selectingPendingPaymentBooking:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case _PrivateFlowStep.confirmingBookingCancel:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.bookingActions(selectedBooking),
            replyMarkup: _bookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingBookingToManage:
          await _openMyBookingListSegment(chatId: chatId, userId: userId);
          return true;
        case _PrivateFlowStep.selectingRescheduleTraining:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.bookingActions(selectedBooking),
            replyMarkup: _bookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingManagementAction:
        case _PrivateFlowStep.selectingAdminToolsAction:
        case _PrivateFlowStep.selectingAdminSubscriptionsAction:
        case _PrivateFlowStep.selectingAdminSubscriptionFilter:
        case _PrivateFlowStep.enteringAdminSubscriptionSearchQuery:
        case _PrivateFlowStep.selectingAdminSubscriptionReasonTemplate:
        case _PrivateFlowStep.enteringAdminSubscriptionReasonComment:
        case _PrivateFlowStep.enteringAdminBroadcastText:
        case _PrivateFlowStep.selectingAdminBroadcastTarget:
        case _PrivateFlowStep.enteringAdminUserSearchQuery:
          _cancelBroadcastMediaCollection(userId);
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingListSegment:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingManagementAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementAction(),
            replyMarkup: _templates.adminBookingManagementKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingListCategory:
          await _openAdminBookingListSegment(
            chatId: chatId,
            userId: userId,
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingFromList:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingAdminBookingListCategory,
            availableBookings: const <TrainingBooking>[],
            selectedBooking: null,
            adminBookingsPage: 0,
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingAction:
          _flowByUserId[userId] = flowState!.copyWith(
            step: _PrivateFlowStep.selectingAdminBookingFromList,
            selectedBooking: null,
          );
          await _sendAdminBookingListPage(chatId: chatId, userId: userId);
          return true;
        case _PrivateFlowStep.selectingAdminBookingEditField:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.adminBookingActions(selectedBooking),
            replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingAdminBookingEditStatus:
        case _PrivateFlowStep.enteringAdminBookingUsername:
        case _PrivateFlowStep.selectingAdminBookingEditEvent:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingEditField);
          await _sender.sendMessage(
            chatId,
            _templates.chooseAdminBookingEditField(selectedBooking),
            replyMarkup: _templates.adminBookingEditFieldsKeyboard(),
          );
          return true;
        case _PrivateFlowStep.confirmingAdminBookingDelete:
          final selectedBooking = flowState?.selectedBooking;
          if (selectedBooking == null) {
            _flowByUserId.remove(userId);
            await _sender.sendMessage(
              chatId,
              'Вернул в главное меню 👇',
              replyMarkup: _templates.privateMenuKeyboard(
                  isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
            );
            return true;
          }
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminBookingAction);
          await _sender.sendMessage(
            chatId,
            _templates.adminBookingActions(selectedBooking),
            replyMarkup: _adminBookingActionsKeyboard(selectedBooking),
          );
          return true;
        case _PrivateFlowStep.selectingAdminCreateCategory:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingManagementAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementAction(),
            replyMarkup: _templates.adminBookingManagementKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminCreateEvent:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminCreateCategory,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseCreateBookingCategory(),
            replyMarkup: _templates.categorySelectionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.enteringAdminCreateUsername:
          final trainings = flowState!.availableTrainings;
          _flowByUserId[userId] =
              flowState.copyWith(step: _PrivateFlowStep.selectingAdminCreateEvent);
          await _sender.sendMessage(
            chatId,
            _templates.chooseCreateBookingEvent(trainings),
            replyMarkup: _templates.bookingSelectionKeyboard(trainings),
          );
          return true;
        case _PrivateFlowStep.selectingAdminCreateStatus:
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.enteringAdminCreateUsername);
          await _sender.sendMessage(
            chatId,
            _templates.createBookingAskUsername(),
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case _PrivateFlowStep.confirmingAdminCreate:
          _flowByUserId[userId] =
              flowState!.copyWith(step: _PrivateFlowStep.selectingAdminCreateStatus);
          await _sender.sendMessage(
            chatId,
            _templates.chooseCreateBookingPaymentStatus(),
            replyMarkup: _templates.bookingPaymentStatusKeyboard(),
          );
          return true;
        case _PrivateFlowStep.selectingAdminClientNotificationPreference:
          _flowByUserId[userId] = const _PrivateFlowState(
            step: _PrivateFlowStep.selectingAdminBookingManagementAction,
            availableTrainings: <TrainingInfo>[],
          );
          await _sender.sendMessage(
            chatId,
            _templates.chooseBookingManagementAction(),
            replyMarkup: _templates.adminBookingAfterActionKeyboard(),
          );
          return true;
        case _PrivateFlowStep.onboardingWelcome:
        case _PrivateFlowStep.onboardingQuizGoal:
        case _PrivateFlowStep.onboardingQuizExperience:
        case _PrivateFlowStep.onboardingTrack:
        case _PrivateFlowStep.onboardingMap:
        case _PrivateFlowStep.awaitingTrainingFeedbackRating:
        case _PrivateFlowStep.awaitingTrainingFeedbackComment:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
        case null:
          await _sender.sendMessage(
            chatId,
            'Ты уже в главном меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(
                isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
          );
          return true;
      }
    }

    return false;
  }
}
