import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class PrivateHandlers {
  PrivateHandlers({
    required MessageSender sender,
    required TrainingScheduleRepository scheduleRepository,
    required BookingRepository bookingRepository,
    required MessageTemplates templates,
    required Set<int> adminUserIds,
    int? adminChatId,
  })  : _sender = sender,
        _scheduleRepository = scheduleRepository,
        _bookingRepository = bookingRepository,
        _templates = templates,
        _adminUserIds = adminUserIds,
        _adminChatId = adminChatId;

  final MessageSender _sender;
  final TrainingScheduleRepository _scheduleRepository;
  final BookingRepository _bookingRepository;
  final MessageTemplates _templates;
  final Set<int> _adminUserIds;
  final int? _adminChatId;
  final Map<int, _PrivateFlowState> _flowByUserId = <int, _PrivateFlowState>{};

  Future<bool> handle(Map<String, dynamic> update) async {
    final context = _extractContext(update);
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
    final text = context.text;
    final rawUserId = context.from?['id'];
    final userId = rawUserId is int ? rawUserId : null;
    final isAdmin = userId != null && _adminUserIds.contains(userId);
    final flowState = userId == null ? null : _flowByUserId[userId];
    final paymentProof = _extractPaymentProof(context.message);

    if (text != null && text.startsWith('/start')) {
      if (userId != null) {
        _flowByUserId.remove(userId);
      }
      await _sender.sendMessage(
        chatId,
        _templates.privateWelcome(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        (text.startsWith('/trainings') || text == MessageTemplates.buttonTrainings)) {
      final upcoming = _scheduleRepository.upcoming();
      if (userId != null) {
        _flowByUserId.remove(userId);
      }
      await _sender.sendMessage(
        chatId,
        _templates.trainings(upcoming),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonHelp) {
      if (userId != null) {
        _flowByUserId.remove(userId);
      }
      await _sender.sendMessage(
        chatId,
        _templates.privateHelp(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonMainMenu) {
      if (userId == null) {
        return false;
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        'Главное меню 👇',
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonBack) {
      if (userId == null) {
        return false;
      }
      switch (flowState?.step) {
        case _PrivateFlowStep.selectingTraining:
          _flowByUserId.remove(userId);
          await _sender.sendMessage(
            chatId,
            'Вернул в главное меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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
        case null:
          await _sender.sendMessage(
            chatId,
            'Ты уже в главном меню 👇',
            replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
          );
          return true;
      }
    }

    if (text != null && (text == MessageTemplates.buttonBookTraining || text.startsWith('/book'))) {
      if (userId == null) {
        return false;
      }
      final upcoming = _scheduleRepository.upcoming(limit: 8);
      if (upcoming.isEmpty) {
        _flowByUserId.remove(userId);
        await _sender.sendMessage(
          chatId,
          _templates.noUpcomingForBooking(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      _flowByUserId[userId] = _PrivateFlowState(
        step: _PrivateFlowStep.selectingTraining,
        availableTrainings: upcoming,
      );
      await _sender.sendMessage(
        chatId,
        _templates.chooseTrainingForBooking(upcoming),
        replyMarkup: _templates.bookingSelectionKeyboard(upcoming),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.selectingTraining &&
        text != null &&
        !text.startsWith('/')) {
      final index = _parseTrainingSelectionIndex(text);
      if (index == null || index < 1 || index > flowState!.availableTrainings.length) {
        await _sender.sendMessage(
          chatId,
          'Не понял выбор. Нажми кнопку с нужной тренировкой 👇',
          replyMarkup: _templates.bookingSelectionKeyboard(flowState!.availableTrainings),
        );
        return true;
      }
      final result = await _bookingRepository.createPendingBooking(
        userId: userId,
        userUsername: context.from?['username']?.toString(),
        training: flowState.availableTrainings[index - 1],
      );
      _flowByUserId[userId] = flowState.copyWith(
        step: _PrivateFlowStep.paymentConfirmation,
        activeBooking: result.booking,
      );
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreated(result.booking)
            : _templates.bookingAlreadyExists(result.booking),
        replyMarkup: _templates.paymentConfirmationKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonMyBookings || text.startsWith('/my_bookings'))) {
      if (userId == null) {
        return false;
      }
      final bookings = await _bookingRepository.listUserBookings(userId);
      await _sender.sendMessage(
        chatId,
        _templates.myBookings(bookings),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (userId != null &&
        flowState?.step == _PrivateFlowStep.paymentConfirmation &&
        paymentProof != null) {
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        note: paymentProof.caption,
      );
      if (booking != null) {
        await _notifyAdminAboutPaymentSubmitted(booking, paymentProof: paymentProof);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        booking == null ? _templates.noPendingPayment() : _templates.paymentSubmitted(booking),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonSubmitPayment || text.startsWith('/paid'))) {
      if (userId == null) {
        return false;
      }
      if (flowState?.step != _PrivateFlowStep.paymentConfirmation) {
        await _sender.sendMessage(
          chatId,
          'Сначала выбери тренировку через `${MessageTemplates.buttonBookTraining}`.',
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      await _sender.sendMessage(
        chatId,
        _templates.paymentProofRequired(),
        replyMarkup: _templates.paymentConfirmationKeyboard(),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonRefreshSchedule || text.startsWith('/refresh_schedule'))) {
      if (!isAdmin) {
        await _sender.sendMessage(
          chatId,
          _templates.scheduleRefreshForbidden(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final refreshOk = await _scheduleRepository.refresh(force: true);
      await _sender.sendMessage(
        chatId,
        refreshOk ? _templates.scheduleRefreshDone() : _templates.scheduleRefreshFailed(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonPaymentsQueue || text.startsWith('/payments_queue'))) {
      if (!isAdmin) {
        await _sender.sendMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final queue = await _bookingRepository.listByStatus(
        BookingStatus.paymentSubmitted,
      );
      await _sender.sendMessage(
        chatId,
        _templates.paymentsQueue(queue),
        replyMarkup: _templates.paymentsQueueInlineKeyboard(queue),
      );
      return true;
    }

    if (text != null &&
        (text == MessageTemplates.buttonParticipantsList ||
            text.startsWith('/participants_list'))) {
      if (!isAdmin) {
        await _sender.sendMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final upcoming = _scheduleRepository.upcoming(limit: 12);
      final keys = upcoming.map((item) => item.sessionKey).toSet();
      final bookings = await _bookingRepository.listByTrainingKeys(keys);
      final byTraining = <String, List<TrainingBooking>>{};
      for (final booking in bookings) {
        byTraining.putIfAbsent(booking.trainingKey, () => <TrainingBooking>[]).add(booking);
      }
      await _sender.sendMessage(
        chatId,
        _templates.trainingParticipants(
          trainings: upcoming,
          bookingsByTrainingKey: byTraining,
        ),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text != null &&
        (text.startsWith('/approve_payment') || text.startsWith('/reject_payment'))) {
      if (!isAdmin) {
        await _sender.sendMessage(
          chatId,
          _templates.adminOnlyAction(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final bookingId = _parseCommandId(text);
      if (bookingId == null) {
        await _sender.sendMessage(
          chatId,
          _templates.paymentActionUsage(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final status =
          text.startsWith('/approve_payment') ? BookingStatus.paid : BookingStatus.paymentRejected;
      final booking = await _bookingRepository.updateStatus(bookingId, status);
      if (booking != null) {
        await _notifyAboutPaymentReview(booking, moderatorUserId: userId);
      }
      await _sender.sendMessage(
        chatId,
        booking == null
            ? _templates.bookingNotFound(bookingId)
            : _templates.bookingStatusUpdated(booking),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    return false;
  }

  int? _parseCommandId(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    return int.tryParse(parts[1]);
  }

  int? _parseTrainingSelectionIndex(String text) {
    final trimmed = text.trim();
    final direct = int.tryParse(trimmed);
    if (direct != null) {
      return direct;
    }
    final prefixed = RegExp(r'^🎯\s*(\d+)\.').firstMatch(trimmed);
    if (prefixed != null) {
      return int.tryParse(prefixed.group(1)!);
    }
    final numbered = RegExp(r'^(\d+)\.').firstMatch(trimmed);
    if (numbered != null) {
      return int.tryParse(numbered.group(1)!);
    }
    return null;
  }

  _PaymentProof? _extractPaymentProof(Map<String, dynamic>? message) {
    if (message == null) {
      return null;
    }
    final messageId = message['message_id'];
    final chatRaw = message['chat'];
    if (messageId is! int || chatRaw is! Map) {
      return null;
    }
    final chat = Map<String, dynamic>.from(chatRaw);
    final fromChatId = chat['id'];
    if (fromChatId is! int) {
      return null;
    }
    final hasDocument = message['document'] is Map;
    final hasPhoto = message['photo'] is List && (message['photo'] as List).isNotEmpty;
    if (!hasDocument && !hasPhoto) {
      return null;
    }
    return _PaymentProof(
      fromChatId: fromChatId,
      messageId: messageId,
      caption: message['caption']?.toString().trim(),
    );
  }

  _PrivateMessageContext? _extractContext(Map<String, dynamic> update) {
    final callback = update['callback_query'];
    if (callback is Map) {
      final callbackMap = Map<String, dynamic>.from(callback);
      final callbackMessageRaw = callbackMap['message'];
      final fromRaw = callbackMap['from'];
      final text = _callbackToCommandText(callbackMap['data']?.toString());
      if (callbackMessageRaw is! Map || text == null) {
        return null;
      }
      final callbackMessage = Map<String, dynamic>.from(callbackMessageRaw);
      final callbackChatRaw = callbackMessage['chat'];
      if (callbackChatRaw is! Map) {
        return null;
      }
      return _PrivateMessageContext(
        chat: Map<String, dynamic>.from(callbackChatRaw),
        from: fromRaw is Map ? Map<String, dynamic>.from(fromRaw) : null,
        text: text,
        message: null,
      );
    }

    final messageRaw = update['message'];
    if (messageRaw is Map) {
      final message = Map<String, dynamic>.from(messageRaw);
      final chatRaw = message['chat'];
      if (chatRaw is! Map) {
        return null;
      }
      final fromRaw = message['from'];
      return _PrivateMessageContext(
        chat: Map<String, dynamic>.from(chatRaw),
        from: fromRaw is Map ? Map<String, dynamic>.from(fromRaw) : null,
        text: message['text']?.toString().trim(),
        message: message,
      );
    }

    final chatRaw = update['chat'];
    if (chatRaw is! Map) {
      return null;
    }
    final fromRaw = update['from'];
    return _PrivateMessageContext(
      chat: Map<String, dynamic>.from(chatRaw),
      from: fromRaw is Map ? Map<String, dynamic>.from(fromRaw) : null,
      text: update['text']?.toString().trim(),
      message: update,
    );
  }

  String? _callbackToCommandText(String? callbackData) {
    if (callbackData == null) {
      return null;
    }
    if (callbackData.startsWith(MessageTemplates.callbackApprovePaymentPrefix)) {
      final rawId = callbackData.substring(MessageTemplates.callbackApprovePaymentPrefix.length);
      final bookingId = int.tryParse(rawId);
      return bookingId == null ? null : '/approve_payment $bookingId';
    }
    if (callbackData.startsWith(MessageTemplates.callbackRejectPaymentPrefix)) {
      final rawId = callbackData.substring(MessageTemplates.callbackRejectPaymentPrefix.length);
      final bookingId = int.tryParse(rawId);
      return bookingId == null ? null : '/reject_payment $bookingId';
    }
    return null;
  }

  Future<void> _notifyAdminAboutPaymentSubmitted(
    TrainingBooking booking, {
    required _PaymentProof paymentProof,
  }) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sender.copyMessage(
        adminChatId,
        fromChatId: paymentProof.fromChatId,
        messageId: paymentProof.messageId,
      );
      await _sender.sendMessage(
        adminChatId,
        _templates.paymentSubmittedAdminNotification(booking),
        replyMarkup: _templates.paymentDecisionInlineKeyboard(booking.id),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment submission: $error', stackTrace);
    }
  }

  Future<void> _notifyAboutPaymentReview(
    TrainingBooking booking, {
    required int? moderatorUserId,
  }) async {
    try {
      await _sender.sendMessage(
        booking.userId,
        booking.status == BookingStatus.paid
            ? _templates.paymentApprovedForUser(booking)
            : _templates.paymentRejectedForUser(booking),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify user about payment review: $error', stackTrace);
    }

    final adminChatId = _adminChatId;
    if (adminChatId == null || moderatorUserId == null) {
      return;
    }
    try {
      await _sender.sendMessage(
        adminChatId,
        _templates.paymentReviewAdminNotification(
          booking: booking,
          moderatorUserId: moderatorUserId,
        ),
      );
    } on Object catch (error, stackTrace) {
      l.w('Failed to notify admin chat about payment review: $error', stackTrace);
    }
  }
}

final class _PrivateMessageContext {
  const _PrivateMessageContext({
    required this.chat,
    required this.from,
    required this.text,
    required this.message,
  });

  final Map<String, dynamic> chat;
  final Map<String, dynamic>? from;
  final String? text;
  final Map<String, dynamic>? message;
}

final class _PaymentProof {
  const _PaymentProof({
    required this.fromChatId,
    required this.messageId,
    required this.caption,
  });

  final int fromChatId;
  final int messageId;
  final String? caption;
}

enum _PrivateFlowStep {
  selectingTraining,
  paymentConfirmation,
}

final class _PrivateFlowState {
  const _PrivateFlowState({
    required this.step,
    required this.availableTrainings,
    this.activeBooking,
  });

  final _PrivateFlowStep step;
  final List<TrainingInfo> availableTrainings;
  final TrainingBooking? activeBooking;

  _PrivateFlowState copyWith({
    _PrivateFlowStep? step,
    List<TrainingInfo>? availableTrainings,
    TrainingBooking? activeBooking,
  }) {
    return _PrivateFlowState(
      step: step ?? this.step,
      availableTrainings: availableTrainings ?? this.availableTrainings,
      activeBooking: activeBooking ?? this.activeBooking,
    );
  }
}
