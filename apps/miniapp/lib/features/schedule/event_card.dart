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
    final low = event.lowSeats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          Fmt.price(event.price),
          style: context.text.labelLarge?.copyWith(color: event.isFree ? c.accent : c.ink),
        ),
        if (low != null) ...[
          const SizedBox(height: 4),
          Text(
            low == 0 ? 'Мест нет' : 'Осталось ${Fmt.seats(low)}',
            style: context.text.labelSmall?.copyWith(
              color: low == 0 ? c.danger : c.warning,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
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
    final low = event.lowSeats;
    final facts = [
      Fmt.price(event.price),
      if (event.prepayPercent != null && !event.isFree) 'предоплата ${event.prepayPercent}%',
      if (low != null) low == 0 ? 'мест нет' : 'осталось ${Fmt.seats(low)}',
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

/// Club's headline event (FeaturedTrainings in the bot): a large accent
/// cover above everything else on the main screen.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.event, required this.booked, required this.onTap});

  final ClubEvent event;
  final Booking? booked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = splitTitleEmoji(event.title);
    final low = event.lowSeats;
    final when = event.category.isOutdoor
        ? Fmt.dateRange(event.startsAt, event.endsAt)
        : '${Fmt.dayMonth(event.startsAt)} · ${Fmt.time(event.startsAt)}';
    final place = [event.location, ?event.coach].where((s) => s.isNotEmpty).join(' · ');
    final facts = [
      Fmt.price(event.price),
      if (low != null) low == 0 ? 'мест нет' : 'осталось ${Fmt.seats(low)}',
    ].join(' · ');
    final booking = booked;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Главное: ${title.text}',
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: coverDecoration(
          context,
          c.accent,
        ).copyWith(border: Border.all(color: c.accent, width: 1.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Pill(label: 'ГЛАВНОЕ', color: c.accent, filled: true, dense: true),
                const Spacer(),
                if (title.emoji case final emoji?) Text(emoji, style: emojiStyle(22)),
              ],
            ),
            const SizedBox(height: Space.l),
            Text(when.toUpperCase(), style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
            const SizedBox(height: 2),
            Text(
              title.text.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineMedium?.copyWith(height: 1.05),
            ),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(
                  child: Text(
                    facts,
                    style: context.text.labelLarge?.copyWith(color: low == 0 ? c.danger : c.ink),
                  ),
                ),
                if (booking != null)
                  Pill(
                    label: booking.status.needsPayment ? 'Оплатить' : 'Ты идёшь',
                    icon: booking.status.needsPayment
                        ? Icons.schedule_rounded
                        : Icons.check_rounded,
                    color: booking.status.needsPayment ? c.warning : c.accent,
                    dense: true,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Подробнее', style: context.text.labelLarge?.copyWith(color: c.accent)),
                      Icon(Icons.chevron_right_rounded, size: 18, color: c.accent),
                    ],
                  ),
              ],
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
