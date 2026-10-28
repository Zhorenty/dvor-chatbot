import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/admin/payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _AdminTab { payments, sessions }

/// Payment review and rosters. Writes go through the bot, so users get the
/// same chat notices as from the chat admin buttons.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  _AdminTab _tab = _AdminTab.payments;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final inset = ref.watch(telegramProvider).safeArea;
    if (me != null && !me.isAdmin) {
      return const Center(
        child: StateMessage(icon: Icons.lock_outline_rounded, title: 'Раздел для админов'),
      );
    }
    final payments = ref.watch(adminPaymentsProvider);
    final count = payments.value?.length;
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () async {
        if (_tab == _AdminTab.payments) {
          ref.invalidate(adminPaymentsProvider);
          await ref.read(adminPaymentsProvider.future);
        } else {
          ref.invalidate(adminSessionsProvider);
          await ref.read(adminSessionsProvider.future);
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                inset.top + Space.xl,
                Space.gutter,
                Space.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('АДМИНКА', style: context.text.displayLarge),
                  const SizedBox(height: Space.l),
                  Row(
                    children: [
                      _TabChip(
                        label: count == null || count == 0 ? 'Оплаты' : 'Оплаты · $count',
                        selected: _tab == _AdminTab.payments,
                        onTap: () => setState(() => _tab = _AdminTab.payments),
                      ),
                      const SizedBox(width: Space.s),
                      _TabChip(
                        label: 'Списки',
                        selected: _tab == _AdminTab.sessions,
                        onTap: () => setState(() => _tab = _AdminTab.sessions),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ...switch (_tab) {
            _AdminTab.payments => _payments(payments),
            _AdminTab.sessions => _sessions(ref.watch(adminSessionsProvider)),
          },
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  List<Widget> _payments(AsyncValue<List<AdminPayment>> payments) {
    return switch (payments) {
      AsyncValue(:final value?) when value.isEmpty => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.task_alt_rounded,
            title: 'Очередь пуста',
            body: 'Новые чеки появятся здесь и в чате админов.',
          ),
        ),
      ],
      AsyncValue(:final value?) => [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.m),
            itemBuilder: (_, index) =>
                PaymentCard(key: ValueKey(value[index].id), payment: value[index]),
          ),
        ),
      ],
      AsyncValue(:final error?) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(error: error, onRetry: () => ref.invalidate(adminPaymentsProvider)),
        ),
      ],
      _ => [_skeletons()],
    };
  }

  List<Widget> _sessions(AsyncValue<List<AdminSession>> sessions) {
    return switch (sessions) {
      AsyncValue(:final value?) when value.isEmpty => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.groups_outlined,
            title: 'Событий нет',
            body: 'Здесь будут ближайшие события и тренировки за неделю.',
          ),
        ),
      ],
      AsyncValue(:final value?) => _sessionList(value),
      AsyncValue(:final error?) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(error: error, onRetry: () => ref.invalidate(adminSessionsProvider)),
        ),
      ],
      _ => [_skeletons()],
    };
  }

  List<Widget> _sessionList(List<AdminSession> all) {
    final now = ref.read(clockProvider)().toUtc();
    final past = all.where((s) => !s.startsAt.isAfter(now)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final upcoming = all.where((s) => s.startsAt.isAfter(now)).toList();
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.m),
      child: Text(title, style: context.text.labelSmall?.copyWith(color: context.colors.inkFaint)),
    );
    Widget list(List<AdminSession> items) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.s),
        itemBuilder: (context, index) => _SessionTile(
          session: items[index],
          onTap: () => context.push('/admin/session', extra: items[index]),
        ),
      ),
    );
    return [
      if (past.isNotEmpty) ...[
        SliverToBoxAdapter(child: section('ПРОШЛИ · ОТМЕТЬ ЯВКУ')),
        list(past),
      ],
      if (upcoming.isNotEmpty) ...[SliverToBoxAdapter(child: section('ВПЕРЕДИ')), list(upcoming)],
    ];
  }

  Widget _skeletons() => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    sliver: SliverList.separated(
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: Space.m),
      itemBuilder: (_, _) => const DvorCard(child: Skeleton(height: 96)),
    ),
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: HapticKind.selection,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: selected ? c.accent : c.stroke),
        ),
        child: Text(
          label,
          style: context.text.labelLarge?.copyWith(color: selected ? c.onAccent : c.ink),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final AdminSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    final tone = categoryColor(context, s.category);
    final when = s.category.isOutdoor
        ? Fmt.dayMonth(s.startsAt)
        : '${Fmt.dayMonthShort(s.startsAt)} · ${Fmt.time(s.startsAt)}';
    final count = s.limit != null && s.limit! > 0
        ? '${s.participants}/${s.limit}'
        : '${s.participants}';
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: DvorCard(
        radius: Radii.tile,
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        child: Row(
          children: [
            Icon(categoryIcon(s.category), size: 18, color: tone),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      text: when,
                      children: [
                        if (s.attendanceOpen && s.unmarked > 0)
                          TextSpan(
                            text: ' · без отметки: ${s.unmarked}',
                            style: TextStyle(color: c.warning),
                          ),
                      ],
                    ),
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Pill(label: count, icon: Icons.person_outline_rounded, dense: true),
            Icon(Icons.chevron_right_rounded, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}
