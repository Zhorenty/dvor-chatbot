import 'dart:ui';

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

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final filter = ref.watch(categoryFilterProvider);
    final booked = ref.watch(bookedKeysProvider);
    final now = ref.watch(clockProvider)();
    final inset = ref.watch(telegramProvider).safeArea;

    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
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
          SliverPersistentHeader(pinned: true, delegate: _FilterBarDelegate(topInset: inset.top)),
          ...switch (events) {
            AsyncValue(:final value?) => _content(context, ref, value, filter, booked, now),
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(error: error, onRetry: () => ref.invalidate(eventsProvider)),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, 0),
                sliver: SliverList.separated(
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.m),
                  itemBuilder: (_, _) => const EventCardSkeleton(),
                ),
              ),
            ],
          },
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    List<ClubEvent> all,
    EventCategory? filter,
    Map<String, Booking> booked,
    DateTime now,
  ) {
    final events = filter == null ? all : all.where((e) => e.category == filter).toList();
    if (events.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateMessage(
            icon: Icons.event_busy_rounded,
            title: filter == null ? 'Пока пусто' : '${filter.label}: пока пусто',
            body: 'Расписание обновляется. Загляни чуть позже.',
            actionLabel: filter == null ? null : 'Показать всё',
            onAction: filter == null
                ? null
                : () => ref.read(categoryFilterProvider.notifier).select(null),
          ),
        ),
      ];
    }
    final byDay = <DateTime, List<ClubEvent>>{};
    for (final event in events) {
      byDay.putIfAbsent(ClubTime.dayOf(event.startsAt), () => []).add(event);
    }
    final days = byDay.keys.toList()..sort();
    return [
      for (final day in days) ...[
        SliverToBoxAdapter(
          child: _DayHeader(day: day, now: now),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.separated(
            itemCount: byDay[day]!.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.m),
            itemBuilder: (context, index) {
              final event = byDay[day]![index];
              return EventCard(
                event: event,
                booked: booked[event.key],
                onTap: () => context.push('/event', extra: event),
              );
            },
          ),
        ),
      ],
    ];
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final name = ref.watch(meProvider).value?.firstName;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, topInset + Space.l, Space.gutter, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DvorLogo(height: 20),
              const Spacer(),
              AnimatedOpacity(
                opacity: name == null ? 0 : 1,
                duration: Motion.medium,
                child: Text(
                  name == null || name.isEmpty ? '' : 'Привет, $name',
                  style: context.text.labelLarge?.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('АФИША', style: context.text.displayLarge),
          const SizedBox(height: Space.s),
          Text(
            'Тренировки, походы и трейлы. Выбирай слот — запись в пару касаний.',
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = Fmt.dayTitle(day, now);
    final isNamed = title == 'Сегодня' || title == 'Завтра';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            (isNamed ? title : title.split(',').first).toUpperCase(),
            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: Space.s),
          Text(
            Fmt.dayMonth(day.subtract(ClubTime.offset)),
            style: context.text.labelLarge?.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({required this.topInset});

  final double topInset;

  static const double _barHeight = 60;

  @override
  double get minExtent => _barHeight;

  @override
  double get maxExtent => _barHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: c.background.withValues(alpha: overlapsContent ? 0.82 : 1),
          alignment: Alignment.center,
          child: const _FilterChips(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => oldDelegate.topInset != topInset;
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
      (EventCategory.trails, 'Трейлы'),
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
        duration: Motion.medium,
        curve: Motion.curve,
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
