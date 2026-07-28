import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/jobs/business_timezone.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:l/l.dart';

final class ReferralBroadcastJob {
  ReferralBroadcastJob({
    required GroupAnnouncementService announcements,
    required MessageTemplates templates,
    required int? targetChatId,
    int timezoneOffsetHours = 3,
    JobDedupeRepository? jobDedupeRepository,
    DateTime Function()? nowProvider,
  })  : _announcements = announcements,
        _templates = templates,
        _targetChatId = targetChatId,
        _timezoneOffsetHours = timezoneOffsetHours,
        _jobDedupeRepository = jobDedupeRepository,
        _nowProvider = nowProvider ?? DateTime.now;

  static const int weekday = DateTime.wednesday;
  static const int hour = 10;
  static const int minute = 0;

  final GroupAnnouncementService _announcements;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final int _timezoneOffsetHours;
  final JobDedupeRepository? _jobDedupeRepository;
  final DateTime Function() _nowProvider;
  final Map<String, DateTime> _sentBroadcasts = <String, DateTime>{};

  Future<void> run() async {
    final targetChatId = _targetChatId;
    if (targetChatId == null) {
      return;
    }
    try {
      final now = inBusinessTimezone(_nowProvider(), timezoneOffsetHours: _timezoneOffsetHours);
      _cleanupSentBroadcasts(now);
      _jobDedupeRepository?.cleanupOlderThan(const Duration(days: 14));
      if (now.weekday != weekday || now.hour != hour || now.minute != minute) {
        return;
      }
      final broadcastKey = 'referral|${now.year}-${now.month}-${now.day}';
      if (!_claimBroadcast(broadcastKey, now)) {
        return;
      }
      final sent = await _announcements.publish(
        chatId: targetChatId,
        type: GroupAnnouncementType.referralBroadcast,
        text: _templates.groupReferralBroadcast(),
        parseMode: 'HTML',
        disableWebPagePreview: true,
      );
      if (!sent) {
        _releaseBroadcast(broadcastKey);
      }
    } on Object catch (error, stackTrace) {
      l.w('Referral broadcast job failed: $error', stackTrace);
    }
  }

  bool _claimBroadcast(String broadcastKey, DateTime now) {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null) {
      return dedupe.tryClaim(broadcastKey);
    }
    if (_sentBroadcasts.containsKey(broadcastKey)) {
      return false;
    }
    _sentBroadcasts[broadcastKey] = now;
    return true;
  }

  void _releaseBroadcast(String broadcastKey) {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null) {
      dedupe.release(broadcastKey);
      return;
    }
    _sentBroadcasts.remove(broadcastKey);
  }

  void _cleanupSentBroadcasts(DateTime now) {
    final threshold = now.subtract(const Duration(days: 14));
    _sentBroadcasts.removeWhere((_, sentAt) => sentAt.isBefore(threshold));
  }
}
