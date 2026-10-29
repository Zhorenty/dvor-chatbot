import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// BOXING CARD request awaiting review. Approve and reject run the same
/// chat commands as the admin buttons, so the member gets the usual notice.
class CardRequestCard extends ConsumerStatefulWidget {
  const CardRequestCard({super.key, required this.request});

  final CardRequest request;

  @override
  ConsumerState<CardRequestCard> createState() => _CardRequestCardState();
}

class _CardRequestCardState extends ConsumerState<CardRequestCard> {
  bool _busy = false;

  Future<void> _review({required bool approve, String? reason, String? comment}) async {
    setState(() => _busy = true);
    await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('admin.cards.review', {
        'id': widget.request.id,
        'approve': approve,
        'reason': ?reason,
        'comment': ?comment,
      }),
      success: approve ? 'BOXING CARD подтверждена' : 'Заявка отклонена',
    );
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final picked = await showDvorSheet<(String, String)>(context, (sheet) => const _RejectSheet());
    if (picked != null) {
      await _review(approve: false, reason: picked.$1, comment: picked.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final c = context.colors;
    return DvorCard(
      radius: Radii.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(label: 'BOXING CARD', color: c.accent, dense: true),
              const SizedBox(width: Space.s),
              Text(
                Fmt.dayMonthShort(r.createdAt),
                style: context.text.labelMedium?.copyWith(color: c.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(
            '${r.planName ?? 'Тариф'} · ${r.username == null ? 'без username' : '@${r.username}'}',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (r.price != null) Fmt.money(r.price!),
              if (r.peaksSpent > 0) 'списано ${Fmt.number(r.peaksSpent)} ⛰️',
              if (!r.hasProof) 'без чека',
            ].join(' · '),
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          if (r.note != null) ...[
            const SizedBox(height: Space.s),
            Text('«${r.note}»', style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(height: Space.m),
          if (_busy)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Отклонить',
                    color: c.danger,
                    expand: true,
                    onTap: _reject,
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: SecondaryButton(
                    label: 'Подтвердить',
                    color: c.accent,
                    expand: true,
                    onTap: () => _review(approve: true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String _reason = 'not_confirmed';
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Отклонить заявку', subtitle: 'Причина уйдёт участнику в чат.'),
        const GroupLabel('Причина'),
        ChoiceChips<String>(
          options: const [
            ('not_confirmed', 'Чек не подтверждён'),
            ('wrong_amount', 'Сумма не совпадает'),
            ('duplicate', 'Дубликат'),
          ],
          selected: _reason,
          onSelected: (v) => setState(() => _reason = v),
        ),
        const GroupLabel('Комментарий'),
        DvorTextField(controller: _comment, hint: 'Необязательно', maxLines: 3),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Отклонить',
          onTap: () => Navigator.pop(context, (_reason, _comment.text.trim())),
        ),
      ],
    );
  }
}
