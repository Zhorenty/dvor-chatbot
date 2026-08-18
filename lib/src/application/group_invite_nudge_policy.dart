import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';

final class GroupInviteNudgeDecision {
  const GroupInviteNudgeDecision({
    required this.index,
    required this.nudgeKey,
  });

  final int index;
  final String nudgeKey;
}

/// Spacing for DM invites to the DVOR group. Keeps this quieter than onboarding drip.
final class GroupInviteNudgePolicy {
  const GroupInviteNudgePolicy();

  static const Duration minAgeAfterStart = Duration(hours: 24);
  static const Duration quizQuietWindow = Duration(hours: 48);
  static const Duration minGapAfterOnboardingNudge = Duration(hours: 6);
  static const Duration firstToSecondGap = Duration(days: 7);
  static const Duration secondToThirdGap = Duration(days: 14);
  static const int maxNudges = 3;

  static const Set<OnboardingPhase> _quizQuietPhases = <OnboardingPhase>{
    OnboardingPhase.phase1Quiz,
    OnboardingPhase.phase1Track,
  };

  GroupInviteNudgeDecision? next({
    required GroupInviteNudgeCandidate candidate,
    required DateTime now,
    Set<int> adminUserIds = const <int>{},
  }) {
    if (adminUserIds.contains(candidate.userId)) {
      return null;
    }
    if (candidate.membership != GroupMembershipStatus.notMember) {
      return null;
    }
    if (candidate.nudgeCount >= maxNudges) {
      return null;
    }
    if (now.difference(candidate.startedAt) < minAgeAfterStart) {
      return null;
    }

    final snoozeUntil = candidate.snoozeUntil;
    if (snoozeUntil != null && snoozeUntil.isAfter(now)) {
      return null;
    }

    final phase = candidate.phase;
    final quizStartedAt = candidate.onboardingStartedAt ?? candidate.startedAt;
    if (phase != null &&
        _quizQuietPhases.contains(phase) &&
        now.difference(quizStartedAt) < quizQuietWindow) {
      return null;
    }

    final lastOnboardingNudgeAt = candidate.lastOnboardingNudgeAt;
    if (lastOnboardingNudgeAt != null &&
        now.difference(lastOnboardingNudgeAt) < minGapAfterOnboardingNudge) {
      return null;
    }

    final nextIndex = candidate.nudgeCount + 1;
    final lastInviteNudgeAt = candidate.lastInviteNudgeAt;
    if (nextIndex > 1 && lastInviteNudgeAt != null) {
      final requiredGap = nextIndex == 2 ? firstToSecondGap : secondToThirdGap;
      if (now.difference(lastInviteNudgeAt) < requiredGap) {
        return null;
      }
    }

    return GroupInviteNudgeDecision(
      index: nextIndex,
      nudgeKey: 'group_invite_$nextIndex',
    );
  }
}
