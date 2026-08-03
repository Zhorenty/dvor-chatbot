import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

typedef TrainingFeedbackFlowStarter = Future<void> Function({
  required int userId,
  required int bookingId,
  required String sessionKey,
  required String trainingTitle,
});

final class TrainingFeedbackJob {
  const TrainingFeedbackJob({
    required BookingRepository bookingRepository,
    required OnboardingRepository onboardingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required bool enabled,
    required TrainingFeedbackFlowStarter onAskFeedback,
    DateTime Function()? nowProvider,
    this.delayAfterStart = const Duration(hours: 2),
    this.lookback = const Duration(days: 2),
  })  : _bookingRepository = bookingRepository,
        _onboardingRepository = onboardingRepository,
        _sender = sender,
        _templates = templates,
        _enabled = enabled,
        _onAskFeedback = onAskFeedback,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final OnboardingRepository _onboardingRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final bool _enabled;
  final TrainingFeedbackFlowStarter _onAskFeedback;
  final DateTime Function() _nowProvider;
  final Duration delayAfterStart;
  final Duration lookback;

  Future<void> run() async {
    if (!_enabled) {
      return;
    }
    final now = _nowProvider().toUtc();
    final dueTo = now.subtract(delayAfterStart);
    final dueFrom = dueTo.subtract(lookback);
    try {
      final bookings = await _bookingRepository.listSelfPaidBookingsStartedBetween(
        startsFromInclusive: dueFrom,
        startsToInclusive: dueTo,
        limit: 100,
      );
      final startedIds = (await _onboardingRepository.getAllStartedUserIds()).toSet();
      for (final booking in bookings) {
        try {
          if (await _onboardingRepository.hasTrainingFeedbackRequest(booking.id)) {
            continue;
          }
          if (await _onboardingRepository.hasTrainingFeedback(booking.id)) {
            continue;
          }
          if (!startedIds.contains(booking.userId)) {
            continue;
          }
          await _onboardingRepository.recordTrainingFeedbackRequest(
            bookingId: booking.id,
            userId: booking.userId,
            sessionKey: booking.trainingKey,
            trainingTitle: booking.trainingTitle,
            sentAt: now,
          );
          await _sender.sendMessage(
            booking.userId,
            _templates.trainingFeedbackAsk(trainingTitle: booking.trainingTitle),
            replyMarkup: _templates.trainingFeedbackInlineKeyboard(booking.id),
          );
          await _onAskFeedback(
            userId: booking.userId,
            bookingId: booking.id,
            sessionKey: booking.trainingKey,
            trainingTitle: booking.trainingTitle,
          );
        } on Object catch (error, stackTrace) {
          l.w(
            'Failed training feedback ask for booking ${booking.id}: $error',
            stackTrace,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Training feedback job failed: $error', stackTrace);
    }
  }
}
