import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/business_timezone.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:l/l.dart';

final class TrainingDayPromoJob {
  TrainingDayPromoJob({
    required TrainingScheduleRepository scheduleRepository,
    required GroupAnnouncementService announcements,
    required MessageTemplates templates,
    required int? targetChatId,
    int timezoneOffsetHours = 3,
    JobDedupeRepository? jobDedupeRepository,
    DateTime Function()? nowProvider,
  })  : _scheduleRepository = scheduleRepository,
        _announcements = announcements,
        _templates = templates,
        _targetChatId = targetChatId,
        _timezoneOffsetHours = timezoneOffsetHours,
        _jobDedupeRepository = jobDedupeRepository,
        _nowProvider = nowProvider ?? DateTime.now;

  final TrainingScheduleRepository _scheduleRepository;
  final GroupAnnouncementService _announcements;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final int _timezoneOffsetHours;
  final JobDedupeRepository? _jobDedupeRepository;
  final DateTime Function() _nowProvider;
  final Map<String, DateTime> _sentPromos = <String, DateTime>{};

  Future<void> run() async {
    final targetChatId = _targetChatId;
    if (targetChatId == null) {
      return;
    }
    try {
      final now = inBusinessTimezone(_nowProvider(), timezoneOffsetHours: _timezoneOffsetHours);
      _cleanupSentPromos(now);
      _jobDedupeRepository?.cleanupOlderThan(const Duration(days: 3));
      final upcoming = _scheduleRepository
          .upcoming(now: now.subtract(const Duration(days: 1)), limit: 200)
          .where(
            (training) => training.category == ActivityCategory.trainings,
          )
          .toList(growable: false);

      for (final training in upcoming) {
        final startsAt = training.startsAt;
        final sendAt = _targetPromoTime(startsAt);
        if (!_isSameMinute(now, sendAt)) {
          continue;
        }
        final promoKey = 'training_day_promo|${training.sessionKey}|${sendAt.toIso8601String()}';
        if (!_claimPromo(promoKey, now)) {
          continue;
        }
        final sent = await _sendPromo(
          targetChatId,
          training,
          isToday: _isSameDay(startsAt, now),
        );
        if (!sent) {
          _releasePromo(promoKey);
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Training day promo job failed: $error', stackTrace);
    }
  }

  bool _claimPromo(String promoKey, DateTime now) {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null) {
      return dedupe.tryClaim(promoKey);
    }
    if (_sentPromos.containsKey(promoKey)) {
      return false;
    }
    _sentPromos[promoKey] = now;
    return true;
  }

  void _releasePromo(String promoKey) {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null) {
      dedupe.release(promoKey);
      return;
    }
    _sentPromos.remove(promoKey);
  }

  Future<bool> _sendPromo(
    int chatId,
    TrainingInfo training, {
    required bool isToday,
  }) async {
    try {
      return await _announcements.publish(
        chatId: chatId,
        type: GroupAnnouncementType.trainingDayPromo,
        text: _templates.groupTrainingTodayPromo(
          training: training,
          isToday: isToday,
        ),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
    } on Object catch (error, stackTrace) {
      l.w(
        'Failed to send training day promo for ${training.sessionKey}: $error',
        stackTrace,
      );
      return false;
    }
  }

  void _cleanupSentPromos(DateTime now) {
    final threshold = now.subtract(const Duration(days: 3));
    _sentPromos.removeWhere((_, sentAt) => sentAt.isBefore(threshold));
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  bool _isSameMinute(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day &&
        left.hour == right.hour &&
        left.minute == right.minute;
  }

  DateTime _targetPromoTime(DateTime startsAt) {
    final isLateTraining = startsAt.hour >= 16;
    if (isLateTraining) {
      return DateTime(
        startsAt.year,
        startsAt.month,
        startsAt.day,
        12,
      );
    }
    final dayBefore = startsAt.subtract(const Duration(days: 1));
    return DateTime(
      dayBefore.year,
      dayBefore.month,
      dayBefore.day,
      20,
    );
  }
}
