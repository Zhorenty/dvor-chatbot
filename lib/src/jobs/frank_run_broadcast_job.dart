import 'package:dvor_chatbot/src/application/broadcast_service.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/featured_trainings.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

/// One DM to everyone who pressed Start, about the FRANK run. Claimed once.
final class FrankRunBroadcastJob {
  FrankRunBroadcastJob({
    required MessageSender sender,
    required OnboardingRepository onboardingRepository,
    required MessageTemplates templates,
    JobDedupeRepository? jobDedupeRepository,
    DateTime Function()? nowProvider,
    int? groupChatId,
  })  : _broadcast = BroadcastService(
          sender: sender,
          onboardingRepository: onboardingRepository,
          groupChatId: groupChatId,
        ),
        _templates = templates,
        _jobDedupeRepository = jobDedupeRepository,
        _nowProvider = nowProvider ?? DateTime.now;

  static const String dedupeKey = 'broadcast:frank-run:2026-10-17';

  final BroadcastService _broadcast;
  final MessageTemplates _templates;
  final JobDedupeRepository? _jobDedupeRepository;
  final DateTime Function() _nowProvider;
  bool _claimedInMemory = false;

  Future<void> run() async {
    final start = FeaturedTrainings.events.first.startsAt;
    if (!_nowProvider().isBefore(start)) {
      _claim();
      return;
    }
    if (!_claim()) {
      return;
    }
    try {
      final result = await _broadcast.broadcastToUsers(
        BroadcastContent.text(_templates.frankRunBroadcast()),
      );
      l.i(
        'FRANK run broadcast: sent ${result.sent}/${result.total}, failed ${result.failed}.',
      );
      if (result.sent == 0) {
        _release();
      }
    } on Object catch (error, stackTrace) {
      _release();
      l.w('FRANK run broadcast failed: $error', stackTrace);
    }
  }

  bool _claim() {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null) {
      return dedupe.tryClaim(dedupeKey);
    }
    if (_claimedInMemory) {
      return false;
    }
    _claimedInMemory = true;
    return true;
  }

  void _release() {
    final dedupe = _jobDedupeRepository;
    if (dedupe != null) {
      dedupe.release(dedupeKey);
      return;
    }
    _claimedInMemory = false;
  }
}
