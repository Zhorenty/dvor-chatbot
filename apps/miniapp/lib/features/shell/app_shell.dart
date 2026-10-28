import 'dart:ui';

import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tabs with a floating glass navigation bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = ref.watch(telegramProvider).safeArea.bottom;
    final pending = (ref.watch(bookingsProvider).value ?? const [])
        .where((b) => b.status.needsPayment && b.startsAt.isAfter(DateTime.now().toUtc()))
        .length;
    final isAdmin = ref.watch(meProvider).value?.isAdmin ?? false;
    final queue = isAdmin ? (ref.watch(adminPaymentsProvider).value?.length ?? 0) : 0;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.m + bottom),
        child: SafeArea(
          top: false,
          child: _NavBar(
            index: shell.currentIndex,
            badge: pending,
            isAdmin: isAdmin,
            adminBadge: queue,
            onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onSelect,
    required this.badge,
    this.isAdmin = false,
    this.adminBadge = 0,
  });

  final int index;
  final int badge;
  final bool isAdmin;
  final int adminBadge;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, IconData, String)>[
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Афиша'),
    (Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, 'Записи'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  static const _adminItem = (
    Icons.admin_panel_settings_outlined,
    Icons.admin_panel_settings_rounded,
    'Админка',
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = isAdmin ? [..._items, _adminItem] : _items;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: c.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  // Four tabs: the selected one needs room for its label.
                  flex: items.length > 3 && i == index ? 2 : 1,
                  child: Pressable(
                    onTap: () => onSelect(i),
                    haptic: HapticKind.selection,
                    semanticLabel: items[i].$3,
                    child: AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      decoration: BoxDecoration(
                        color: i == index ? c.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Badge(
                            isLabelVisible: (i == 1 && badge > 0) || (i == 3 && adminBadge > 0),
                            label: Text('${i == 3 ? adminBadge : badge}'),
                            backgroundColor: c.warning,
                            textColor: c.onAccent,
                            child: Icon(
                              i == index ? items[i].$2 : items[i].$1,
                              size: 22,
                              color: i == index ? c.onAccent : c.inkMuted,
                            ),
                          ),
                          Flexible(
                            child: AnimatedSize(
                              duration: Motion.medium,
                              curve: Motion.curve,
                              child: i == index
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        items[i].$3,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.clip,
                                        style: context.text.labelLarge?.copyWith(color: c.onAccent),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
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
