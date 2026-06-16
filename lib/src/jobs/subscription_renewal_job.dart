import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class SubscriptionRenewalJob {
  SubscriptionRenewalJob({
    required SubscriptionRepository subscriptionRepository,
    required MessageSender sender,
    required MessageTemplates templates,
  })  : _subscriptionRepository = subscriptionRepository,
        _sender = sender,
        _templates = templates;

  final SubscriptionRepository _subscriptionRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;

  Future<void> run() async {
    final now = DateTime.now().toUtc();
    final reminderTargets = await _subscriptionRepository.listRenewalReminderTargets(
      now: now,
      limit: 100,
    );
    for (final target in reminderTargets) {
      final until = target.request.activeUntil;
      if (until == null) {
        continue;
      }
      try {
        await _sender.sendMessage(
          target.request.userId,
          _templates.subscriptionRenewalReminder(
            activeUntil: until,
            daysBefore: target.daysBefore,
          ),
          parseMode: 'HTML',
        );
        await _subscriptionRepository.markRenewalReminderSent(
          requestId: target.request.id,
          daysBefore: target.daysBefore,
          sentAt: now,
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to send subscription renewal reminder: $error', stackTrace);
      }
    }

    final expired = await _subscriptionRepository.listExpiredWithoutPromo(
      now: now,
      limit: 100,
    );
    for (final request in expired) {
      try {
        await _sender.sendMessage(
          request.userId,
          _templates.subscriptionExpiryPromo(),
          parseMode: 'HTML',
        );
        await _subscriptionRepository.markExpiryPromoSent(
          requestId: request.id,
          sentAt: now,
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to send subscription expiry promo: $error', stackTrace);
      }
    }
  }
}
