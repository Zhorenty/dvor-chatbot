import 'package:dvor_chatbot/src/application/group_membership_lookup.dart';
import 'package:dvor_chatbot/src/domain/group_membership.dart';
import 'package:dvor_chatbot/src/domain/onboarding.dart';
import 'package:dvor_chatbot/src/jobs/group_invite_nudge_job.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 18, 12);
  final startedAt = now.subtract(const Duration(days: 2));

  GroupInviteNudgeJob job({
    required FakeOnboardingRepository onboarding,
    required _FakeMembershipLookup lookup,
    required FakeSender sender,
    bool enabled = true,
    int? targetChatId = -100123,
    Set<int> adminUserIds = const <int>{},
  }) {
    return GroupInviteNudgeJob(
      onboardingRepository: onboarding,
      membershipLookup: lookup,
      sender: sender,
      templates: const MessageTemplates(),
      targetChatId: targetChatId,
      enabled: enabled,
      adminUserIds: adminUserIds,
      nowProvider: () => now,
    );
  }

  test('looks up unknown membership and invites when user is outside the group', () async {
    final onboarding = FakeOnboardingRepository()
      ..seedUser(
        userId: 101,
        startedAt: startedAt,
        phase: OnboardingPhase.legacySkipped,
      );
    final lookup = _FakeMembershipLookup();
    final sender = FakeSender();

    await job(onboarding: onboarding, lookup: lookup, sender: sender).run();

    expect(lookup.lookups, equals(<int>[101]));
    expect(sender.messages, hasLength(1));
    expect(sender.messages.single.chatId, 101);
    expect(sender.messages.single.text, contains('Новости и общение'));
    expect(sender.messages.single.parseMode, 'HTML');
    expect(sender.messages.single.disableWebPagePreview, isTrue);
    expect(onboarding.sentNudgeKeys, contains('101::group_invite_1'));
    final markup = sender.messages.single.replyMarkup!;
    final inline = markup['inline_keyboard'] as List<dynamic>;
    final button = Map<String, Object?>.from((inline.first as List<dynamic>).first as Map);
    expect(button['text'], MessageCopy.buttonOpenGroup);
    expect(button['url'], MessageCopy.dvorGroupInviteUrl);
  });

  test('does not invite after lookup shows the user is already in the group', () async {
    final onboarding = FakeOnboardingRepository()
      ..seedUser(
        userId: 102,
        startedAt: startedAt,
        phase: OnboardingPhase.legacySkipped,
      );
    final lookup = _FakeMembershipLookup(members: const <int>{102});
    final sender = FakeSender();

    await job(onboarding: onboarding, lookup: lookup, sender: sender).run();

    expect(lookup.lookups, equals(<int>[102]));
    expect(sender.messages, isEmpty);
    expect(onboarding.sentNudgeKeys, isEmpty);
  });

  test('does not call Telegram again for a known non-member', () async {
    final onboarding = FakeOnboardingRepository()
      ..seedUser(
        userId: 103,
        startedAt: startedAt,
        phase: OnboardingPhase.legacySkipped,
        membership: GroupMembershipStatus.notMember,
      );
    final lookup = _FakeMembershipLookup();
    final sender = FakeSender();

    await job(onboarding: onboarding, lookup: lookup, sender: sender).run();

    expect(lookup.lookups, isEmpty);
    expect(sender.messages, hasLength(1));
  });

  test('skips when disabled or group chat is not configured', () async {
    final onboarding = FakeOnboardingRepository()
      ..seedUser(
        userId: 104,
        startedAt: startedAt,
        phase: OnboardingPhase.legacySkipped,
        membership: GroupMembershipStatus.notMember,
      );
    final lookup = _FakeMembershipLookup();
    final sender = FakeSender();

    await job(
      onboarding: onboarding,
      lookup: lookup,
      sender: sender,
      enabled: false,
    ).run();
    await job(
      onboarding: onboarding,
      lookup: lookup,
      sender: sender,
      targetChatId: null,
    ).run();

    expect(sender.messages, isEmpty);
    expect(lookup.lookups, isEmpty);
  });

  test('does not invite admins', () async {
    final onboarding = FakeOnboardingRepository()
      ..seedUser(
        userId: 105,
        startedAt: startedAt,
        phase: OnboardingPhase.legacySkipped,
        membership: GroupMembershipStatus.notMember,
      );
    final lookup = _FakeMembershipLookup();
    final sender = FakeSender();

    await job(
      onboarding: onboarding,
      lookup: lookup,
      sender: sender,
      adminUserIds: const <int>{105},
    ).run();

    expect(sender.messages, isEmpty);
  });
}

final class _FakeMembershipLookup implements GroupMembershipLookup {
  _FakeMembershipLookup({this.members = const <int>{}});

  final Set<int> members;
  final List<int> lookups = <int>[];

  @override
  Future<bool> isChatMember({
    required int chatId,
    required int userId,
  }) async {
    lookups.add(userId);
    return members.contains(userId);
  }
}
