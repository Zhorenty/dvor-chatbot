import 'package:dvor_chatbot/src/domain/onboarding.dart';

enum GroupMembershipStatus {
  member,
  notMember,
}

extension GroupMembershipStatusX on GroupMembershipStatus {
  String get storageValue => switch (this) {
        GroupMembershipStatus.member => 'member',
        GroupMembershipStatus.notMember => 'not_member',
      };

  static GroupMembershipStatus? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final value in GroupMembershipStatus.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Telegram ChatMember statuses that count as being in the group.
bool isEffectiveGroupMember({
  required String? status,
  bool isMemberFlag = false,
}) {
  if (status == null) {
    return false;
  }
  switch (status) {
    case 'creator':
    case 'administrator':
    case 'member':
      return true;
    case 'restricted':
      return isMemberFlag;
    default:
      return false;
  }
}

final class GroupInviteNudgeCandidate {
  const GroupInviteNudgeCandidate({
    required this.userId,
    required this.startedAt,
    this.membership,
    this.nudgeCount = 0,
    this.lastInviteNudgeAt,
    this.lastOnboardingNudgeAt,
    this.phase,
    this.onboardingStartedAt,
    this.snoozeUntil,
  });

  final int userId;
  final DateTime startedAt;
  final GroupMembershipStatus? membership;
  final int nudgeCount;
  final DateTime? lastInviteNudgeAt;
  final DateTime? lastOnboardingNudgeAt;
  final OnboardingPhase? phase;
  final DateTime? onboardingStartedAt;
  final DateTime? snoozeUntil;

  GroupInviteNudgeCandidate copyWith({
    GroupMembershipStatus? membership,
  }) {
    return GroupInviteNudgeCandidate(
      userId: userId,
      startedAt: startedAt,
      membership: membership ?? this.membership,
      nudgeCount: nudgeCount,
      lastInviteNudgeAt: lastInviteNudgeAt,
      lastOnboardingNudgeAt: lastOnboardingNudgeAt,
      phase: phase,
      onboardingStartedAt: onboardingStartedAt,
      snoozeUntil: snoozeUntil,
    );
  }
}
