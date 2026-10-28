import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/schedule/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Selected day in the week strip (club-local midnight as UTC), or null.
class DayFilter extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void toggle(DateTime day) => state = state == day ? null : day;

  void clear() => state = null;
}

final dayFilterProvider = NotifierProvider<DayFilter, DateTime?>(DayFilter.new);

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final inset = ref.watch(safeAreaProvider);

    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      edgeOffset: inset.top,
      onRefresh: () async {
        ref
          ..invalidate(eventsProvider)
          ..invalidate(bookingsProvider);
        await ref.read(eventsProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _Header(topInset: inset.top)),
          const SliverToBoxAdapter(child: _NextBooking()),
          if (events.value case final all?) SliverToBoxAdapter(child: _DayStrip(events: all)),
          const SliverPersistentHeader(pinned: true, delegate: _FilterBarDelegate()),
          ...switch (events) {
            AsyncValue(:final value?) => _content(context, ref, value),
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(error: error, onRetry: () => ref.invalidate(eventsProvider)),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, 0),
                sliver: SliverList.separated(
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                  itemBuilder: (_, _) => const EventCardSkeleton(),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: 110 + inset.bottom)),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, List<ClubEvent> all) {
    final filter = ref.watch(categoryFilterProvider);
    final day = ref.watch(dayFilterProvider);
    final booked = ref.watch(bookedKeysProvider);
    final now = ref.watch(clockProvider)();

    bool onDay(ClubEvent e) {
      if (day == null) {
        return true;
      }
      final start = ClubTime.dayOf(e.startsAt);
      final end = e.endsAt == null ? start : ClubTime.dayOf(e.endsAt!);
      return !day.isBefore(start) && !day.isAfter(end);
    }

    final visible = all.where((e) => (filter == null || e.category == filter) && onDay(e)).toList();
    final outdoor = visible.where((e) => e.category.isOutdoor).toList();
    final trainings = visible.where((e) => !e.category.isOutdoor).toList();

    void open(ClubEvent e) => context.push('/event', extra: e);

    if (visible.isEmpty) {
      final filtered = filter != null || day != null;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.event_busy_rounded,
            title: filtered ? 'Здесь пока пусто' : 'Расписание пустое',
            body: 'Расписание обновляется. Загляни чуть позже.',
            actionLabel: filtered ? 'Показать всё' : null,
            onAction: filtered
                ? () {
                    ref.read(categoryFilterProvider.notifier).select(null);
                    ref.read(dayFilterProvider.notifier).clear();
                  }
                : null,
          ),
        ),
      ];
    }

    final byDay = <DateTime, List<ClubEvent>>{};
    for (final e in trainings) {
      byDay.putIfAbsent(ClubTime.dayOf(e.startsAt), () => []).add(e);
    }
    final days = byDay.keys.toList()..sort();
    // Only outdoor events: a vertical list of covers reads better than a strip.
    final outdoorAsList = trainings.isEmpty;

    return [
      if (outdoor.isNotEmpty && !outdoorAsList) ...[
        const SliverToBoxAdapter(child: _SectionLabel('Выезды')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              itemCount: outdoor.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.s),
              itemBuilder: (context, i) => OutdoorCard(
                event: outdoor[i],
                booked: booked[outdoor[i].key],
                width: outdoor.length == 1
                    ? MediaQuery.sizeOf(context).width - 2 * Space.gutter
                    : 272,
                onTap: () => open(outdoor[i]),
              ),
            ),
          ),
        ),
      ],
      if (outdoorAsList)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, 0),
          sliver: SliverList.separated(
            itemCount: outdoor.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.s),
            itemBuilder: (_, i) => OutdoorCard(
              event: outdoor[i],
              booked: booked[outdoor[i].key],
              onTap: () => open(outdoor[i]),
            ),
          ),
        ),
      for (final d in days) ...[
        SliverToBoxAdapter(child: _SectionLabel(_dayLabel(d, now))),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.separated(
            itemCount: byDay[d]!.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.s),
            itemBuilder: (context, i) {
              final e = byDay[d]![i];
              return EventCard(event: e, booked: booked[e.key], onTap: () => open(e));
            },
          ),
        ),
      ],
    ];
  }

  static String _dayLabel(DateTime day, DateTime now) {
    final title = Fmt.dayTitle(day, now);
    final date = Fmt.dayMonth(day.subtract(ClubTime.offset));
    return title == 'Сегодня' || title == 'Завтра' ? '$title · $date' : title;
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final me = ref.watch(meProvider).value;
    final name = me?.firstName ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, topInset + Space.m, Space.gutter, Space.m),
      child: Row(
        children: [
          const DvorLogo(height: 18),
          const Spacer(),
          if (name.isNotEmpty) ...[
            Text('Привет, $name', style: context.text.labelLarge?.copyWith(color: c.inkMuted)),
            const SizedBox(width: Space.s),
          ],
          Pressable(
            onTap: () => context.go('/profile'),
            semanticLabel: 'Профиль',
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: Text(
                me?.initials ?? 'D',
                style: context.text.labelMedium?.copyWith(
                  color: c.onAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lime card with the nearest own booking; hidden when there is none.
class _NextBooking extends ConsumerWidget {
  const _NextBooking();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final now = ref.watch(clockProvider)().toUtc();
    final bookings = ref.watch(bookingsProvider).value ?? const <Booking>[];
    final upcoming =
        bookings
            .where((b) => b.status.isActive && b.participant == null && b.startsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (upcoming.isEmpty) {
      return const SizedBox.shrink();
    }
    final b = upcoming.first;
    final title = splitTitleEmoji(b.title).text;
    final when = b.category.isOutdoor
        ? Fmt.dayMonth(b.startsAt)
        : '${Fmt.dayTitle(ClubTime.dayOf(b.startsAt), now)} · ${Fmt.time(b.startsAt)}';
    final status = b.status.needsPayment ? 'Ждёт оплаты' : '${b.status.label} ✓';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.m),
      child: Pressable(
        onTap: () => context.go('/bookings'),
        semanticLabel: 'Ближайшая запись: $title',
        child: Container(
          padding: const EdgeInsets.all(Space.l),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'БЛИЖАЙШАЯ ЗАПИСЬ',
                style: context.text.labelSmall?.copyWith(color: c.onAccent.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 4),
              Text(
                when.toUpperCase(),
                style: context.text.headlineMedium?.copyWith(color: c.onAccent),
              ),
              const SizedBox(height: 2),
              Text(
                [title, b.location].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(color: c.onAccent),
              ),
              const SizedBox(height: Space.s),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.onAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text(status, style: context.text.labelMedium?.copyWith(color: c.onAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Next two weeks; dots mark days with events, tap filters by day.
class _DayStrip extends ConsumerWidget {
  const _DayStrip({required this.events});

  final List<ClubEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(dayFilterProvider);
    final now = ref.watch(clockProvider)();
    final today = ClubTime.today(now);
    final busy = <DateTime>{};
    for (final e in events) {
      final last = ClubTime.dayOf(e.endsAt ?? e.startsAt);
      for (
        var d = ClubTime.dayOf(e.startsAt);
        !d.isAfter(last);
        d = d.add(const Duration(days: 1))
      ) {
        busy.add(d);
      }
    }
    final days = List.generate(14, (i) => today.add(Duration(days: i)));
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final d = days[i];
          final on = d == selected;
          final has = busy.contains(d);
          return Pressable(
            onTap: () => ref.read(dayFilterProvider.notifier).toggle(d),
            haptic: HapticKind.selection,
            semanticLabel: Fmt.dayTitle(d, now),
            child: AnimatedContainer(
              duration: Motion.fast,
              width: 46,
              decoration: BoxDecoration(
                color: on ? c.ink : c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? c.ink : c.stroke),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Fmt.weekdayShort(d).toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: on ? c.background.withValues(alpha: 0.6) : c.inkFaint,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: on ? c.background : (has ? c.ink : c.inkFaint),
                      height: 1.15,
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: has ? (on ? c.background : c.accent) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.s),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.inkFaint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Pinned category chips on a solid background: no blur, nothing re-rendered
/// beneath it while scrolling.
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  const _FilterBarDelegate();

  static const double _height = 56;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: overlapsContent ? c.stroke : Colors.transparent)),
      ),
      child: const _FilterChips(),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => false;
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(categoryFilterProvider);
    final options = <(EventCategory?, String)>[
      (null, 'Все'),
      (EventCategory.trainings, 'Тренировки'),
      (EventCategory.hikes, 'Походы'),
      (EventCategory.trails, 'Кэмпы'),
    ];
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 10),
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(width: Space.s),
      itemBuilder: (context, index) {
        final (category, label) = options[index];
        return _Chip(
          label: label,
          selected: selected == category,
          onTap: () => ref.read(categoryFilterProvider.notifier).select(category),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

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
        duration: Motion.fast,
        curve: Motion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: selected ? c.accent : c.stroke),
        ),
        child: Text(
          label,
          style: context.text.labelLarge?.copyWith(
            color: selected ? c.onAccent : c.ink,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
