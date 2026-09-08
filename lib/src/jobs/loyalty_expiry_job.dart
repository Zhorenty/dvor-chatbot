import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/application/loyalty_service.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class LoyaltyExpiryJob {
  const LoyaltyExpiryJob({
    required LoyaltyService loyaltyService,
    required MessageSender sender,
    required MessageTemplates templates,
    JobDedupeRepository? jobDedupeRepository,
    DateTime Function()? nowProvider,
  })  : _loyaltyService = loyaltyService,
        _sender = sender,
        _templates = templates,
        _jobDedupeRepository = jobDedupeRepository,
        _nowProvider = nowProvider ?? DateTime.now;

  final LoyaltyService _loyaltyService;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final JobDedupeRepository? _jobDedupeRepository;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    final now = _nowProvider();
    try {
      await _sendReminders(now);
      await _expireDue(now);
    } on Object catch (error, stackTrace) {
      l.w('Loyalty expiry job failed: $error', stackTrace);
    }
  }

  Future<void> _sendReminders(DateTime now) async {
    final targets = await _loyaltyService.listExpiringSoon(now: now);
    for (final account in targets) {
      if (account.remaining <= 0) {
        continue;
      }
      final expiresAt = account.expiresAt(lifetime: LoyaltyMath.lifetime);
      if (expiresAt == null) {
        continue;
      }
      final key = LoyaltyKeys.reminder(account.userId, expiresAt);
      final dedupe = _jobDedupeRepository;
      if (dedupe != null && !dedupe.tryClaim(key)) {
        continue;
      }
      try {
        await sendBotHtml(
          _sender,
          account.userId,
          _templates.loyaltyExpiryReminder(
            remaining: account.remaining,
            expiresAt: expiresAt,
          ),
        );
      } on Object catch (error, stackTrace) {
        dedupe?.release(key);
        l.w(
          'Failed to send loyalty expiry reminder for user ${account.userId}: $error',
          stackTrace,
        );
      }
    }
  }

  Future<void> _expireDue(DateTime now) async {
    final due = await _loyaltyService.listExpired(now: now);
    for (final account in due) {
      try {
        final result = await _loyaltyService.expireDue(account, now: now);
        if (!result.applied || result.amount <= 0) {
          continue;
        }
        await sendBotHtml(
          _sender,
          account.userId,
          _templates.loyaltyExpired(
            burned: result.amount,
            remaining: result.account.remaining,
          ),
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to expire loyalty for user ${account.userId}: $error', stackTrace);
      }
    }
  }
}
