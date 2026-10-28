import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Schedule row: glyph, time and title, price or "booked" on the right.
/// Single layout pass, no clips or opacity layers.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.booked, required this.onTap});

  final ClubEvent event;
  final Booking? booked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = splitTitleEmoji(event.title);
    final place = [event.location, ?event.coach].where((s) => s.isNotEmpty).join(' · ');
    final booking = booked;
    return Pressable(
      onTap: onTap,
      semanticLabel: '${title.text}, ${Fmt.time(event.startsAt)}',
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.tile),
          border: Border.all(color: booking != null ? c.accent.withValues(alpha: 0.6) : c.stroke),
        ),
        child: Row(
          children: [
            EventGlyph(emoji: title.emoji, category: event.category),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.time(event.startsAt),
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    title.text.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(fontSize: 13.5),
                  ),
                  if (place.isNotEmpty)
                    Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            booking != null ? _BookedMark(booking: booking) : _PriceAndSeats(event: event),
          ],
        ),
      ),
    );
  }
}

class _BookedMark extends StatelessWidget {
  const _BookedMark({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final waiting = booking.status.needsPayment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: waiting ? c.warning : c.accent, shape: BoxShape.circle),
          child: Icon(
            waiting ? Icons.schedule_rounded : Icons.check_rounded,
            size: 14,
            color: c.onAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          waiting ? 'Оплатить' : 'Ты идёшь',
          style: context.text.labelSmall?.copyWith(
            color: waiting ? c.warning : c.accent,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _PriceAndSeats extends StatelessWidget {
  const _PriceAndSeats({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seats = event.seatsLeft;
    final limit = event.limit;
    final tone = seats == 0 ? c.danger : (seats != null && seats <= 3 ? c.warning : c.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          Fmt.price(event.price),
          style: context.text.labelLarge?.copyWith(color: event.isFree ? c.accent : c.ink),
        ),
        if (seats != null && limit != null) ...[
          const SizedBox(height: 6),
          _SeatsBar(ratio: 1 - seats / limit, color: tone),
          const SizedBox(height: 3),
          Text(
            seats == 0 ? 'Мест нет' : Fmt.seats(seats),
            style: context.text.labelSmall?.copyWith(
              color: seats <= 3 ? tone : c.inkFaint,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _SeatsBar extends StatelessWidget {
  const _SeatsBar({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 4,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        widthFactor: ratio.clamp(0.04, 1),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Hike or camp cover for the "Выезды" strip and the outdoor filter.
class OutdoorCard extends StatelessWidget {
  const OutdoorCard({
    super.key,
    required this.event,
    required this.booked,
    required this.onTap,
    this.width,
  });

  final ClubEvent event;
  final Booking? booked;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = categoryColor(context, event.category);
    final title = splitTitleEmoji(event.title);
    final seats = event.seatsLeft;
    final facts = [
      Fmt.price(event.price),
      if (event.prepayPercent != null && !event.isFree) 'предоплата ${event.prepayPercent}%',
      if (seats != null) seats == 0 ? 'мест нет' : Fmt.seats(seats),
    ].join(' · ');
    return Pressable(
      onTap: onTap,
      semanticLabel: '${event.category.shortLabel} ${title.text}',
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(Space.l),
        decoration: coverDecoration(
          context,
          tone,
        ).copyWith(border: Border.all(color: booked != null ? tone : c.stroke)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Pill(
                  label: event.category.shortLabel.toUpperCase(),
                  color: tone,
                  filled: true,
                  dense: true,
                ),
                const Spacer(),
                if (booked != null)
                  Pill(label: 'Ты едешь', icon: Icons.check_rounded, color: tone, dense: true),
              ],
            ),
            const SizedBox(height: Space.l),
            Text(
              Fmt.dateRange(event.startsAt, event.endsAt).toUpperCase(),
              style: context.text.labelMedium?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: 2),
            Text(
              title.text.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
            ),
            const SizedBox(height: 4),
            Text(
              facts,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const DvorCard(
      padding: EdgeInsets.all(Space.m),
      radius: Radii.tile,
      child: Row(
        children: [
          Skeleton(width: 40, height: 40),
          SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 14, width: 48),
                SizedBox(height: 6),
                Skeleton(height: 14, width: 150),
                SizedBox(height: 6),
                Skeleton(height: 10, width: 110),
              ],
            ),
          ),
          Skeleton(height: 14, width: 44),
        ],
      ),
    );
  }
}
