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

  Future<bool> handle(Map<String, dynamic> message) async {
    final chat = message['chat'];
    if (chat is! Map || chat['type']?.toString() != 'private') {
      return false;
    }
    final chatId = chat['id'];
    if (chatId is! int) {
      return false;
    }
    final text = message['text']?.toString().trim();
    if (text == null) {
      return false;
    }
    final from = message['from'];
    final rawUserId = from is Map ? from['id'] : null;
    final userId = rawUserId is int ? rawUserId : null;
    final isAdmin = userId != null && _adminUserIds.contains(userId);

    if (text.startsWith('/start')) {
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

    if (text.startsWith('/trainings') || text == MessageTemplates.buttonTrainings) {
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

    final flowState = userId == null ? null : _flowByUserId[userId];
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

    if (text == MessageTemplates.buttonBookTraining || text.startsWith('/book')) {
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

    if (userId != null && flowState?.step == _PrivateFlowStep.selectingTraining) {
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

    if (text == MessageTemplates.buttonMyBookings || text.startsWith('/my_bookings')) {
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

    if (text == MessageTemplates.buttonSubmitPayment || text.startsWith('/paid')) {
      if (userId == null) {
        return false;
      }
      if (text == MessageTemplates.buttonSubmitPayment &&
          flowState?.step != _PrivateFlowStep.paymentConfirmation) {
        await _sender.sendMessage(
          chatId,
          'Сначала выбери тренировку через `${MessageTemplates.buttonBookTraining}`.',
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final note = _tailAfterCommand(text);
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        note: note,
      );
      if (booking != null) {
        await _notifyAdminAboutPaymentSubmitted(booking);
      }
      _flowByUserId.remove(userId);
      await _sender.sendMessage(
        chatId,
        booking == null ? _templates.noPendingPayment() : _templates.paymentSubmitted(booking),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonRefreshSchedule || text.startsWith('/refresh_schedule')) {
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

    if (text == MessageTemplates.buttonPaymentsQueue || text.startsWith('/payments_queue')) {
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
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text.startsWith('/approve_payment') || text.startsWith('/reject_payment')) {
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

  String? _tailAfterCommand(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    return parts.skip(1).join(' ');
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

  Future<void> _notifyAdminAboutPaymentSubmitted(TrainingBooking booking) async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    try {
      await _sender.sendMessage(
        adminChatId,
        _templates.paymentSubmittedAdminNotification(booking),
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
