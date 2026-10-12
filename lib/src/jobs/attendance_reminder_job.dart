import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

/// Asks the admin to mark attendance after a training, then again until the
/// roster is closed or the lookback window ends.
final class AttendanceReminderJob {
  const AttendanceReminderJob({
    required BookingRepository bookingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required int? adminChatId,
    JobDedupeRepository? jobDedupeRepository,
    ActivityCatalogService? catalogService,
    DateTime Function()? nowProvider,
    this.delayAfterStart = const Duration(hours: 2),
    this.repeatEvery = const Duration(hours: 12),
    this.lookback = const Duration(days: 7),
  })  : _bookingRepository = bookingRepository,
        _sender = sender,
        _templates = templates,
        _adminChatId = adminChatId,
        _jobDedupeRepository = jobDedupeRepository,
        _catalogService = catalogService,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _adminChatId;
  final JobDedupeRepository? _jobDedupeRepository;
  final ActivityCatalogService? _catalogService;
  final DateTime Function() _nowProvider;
  final Duration delayAfterStart;
  final Duration repeatEvery;
  final Duration lookback;

  Future<void> run() async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    final now = _nowProvider();
    try {
      final bookings = await _bookingRepository.listBookingsStartedBetween(
        startsFromInclusive: now.subtract(lookback),
        startsToInclusive: now,
        limit: 500,
      );
      final sessions = <String, List<TrainingBooking>>{};
      for (final booking in bookings) {
        if (!_isTraining(booking)) {
          continue;
        }
        sessions.putIfAbsent(booking.trainingKey, () => <TrainingBooking>[]).add(booking);
      }
      for (final entry in sessions.entries) {
        try {
          await _remindSession(
            adminChatId: adminChatId,
            trainingKey: entry.key,
            bookings: entry.value,
            now: now,
          );
        } on Object catch (error, stackTrace) {
          l.w('Failed attendance reminder for ${entry.key}: $error', stackTrace);
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Attendance reminder job failed: $error', stackTrace);
    }
  }

  bool _isTraining(TrainingBooking booking) {
    final catalog = _catalogService;
    if (catalog == null) {
      return true;
    }
    return catalog.categoryForBooking(booking) == ActivityCategory.trainings;
  }

  Future<void> _remindSession({
    required int adminChatId,
    required String trainingKey,
    required List<TrainingBooking> bookings,
    required DateTime now,
  }) async {
    if (bookings.isEmpty || bookings.every((booking) => booking.attendance != null)) {
      return;
    }
    final startsAt = bookings.first.startsAt;
    final dueAt = startsAt.add(delayAfterStart);
    if (now.isBefore(dueAt)) {
      return;
    }
    final slot =
        repeatEvery.inMinutes <= 0 ? 0 : now.difference(dueAt).inMinutes ~/ repeatEvery.inMinutes;
    final key = 'attendance-reminder:$trainingKey:$slot';
    final dedupe = _jobDedupeRepository;
    if (dedupe != null && !dedupe.tryClaim(key)) {
      return;
    }
    final unmarked = bookings.where((booking) => booking.attendance == null).length;
    try {
      await sendBotHtml(
        _sender,
        adminChatId,
        _templates.attendanceReminderAdmin(
          trainingTitle: bookings.first.trainingTitle,
          startsAt: startsAt,
          unmarked: unmarked,
          followUp: slot > 0,
        ),
      );
    } on Object {
      dedupe?.release(key);
      rethrow;
    }
  }
}
