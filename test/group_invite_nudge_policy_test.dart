import 'package:dvor_chatbot/src/application/group_invite_nudge_policy.dart';
import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:test/test.dart';

void main() {
  const policy = GroupInviteNudgePolicy();
  final startedAt = DateTime.utc(2026, 8, 1, 10);
  final now = startedAt.add(const Duration(hours: 25));

  GroupInviteNudgeCandidate candidate({
    GroupMembershipStatus membership = GroupMembershipStatus.notMember,
    int nudgeCount = 0,
    DateTime? lastInviteNudgeAt,
    DateTime? lastOnboardingNudgeAt,
    OnboardingPhase? phase,
    DateTime? onboardingStartedAt,
    DateTime? snoozeUntil,
    DateTime? started,
  }) {
    return GroupInviteNudgeCandidate(
      userId: 42,
      startedAt: started ?? startedAt,
      membership: membership,
      nudgeCount: nudgeCount,
      lastInviteNudgeAt: lastInviteNudgeAt,
      lastOnboardingNudgeAt: lastOnboardingNudgeAt,
      phase: phase,
      onboardingStartedAt: onboardingStartedAt,
      snoozeUntil: snoozeUntil,
    );
  }

  test('offers first invite a day after start', () {
    final decision = policy.next(candidate: candidate(), now: now);
    expect(decision, isNotNull);
    expect(decision!.index, 1);
    expect(decision.nudgeKey, 'group_invite_1');
  });

  test('skips known members and unknown membership', () {
    expect(
      policy.next(
        candidate: candidate(membership: GroupMembershipStatus.member),
        now: now,
      ),
      isNull,
    );
    expect(
      policy.next(
        candidate: GroupInviteNudgeCandidate(
          userId: 42,
          startedAt: startedAt,
        ),
        now: now,
      ),
      isNull,
    );
  });

  test('skips admins, snooze, and first-day starts', () {
    expect(
      policy.next(candidate: candidate(), now: now, adminUserIds: const <int>{42}),
      isNull,
    );
    expect(
      policy.next(
        candidate: candidate(snoozeUntil: now.add(const Duration(hours: 1))),
        now: now,
      ),
      isNull,
    );
    expect(
      policy.next(
        candidate: candidate(),
        now: startedAt.add(const Duration(hours: 12)),
      ),
      isNull,
    );
  });

  test('keeps quiz quiet for 48 hours then allows invite', () {
    expect(
      policy.next(
        candidate: candidate(
          phase: OnboardingPhase.phase1Quiz,
          onboardingStartedAt: startedAt,
        ),
        now: startedAt.add(const Duration(hours: 30)),
      ),
      isNull,
    );
    expect(
      policy.next(
        candidate: candidate(
          phase: OnboardingPhase.phase1Quiz,
          onboardingStartedAt: startedAt,
        ),
        now: startedAt.add(const Duration(hours: 49)),
      ),
      isNotNull,
    );
  });

  test('spaces second and third invites', () {
    final firstSentAt = now;
    expect(
      policy.next(
        candidate: candidate(nudgeCount: 1, lastInviteNudgeAt: firstSentAt),
        now: firstSentAt.add(const Duration(days: 6)),
      ),
      isNull,
    );
    final second = policy.next(
      candidate: candidate(nudgeCount: 1, lastInviteNudgeAt: firstSentAt),
      now: firstSentAt.add(const Duration(days: 7)),
    );
    expect(second?.index, 2);

    final secondSentAt = firstSentAt.add(const Duration(days: 7));
    expect(
      policy.next(
        candidate: candidate(nudgeCount: 2, lastInviteNudgeAt: secondSentAt),
        now: secondSentAt.add(const Duration(days: 13)),
      ),
      isNull,
    );
    expect(
      policy
          .next(
            candidate: candidate(nudgeCount: 2, lastInviteNudgeAt: secondSentAt),
            now: secondSentAt.add(const Duration(days: 14)),
          )
          ?.index,
      3,
    );
    expect(
      policy.next(
        candidate: candidate(nudgeCount: 3, lastInviteNudgeAt: secondSentAt),
        now: secondSentAt.add(const Duration(days: 30)),
      ),
      isNull,
    );
  });

  test('waits if an onboarding nudge went out recently', () {
    expect(
      policy.next(
        candidate: candidate(
          lastOnboardingNudgeAt: now.subtract(const Duration(hours: 2)),
        ),
        now: now,
      ),
      isNull,
    );
  });
}
