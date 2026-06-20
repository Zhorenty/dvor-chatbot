import 'package:dvor_chatbot/src/application/booking_policy_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class PaymentReminderJob {
  const PaymentReminderJob({
    required BookingRepository bookingRepository,
    required BookingPolicyService bookingPolicyService,
    required MessageSender sender,
    required MessageTemplates templates,
    Duration pendingPaymentTtl = const Duration(minutes: 120),
    DateTime Function()? nowProvider,
  })  : _bookingRepository = bookingRepository,
        _bookingPolicyService = bookingPolicyService,
        _sender = sender,
        _templates = templates,
        _pendingPaymentTtl = pendingPaymentTtl,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final BookingPolicyService _bookingPolicyService;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final Duration _pendingPaymentTtl;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    try {
      final now = _nowProvider();
      final reminderOffset = _pendingPaymentTtl > const Duration(minutes: 5)
          ? const Duration(minutes: 5)
          : Duration(minutes: _pendingPaymentTtl.inMinutes.clamp(1, 5));
      final expiredBookings = await _bookingRepository.expirePendingPaymentBookings(
        createdBefore: now.subtract(_pendingPaymentTtl),
        limit: 50,
      );
      for (final booking in expiredBookings) {
        try {
          await _sender.sendMessage(
            booking.userId,
            _templates.pendingPaymentExpired(booking),
            replyMarkup: _templates.simpleNavigationKeyboard(),
          );
        } on Object catch (error, stackTrace) {
          l.w(
            'Failed to send pending payment expiry notification for booking ${booking.id}: $error',
            stackTrace,
          );
        }
      }

      final bookings = await _bookingRepository.listPendingPaymentForReminder(
        createdBefore: now.subtract(reminderOffset),
        remindedBefore: now.subtract(reminderOffset),
        limit: 50,
      );

      for (final booking in bookings) {
        try {
          await _sender.sendMessage(
            booking.userId,
            _templates.pendingPaymentReminder(booking),
            replyMarkup: _templates.paymentConfirmationKeyboard(
              showStarterBonus: false,
              showCancelBooking: _bookingPolicyService.canCancel(booking, now: now),
            ),
            parseMode: 'HTML',
          );
          await _bookingRepository.markReminderSent(booking.id);
        } on Object catch (error, stackTrace) {
          l.w('Failed to send payment reminder for booking ${booking.id}: $error', stackTrace);
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Payment reminder job failed: $error', stackTrace);
    }
  }
}
