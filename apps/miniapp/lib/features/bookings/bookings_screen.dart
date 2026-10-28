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

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final now = ref.watch(clockProvider)();
    final inset = ref.watch(telegramProvider).safeArea;

    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
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
                inset.top + Space.xl,
                Space.gutter,
                Space.s,
              ),
              child: Text('МОИ ЗАПИСИ', style: context.text.displayLarge),
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
                padding: const EdgeInsets.all(Space.gutter),
                sliver: SliverList.separated(
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.m),
                  itemBuilder: (_, _) => const DvorCard(child: Skeleton(height: 96)),
                ),
              ),
            ],
          },
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
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

    if (all.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.event_available_rounded,
            title: 'Записей пока нет',
            body: 'Выбери тренировку или поход в афише — запись появится здесь.',
            actionLabel: 'Открыть афишу',
            onAction: () => context.go('/'),
          ),
        ),
      ];
    }

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.m),
      child: Text(title, style: context.text.labelSmall?.copyWith(color: context.colors.inkFaint)),
    );

    return [
      if (upcoming.isNotEmpty) ...[
        SliverToBoxAdapter(child: section('ВПЕРЕДИ · ${upcoming.length}')),
        _list(upcoming, past: false),
      ],
      if (past.isNotEmpty) ...[
        SliverToBoxAdapter(child: section('ИСТОРИЯ')),
        _list(past.take(20).toList(), past: true),
      ],
    ];
  }

  Widget _list(List<Booking> items, {required bool past}) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.m),
        itemBuilder: (_, index) => BookingCard(booking: items[index], past: past),
      ),
    );
  }
}

class BookingCard extends ConsumerStatefulWidget {
  const BookingCard({super.key, required this.booking, required this.past});

  final Booking booking;
  final bool past;

  @override
  ConsumerState<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<BookingCard> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final tg = ref.read(telegramProvider);
    final b = widget.booking;
    final ok = tg.isAvailable
        ? await tg.confirm('Отменить запись на «${b.title}»?')
        : await _fallbackConfirm(b);
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

  Future<bool> _fallbackConfirm(Booking b) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: Text(b.title),
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
    final c = context.colors;
    final tone = categoryColor(context, b.category);
    final statusColor = switch (b.status) {
      BookingStatus.pendingPayment || BookingStatus.paymentSubmitted => c.warning,
      BookingStatus.paymentRejected || BookingStatus.cancelled => c.danger,
      _ => c.accent,
    };
    final actions = <Widget>[
      if (!widget.past && b.status.needsPayment)
        Expanded(
          child: SecondaryButton(
            label: 'Оплатить',
            icon: Icons.account_balance_wallet_outlined,
            color: c.accent,
            expand: true,
            onTap: () => openBotChat(ref),
          ),
        ),
      if (!widget.past && b.locationUrl != null)
        Expanded(
          child: SecondaryButton(
            label: 'Маршрут',
            icon: Icons.near_me_outlined,
            expand: true,
            onTap: () => ref.read(telegramProvider).openLink(b.locationUrl!),
          ),
        ),
      if (!widget.past && b.canCancel)
        Expanded(
          child: _cancelling
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : SecondaryButton(label: 'Отменить', color: c.danger, expand: true, onTap: _cancel),
        ),
    ];

    return Opacity(
      opacity: widget.past ? 0.62 : 1,
      child: DvorCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon(b.category), size: 16, color: tone),
                const SizedBox(width: 6),
                Text(
                  (b.category.isOutdoor
                          ? Fmt.dayMonth(b.startsAt)
                          : '${Fmt.dayMonthShort(b.startsAt)} · ${Fmt.time(b.startsAt)}')
                      .toUpperCase(),
                  style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                ),
                const Spacer(),
                Pill(
                  label: b.boxingCard && b.status == BookingStatus.paid
                      ? 'BOXING CARD'
                      : b.status.label,
                  color: statusColor,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Text(b.title.toUpperCase(), style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(b.location, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
            if (b.participant != null) ...[
              const SizedBox(height: 4),
              Text(
                'За кого: ${b.participant}',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
            ],
            if (b.status == BookingStatus.paymentSubmitted && !widget.past) ...[
              const SizedBox(height: Space.s),
              Text(
                'Чек у администратора. Пришлём ответ в чат.',
                style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 13),
              ),
            ],
            if (widget.past && b.attended) ...[
              const SizedBox(height: Space.s),
              Pill(
                label: 'Был на тренировке',
                icon: Icons.check_rounded,
                color: c.success,
                dense: true,
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: Space.l),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: Space.s),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
