import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class PaymentReminderJob {
  const PaymentReminderJob({
    required BookingRepository bookingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    DateTime Function()? nowProvider,
  })  : _bookingRepository = bookingRepository,
        _sender = sender,
        _templates = templates,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    try {
      final now = _nowProvider();
      final bookings = await _bookingRepository.listPendingPaymentForReminder(
        createdBefore: now.subtract(const Duration(minutes: 30)),
        remindedBefore: now.subtract(const Duration(minutes: 60)),
        limit: 50,
      );

      for (final booking in bookings) {
        try {
          await _sender.sendMessage(
            booking.userId,
            _templates.pendingPaymentReminder(booking),
            replyMarkup: _templates.paymentConfirmationKeyboard(
              showStarterBonus: false,
              showCancelBooking: _canCancelBooking(booking, now: now),
            ),
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

  bool _canCancelBooking(TrainingBooking booking, {required DateTime now}) {
    final isOutdoor = booking.trainingKey.startsWith('hikes|') ||
        booking.trainingKey.startsWith('trails|') ||
        booking.trainingTitle.startsWith('🥾 Поход:') ||
        booking.trainingTitle.startsWith('🏃 Трейл:');
    if (!isOutdoor) {
      return false;
    }
    return booking.startsAt.difference(now) >= const Duration(days: 7);
  }
}
