import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';

final class PrivateHandlers {
  const PrivateHandlers({
    required MessageSender sender,
    required TrainingScheduleRepository scheduleRepository,
    required BookingRepository bookingRepository,
    required MessageTemplates templates,
    required Set<int> adminUserIds,
  })  : _sender = sender,
        _scheduleRepository = scheduleRepository,
        _bookingRepository = bookingRepository,
        _templates = templates,
        _adminUserIds = adminUserIds;

  final MessageSender _sender;
  final TrainingScheduleRepository _scheduleRepository;
  final BookingRepository _bookingRepository;
  final MessageTemplates _templates;
  final Set<int> _adminUserIds;

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
      await _sender.sendMessage(
        chatId,
        _templates.privateWelcome(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text.startsWith('/trainings') || text == MessageTemplates.buttonTrainings) {
      final upcoming = _scheduleRepository.upcoming();
      await _sender.sendMessage(
        chatId,
        _templates.trainings(upcoming),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonHelp) {
      await _sender.sendMessage(
        chatId,
        _templates.privateHelp(),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
      );
      return true;
    }

    if (text == MessageTemplates.buttonBookTraining || text.startsWith('/book')) {
      if (userId == null) {
        return false;
      }
      final upcoming = _scheduleRepository.upcoming(limit: 1);
      if (upcoming.isEmpty) {
        await _sender.sendMessage(
          chatId,
          _templates.noUpcomingForBooking(),
          replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
        );
        return true;
      }
      final result = await _bookingRepository.createPendingBooking(
        userId: userId,
        training: upcoming.single,
      );
      await _sender.sendMessage(
        chatId,
        result.created
            ? _templates.bookingCreated(result.booking)
            : _templates.bookingAlreadyExists(result.booking),
        replyMarkup: _templates.privateMenuKeyboard(isAdmin: isAdmin),
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
      final note = _tailAfterCommand(text);
      final booking = await _bookingRepository.submitPaymentForLatestPending(
        userId,
        note: note,
      );
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
}
