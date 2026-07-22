import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class ScheduleBroadcastJob {
  ScheduleBroadcastJob({
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

  static const List<(int weekday, int hour, int minute)> slots = <(int, int, int)>[
    (DateTime.sunday, 18, 30),
    (DateTime.tuesday, 10, 0),
    (DateTime.thursday, 10, 0),
  ];

  final TrainingScheduleRepository _scheduleRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final Duration _timezoneOffset;
  final DateTime Function() _nowProvider;
  final Map<String, DateTime> _sentBroadcasts = <String, DateTime>{};

  Future<void> run() async {
    final targetChatId = _targetChatId;
    if (targetChatId == null) {
      return;
    }
    try {
      final now = _inBusinessTimezone(_nowProvider());
      _cleanupSentBroadcasts(now);
      final matchingSlot = _matchingSlot(now);
      if (matchingSlot == null) {
        return;
      }
      final broadcastKey =
          'schedule|${now.year}-${now.month}-${now.day}|${matchingSlot.$2}:${matchingSlot.$3}';
      if (_sentBroadcasts.containsKey(broadcastKey)) {
        return;
      }
      final upcoming = _scheduleRepository
          .upcoming(now: now, limit: 20)
          .where((training) => training.category == ActivityCategory.trainings)
          .toList(growable: false);
      if (upcoming.isEmpty) {
        return;
      }
      await _sender.sendMessage(
        targetChatId,
        _templates.groupScheduleBroadcast(
          trainings: upcoming,
          weekday: matchingSlot.$1,
        ),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      _sentBroadcasts[broadcastKey] = now;
    } on Object catch (error, stackTrace) {
      l.w('Schedule broadcast job failed: $error', stackTrace);
    }
  }

  (int, int, int)? _matchingSlot(DateTime now) {
    for (final slot in slots) {
      if (slot.$1 == now.weekday && slot.$2 == now.hour && slot.$3 == now.minute) {
        return slot;
      }
    }
    return null;
  }

  void _cleanupSentBroadcasts(DateTime now) {
    final threshold = now.subtract(const Duration(days: 7));
    _sentBroadcasts.removeWhere((_, sentAt) => sentAt.isBefore(threshold));
  }

  DateTime _inBusinessTimezone(DateTime value) {
    return value.toUtc().add(_timezoneOffset);
  }
}
