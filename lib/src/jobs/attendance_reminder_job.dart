import 'package:dvor_chatbot/src/application/activity_catalog_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/attendance_reminder.dart';
import 'package:dvor_chatbot/src/domain/training_booking.dart';
import 'package:dvor_chatbot/src/jobs/business_timezone.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:intl/intl.dart';
import 'package:l/l.dart';

/// Sends the admin one daily digest of trainings whose attendance is still
/// open, until each roster is closed or the lookback window ends.
final class AttendanceReminderJob {
  const AttendanceReminderJob({
    required BookingRepository bookingRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required int? adminChatId,
    JobDedupeRepository? jobDedupeRepository,
    ActivityCatalogService? catalogService,
    DateTime Function()? nowProvider,
    int timezoneOffsetHours = 3,
    this.sendFromHour = 10,
    this.delayAfterStart = const Duration(hours: 2),
    this.lookback = const Duration(days: 7),
  })  : _bookingRepository = bookingRepository,
        _sender = sender,
        _templates = templates,
        _adminChatId = adminChatId,
        _jobDedupeRepository = jobDedupeRepository,
        _catalogService = catalogService,
        _nowProvider = nowProvider ?? DateTime.now,
        _timezoneOffsetHours = timezoneOffsetHours;

  final BookingRepository _bookingRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _adminChatId;
  final JobDedupeRepository? _jobDedupeRepository;
  final ActivityCatalogService? _catalogService;
  final DateTime Function() _nowProvider;
  final int _timezoneOffsetHours;
  final int sendFromHour;
  final Duration delayAfterStart;
  final Duration lookback;

  Future<void> run() async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    final now = _nowProvider();
    final localNow = inBusinessTimezone(now, timezoneOffsetHours: _timezoneOffsetHours);
    // A midnight digest gets lost: wait for the morning.
    if (localNow.hour < sendFromHour) {
      return;
    }
    try {
      final bookings = await _bookingRepository.listBookingsStartedBetween(
        startsFromInclusive: now.subtract(lookback),
        startsToInclusive: now.subtract(delayAfterStart),
        limit: 500,
      );
      final sessions = <String, List<TrainingBooking>>{};
      for (final booking in bookings) {
        if (!_isTraining(booking)) {
          continue;
        }
        sessions.putIfAbsent(booking.trainingKey, () => <TrainingBooking>[]).add(booking);
      }
      final open = <AttendanceReminderSession>[
        for (final session in sessions.values)
          if (session.any((booking) => booking.attendance == null))
            AttendanceReminderSession(
              trainingTitle: session.first.trainingTitle,
              startsAt: session.first.startsAt,
              unmarked: session.where((booking) => booking.attendance == null).length,
            ),
      ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (open.isEmpty) {
        return;
      }
      final day = localNow;
      final key = 'attendance-reminder:${DateFormat('yyyy-MM-dd').format(day)}';
      final dedupe = _jobDedupeRepository;
      if (dedupe != null && !dedupe.tryClaim(key)) {
        return;
      }
      try {
        await sendBotHtml(_sender, adminChatId, _templates.attendanceReminderAdmin(open));
      } on Object {
        dedupe?.release(key);
        rethrow;
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
}
