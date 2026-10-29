import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _optionsProvider = FutureProvider.autoDispose.family<List<ClubEvent>, int>((ref, id) async {
  final json = await ref.watch(repositoryProvider).rpc('booking.rescheduleOptions', {
    'bookingId': id,
  });
  return (json['events'] as List<Object?>? ?? const [])
      .whereType<Map<String, Object?>>()
      .map(ClubEvent.fromJson)
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
});

/// Move a training booking to another slot with the same price rules as
/// the chat (free stays free, BOXING CARD stays on boxing).
Future<void> showRescheduleSheet(BuildContext context, Booking booking) {
  return showDvorSheet<void>(context, (_) => _RescheduleSheet(booking: booking));
}

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  String? _busyKey;

  Future<void> _move(ClubEvent target) async {
    setState(() => _busyKey = target.key);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('booking.reschedule', {
        'bookingId': widget.booking.id,
        'key': target.key,
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busyKey = null);
    if (result != null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(_optionsProvider(widget.booking.id));
    final from = widget.booking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          'Перенести',
          subtitle:
              '${splitTitleEmoji(from.title).text} · ${Fmt.dayMonthShort(from.startsAt)}, ${Fmt.time(from.startsAt)}',
        ),
        const SizedBox(height: Space.l),
        switch (options) {
          AsyncValue(:final value?) when value.isEmpty => const StateMessage(
            icon: Icons.event_busy_rounded,
            title: 'Перенести некуда',
            body: 'Подходящих тренировок пока нет.',
          ),
          AsyncValue(:final value?) => Column(
            children: [
              for (final e in value) ...[
                OptionTile(
                  icon: Icons.east_rounded,
                  title: splitTitleEmoji(e.title).text,
                  subtitle:
                      '${Fmt.dayTitle(ClubTime.dayOf(e.startsAt), ref.read(clockProvider)())}, ${Fmt.time(e.startsAt)} · ${e.location}',
                  busy: _busyKey == e.key,
                  onTap: _busyKey == null ? () => _move(e) : null,
                ),
                const SizedBox(height: Space.s),
              ],
            ],
          ),
          AsyncValue(:final error?) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(_optionsProvider(widget.booking.id)),
          ),
          _ => const Skeleton(height: 160),
        },
      ],
    );
  }
}
