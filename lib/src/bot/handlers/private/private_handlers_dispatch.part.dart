part of '../private_handlers.dart';

extension PrivateHandlersDispatch on PrivateHandlers {
  Future<bool> handle(Map<String, dynamic> update) async {
    final context = extractPrivateMessageContext(update);
    if (context == null) {
      return false;
    }
    final chat = context.chat;
    if (chat['type']?.toString() != 'private') {
      return false;
    }
    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    final callbackQueryId = context.callbackQueryId;
    if (callbackQueryId != null) {
      try {
        await _sender.answerCallbackQuery(callbackQueryId);
      } on Object catch (error, stackTrace) {
        l.w('Failed to acknowledge callback query $callbackQueryId: $error', stackTrace);
      }
    }
    final text = context.text;
    final rawUserId = context.from?['id'];
    final userId = rawUserId is int ? rawUserId : null;
    final isConfiguredAdmin = userId != null && _adminUserIds.contains(userId);
    if (userId != null && text != null && text.startsWith('/start')) {
      _adminsInClientMode.remove(userId);
    }
    if (userId != null && text == MessageTemplates.buttonAdminMenu) {
      _adminsInClientMode.remove(userId);
    }
    final isAdmin = userId != null && isConfiguredAdmin && !_adminsInClientMode.contains(userId);
    final showReturnToAdminMenu = isConfiguredAdmin && !isAdmin;
    final username = context.from?['username']?.toString();
    final isYogaTrainer = userId == PrivateHandlers._yogaTrainerUserId;
    final isWhitelistedTrainer =
        userId != null && isTrainerBookingWhitelisted(userId: userId, username: username);
    final canRunAdminAction = _adminHandler.canRunAdminAction(isAdmin: isConfiguredAdmin);
    final canRunParticipantsAction = canRunAdminAction || isYogaTrainer || isWhitelistedTrainer;
    final flowState = userId == null ? null : _flowByUserId[userId];
    final paymentProof = extractPaymentProof(context.message);
    if (_isIgnorableServiceMessage(context.message)) {
      return true;
    }
    await _logInboundPrivateMessage(
      userId: userId,
      username: username,
      chatId: chatId,
      message: context.message,
      text: text,
    );
    if (userId != null && text == MessageTemplates.buttonMainMenu) {
      _cancelBroadcastMediaCollection(userId);
    }

    final handledStaticCommand = await _staticCommands.handle(
      text: text,
      chatId: chatId,
      userId: userId,
      isAdmin: isAdmin,
      showReturnToAdminMenu: showReturnToAdminMenu,
      flowByUserId: _flowByUserId,
      trainerDirectoryRepository: _trainerDirectoryRepository,
      onboardingRepository: _onboardingRepository,
      onboardingService: _onboardingService,
      sender: _sender,
      templates: _templates,
      canViewParticipantsList: canRunParticipantsAction,
      onStartCleanup: _handleStartCleanup,
      onEveryFifthUnlocked: _maybeNotifyEveryFifthRewardUnlocked,
      onPinWelcomeMessage: _tryPinWelcomeMessage,
      nowProvider: _nowProvider,
      onOpenBookingCategories: ({
        required int chatId,
        required int userId,
        required bool isAdmin,
        required bool canViewParticipantsList,
        required bool showReturnToAdminMenu,
      }) async {
        _flowByUserId[userId] = const PrivateFlowState(
          step: PrivateFlowStep.selectingBookingCategory,
          availableTrainings: <TrainingInfo>[],
        );
        await _sender.sendMessage(
          chatId,
          _templates.chooseBookingCategory(),
          replyMarkup: _templates.categorySelectionKeyboard(),
        );
      },
      username: username,
    );
    if (handledStaticCommand) {
      return true;
    }

    if (userId != null && text != null) {
      final handledOnboarding = await _handleOnboardingFlow(
        text: text,
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
        canViewParticipantsList: canRunParticipantsAction,
      );
      if (handledOnboarding) {
        return true;
      }
      final handledFeedback = await _handleTrainingFeedbackFlow(
        text: text,
        chatId: chatId,
        userId: userId,
        isAdmin: isAdmin,
        showReturnToAdminMenu: showReturnToAdminMenu,
      );
      if (handledFeedback) {
        return true;
      }
    }

    final request = PrivateRequestContext(
      chatId: chatId,
      userId: userId,
      text: text,
      isAdmin: isAdmin,
      isConfiguredAdmin: isConfiguredAdmin,
      showReturnToAdminMenu: showReturnToAdminMenu,
      canRunAdminAction: canRunAdminAction,
      canRunParticipantsAction: canRunParticipantsAction,
      isYogaTrainer: isYogaTrainer,
      isWhitelistedTrainer: isWhitelistedTrainer,
      flowState: flowState,
      paymentProof: paymentProof,
      username: username,
      message: context.message,
    );

    if (await _dispatchBackNavigation(request)) {
      return true;
    }
    if (await _dispatchUserCommands(request)) {
      return true;
    }
    if (await _dispatchAdminCommands(request)) {
      return true;
    }

    await _sender.sendMessage(
      chatId,
      _templates.privateFallback(),
      replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin, showReturnToAdminMenu: showReturnToAdminMenu),
    );
    return true;
  }
}
