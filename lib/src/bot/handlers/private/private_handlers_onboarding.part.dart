part of '../private_handlers.dart';

extension PrivateHandlersOnboardingOps on PrivateHandlers {
  Future<void> _maybeMarkOnboardingActivation(int userId) async {
    final marked = await _onboardingService.tryMarkActivation(
      userId,
      activatedAt: _nowProvider(),
    );
    if (!marked) {
      return;
    }
    try {
      await _sender.sendMessage(
        userId,
        _templates.onboardingActivationSuccess(),
        replyMarkup: _templates.onboardingActivationKeyboard(),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to send onboarding activation message to $userId: $error', stackTrace);
    }
  }

  Future<bool> _handleOnboardingFlow({
    required String text,
    required int chatId,
    required int userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
    required bool canViewParticipantsList,
  }) async {
    if (text == MessageTemplates.buttonOnboardingNeedHelp) {
      await _sender.sendMessage(
        chatId,
        _templates.onboardingNeedHelp(),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }
    if (text == MessageTemplates.buttonOnboardingNeedMoreTime) {
      await _onboardingService.snooze(
        userId,
        until: _nowProvider().toUtc().add(const Duration(hours: 48)),
      );
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        _templates.onboardingSnoozeAck(),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          canViewParticipantsList: canViewParticipantsList,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      return true;
    }

    final step = _flowByUserId[userId]?.step;
    if (step == PrivateFlowStep.onboardingWelcome ||
        (step == null && text == MessageTemplates.buttonOnboardingContinue)) {
      if (text != MessageTemplates.buttonOnboardingContinue &&
          text != MessageTemplates.buttonOnboardingSkipQuiz) {
        if (step != PrivateFlowStep.onboardingWelcome) {
          return false;
        }
      }
      if (text == MessageTemplates.buttonOnboardingSkipQuiz) {
        await _onboardingService.applyDefaultTrackIfNeeded(userId);
        await _sendOnboardingMap(
          chatId: chatId,
          userId: userId,
        );
        return true;
      }
      if (text == MessageTemplates.buttonOnboardingContinue ||
          step == PrivateFlowStep.onboardingWelcome) {
        if (text != MessageTemplates.buttonOnboardingContinue &&
            step == PrivateFlowStep.onboardingWelcome) {
          return false;
        }
        _flowByUserId[userId] = const PrivateFlowState(
          step: PrivateFlowStep.onboardingQuizGoal,
          availableTrainings: <TrainingInfo>[],
        );
        await _onboardingRepository.updateOnboardingProgress(
          userId: userId,
          phase: OnboardingPhase.phase1Quiz,
          step: OnboardingStep.quizGoal,
        );
        await _sender.sendMessage(
          chatId,
          _templates.onboardingQuizGoal(),
          replyMarkup: _templates.onboardingQuizGoalKeyboard(),
        );
        return true;
      }
    }

    if (step == PrivateFlowStep.onboardingQuizGoal) {
      if (text == MessageTemplates.buttonOnboardingSkipQuiz) {
        await _onboardingService.applyDefaultTrackIfNeeded(userId);
        await _sendOnboardingMap(chatId: chatId, userId: userId);
        return true;
      }
      final goal = switch (text) {
        MessageTemplates.buttonQuizGoalForm => OnboardingQuizGoal.formStrength,
        MessageTemplates.buttonQuizGoalEndurance => OnboardingQuizGoal.enduranceRun,
        MessageTemplates.buttonQuizGoalYoga => OnboardingQuizGoal.yogaRecovery,
        MessageTemplates.buttonQuizGoalOutdoor => OnboardingQuizGoal.outdoorHikes,
        MessageTemplates.buttonQuizGoalUnknown => OnboardingQuizGoal.unknown,
        _ => null,
      };
      if (goal == null) {
        await _sender.sendMessage(
          chatId,
          _templates.onboardingQuizGoal(),
          replyMarkup: _templates.onboardingQuizGoalKeyboard(),
        );
        return true;
      }
      await _onboardingService.saveQuizGoal(userId, goal);
      _flowByUserId[userId] = const PrivateFlowState(
        step: PrivateFlowStep.onboardingQuizExperience,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.onboardingQuizExperience(),
        replyMarkup: _templates.onboardingQuizExperienceKeyboard(),
      );
      return true;
    }

    if (step == PrivateFlowStep.onboardingQuizExperience) {
      final experience = switch (text) {
        MessageTemplates.buttonQuizExpBeginner => OnboardingQuizExperience.beginner,
        MessageTemplates.buttonQuizExpReturning => OnboardingQuizExperience.returning,
        MessageTemplates.buttonQuizExpRegular => OnboardingQuizExperience.regular,
        _ => null,
      };
      if (experience == null) {
        await _sender.sendMessage(
          chatId,
          _templates.onboardingQuizExperience(),
          replyMarkup: _templates.onboardingQuizExperienceKeyboard(),
        );
        return true;
      }
      await _onboardingService.saveQuizExperience(userId, experience);
      _flowByUserId[userId] = const PrivateFlowState(
        step: PrivateFlowStep.onboardingTrack,
        availableTrainings: <TrainingInfo>[],
      );
      await _sender.sendMessage(
        chatId,
        _templates.onboardingTrackChoice(),
        replyMarkup: _templates.onboardingTrackKeyboard(),
      );
      return true;
    }

    if (step == PrivateFlowStep.onboardingTrack) {
      final track = switch (text) {
        MessageTemplates.buttonTrackOneOff => OnboardingTrack.oneOff,
        MessageTemplates.buttonTrackOutdoor => OnboardingTrack.outdoor,
        _ => null,
      };
      if (track == null) {
        await _sender.sendMessage(
          chatId,
          _templates.onboardingTrackChoice(),
          replyMarkup: _templates.onboardingTrackKeyboard(),
        );
        return true;
      }
      await _onboardingService.saveTrack(userId, track);
      await _sendOnboardingMap(chatId: chatId, userId: userId);
      return true;
    }

    if (step == PrivateFlowStep.onboardingMap) {
      if (text == MessageTemplates.buttonBookTraining ||
          text == MessageTemplates.buttonCategoryHikes) {
        final category = await _onboardingService.preferredCategory(userId);
        await _openBookingByCategory(
          chatId: chatId,
          userId: userId,
          category: category,
          isAdmin: isAdmin,
          fromSchedulePreview: false,
        );
        return true;
      }
    }

    return false;
  }

  Future<void> _sendOnboardingMap({
    required int chatId,
    required int userId,
  }) async {
    final starterBonusAvailable = await _onboardingRepository.hasStarterBonusAvailable(userId);
    final state = await _onboardingRepository.getOnboardingState(userId);
    final outdoor = state?.selectedTrack == OnboardingTrack.outdoor;
    _flowByUserId[userId] = const PrivateFlowState(
      step: PrivateFlowStep.onboardingMap,
      availableTrainings: <TrainingInfo>[],
    );
    await _onboardingService.markMapShown(userId);
    await _sender.sendMessage(
      chatId,
      _templates.onboardingClubMap(starterBonusAvailable: starterBonusAvailable),
      replyMarkup: _templates.onboardingMapCtaKeyboard(outdoorTrack: outdoor),
    );
  }

  Future<bool> _handleTrainingFeedbackFlow({
    required String text,
    required int chatId,
    required int userId,
    required bool isAdmin,
    required bool showReturnToAdminMenu,
  }) async {
    if (text.startsWith('/feedback_skip ')) {
      final bookingId = _updateRouter.parseCommandId(text);
      if (bookingId != null) {
        await _ensureTrainingFeedbackFlow(userId: userId, bookingId: bookingId);
        return _handleTrainingFeedbackFlow(
          text: MessageTemplates.buttonFeedbackSkip,
          chatId: chatId,
          userId: userId,
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        );
      }
    }
    if (text.startsWith('/feedback_rate ')) {
      final parts = text.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final bookingId = int.tryParse(parts[1]);
        final rating = TrainingFeedbackRatingX.tryParse(parts[2]);
        if (bookingId != null && rating != null) {
          await _ensureTrainingFeedbackFlow(userId: userId, bookingId: bookingId);
          final ratingText = switch (rating) {
            TrainingFeedbackRating.great => MessageTemplates.buttonFeedbackGreat,
            TrainingFeedbackRating.ok => MessageTemplates.buttonFeedbackOk,
            TrainingFeedbackRating.weak => MessageTemplates.buttonFeedbackWeak,
            TrainingFeedbackRating.skipped => MessageTemplates.buttonFeedbackSkip,
          };
          return _handleTrainingFeedbackFlow(
            text: ratingText,
            chatId: chatId,
            userId: userId,
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          );
        }
      }
    }

    final flow = _flowByUserId[userId];
    final step = flow?.step;
    if (step == PrivateFlowStep.awaitingTrainingFeedbackRating) {
      final rating = switch (text) {
        MessageTemplates.buttonFeedbackGreat => TrainingFeedbackRating.great,
        MessageTemplates.buttonFeedbackOk => TrainingFeedbackRating.ok,
        MessageTemplates.buttonFeedbackWeak => TrainingFeedbackRating.weak,
        MessageTemplates.buttonFeedbackSkip => TrainingFeedbackRating.skipped,
        _ => null,
      };
      if (rating == null) {
        final bookingId = flow?.feedbackBookingId;
        await _sender.sendMessage(
          chatId,
          _templates.trainingFeedbackAsk(
            trainingTitle: flow?.feedbackTrainingTitle ?? 'тренировка',
          ),
          replyMarkup: bookingId == null
              ? _templates.trainingFeedbackKeyboard()
              : _templates.trainingFeedbackInlineKeyboard(bookingId),
        );
        return true;
      }
      final bookingId = flow?.feedbackBookingId;
      final sessionKey = flow?.feedbackSessionKey;
      if (bookingId == null || sessionKey == null) {
        _flowByUserId.remove(userId);
        return true;
      }
      await _onboardingRepository.submitTrainingFeedback(
        bookingId: bookingId,
        sessionKey: sessionKey,
        rating: rating,
        submittedAt: _nowProvider(),
      );
      if (rating == TrainingFeedbackRating.skipped) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.trainingFeedbackThanks(),
          replyMarkup: _templates.privateMenuKeyboard(
            isAdmin: isAdmin,
            showReturnToAdminMenu: showReturnToAdminMenu,
          ),
        );
        await _notifyAdminAboutTrainingFeedback(
          trainingTitle: flow?.feedbackTrainingTitle ?? 'Тренировка',
          rating: rating,
        );
        return true;
      }
      _flowByUserId[userId] = flow!.copyWith(
        step: PrivateFlowStep.awaitingTrainingFeedbackComment,
        feedbackRating: rating,
      );
      await _sender.sendMessage(
        chatId,
        _templates.trainingFeedbackCommentAsk(),
        replyMarkup: _templates.trainingFeedbackCommentKeyboard(),
      );
      return true;
    }

    if (step == PrivateFlowStep.awaitingTrainingFeedbackComment) {
      final bookingId = flow?.feedbackBookingId;
      final sessionKey = flow?.feedbackSessionKey;
      final trainingTitle = flow?.feedbackTrainingTitle ?? 'Тренировка';
      final rating = flow?.feedbackRating ?? TrainingFeedbackRating.ok;
      if (bookingId == null || sessionKey == null) {
        _flowByUserId.remove(userId);
        return true;
      }
      String? comment;
      if (text != MessageTemplates.buttonSkipComment && text != MessageTemplates.buttonMainMenu) {
        comment = text.trim();
        if (comment.isEmpty) {
          comment = null;
        }
      }
      await _onboardingRepository.submitTrainingFeedback(
        bookingId: bookingId,
        sessionKey: sessionKey,
        rating: rating,
        submittedAt: _nowProvider(),
        comment: comment,
      );
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        _templates.trainingFeedbackThanks(),
        replyMarkup: _templates.privateMenuKeyboard(
          isAdmin: isAdmin,
          showReturnToAdminMenu: showReturnToAdminMenu,
        ),
      );
      await _notifyAdminAboutTrainingFeedback(
        trainingTitle: trainingTitle,
        rating: rating,
        comment: comment,
      );
      return true;
    }

    return false;
  }

  Future<void> _notifyAdminAboutTrainingFeedback({
    required String trainingTitle,
    required TrainingFeedbackRating rating,
    String? comment,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sendAdminMessage(
        adminChatId,
        _templates.trainingFeedbackAdminNotification(
          trainingTitle: trainingTitle,
          rating: rating,
          comment: comment,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin about training feedback: $error', stackTrace);
    }
  }

  Future<void> _handleStartCleanup(int userId) async {
    try {
      final welcome = await _onboardingRepository.markStartedAndGetPendingWelcome(
        userId,
        startedAt: _nowProvider(),
      );
      if (welcome == null) {
        return;
      }
      await _sender.deleteMessage(
        welcome.groupChatId,
        messageId: welcome.welcomeMessageId,
      );
      await _onboardingRepository.markWelcomeDeleted(
        userId: userId,
        deletedAt: _nowProvider(),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to cleanup group welcome on /start for user $userId: $error', stackTrace);
    }
  }

  Future<void> _tryPinWelcomeMessage({
    required int chatId,
    required int messageId,
  }) async {
    try {
      await _sender.pinMessage(chatId, messageId: messageId);
    } on Object catch (error, stackTrace) {
      l.w(
        'Failed to pin welcome message in private chat $chatId (message_id=$messageId): $error',
        stackTrace,
      );
    }
  }

  bool _isIgnorableServiceMessage(Map<String, dynamic>? message) {
    if (message == null) {
      return false;
    }
    // Telegram sends a service update after pinning; it should not trigger fallback.
    return message['pinned_message'] is Map;
  }

  Future<void> _logInboundPrivateMessage({
    required int? userId,
    required String? username,
    required int chatId,
    required Map<String, dynamic>? message,
    required String? text,
  }) async {
    if (userId == null || message == null || chatId <= 0) {
      return;
    }
    final messageId = message['message_id'];
    final contentType = _inboundContentType(message);
    final preview =
        text?.trim().isNotEmpty == true ? text!.trim() : message['caption']?.toString().trim();
    try {
      await _conversationLogRepository.append(
        direction: ConversationDirection.inbound,
        peerUserId: userId,
        peerUsername: username,
        chatId: chatId,
        telegramMessageId: messageId is int ? messageId : null,
        contentType: contentType,
        textPreview: preview?.isEmpty == true ? null : preview,
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to append inbound conversation log: $error', stackTrace);
    }
  }

  ConversationContentType _inboundContentType(Map<String, dynamic> message) {
    if (message['text'] != null) {
      return ConversationContentType.text;
    }
    if (message['photo'] is List && (message['photo'] as List).isNotEmpty) {
      return ConversationContentType.photo;
    }
    if (message['document'] is Map) {
      return ConversationContentType.document;
    }
    return ConversationContentType.other;
  }

  Future<void> _ensureTrainingFeedbackFlow({
    required int userId,
    required int bookingId,
  }) async {
    final flow = _flowByUserId[userId];
    if (flow?.step == PrivateFlowStep.awaitingTrainingFeedbackRating &&
        flow?.feedbackBookingId == bookingId) {
      return;
    }
    final request = await _onboardingRepository.getTrainingFeedbackRequest(bookingId);
    if (request != null && request.userId == userId) {
      beginTrainingFeedbackFlow(
        userId: userId,
        bookingId: request.bookingId,
        sessionKey: request.sessionKey,
        trainingTitle: request.trainingTitle,
      );
      return;
    }
    final booking = await _findUserBooking(userId, bookingId);
    if (booking != null) {
      beginTrainingFeedbackFlow(
        userId: userId,
        bookingId: booking.id,
        sessionKey: booking.trainingKey,
        trainingTitle: booking.trainingTitle,
      );
    }
  }
}
