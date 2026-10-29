import 'dart:convert';

import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/media/image_picker.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pay for one booking without leaving the app: SBP link, receipt photo,
/// peaks and promo code. Each action runs through the bot, so admins get
/// the usual notices and the chat keeps a copy.
Future<void> showPaymentSheet(BuildContext context, int bookingId) {
  return showDvorSheet<void>(context, (_) => _PaymentSheet(bookingId: bookingId));
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.bookingId});

  final int bookingId;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _promo = TextEditingController();
  String _choice = 'full';
  String? _busy;
  bool _paidLinkOpened = false;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _act(String key, String method, [Map<String, Object?> extra = const {}]) async {
    setState(() => _busy = key);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call(method, {'bookingId': widget.bookingId, ...extra}),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = null);
    final booking = result?['booking'];
    if (booking is Map<String, Object?> &&
        !BookingStatus.parse(booking['status']).needsPayment &&
        mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _attachReceipt() async {
    final image = await pickImage();
    if (image == null || !mounted) {
      return;
    }
    await _act('receipt', 'payment.receipt', {
      'choice': _choice,
      'image': base64Encode(image.bytes),
      'filename': image.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(paymentOptionsProvider(widget.bookingId));
    return switch (options) {
      AsyncValue(:final value?) => _content(value),
      AsyncValue(:final error?) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(paymentOptionsProvider(widget.bookingId)),
      ),
      _ => const Column(
        children: [
          Skeleton(height: 40),
          SizedBox(height: Space.m),
          Skeleton(height: 220),
        ],
      ),
    };
  }

  Widget _content(PaymentOptions o) {
    final c = context.colors;
    final b = o.booking;
    final title = b == null ? 'Оплата' : splitTitleEmoji(b.title).text;
    final subtitle = b == null
        ? null
        : '${b.category.isOutdoor ? Fmt.dayMonth(b.startsAt) : '${Fmt.dayMonth(b.startsAt)}, ${Fmt.time(b.startsAt)}'}'
              '${o.participants > 1 ? ' · ${o.participants} участника' : ''}';
    if (!o.payable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(title, subtitle: subtitle),
          const SizedBox(height: Space.l),
          StateMessage(
            icon: Icons.receipt_long_rounded,
            title: b?.status.label ?? 'Оплата не нужна',
            body: b?.status == BookingStatus.paymentSubmitted
                ? 'Чек у администратора. Ответ придёт в чат и сюда.'
                : null,
          ),
        ],
      );
    }
    final partial = o.outdoorChoice && _choice == 'partial';
    final due = partial ? (o.prepayAmount ?? o.amount) : o.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(title, subtitle: subtitle),
        const SizedBox(height: Space.l),
        Text(Fmt.money(due), style: context.text.displayMedium),
        if (partial)
          Text(
            'Предоплата ${o.prepayPercent}% · остаток ${Fmt.money(o.amount - due)} на месте',
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
        if (o.outdoorChoice) ...[
          const SizedBox(height: Space.m),
          ChoiceChips<String>(
            options: [
              ('full', 'Полностью · ${Fmt.money(o.amount)}'),
              ('partial', 'Предоплата ${o.prepayPercent}% · ${Fmt.money(o.prepayAmount ?? 0)}'),
            ],
            selected: _choice,
            onSelected: (v) => setState(() => _choice = v),
          ),
        ],
        if (o.peaksAvailable || o.promo) const GroupLabel('Скидки'),
        if (o.peaksAvailable) ...[
          OptionTile(
            icon: Icons.landscape_rounded,
            title: 'Списать ${Fmt.number(o.peaksSpend)} ⛰️',
            subtitle: o.peaksCoverFully
                ? 'Покроет тренировку целиком'
                : 'Останется доплатить ${Fmt.money(o.peaksRemainder ?? 0)}',
            busy: _busy == 'peaks',
            onTap: () => _act('peaks', 'payment.peaks'),
          ),
          const SizedBox(height: Space.s),
        ],
        if (o.promo)
          Row(
            children: [
              Expanded(
                child: DvorTextField(controller: _promo, hint: 'Промокод'),
              ),
              const SizedBox(width: Space.s),
              SecondaryButton(
                label: _busy == 'promo' ? '…' : 'Применить',
                color: c.accent,
                onTap: () {
                  if (_promo.text.trim().isNotEmpty && _busy == null) {
                    _act('promo', 'payment.promo', {'code': _promo.text.trim()});
                  }
                },
              ),
            ],
          ),
        const GroupLabel('Оплата по СБП'),
        _Step(
          number: 1,
          done: _paidLinkOpened,
          child: SecondaryButton(
            label: 'Оплатить ${Fmt.money(due)} по СБП',
            icon: Icons.open_in_new_rounded,
            expand: true,
            onTap: () {
              ref.read(telegramProvider).openLink(o.sbpLink);
              setState(() => _paidLinkOpened = true);
            },
          ),
        ),
        const SizedBox(height: Space.s),
        _Step(
          number: 2,
          child: PrimaryButton(
            label: 'Прикрепить чек',
            loading: _busy == 'receipt',
            onTap: _busy == null ? _attachReceipt : null,
          ),
        ),
        const SizedBox(height: Space.s),
        Text(
          'Скриншот или фото чека уйдёт администратору. Ответ придёт в чат.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.child, this.done = false});

  final int number;
  final Widget child;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        AnimatedContainer(
          duration: Motion.fast,
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? c.accent : c.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: done ? c.accent : c.stroke),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 16, color: c.onAccent)
              : Text('$number', style: context.text.labelMedium),
        ),
        const SizedBox(width: Space.m),
        Expanded(child: child),
      ],
    );
  }
}
