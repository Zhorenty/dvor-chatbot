import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/bookings/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _ShowHistory extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final _showHistoryProvider = NotifierProvider<_ShowHistory, bool>(_ShowHistory.new);

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final now = ref.watch(clockProvider)();
    final inset = ref.watch(safeAreaProvider);

    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      edgeOffset: inset.top,
      onRefresh: () async {
        ref.invalidate(bookingsProvider);
        await ref.read(bookingsProvider.future);
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
                Space.m,
              ),
              child: Text('ЗАПИСИ', style: context.text.displayMedium),
            ),
          ),
          ...switch (bookings) {
            AsyncValue(:final value?) => _content(context, ref, value, now),
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(error: error, onRetry: () => ref.invalidate(bookingsProvider)),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.separated(
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.m),
                  itemBuilder: (_, _) => const Skeleton(height: 132, radius: Radii.tile),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: 110 + inset.bottom)),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, List<Booking> all, DateTime now) {
    final cutoff = now.toUtc().subtract(const Duration(hours: 3));
    final upcoming = all.where((b) => b.status.isActive && b.startsAt.isAfter(cutoff)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = all.where((b) => !upcoming.contains(b)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final showHistory = ref.watch(_showHistoryProvider);

    if (all.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.confirmation_number_outlined,
            title: 'Записей пока нет',
            body: 'Выбери тренировку или поход в афише — запись появится здесь.',
            actionLabel: 'Открыть афишу',
            onAction: () => context.go('/'),
          ),
        ),
      ];
    }

    final items = showHistory ? past.take(30).toList() : upcoming;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.m),
          child: _Segmented(
            left: 'Впереди · ${upcoming.length}',
            right: 'История',
            rightSelected: showHistory,
            onChanged: (value) => ref.read(_showHistoryProvider.notifier).set(value),
          ),
        ),
      ),
      if (items.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.event_available_rounded,
            title: showHistory ? 'Истории пока нет' : 'Впереди ничего',
            body: showHistory ? null : 'Выбери слот в афише.',
            actionLabel: showHistory ? null : 'Открыть афишу',
            onAction: showHistory ? null : () => context.go('/'),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.m),
            itemBuilder: (_, index) => BookingTicket(booking: items[index], past: showHistory),
          ),
        ),
    ];
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget segment(String label, bool selected, bool value) => Expanded(
      child: Pressable(
        onTap: () => onChanged(value),
        haptic: HapticKind.selection,
        scale: 1,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: context.text.labelLarge?.copyWith(color: selected ? c.ink : c.inkFaint),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.stroke),
      ),
      child: Row(
        children: [segment(left, !rightSelected, false), segment(right, rightSelected, true)],
      ),
    );
  }
}

/// Booking as a ticket: status tag, event, a step track for paid bookings
/// and one row of actions. No clip or opacity layers.
class BookingTicket extends ConsumerStatefulWidget {
  const BookingTicket({super.key, required this.booking, required this.past});

  final Booking booking;
  final bool past;

  @override
  ConsumerState<BookingTicket> createState() => _BookingTicketState();
}

class _BookingTicketState extends ConsumerState<BookingTicket> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final tg = ref.read(telegramProvider);
    final b = widget.booking;
    final name = splitTitleEmoji(b.title).text;
    final ok = tg.isAvailable
        ? await tg.confirm('Отменить запись на «$name»?')
        : await _fallbackConfirm(name);
    if (!ok || !mounted) {
      return;
    }
    setState(() => _cancelling = true);
    try {
      final result = await ref.read(bookingActionsProvider).cancel(b.id);
      tg.haptic(HapticKind.success);
      if (mounted) {
        final refund = result.refundPeaks ?? 0;
        showToast(context, refund > 0 ? 'Запись отменена. Вернули $refund ⛰️' : 'Запись отменена');
      }
    } on ApiException catch (error) {
      tg.haptic(HapticKind.error);
      if (mounted) {
        showToast(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  Future<bool> _fallbackConfirm(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: Text(name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final past = widget.past;
    final c = context.colors;
    final title = splitTitleEmoji(b.title);
    final statusColor = switch (b.status) {
      BookingStatus.pendingPayment || BookingStatus.paymentSubmitted => c.warning,
      BookingStatus.paymentRejected || BookingStatus.cancelled => c.danger,
      _ => c.accent,
    };
    final statusLabel = b.boxingCard && b.status == BookingStatus.paid
        ? 'BOXING CARD'
        : b.status.label;
    final when = b.category.isOutdoor
        ? '${Fmt.dayMonth(b.startsAt)} · ${b.category.shortLabel}'
        : '${Fmt.weekdayShort(ClubTime.dayOf(b.startsAt))}, ${Fmt.dayMonthShort(b.startsAt)} · ${Fmt.time(b.startsAt)}';
    final subtitle = [
      b.location,
      if (b.participant != null) 'за ${b.participant}',
      if (b.status == BookingStatus.partialPaid && b.price != null && b.prepayPercent != null)
        '${Fmt.money((b.price! * b.prepayPercent! / 100).round())} внесено · остаток на месте',
    ].where((s) => s.isNotEmpty).join(' · ');

    final actions = <Widget>[
      if (!past && b.status.needsPayment)
        _Action(label: 'Оплатить', color: c.accent, onTap: () => openBotChat(ref)),
      if (!past && b.locationUrl != null)
        _Action(label: 'Маршрут', onTap: () => ref.read(telegramProvider).openLink(b.locationUrl!)),
      if (!past && b.canCancel)
        _cancelling
            ? const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : _Action(label: 'Отменить', color: c.danger, onTap: _cancel),
    ];
    final track = past ? null : _trackFor(b.status);

    return Container(
      decoration: BoxDecoration(
        color: past ? c.background : c.surface,
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: c.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Pill(label: statusLabel, color: statusColor, dense: true),
                      const SizedBox(height: Space.s),
                      Text(
                        when.toUpperCase(),
                        style: context.text.labelMedium?.copyWith(
                          color: past ? c.inkFaint : c.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title.text.toUpperCase(),
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: past ? c.inkMuted : c.ink,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: context.text.bodyMedium?.copyWith(
                            color: c.inkFaint,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      if (past && b.attended) ...[
                        const SizedBox(height: Space.s),
                        Pill(
                          label: 'Был на тренировке',
                          icon: Icons.check_rounded,
                          color: c.success,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (title.emoji != null) ...[
                  const SizedBox(width: Space.m),
                  EventGlyph(emoji: title.emoji, category: b.category, size: 44),
                ],
              ],
            ),
          ),
          if (track != null || actions.isNotEmpty) ...[
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?track,
                  if (track != null && actions.isNotEmpty) const SizedBox(height: Space.m),
                  if (actions.isNotEmpty)
                    Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: Space.s),
                          actions[i],
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _trackFor(BookingStatus status) {
    return switch (status) {
      BookingStatus.pendingPayment => const _Track(done: 1, current: 1),
      BookingStatus.paymentRejected => const _Track(done: 1, current: 1, failed: true),
      BookingStatus.paymentSubmitted => const _Track(done: 2, current: 2),
      _ => null,
    };
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label, style: context.text.labelLarge?.copyWith(color: color ?? c.ink)),
        ),
      ),
    );
  }
}

/// Записан → Чек → Оплачено. [done] steps are filled, [current] is the one
/// waiting on someone.
class _Track extends StatelessWidget {
  const _Track({required this.done, required this.current, this.failed = false});

  final int done;
  final int current;
  final bool failed;

  static const _labels = ['Записан', 'Чек', 'Оплачено'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Color dot(int i) {
      if (i < done) {
        return c.accent;
      }
      if (i == current) {
        return failed ? c.danger : c.warning;
      }
      return c.surfaceRaised;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0)
                Expanded(child: Container(height: 2, color: i < done ? c.accent : c.stroke)),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot(i), shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Text(
                i == current && failed ? 'Чек отклонён' : _labels[i],
                style: context.text.labelSmall?.copyWith(
                  color: i == current ? dot(i) : (i < done ? c.inkMuted : c.inkFaint),
                  letterSpacing: 0.2,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Dashed tear line with notches, drawn on the card itself.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: _PerforationPainter(line: c.stroke, notch: c.background),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter({required this.line, required this.notch});

  final Color line;
  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dash = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    for (var x = 14.0; x < size.width - 14; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
    }
    final hole = Paint()..color = notch;
    canvas
      ..drawCircle(Offset(-1, y), 7, hole)
      ..drawCircle(Offset(size.width + 1, y), 7, hole);
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter old) => old.line != line || old.notch != notch;
}
