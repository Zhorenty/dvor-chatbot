import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class TrainingDayPromoJob {
  TrainingDayPromoJob({
    required TrainingScheduleRepository scheduleRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    required int? targetChatId,
    int timezoneOffsetHours = 3,
    DateTime Function()? nowProvider,
  })  : _scheduleRepository = scheduleRepository,
        _sender = sender,
        _templates = templates,
        _targetChatId = targetChatId,
        _timezoneOffset = Duration(hours: timezoneOffsetHours),
        _nowProvider = nowProvider ?? DateTime.now;

  final TrainingScheduleRepository _scheduleRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final Duration _timezoneOffset;
  final DateTime Function() _nowProvider;
  final Map<String, DateTime> _sentPromos = <String, DateTime>{};

  Future<void> run() async {
    final targetChatId = _targetChatId;
    if (targetChatId == null) {
      return;
    }
    try {
      final now = _inBusinessTimezone(_nowProvider());
      _cleanupSentPromos(now);
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
        final promoKey = '${training.sessionKey}|${sendAt.toIso8601String()}';
        if (_sentPromos.containsKey(promoKey)) {
          continue;
        }
        await _sendPromo(
          targetChatId,
          training,
          isToday: _isSameDay(startsAt, now),
        );
        _sentPromos[promoKey] = now;
      }
    } on Object catch (error, stackTrace) {
      l.w('Training day promo job failed: $error', stackTrace);
    }
  }

  Future<void> _sendPromo(
    int chatId,
    TrainingInfo training, {
    required bool isToday,
  }) async {
    try {
      await _sender.sendMessage(
        chatId,
        _templates.groupTrainingTodayPromo(
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

  DateTime _inBusinessTimezone(DateTime value) {
    return value.toUtc().add(_timezoneOffset);
  }
}
