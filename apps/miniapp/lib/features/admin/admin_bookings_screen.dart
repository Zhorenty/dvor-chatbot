import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
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
            AsyncValue(:final value?) => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                  itemBuilder: (_, i) => _AdminBookingTile(item: value[i], archived: archived),
                ),
              ),
            ],
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
    final title = splitTitleEmoji(b.title).text;
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
                  Text(
                    '$title · ${Fmt.dayMonthShort(b.startsAt)}, ${Fmt.time(b.startsAt)}',
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
            if (item.manager != null && '@${item.manager}' != item.participant)
              'записал @${item.manager}',
            if (item.promoCode != null) 'промокод ${item.promoCode}',
          ].join(' · '),
        ),
        if (item.paymentNote != null) ...[
          const SizedBox(height: Space.s),
          Text(item.paymentNote!, style: context.text.bodyMedium?.copyWith(color: c.inkFaint)),
        ],
        const GroupLabel('Статус'),
        ChoiceChips<BookingStatus>(
          options: _statusOptions,
          selected: _status,
          onSelected: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Сохранить статус',
          loading: _busy,
          onTap: _status == b.status
              ? null
              : () => _run('admin.bookings.status', {'id': b.id, 'status': _wire(_status)}),
        ),
        const SizedBox(height: Space.s),
        SecondaryButton(
          label: 'В архив',
          icon: Icons.archive_outlined,
          color: c.danger,
          expand: true,
          onTap: () async {
            if (await confirmAction(context, ref, 'Убрать запись в архив?')) {
              await _run('admin.bookings.archive', {'id': b.id});
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
        const SheetTitle('Новая запись', subtitle: 'Участнику уведомление не уходит.'),
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
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Создать',
          loading: _busy,
          onTap: _key == null || _username.text.trim().isEmpty ? null : _create,
        ),
      ],
    );
  }
}
