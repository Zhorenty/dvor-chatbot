import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Schedule row: big time on the left, facts on the right.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.booked, required this.onTap});

  final ClubEvent event;
  final Booking? booked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return event.category.isOutdoor
        ? _OutdoorCard(event: event, booked: booked, onTap: onTap)
        : _TrainingCard(event: event, booked: booked, onTap: onTap);
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.event, required this.booked, required this.onTap});

  final ClubEvent event;
  final Booking? booked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = categoryColor(context, event.category);
    return Pressable(
      onTap: onTap,
      semanticLabel: '${event.title}, ${Fmt.time(event.startsAt)}',
      child: DvorCard(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.m, Space.l),
        borderColor: booked != null ? tone.withValues(alpha: 0.55) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Fmt.time(event.startsAt),
                        maxLines: 1,
                        softWrap: false,
                        style: context.text.headlineMedium?.copyWith(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 3,
                margin: const EdgeInsets.only(right: Space.m),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    _Meta(icon: Icons.place_outlined, text: event.location),
                    if (event.coach != null) ...[
                      const SizedBox(height: 2),
                      _Meta(icon: Icons.sports_outlined, text: event.coach!),
                    ],
                    const SizedBox(height: Space.s),
                    _Badges(event: event, booked: booked),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutdoorCard extends StatelessWidget {
  const _OutdoorCard({required this.event, required this.booked, required this.onTap});

  final ClubEvent event;
  final Booking? booked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = categoryColor(context, event.category);
    return Pressable(
      onTap: onTap,
      semanticLabel: '${event.category.shortLabel} ${event.title}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tone.withValues(alpha: 0.28), c.surface, c.surface],
              stops: const [0, 0.55, 1],
            ),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: booked != null ? tone.withValues(alpha: 0.6) : c.stroke),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -10,
                child: Icon(
                  categoryIcon(event.category),
                  size: 120,
                  color: tone.withValues(alpha: 0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.l + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Pill(
                          label: event.category.shortLabel.toUpperCase(),
                          color: tone,
                          filled: true,
                          dense: true,
                        ),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(
                            Fmt.dateRange(event.startsAt, event.endsAt).toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.m),
                    Text(
                      event.title.toUpperCase(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineMedium,
                    ),
                    if (event.location.isNotEmpty) ...[
                      const SizedBox(height: Space.s),
                      _Meta(icon: Icons.place_outlined, text: event.location),
                    ],
                    const SizedBox(height: Space.m),
                    _Badges(event: event, booked: booked),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 14, color: c.inkFaint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.event, required this.booked});

  final ClubEvent event;
  final Booking? booked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seats = event.seatsLeft;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (booked != null)
          Pill(
            label: booked!.status.needsPayment ? 'Ждёт оплаты' : 'Ты записан',
            icon: booked!.status.needsPayment ? Icons.schedule_rounded : Icons.check_rounded,
            color: booked!.status.needsPayment ? c.warning : c.accent,
            filled: !booked!.status.needsPayment,
            dense: true,
          ),
        Pill(label: Fmt.price(event.price), dense: true, color: event.isFree ? c.success : null),
        if (seats != null && booked == null)
          Pill(
            label: seats == 0 ? 'Мест нет' : 'Осталось ${Fmt.seats(seats)}',
            dense: true,
            color: seats == 0 ? c.danger : (seats <= 3 ? c.warning : null),
          ),
      ],
    );
  }
}

class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const DvorCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 52, height: 24),
          SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 16, width: 160),
                SizedBox(height: Space.s),
                Skeleton(height: 12, width: 120),
                SizedBox(height: Space.m),
                Row(
                  children: [
                    Skeleton(height: 22, width: 64),
                    SizedBox(width: 6),
                    Skeleton(height: 22, width: 90),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
