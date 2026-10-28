import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Participants of one event; attendance after the start of a training.
class RosterScreen extends ConsumerWidget {
  const RosterScreen({super.key, required this.initial});

  final AdminSession initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider(initial.key));
    final session = roster.value?.session ?? initial;
    final tg = ref.watch(telegramProvider);
    final inset = ref.watch(safeAreaProvider);
    final c = context.colors;
    final when = session.category.isOutdoor
        ? Fmt.dateRange(session.startsAt, null)
        : '${Fmt.dayMonth(session.startsAt)} · ${Fmt.time(session.startsAt)}';
    return TelegramBackButton(
      onBack: () => context.pop(),
      child: Scaffold(
        body: RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surface,
          onRefresh: () async {
            ref.invalidate(rosterProvider(initial.key));
            await ref.read(rosterProvider(initial.key).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Space.gutter,
                    inset.top + Space.l,
                    Space.gutter,
                    Space.l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!tg.isAvailable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.l),
                          child: Pressable(
                            onTap: () => context.pop(),
                            semanticLabel: 'Назад',
                            child: Icon(Icons.arrow_back_rounded, color: c.ink),
                          ),
                        ),
                      Text(session.title.toUpperCase(), style: context.text.headlineMedium),
                      const SizedBox(height: Space.xs),
                      Text(
                        '$when · ${session.location}',
                        style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                      ),
                      const SizedBox(height: Space.m),
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          Pill(
                            label: session.limit != null && session.limit! > 0
                                ? 'Записано ${session.participants} из ${session.limit}'
                                : 'Записано ${session.participants}',
                            icon: Icons.person_outline_rounded,
                          ),
                          if (session.attendanceOpen && session.unmarked > 0)
                            Pill(label: 'Без отметки: ${session.unmarked}', color: c.warning),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ...switch (roster) {
                AsyncValue(:final value?) when value.participants.isEmpty => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateMessage(icon: Icons.groups_outlined, title: 'Записей нет'),
                  ),
                ],
                AsyncValue(:final value?) => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    sliver: SliverList.separated(
                      itemCount: value.participants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                      itemBuilder: (_, index) => _ParticipantTile(
                        key: ValueKey(value.participants[index].bookingId),
                        sessionKey: initial.key,
                        participant: value.participants[index],
                      ),
                    ),
                  ),
                ],
                AsyncValue(:final error?) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(rosterProvider(initial.key)),
                    ),
                  ),
                ],
                _ => [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    sliver: SliverList.separated(
                      itemCount: 4,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                      itemBuilder: (_, _) => const Skeleton(height: 64, radius: Radii.tile),
                    ),
                  ),
                ],
              },
              SliverToBoxAdapter(child: SizedBox(height: Space.xxl + inset.bottom)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantTile extends ConsumerStatefulWidget {
  const _ParticipantTile({super.key, required this.sessionKey, required this.participant});

  final String sessionKey;
  final AdminParticipant participant;

  @override
  ConsumerState<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends ConsumerState<_ParticipantTile> {
  Attendance? _busy;
  Attendance? _mark;

  @override
  void didUpdateWidget(covariant _ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.attendance != widget.participant.attendance) {
      _mark = null;
    }
  }

  Future<void> _set(Attendance attendance) async {
    final current = _mark ?? widget.participant.attendance;
    if (current == attendance || _busy != null) {
      return;
    }
    final tg = ref.read(telegramProvider);
    setState(() => _busy = attendance);
    try {
      final updated = await ref
          .read(adminActionsProvider)
          .mark(widget.sessionKey, widget.participant.bookingId, attendance);
      tg.haptic(HapticKind.success);
      if (mounted) {
        setState(() => _mark = updated.attendance);
      }
    } on ApiException catch (error) {
      tg.haptic(HapticKind.error);
      if (mounted) {
        showToast(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.participant;
    final c = context.colors;
    final mark = _mark ?? p.attendance;
    final statusColor = switch (p.status) {
      BookingStatus.pendingPayment || BookingStatus.paymentSubmitted => c.warning,
      BookingStatus.paymentRejected || BookingStatus.cancelled => c.danger,
      _ => c.inkMuted,
    };
    final details = [
      if (p.guest) 'гость',
      if (p.managedBy != null) 'записал ${p.managedBy}',
    ].join(' · ');
    return DvorCard(
      radius: Radii.tile,
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: context.text.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill(
                      label: p.boxingCard && p.status == BookingStatus.paid
                          ? 'BOXING CARD'
                          : p.status.label,
                      color: statusColor,
                      dense: true,
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (p.canMark) ...[
            const SizedBox(width: Space.s),
            _MarkButton(
              label: 'Был',
              icon: Icons.check_rounded,
              color: c.success,
              selected: mark == Attendance.attended,
              loading: _busy == Attendance.attended,
              onTap: () => _set(Attendance.attended),
            ),
            const SizedBox(width: Space.xs),
            _MarkButton(
              label: 'Не был',
              icon: Icons.close_rounded,
              color: c.danger,
              selected: mark == Attendance.absent,
              loading: _busy == Attendance.absent,
              onTap: () => _set(Attendance.absent),
            ),
          ] else if (mark != null) ...[
            const SizedBox(width: Space.s),
            Pill(
              label: mark == Attendance.attended ? 'Был' : 'Не был',
              color: mark == Attendance.attended ? c.success : c.danger,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? Pill.onColor(color) : color;
    return Pressable(
      onTap: onTap,
      haptic: HapticKind.selection,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.curve,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: Space.m),
        decoration: BoxDecoration(
          color: selected ? color : c.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : c.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
