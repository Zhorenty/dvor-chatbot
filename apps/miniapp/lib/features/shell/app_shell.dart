import 'dart:math' as math;

import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One bottom-bar tab: outline icon, filled icon when active, a name for
/// screen readers and an optional counter.
@immutable
class NavTab {
  const NavTab(this.icon, this.activeIcon, this.label, {this.badge = 0});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

/// Member tabs: schedule, bookings, profile.
class MemberShell extends ConsumerWidget {
  const MemberShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)().toUtc();
    final pending = (ref.watch(bookingsProvider).value ?? const [])
        .where((b) => b.status.needsPayment && b.startsAt.isAfter(now))
        .toList();
    final seen = ref.watch(seenBookingNoticesProvider);
    final unread = pending.where((b) => !seen.contains(b.id)).length;
    if (shell.currentIndex == 1) {
      final fresh = pending.where((b) => !seen.contains(b.id)).map((b) => b.id);
      if (fresh.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ref.read(seenBookingNoticesProvider.notifier).mark(fresh);
          }
        });
      }
    }
    return _Shell(
      shell: shell,
      tabs: [
        const NavTab(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Афиша'),
        NavTab(
          Icons.confirmation_number_outlined,
          Icons.confirmation_number_rounded,
          'Записи',
          badge: unread,
        ),
        const NavTab(Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
      ],
    );
  }
}

/// Admin tabs: payments, attendance, schedule, bookings, tools.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(adminPaymentsProvider).value?.length ?? 0;
    final cards = ref.watch(adminCardRequestsProvider).value?.length ?? 0;
    final unmarked = (ref.watch(adminSessionsProvider).value ?? const [])
        .where((s) => s.attendanceOpen && s.unmarked > 0)
        .length;
    return _Shell(
      shell: shell,
      tabs: [
        NavTab(
          Icons.receipt_long_outlined,
          Icons.receipt_long_rounded,
          'Оплаты',
          badge: queue + cards,
        ),
        NavTab(Icons.fact_check_outlined, Icons.fact_check_rounded, 'Явка', badge: unmarked),
        const NavTab(Icons.edit_calendar_outlined, Icons.edit_calendar_rounded, 'Расписание'),
        const NavTab(
          Icons.confirmation_number_outlined,
          Icons.confirmation_number_rounded,
          'Записи',
        ),
        const NavTab(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Инструменты'),
      ],
    );
  }
}

class _Shell extends ConsumerWidget {
  const _Shell({required this.shell, required this.tabs});

  final StatefulNavigationShell shell;
  final List<NavTab> tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = ref.watch(safeAreaProvider).bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          shell,
          const Offstage(child: _KeptAdminIcons()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: Space.m + bottom),
          child: Center(
            heightFactor: 1,
            child: _NavBar(
              tabs: tabs,
              index: shell.currentIndex,
              onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only floating bar. The lime disc slides under the active icon; no
/// blur, one light shadow.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.tabs, required this.index, required this.onSelect});

  final List<NavTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  static const double _slot = 58;
  static const double _height = 58;
  static const double _disc = 46;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slot = math.min(_slot, (MediaQuery.sizeOf(context).width - 16) / tabs.length);
    return Container(
      height: _height + 12,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.stroke, c.surface),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: c.stroke),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: SizedBox(
        width: slot * tabs.length,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: Motion.medium,
              curve: Curves.easeOutBack,
              left: index * slot + (slot - _disc) / 2,
              top: (_height - _disc) / 2,
              width: _disc,
              height: _disc,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 12)],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _NavIcon(
                    tab: tabs[i],
                    active: i == index,
                    width: slot,
                    height: _height,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.tab,
    required this.active,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final NavTab tab;
  final bool active;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: HapticKind.selection,
      scale: 0.9,
      semanticLabel: tab.label,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  active ? tab.activeIcon : tab.icon,
                  key: ValueKey(active),
                  size: 24,
                  color: active ? c.onAccent : c.inkMuted,
                ),
              ),
              if (tab.badge > 0)
                Positioned(
                  right: -9,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.warning,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Color.alphaBlend(c.stroke, c.surface), width: 2),
                    ),
                    child: Text(
                      tab.badge > 99 ? '99+' : '${tab.badge}',
                      style: context.text.labelSmall?.copyWith(
                        color: const Color(0xFF0D0E0B),
                        fontSize: 10,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icons that live only in the deferred admin chunk. Referenced from the
/// main library so the release web font still contains their glyphs.
class _KeptAdminIcons extends StatelessWidget {
  const _KeptAdminIcons();

  static const _icons = <IconData>[
    Icons.add_photo_alternate_outlined,
    Icons.archive_outlined,
    Icons.calendar_today_rounded,
    Icons.campaign_rounded,
    Icons.delete_outline_rounded,
    Icons.edit_outlined,
    Icons.event_note_outlined,
    Icons.filter_alt_rounded,
    Icons.groups_outlined,
    Icons.image_rounded,
    Icons.inbox_outlined,
    Icons.insights_rounded,
    Icons.keyboard_arrow_down,
    Icons.keyboard_arrow_up,
    Icons.lock_outline_rounded,
    Icons.person_add_alt_1_rounded,
    Icons.person_search_rounded,
    Icons.rate_review_rounded,
    Icons.task_alt_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [for (final icon in _icons) Icon(icon, size: 1)]);
  }
}
