import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/jobs/business_timezone.dart';
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
    ActivityCatalogService? catalogService,
    DateTime Function()? nowProvider,
    this.delayAfterStart = const Duration(hours: 2),
    this.lookback = const Duration(days: 2),
    this.outdoorLookback = const Duration(days: 21),
    this.askWindow = const Duration(days: 2),
    this.timezoneOffsetHours = 3,
    this.outdoorAskHour = 12,
  })  : _bookingRepository = bookingRepository,
        _onboardingRepository = onboardingRepository,
        _sender = sender,
        _templates = templates,
        _enabled = enabled,
        _onAskFeedback = onAskFeedback,
        _catalogService = catalogService,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final OnboardingRepository _onboardingRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final bool _enabled;
  final TrainingFeedbackFlowStarter _onAskFeedback;
  final ActivityCatalogService? _catalogService;
  final DateTime Function() _nowProvider;
  final Duration delayAfterStart;
  final Duration lookback;
  final Duration outdoorLookback;
  final Duration askWindow;
  final int timezoneOffsetHours;
  final int outdoorAskHour;

  Future<void> run() async {
    if (!_enabled) {
      return;
    }
    final nowUtc = _nowProvider().toUtc();
    final nowBusiness = inBusinessTimezone(nowUtc, timezoneOffsetHours: timezoneOffsetHours);
    final candidateFrom = nowUtc.subtract(
      outdoorLookback > lookback + delayAfterStart ? outdoorLookback : lookback + delayAfterStart,
    );
    try {
      final bookings = await _bookingRepository.listSelfPaidBookingsStartedBetween(
        startsFromInclusive: candidateFrom,
        startsToInclusive: nowUtc,
        limit: 200,
      );
      final startedIds = (await _onboardingRepository.getAllStartedUserIds()).toSet();
      for (final booking in bookings) {
        try {
          final dueAt = _feedbackDueAt(booking);
          if (nowBusiness.isBefore(dueAt)) {
            continue;
          }
          if (nowBusiness.difference(dueAt) > askWindow) {
            continue;
          }
          if (await _onboardingRepository.hasTrainingFeedbackRequest(booking.id)) {
            continue;
          }
          if (await _onboardingRepository.hasTrainingFeedback(booking.id)) {
            continue;
          }
          if (!startedIds.contains(booking.userId)) {
            continue;
          }
          final category = _categoryFor(booking);
          await _onboardingRepository.recordTrainingFeedbackRequest(
            bookingId: booking.id,
            userId: booking.userId,
            sessionKey: booking.trainingKey,
            trainingTitle: booking.trainingTitle,
            sentAt: nowUtc,
          );
          await _sender.sendMessage(
            booking.userId,
            _templates.trainingFeedbackAsk(
              trainingTitle: booking.trainingTitle,
              category: category,
            ),
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

  ActivityCategory _categoryFor(TrainingBooking booking) {
    return _catalogService?.categoryForBooking(booking) ?? ActivityCategory.trainings;
  }

  /// Wall-clock due time in business timezone (same convention as promo jobs).
  DateTime _feedbackDueAt(TrainingBooking booking) {
    final category = _categoryFor(booking);
    if (category == ActivityCategory.hikes || category == ActivityCategory.trails) {
      final outdoor = _catalogService?.outdoorByBooking(booking);
      final endDate = outdoor?.dateTo ?? booking.startsAt;
      final endDay = DateTime.utc(endDate.year, endDate.month, endDate.day);
      final askDay = endDay.add(const Duration(days: 1));
      // UTC-tagged wall clock, matching [inBusinessTimezone] convention.
      return DateTime.utc(askDay.year, askDay.month, askDay.day, outdoorAskHour);
    }

    // Trainings: ~2h after start. Compare in business timezone wall clock.
    final startsBusiness = inBusinessTimezone(
      booking.startsAt.toUtc(),
      timezoneOffsetHours: timezoneOffsetHours,
    );
    return startsBusiness.add(delayAfterStart);
  }
}
