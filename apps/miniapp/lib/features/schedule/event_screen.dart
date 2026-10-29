import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/bookings/booking_sheet.dart';
import 'package:dvor_miniapp/features/bookings/party_sheet.dart';
import 'package:dvor_miniapp/features/payment/payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key, required this.initial});

  final ClubEvent initial;

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  bool _busy = false;

  ClubEvent get _event {
    final fresh = ref.watch(eventsProvider).value;
    if (fresh == null) {
      return widget.initial;
    }
    for (final e in fresh) {
      if (e.key == widget.initial.key) {
        return e;
      }
    }
    return widget.initial;
  }

  Future<void> _book(ClubEvent event) async {
    final tg = ref.read(telegramProvider);
    setState(() => _busy = true);
    try {
      final result = await ref.read(bookingActionsProvider).book(event.key);
      tg.haptic(HapticKind.success);
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      await showBookingResultSheet(context, ref, event: event, result: result);
    } on ApiException catch (error) {
      tg.haptic(HapticKind.error);
      if (mounted) {
        showToast(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final booked = ref.watch(bookedKeysProvider)[event.key];
    final c = context.colors;
    final tone = categoryColor(context, event.category);
    final inset = ref.watch(safeAreaProvider);
    final tg = ref.watch(telegramProvider);

    final MainButtonState? buttonState;
    if (booked != null) {
      buttonState = booked.status.needsPayment ? const MainButtonState(text: 'Оплатить') : null;
    } else if (event.isFull) {
      buttonState = const MainButtonState(text: 'Мест нет', enabled: false);
    } else {
      buttonState = MainButtonState(
        text: event.isFree ? 'Записаться' : 'Записаться · ${Fmt.price(event.price)}',
        loading: _busy,
      );
    }

    void onMain() {
      if (booked != null) {
        showPaymentSheet(context, booked.id);
      } else {
        _book(event);
      }
    }

    return TelegramBackButton(
      onBack: () => context.pop(),
      child: Scaffold(
        bottomNavigationBar: TelegramMainButton(state: buttonState, onTap: onMain),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  Space.gutter,
                  inset.top + Space.l,
                  Space.gutter,
                  Space.xl,
                ),
                constraints: BoxConstraints(minHeight: 230 + inset.top),
                decoration: coverDecoration(context, tone, radius: 0).copyWith(
                  border: Border(bottom: BorderSide(color: c.stroke)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!tg.isAvailable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.l),
                        child: Pressable(
                          onTap: () => context.pop(),
                          child: Icon(Icons.arrow_back_rounded, color: c.ink),
                        ),
                      ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.chip),
                            border: Border.all(color: tone, width: 1.5),
                          ),
                          child: Text(
                            event.category.shortLabel.toUpperCase(),
                            style: context.text.labelMedium?.copyWith(color: tone),
                          ),
                        ),
                        const Spacer(),
                        if (booked != null)
                          Pill(
                            label: booked.status.label,
                            color: booked.status.needsPayment ? c.warning : c.accent,
                            filled: !booked.status.needsPayment,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.l),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            splitTitleEmoji(event.title).text.toUpperCase(),
                            style: context.text.displayMedium,
                          ),
                        ),
                        if (splitTitleEmoji(event.title).emoji case final emoji?) ...[
                          const SizedBox(width: Space.m),
                          Text(emoji, style: const TextStyle(fontSize: 34, height: 1)),
                        ],
                      ],
                    ),
                    const SizedBox(height: Space.m),
                    Text(
                      event.category.isOutdoor
                          ? Fmt.dateRange(event.startsAt, event.endsAt)
                          : '${Fmt.dayTitle(ClubTime.dayOf(event.startsAt), ref.read(clockProvider)())}, ${Fmt.time(event.startsAt)}',
                      style: context.text.titleLarge?.copyWith(color: tone),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.list(
                children: [
                  const SizedBox(height: Space.l),
                  _FactsCard(event: event),
                  if (!event.isFull) ...[
                    const SizedBox(height: Space.m),
                    OptionTile(
                      icon: Icons.group_add_rounded,
                      title: booked == null ? 'Записать друзей' : 'Записать ещё друзей',
                      subtitle: 'До 5 человек, одна оплата за всех',
                      onTap: () => showPartySheet(context, event, selfBooked: booked != null),
                    ),
                  ],
                  if (event.lowSeats != null) ...[
                    const SizedBox(height: Space.m),
                    _SeatsCard(event: event),
                  ],
                  for (final (title, body) in [
                    ('О событии', event.description),
                    ('Что взять', event.equipment),
                    ('Программа', event.itinerary),
                    ('Важно', event.notes),
                  ])
                    if (body != null) ...[
                      const SizedBox(height: Space.xl),
                      Text(
                        title.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(color: c.inkFaint),
                      ),
                      const SizedBox(height: Space.s),
                      Text(body, style: context.text.bodyLarge),
                    ],
                  if (booked == null && !event.isFree && event.price != null) ...[
                    const SizedBox(height: Space.xl),
                    _HowToPay(event: event),
                  ],
                  SizedBox(height: Space.xxl + inset.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactsCard extends ConsumerWidget {
  const _FactsCard({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final rows = <Widget>[
      _FactRow(
        icon: Icons.place_outlined,
        label: 'Где',
        value: event.location.isEmpty ? 'Уточняется' : event.location,
        trailing: event.locationUrl == null
            ? null
            : Pressable(
                onTap: () => ref.read(telegramProvider).openLink(event.locationUrl!),
                child: Pill(label: 'Карта', icon: Icons.near_me_rounded, color: c.accent),
              ),
      ),
      _FactRow(
        icon: Icons.payments_outlined,
        label: 'Стоимость',
        value: Fmt.price(event.price),
        hint: event.prepayPercent != null && !event.isFree
            ? 'Можно внести предоплату ${event.prepayPercent}%'
            : null,
      ),
      if (event.coach != null)
        _FactRow(icon: Icons.sports_outlined, label: 'Тренер', value: event.coach!),
    ];
    return DvorCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.stroke),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.m),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: c.inkMuted),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelMedium?.copyWith(color: c.inkFaint)),
                const SizedBox(height: 2),
                Text(value, style: context.text.titleMedium),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Shown only when seats run low (see [ClubEvent.lowSeats]).
class _SeatsCard extends StatelessWidget {
  const _SeatsCard({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = event.lowSeats!;
    final tone = left == 0 ? c.danger : c.warning;
    return DvorCard(
      color: Color.alphaBlend(tone.withValues(alpha: 0.10), c.surface),
      borderColor: tone.withValues(alpha: 0.45),
      child: Row(
        children: [
          Icon(
            left == 0 ? Icons.event_busy_rounded : Icons.local_fire_department_rounded,
            color: tone,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              left == 0 ? 'Мест нет' : 'Места заканчиваются: осталось ${Fmt.seats(left)}',
              style: context.text.titleMedium?.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPay extends StatelessWidget {
  const _HowToPay({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final steps = <String>[
      'Жми «Записаться» — место закрепится за тобой.',
      'Оплати по СБП прямо отсюда — ссылка на экране оплаты.',
      'Прикрепи скриншот чека. После проверки запись станет «Оплачено».',
    ];
    return DvorCard(
      color: c.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('КАК ЭТО РАБОТАЕТ', style: context.text.labelSmall?.copyWith(color: c.inkFaint)),
          const SizedBox(height: Space.m),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: context.text.labelMedium?.copyWith(color: c.onAccent),
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(child: Text(steps[i], style: context.text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
