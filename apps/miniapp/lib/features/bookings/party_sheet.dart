import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/payment/payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Max friends per booking, same as the bot (`maxManagedGuestsPerEvent`).
const int maxFriends = 5;

/// Book friends (by @username) and guests (by name), optionally with
/// yourself. One payment covers the whole group.
Future<void> showPartySheet(BuildContext context, ClubEvent event, {required bool selfBooked}) {
  return showDvorSheet<void>(context, (_) => _PartySheet(event: event, selfBooked: selfBooked));
}

class _Friend {
  _Friend() : controller = TextEditingController();

  bool guest = false;
  final TextEditingController controller;
}

class _PartySheet extends ConsumerStatefulWidget {
  const _PartySheet({required this.event, required this.selfBooked});

  final ClubEvent event;
  final bool selfBooked;

  @override
  ConsumerState<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends ConsumerState<_PartySheet> {
  late bool _self = !widget.selfBooked;
  final List<_Friend> _friends = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _addFriend();
  }

  void _addFriend() {
    final friend = _Friend();
    friend.controller.addListener(() => setState(() {}));
    _friends.add(friend);
  }

  @override
  void dispose() {
    for (final f in _friends) {
      f.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final telegram = <String>[];
    final guests = <String>[];
    for (final f in _friends) {
      final value = f.controller.text.trim().replaceFirst('@', '');
      if (value.isEmpty) {
        continue;
      }
      (f.guest ? guests : telegram).add(value);
    }
    if (telegram.isEmpty && guests.isEmpty) {
      showToast(context, 'Добавь хотя бы одного друга.');
      return;
    }
    setState(() => _busy = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('booking.party', {
        'key': widget.event.key,
        'self': _self,
        'telegram': telegram,
        'guests': guests,
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (result == null) {
      return;
    }
    final pending = (result['bookings'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(Booking.fromJson)
        .where((b) => b.status.needsPayment)
        .toList();
    final navigator = Navigator.of(context);
    navigator.pop();
    if (pending.isNotEmpty && navigator.context.mounted) {
      await showPaymentSheet(navigator.context, pending.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final price = widget.event.price;
    final count =
        (_self ? 1 : 0) + _friends.where((f) => f.controller.text.trim().isNotEmpty).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Записать друзей',
          subtitle: 'До $maxFriends человек. Одна оплата за всех.',
        ),
        if (!widget.selfBooked) ...[
          const SizedBox(height: Space.m),
          OptionTile(
            icon: _self ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            title: 'И меня тоже',
            tone: _self ? c.accent : c.inkMuted,
            trailing: const SizedBox.shrink(),
            onTap: () => setState(() => _self = !_self),
          ),
        ],
        const GroupLabel('Кого'),
        for (final (i, f) in _friends.indexed) ...[
          Row(
            children: [
              Expanded(
                child: DvorTextField(
                  controller: f.controller,
                  hint: f.guest ? 'Имя гостя' : 'username в Telegram',
                  prefixText: f.guest ? null : '@',
                ),
              ),
              const SizedBox(width: Space.s),
              Pressable(
                onTap: () => setState(() => f.guest = !f.guest),
                semanticLabel: f.guest ? 'Гость без Telegram' : 'Друг в Telegram',
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.stroke),
                  ),
                  child: Text(
                    f.guest ? 'Гость' : 'Telegram',
                    style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
              if (_friends.length > 1)
                IconButton(
                  onPressed: () => setState(() => _friends.removeAt(i).controller.dispose()),
                  icon: Icon(Icons.close_rounded, color: c.inkFaint),
                ),
            ],
          ),
          const SizedBox(height: Space.s),
        ],
        if (_friends.length < maxFriends)
          SecondaryButton(
            label: 'Ещё человек',
            icon: Icons.add_rounded,
            expand: true,
            onTap: () => setState(_addFriend),
          ),
        const SizedBox(height: Space.s),
        Text(
          'Гость — тот, у кого нет Telegram.',
          style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 12.5),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: price == null || price <= 0 || count == 0
              ? 'Записать'
              : 'Записать · ${Fmt.money(price * count)}',
          loading: _busy,
          onTap: _submit,
        ),
      ],
    );
  }
}
