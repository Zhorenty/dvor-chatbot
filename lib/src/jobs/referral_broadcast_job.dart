import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:l/l.dart';

final class ReferralBroadcastJob {
  ReferralBroadcastJob({
    required GroupAnnouncementService announcements,
    required MessageTemplates templates,
    required int? targetChatId,
    int timezoneOffsetHours = 3,
    DateTime Function()? nowProvider,
  })  : _announcements = announcements,
        _templates = templates,
        _targetChatId = targetChatId,
        _timezoneOffset = Duration(hours: timezoneOffsetHours),
        _nowProvider = nowProvider ?? DateTime.now;

  static const int weekday = DateTime.wednesday;
  static const int hour = 10;
  static const int minute = 0;

  final GroupAnnouncementService _announcements;
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
      if (now.weekday != weekday || now.hour != hour || now.minute != minute) {
        return;
      }
      final broadcastKey = 'referral|${now.year}-${now.month}-${now.day}';
      if (_sentBroadcasts.containsKey(broadcastKey)) {
        return;
      }
      final sent = await _announcements.publish(
        chatId: targetChatId,
        type: GroupAnnouncementType.referralBroadcast,
        text: _templates.groupReferralBroadcast(),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      if (sent) {
        _sentBroadcasts[broadcastKey] = now;
      }
    } on Object catch (error, stackTrace) {
      l.w('Referral broadcast job failed: $error', stackTrace);
    }
  }

  void _cleanupSentBroadcasts(DateTime now) {
    final threshold = now.subtract(const Duration(days: 14));
    _sentBroadcasts.removeWhere((_, sentAt) => sentAt.isBefore(threshold));
  }

  DateTime _inBusinessTimezone(DateTime value) {
    return value.toUtc().add(_timezoneOffset);
  }
}
