import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/admin/admin_contact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _BookingsFilter extends Notifier<(EventCategory, bool)> {
  @override
  (EventCategory, bool) build() => (EventCategory.trainings, false);

  void set(EventCategory category, bool archived) => state = (category, archived);
}

final _filterProvider = NotifierProvider<_BookingsFilter, (EventCategory, bool)>(
  _BookingsFilter.new,
);

const _statusOptions = <(BookingStatus, String)>[
  (BookingStatus.pendingPayment, 'Ждёт оплаты'),
  (BookingStatus.paymentSubmitted, 'Чек на проверке'),
  (BookingStatus.partialPaid, 'Предоплата'),
  (BookingStatus.paid, 'Оплачено'),
  (BookingStatus.freeTraining, 'Бесплатно'),
  (BookingStatus.paymentRejected, 'Отклонено'),
  (BookingStatus.cancelled, 'Отменено'),
];

String _wire(BookingStatus status) => switch (status) {
  BookingStatus.pendingPayment => 'pending_payment',
  BookingStatus.paymentSubmitted => 'payment_submitted',
  BookingStatus.partialPaid => 'partial_paid',
  BookingStatus.paid => 'paid',
  BookingStatus.freeTraining => 'free_training',
  BookingStatus.paymentRejected => 'payment_rejected',
  BookingStatus.cancelled => 'cancelled',
};

/// All bookings by category: change status, archive, create by @username.
class AdminBookingsScreen extends ConsumerWidget {
  const AdminBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filterProvider);
    final bookings = ref.watch(adminBookingsProvider(filter));
    final inset = ref.watch(safeAreaProvider);
    final c = context.colors;
    final (category, archived) = filter;
    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.surface,
      edgeOffset: inset.top,
      onRefresh: () async {
        ref.invalidate(adminBookingsProvider(filter));
        await ref.read(adminBookingsProvider(filter).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Space.gutter, inset.top + Space.l, Space.gutter, 0),
              child: Row(
                children: [
                  Expanded(child: Text('ЗАПИСИ', style: context.text.displayMedium)),
                  Pressable(
                    onTap: () => showDvorSheet<void>(context, (_) => const _CreateBookingSheet()),
                    semanticLabel: 'Создать запись',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: Icon(Icons.person_add_alt_1_rounded, color: c.onAccent, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, 0),
              child: ChoiceChips<EventCategory>(
                options: const [
                  (EventCategory.trainings, 'Тренировки'),
                  (EventCategory.hikes, 'Походы'),
                  (EventCategory.trails, 'Кэмпы'),
                ],
                selected: category,
                onSelected: (v) => ref.read(_filterProvider.notifier).set(v, archived),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, Space.m),
              child: ChoiceChips<bool>(
                options: const [(false, 'Актуальные'), (true, 'Архив')],
                selected: archived,
                onSelected: (v) => ref.read(_filterProvider.notifier).set(category, v),
              ),
            ),
          ),
          ...switch (bookings) {
            AsyncValue(:final value?) when value.isEmpty => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(icon: Icons.inbox_outlined, title: 'Записей нет'),
              ),
            ],
            AsyncValue(:final value?) => _grouped(context, value, archived),
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(adminBookingsProvider(filter)),
                ),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.separated(
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                  itemBuilder: (_, _) => const Skeleton(height: 72, radius: Radii.tile),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: 120 + inset.bottom)),
        ],
      ),
    );
  }
}

/// One closed row per event. The people list opens on tap.
List<Widget> _grouped(BuildContext context, List<AdminBooking> all, bool archived) {
  final groups = <String, List<AdminBooking>>{};
  for (final item in all) {
    groups.putIfAbsent(item.booking.key, () => []).add(item);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final byTime = groups[a]!.first.booking.startsAt.compareTo(groups[b]!.first.booking.startsAt);
      return archived ? -byTime : byTime;
    });
  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, 0),
      sliver: SliverList.separated(
        itemCount: keys.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.s),
        itemBuilder: (_, i) => _BookingGroup(items: groups[keys[i]]!, archived: archived),
      ),
    ),
  ];
}

class _BookingGroup extends StatefulWidget {
  const _BookingGroup({required this.items, required this.archived});

  final List<AdminBooking> items;
  final bool archived;

  @override
  State<_BookingGroup> createState() => _BookingGroupState();
}

class _BookingGroupState extends State<_BookingGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final b = items.first.booking;
    final active = items.where((i) => i.booking.status.isActive).length;
    final title = splitTitleEmoji(b.title);
    final c = context.colors;
    final when = b.category.isOutdoor
        ? Fmt.dayMonth(b.startsAt)
        : '${Fmt.weekdayShort(ClubTime.dayOf(b.startsAt))}, ${Fmt.dayMonth(b.startsAt)} · ${Fmt.time(b.startsAt)}';
    return Column(
      children: [
        Pressable(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: _open ? 'Свернуть ${title.text}' : 'Развернуть ${title.text}',
          scale: 0.99,
          child: DvorCard(
            radius: Radii.tile,
            padding: const EdgeInsets.all(Space.m),
            child: Row(
              children: [
                EventGlyph(emoji: title.emoji, category: b.category, size: 34),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.text.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                      Text(when, style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                Pill(
                  label: '$active',
                  icon: Icons.person_outline_rounded,
                  color: c.accent,
                  dense: true,
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: c.inkFaint,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: Space.xs),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: Space.xs),
            _AdminBookingTile(item: items[i], archived: widget.archived),
          ],
        ],
      ],
    );
  }
}

/// Another person booked this seat. Letter case in the nick does not count.
bool _bookedByOther(AdminBooking item) {
  final manager = item.manager;
  if (manager == null) {
    return false;
  }
  return !sameTelegramNick(manager, item.participant);
}

Color _statusColor(BuildContext context, BookingStatus status) {
  final c = context.colors;
  return switch (status) {
    BookingStatus.pendingPayment || BookingStatus.paymentSubmitted => c.warning,
    BookingStatus.paymentRejected || BookingStatus.cancelled => c.danger,
    _ => c.accent,
  };
}

class _AdminBookingTile extends ConsumerWidget {
  const _AdminBookingTile({required this.item, required this.archived});

  final AdminBooking item;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = item.booking;
    final c = context.colors;
    return Pressable(
      onTap: () => showDvorSheet<void>(context, (_) => _BookingActionsSheet(item: item)),
      scale: 0.99,
      child: DvorCard(
        radius: Radii.tile,
        padding: const EdgeInsets.all(Space.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.participant, style: context.text.titleMedium),
                  if (_bookedByOther(item))
                    Text(
                      'записал @${item.manager}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Pill(label: b.status.label, color: _statusColor(context, b.status), dense: true),
          ],
        ),
      ),
    );
  }
}

class _BookingActionsSheet extends ConsumerStatefulWidget {
  const _BookingActionsSheet({required this.item});

  final AdminBooking item;

  @override
  ConsumerState<_BookingActionsSheet> createState() => _BookingActionsSheetState();
}

class _BookingActionsSheetState extends ConsumerState<_BookingActionsSheet> {
  late BookingStatus _status = widget.item.booking.status;
  bool _notify = true;
  bool _busy = false;

  Future<void> _run(String method, Map<String, Object?> params) async {
    setState(() => _busy = true);
    final result = await runAction(context, ref, () => ref.read(rpcProvider).call(method, params));
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (result != null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final b = item.booking;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          item.participant,
          subtitle: [
            splitTitleEmoji(b.title).text,
            '${Fmt.dayMonth(b.startsAt)}, ${Fmt.time(b.startsAt)}',
            if (b.price != null) Fmt.price(b.price),
            if (_bookedByOther(item)) 'записал @${item.manager}',
            if (item.promoCode != null) 'промокод ${item.promoCode}',
          ].join(' · '),
        ),
        if (item.paymentNote != null) ...[
          const SizedBox(height: Space.s),
          Text(item.paymentNote!, style: context.text.bodyMedium?.copyWith(color: c.inkFaint)),
        ],
        if (item.contactUserId != null || item.contactUsername != null) ...[
          const SizedBox(height: Space.m),
          SecondaryButton(
            label: 'Написать участнику',
            icon: Icons.chat_bubble_outline_rounded,
            expand: true,
            onTap: () => openMemberProfile(
              context,
              ref,
              userId: item.contactUserId,
              username: item.contactUsername,
              about: '${splitTitleEmoji(b.title).text}, ${Fmt.dayMonth(b.startsAt)}',
            ),
          ),
        ],
        const GroupLabel('Статус'),
        ChoiceChips<BookingStatus>(
          options: _statusOptions,
          selected: _status,
          onSelected: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: Space.m),
        _NotifySwitch(value: _notify, onChanged: (v) => setState(() => _notify = v)),
        const SizedBox(height: Space.l),
        PrimaryButton(
          label: 'Сохранить статус',
          loading: _busy,
          onTap: _status == b.status
              ? null
              : () => _run('admin.bookings.status', {
                  'id': b.id,
                  'status': _wire(_status),
                  'notify': _notify,
                }),
        ),
        const SizedBox(height: Space.s),
        SecondaryButton(
          label: 'В архив',
          icon: Icons.archive_outlined,
          color: c.danger,
          expand: true,
          onTap: () async {
            if (await confirmAction(context, ref, 'Убрать запись в архив?')) {
              await _run('admin.bookings.archive', {'id': b.id, 'notify': _notify});
            }
          },
        ),
      ],
    );
  }
}

class _CreateBookingSheet extends ConsumerStatefulWidget {
  const _CreateBookingSheet();

  @override
  ConsumerState<_CreateBookingSheet> createState() => _CreateBookingSheetState();
}

class _CreateBookingSheetState extends ConsumerState<_CreateBookingSheet> {
  final _username = TextEditingController();
  String? _key;
  BookingStatus _status = BookingStatus.paid;
  bool _notify = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _username.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('admin.bookings.create', {
        'key': _key,
        'username': _username.text.trim(),
        'status': _wire(_status),
        'notify': _notify,
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (result != null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider).value ?? const <ClubEvent>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Новая запись'),
        const GroupLabel('Участник'),
        DvorTextField(controller: _username, hint: 'username', prefixText: '@'),
        const GroupLabel('Событие'),
        ChoiceChips<String?>(
          options: [
            for (final e in events)
              (e.key, '${splitTitleEmoji(e.title).text} · ${Fmt.dayMonthShort(e.startsAt)}'),
          ],
          selected: _key,
          onSelected: (v) => setState(() => _key = v),
        ),
        const GroupLabel('Статус'),
        ChoiceChips<BookingStatus>(
          options: _statusOptions.where((o) => o.$1 != BookingStatus.cancelled).toList(),
          selected: _status,
          onSelected: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: Space.m),
        _NotifySwitch(value: _notify, onChanged: (v) => setState(() => _notify = v)),
        const SizedBox(height: Space.l),
        PrimaryButton(
          label: 'Создать',
          loading: _busy,
          onTap: _key == null || _username.text.trim().isEmpty ? null : _create,
        ),
      ],
    );
  }
}

/// Whether the bot tells the member about the change, like the chat's
/// «уведомить клиента» step.
class _NotifySwitch extends StatelessWidget {
  const _NotifySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Уведомить участника', style: context.text.titleMedium),
              Text(
                'Бот напишет участнику в чат',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: c.accent),
      ],
    );
  }
}
