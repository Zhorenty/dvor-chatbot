import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/admin/admin_confirm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One payment in the review queue. Same decisions as the chat card.
class PaymentCard extends ConsumerStatefulWidget {
  const PaymentCard({super.key, required this.payment});

  final AdminPayment payment;

  @override
  ConsumerState<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<PaymentCard> {
  PaymentDecision? _busy;
  bool _sendingProof = false;

  Future<void> _decide(PaymentDecision decision) async {
    final p = widget.payment;
    final question = switch (decision) {
      PaymentDecision.approve => 'Подтвердить оплату #${p.id}?',
      PaymentDecision.approvePartial => 'Подтвердить предоплату #${p.id}?',
      PaymentDecision.reject =>
        'Отклонить оплату #${p.id}? Участник получит новую карточку оплаты.',
    };
    final ok = await confirmAdminAction(
      context,
      ref,
      message: question,
      confirmLabel: decision == PaymentDecision.reject ? 'Отклонить' : 'Подтвердить',
    );
    if (!ok || !mounted) {
      return;
    }
    final tg = ref.read(telegramProvider);
    // Toast outlives the card, which leaves the list after the review.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = decision);
    try {
      await ref.read(adminActionsProvider).review(p.id, decision);
      tg.haptic(decision == PaymentDecision.reject ? HapticKind.warning : HapticKind.success);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            decision == PaymentDecision.reject
                ? 'Оплата #${p.id} отклонена'
                : 'Оплата #${p.id} подтверждена',
          ),
        ),
      );
    } on ApiException catch (error) {
      tg.haptic(HapticKind.error);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _sendProof() async {
    final tg = ref.read(telegramProvider);
    setState(() => _sendingProof = true);
    try {
      await ref.read(adminActionsProvider).sendProof(widget.payment.id);
      tg.haptic(HapticKind.success);
      if (mounted) {
        showToast(context, 'Чек в чате с ботом');
      }
    } on ApiException catch (error) {
      tg.haptic(HapticKind.error);
      if (mounted) {
        showToast(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _sendingProof = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final c = context.colors;
    final tone = categoryColor(context, p.category);
    final when = p.category.isOutdoor
        ? Fmt.dayMonth(p.startsAt)
        : '${Fmt.dayMonthShort(p.startsAt)} · ${Fmt.time(p.startsAt)}';
    final approve = p.partial ? PaymentDecision.approvePartial : PaymentDecision.approve;
    final busy = _busy != null;
    final rows = <(String, String)>[
      ('Плательщик', p.organizer),
      if (p.participants.isNotEmpty) ('Участники', p.participants.join(', ')),
      if (p.partial)
        ('Тип', p.prepayPercent == null ? 'Предоплата' : 'Предоплата ${p.prepayPercent}%'),
      ('Сумма', p.total > 0 ? Fmt.money(p.total) : Fmt.price(p.price)),
      if (p.promoCode != null) ('Промокод', p.promoCode!),
      if (p.comment != null) ('Комментарий', p.comment!),
    ];
    return DvorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(p.category), size: 16, color: tone),
              const SizedBox(width: 6),
              Text(
                when.toUpperCase(),
                style: context.text.labelMedium?.copyWith(color: c.inkMuted),
              ),
              const Spacer(),
              Pill(label: '#${p.id}', dense: true),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(p.title.toUpperCase(), style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(p.location, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
          const SizedBox(height: Space.m),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: context.text.bodyMedium?.copyWith(fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.l),
          _DecisionButton(
            label: p.partial ? 'Подтвердить предоплату' : 'Подтвердить оплату',
            color: c.accent,
            loading: _busy == approve,
            onTap: busy ? null : () => _decide(approve),
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: _DecisionButton(
                  label: 'Отклонить',
                  color: c.danger,
                  loading: _busy == PaymentDecision.reject,
                  onTap: busy ? null : () => _decide(PaymentDecision.reject),
                ),
              ),
              if (p.hasProof) ...[
                const SizedBox(width: Space.s),
                Expanded(
                  child: _sendingProof
                      ? const SizedBox(
                          height: 44,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : SecondaryButton(
                          label: 'Чек в чат',
                          icon: Icons.receipt_long_outlined,
                          expand: true,
                          onTap: _sendProof,
                        ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: HapticKind.medium,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: onTap == null && !loading ? 0.5 : 1,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(color: color),
                ),
        ),
      ),
    );
  }
}
