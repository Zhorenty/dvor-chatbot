import 'package:dvor_chatbot/src/application/group_invite_nudge_policy.dart';
import 'package:dvor_chatbot/src/application/group_membership_lookup.dart';
import 'package:dvor_chatbot/src/data/onboarding_repository.dart';
import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class GroupInviteNudgeJob {
  const GroupInviteNudgeJob({
    required OnboardingRepository onboardingRepository,
    required GroupMembershipLookup membershipLookup,
    required MessageSender sender,
    required MessageTemplates templates,
    required int? targetChatId,
    this.enabled = true,
    this.adminUserIds = const <int>{},
    this.policy = const GroupInviteNudgePolicy(),
    DateTime Function()? nowProvider,
  })  : _onboardingRepository = onboardingRepository,
        _membershipLookup = membershipLookup,
        _sender = sender,
        _templates = templates,
        _targetChatId = targetChatId,
        _nowProvider = nowProvider ?? DateTime.now;

  final OnboardingRepository _onboardingRepository;
  final GroupMembershipLookup _membershipLookup;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _targetChatId;
  final bool enabled;
  final Set<int> adminUserIds;
  final GroupInviteNudgePolicy policy;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    if (!enabled) {
      return;
    }
    final targetChatId = _targetChatId;
    if (targetChatId == null) {
      return;
    }

    final now = _nowProvider();
    try {
      final candidates = await _onboardingRepository.listGroupInviteNudgeCandidates(
        now: now,
        minAgeAfterStart: GroupInviteNudgePolicy.minAgeAfterStart,
        maxNudges: GroupInviteNudgePolicy.maxNudges,
      );
      for (final candidate in candidates) {
        try {
          await _processCandidate(
            candidate: candidate,
            targetChatId: targetChatId,
            now: now,
          );
        } on Object catch (error, stackTrace) {
          l.w(
            'Failed group invite nudge for user ${candidate.userId}: $error',
            stackTrace,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      l.w('Group invite nudge job failed: $error', stackTrace);
    }
  }

  Future<void> _processCandidate({
    required GroupInviteNudgeCandidate candidate,
    required int targetChatId,
    required DateTime now,
  }) async {
    var membership = candidate.membership;
    if (membership == null) {
      final isMember = await _membershipLookup.isChatMember(
        chatId: targetChatId,
        userId: candidate.userId,
      );
      membership = isMember ? GroupMembershipStatus.member : GroupMembershipStatus.notMember;
      await _onboardingRepository.recordGroupMembership(
        userId: candidate.userId,
        status: membership,
        at: now,
      );
      if (membership == GroupMembershipStatus.member) {
        return;
      }
    }

    final decision = policy.next(
      candidate: candidate.copyWith(membership: membership),
      now: now,
      adminUserIds: adminUserIds,
    );
    if (decision == null) {
      return;
    }

    await _sender.sendMessage(
      candidate.userId,
      _templates.groupInviteNudge(decision.index),
      disableWebPagePreview: true,
      parseMode: 'HTML',
      replyMarkup: _templates.groupInviteUrlKeyboard(),
    );
    await _onboardingRepository.markGroupInviteNudgeSent(
      userId: candidate.userId,
      nudgeKey: decision.nudgeKey,
      sentAt: now,
    );
  }
}
