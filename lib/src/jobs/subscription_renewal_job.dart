import 'package:dvor_chatbot/src/application/boxing_card_ledger.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/subscription_repository.dart';
import 'package:dvor_chatbot/src/domain/subscription.dart';
import 'package:dvor_chatbot/src/messages/formatters/message_formatters.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class SubscriptionRenewalJob {
  SubscriptionRenewalJob({
    required SubscriptionRepository subscriptionRepository,
    required MessageSender sender,
    required MessageTemplates templates,
    BookingRepository? bookingRepository,
    JobDedupeRepository? jobDedupeRepository,
    DateTime Function()? nowProvider,
    this.visitNotifyDelay = const Duration(hours: 2),
    this.visitLookback = const Duration(days: 2),
  })  : _subscriptionRepository = subscriptionRepository,
        _sender = sender,
        _templates = templates,
        _bookingRepository = bookingRepository,
        _jobDedupeRepository = jobDedupeRepository,
        _nowProvider = nowProvider ?? DateTime.now;

  final SubscriptionRepository _subscriptionRepository;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final BookingRepository? _bookingRepository;
  final JobDedupeRepository? _jobDedupeRepository;
  final DateTime Function() _nowProvider;
  final Duration visitNotifyDelay;
  final Duration visitLookback;

  Future<void> run() async {
    final now = _nowProvider().toUtc();
    await _sendRenewalReminders(now);
    await _sendExpiryPromo(now);
    await _sendVisitDebits(now);
    await _sendIndividualReminders(now);
  }

  Future<void> _sendRenewalReminders(DateTime now) async {
    final reminderTargets = await _subscriptionRepository.listRenewalReminderTargets(
      now: now,
      limit: 100,
    );
    for (final target in reminderTargets) {
      final until = target.request.activeUntil;
      if (target.request.plan == null || until == null) {
        await _subscriptionRepository.markRenewalReminderSent(
          requestId: target.request.id,
          daysBefore: target.daysBefore,
          sentAt: now,
        );
        continue;
      }
      try {
        final usage = await _usageFor(target.request, now: now);
        await sendBotHtml(
          _sender,
          target.request.userId,
          _templates.subscriptionRenewalReminder(
            activeUntil: until,
            daysBefore: target.daysBefore,
            remainingGroup: usage.remaining,
            groupQuota: usage.quota,
            individualUsed: usage.individualUsed,
          ),
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
  }

  Future<void> _sendExpiryPromo(DateTime now) async {
    final expired = await _subscriptionRepository.listExpiredWithoutPromo(
      now: now,
      limit: 100,
    );
    for (final request in expired) {
      if (request.plan == null) {
        await _subscriptionRepository.markExpiryPromoSent(
          requestId: request.id,
          sentAt: now,
        );
        continue;
      }
      try {
        await sendBotHtml(
          _sender,
          request.userId,
          _templates.subscriptionExpiryPromo(),
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

  Future<void> _sendVisitDebits(DateTime now) async {
    final bookingRepository = _bookingRepository;
    if (bookingRepository == null) {
      return;
    }
    final from = now.subtract(visitLookback + visitNotifyDelay);
    final bookings = await bookingRepository.listSelfPaidBookingsStartedBetween(
      startsFromInclusive: from,
      startsToInclusive: now,
      limit: 200,
    );
    for (final booking in bookings) {
      if (!MessageFormatters.isBoxingCardIncludedPaymentNote(booking.paymentNote)) {
        continue;
      }
      if (now.difference(booking.startsAt.toUtc()) < visitNotifyDelay) {
        continue;
      }
      final key = 'boxing_card_visit:${booking.id}';
      final dedupe = _jobDedupeRepository;
      if (dedupe != null && !dedupe.tryClaim(key)) {
        continue;
      }
      try {
        final membership = await _subscriptionRepository.getMembership(
          booking.userId,
          now: booking.startsAt,
        );
        final plan = membership.plan;
        if (plan == null) {
          dedupe?.release(key);
          continue;
        }
        final remaining = await _remainingFor(
              membership,
              userId: booking.userId,
              now: booking.startsAt,
            ) ??
            0;
        await sendBotHtml(
          _sender,
          booking.userId,
          _templates.boxingCardVisitDebited(
            remaining: remaining,
            quota: plan.groupQuota,
          ),
        );
      } on Object catch (error, stackTrace) {
        dedupe?.release(key);
        l.w('Failed to send boxing card visit debit for booking ${booking.id}: $error', stackTrace);
      }
    }
  }

  Future<void> _sendIndividualReminders(DateTime now) async {
    final targets = await _subscriptionRepository.listIndividualReminderTargets(
      now: now,
      limit: 100,
    );
    for (final request in targets) {
      final until = request.activeUntil;
      if (until == null) {
        continue;
      }
      try {
        await sendBotHtml(
          _sender,
          request.userId,
          _templates.boxingCardIndividualReminder(activeUntil: until),
        );
        await _subscriptionRepository.markIndividualReminderSent(
          requestId: request.id,
          sentAt: now,
        );
      } on Object catch (error, stackTrace) {
        l.w('Failed to send boxing card individual reminder: $error', stackTrace);
      }
    }
  }

  Future<({int remaining, int quota, bool individualUsed})> _usageFor(
    SubscriptionRequest request, {
    required DateTime now,
  }) async {
    final plan = request.plan;
    final membership = SubscriptionMembership(
      level: plan == null ? MembershipLevel.normal : MembershipLevel.boxingCard,
      plan: plan,
      activeFrom: request.activeFrom,
      activeUntil: request.activeUntil,
      requestId: request.id,
    );
    final remaining = await _remainingFor(membership, userId: request.userId, now: now) ?? 0;
    final individualUsed = await _subscriptionRepository.hasApprovedIndividualInPeriod(
      subscriptionRequestId: request.id,
    );
    return (
      remaining: remaining,
      quota: plan?.groupQuota ?? 0,
      individualUsed: individualUsed,
    );
  }

  Future<int?> _remainingFor(
    SubscriptionMembership membership, {
    required int userId,
    required DateTime now,
  }) async {
    final bookingRepository = _bookingRepository;
    final plan = membership.plan;
    final until = membership.activeUntil;
    if (bookingRepository == null || plan == null || until == null) {
      return null;
    }
    final from = BoxingCardLedger.periodStart(membership, now: now);
    final bookings = await bookingRepository.listUserBookingsByPaymentNotes(
      userId: userId,
      paymentNotes: <String>{
        MessageFormatters.boxingCardIncludedPaymentNoteMarker,
        MessageFormatters.proIncludedTrainingPaymentNoteMarker,
        MessageFormatters.boxingCardLateCancelPaymentNoteMarker,
      },
      startsFromInclusive: from,
      startsToExclusive: until,
    );
    final used = BoxingCardLedger.usedGroupSlots(
      bookings: bookings,
      userId: userId,
      periodStart: from,
      periodEnd: until,
    );
    return BoxingCardLedger.remainingGroupSlots(plan: plan, used: used);
  }
}
