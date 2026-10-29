import 'dart:convert';

import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/media/image_picker.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// BOXING CARD: current card, pending request and buying or renewing.
class CardScreen extends ConsumerWidget {
  const CardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(cardOverviewProvider);
    final inset = ref.watch(safeAreaProvider);
    final c = context.colors;
    return TelegramBackButton(
      onBack: () => context.pop(),
      child: Scaffold(
        body: RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surface,
          edgeOffset: inset.top,
          onRefresh: () async {
            ref.invalidate(cardOverviewProvider);
            await ref.read(cardOverviewProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(Space.gutter, inset.top + Space.l, Space.gutter, 48),
            children: [
              if (!ref.watch(telegramProvider).isAvailable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Pressable(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_rounded, color: c.ink),
                  ),
                ),
              Text('BOXING CARD', style: context.text.displayMedium),
              const SizedBox(height: Space.xs),
              Text(
                'Абонемент на бокс: групповые тренировки и одна индивидуальная.',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Space.l),
              ...switch (overview) {
                AsyncValue(:final value?) => _content(context, value),
                AsyncValue(:final error?) => [
                  ErrorState(error: error, onRetry: () => ref.invalidate(cardOverviewProvider)),
                ],
                _ => const [
                  Skeleton(height: 160),
                  SizedBox(height: Space.m),
                  Skeleton(height: 240),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, CardOverview o) {
    final c = context.colors;
    return [
      if (o.active)
        Container(
          padding: const EdgeInsets.all(Space.l),
          decoration: coverDecoration(context, c.accent).copyWith(
            color: c.accent,
            gradient: LinearGradient(colors: [Color.lerp(c.accent, Colors.white, 0.18)!, c.accent]),
            border: Border.all(color: c.accent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'АКТИВНА · ${o.plan?.name ?? ''}',
                style: context.text.labelSmall?.copyWith(color: c.onAccent.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: Space.s),
              Text(
                o.remaining == null ? 'Действует' : 'Осталось ${o.remaining} из ${o.quota}',
                style: context.text.headlineMedium?.copyWith(color: c.onAccent),
              ),
              if (o.quota != null && o.remaining != null) ...[
                const SizedBox(height: Space.m),
                Row(
                  children: [
                    for (var i = 0; i < o.quota!; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: i < o.remaining!
                                ? c.onAccent
                                : c.onAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: Space.m),
              Text(
                [
                  if (o.activeUntil != null) 'до ${Fmt.dayMonth(o.activeUntil!)}',
                  if (o.individualUsed == true)
                    'индивидуальная использована'
                  else if (o.individualUsed == false)
                    'индивидуальная доступна',
                ].join(' · '),
                style: context.text.labelLarge?.copyWith(color: c.onAccent),
              ),
            ],
          ),
        ),
      if (o.pending) ...[
        if (o.active) const SizedBox(height: Space.m),
        DvorCard(
          color: Color.alphaBlend(c.warning.withValues(alpha: 0.1), c.surface),
          borderColor: c.warning.withValues(alpha: 0.4),
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: c.warning),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  'Заявка на проверке${o.pendingSince == null ? '' : ' с ${Fmt.dayMonth(o.pendingSince!)}'}. Ответ придёт в чат.',
                  style: context.text.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
      GroupLabel(o.active ? 'Продлить' : 'Тарифы'),
      for (final plan in o.plans) ...[
        _PlanCard(plan: plan, overview: o),
        const SizedBox(height: Space.m),
      ],
    ];
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.overview});

  final CardPlan plan;
  final CardOverview overview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = overview.active && overview.planId == plan.id;
    return Pressable(
      onTap: overview.pending
          ? null
          : () => showDvorSheet<void>(context, (_) => _BuySheet(plan: plan, overview: overview)),
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: coverDecoration(
          context,
          c.accent,
        ).copyWith(border: Border.all(color: current ? c.accent : c.stroke)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: context.text.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.trainings} ${Fmt.plural(plan.trainings, 'тренировка', 'тренировки', 'тренировок')} + ${plan.individual} индивидуальная',
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(plan.price), style: context.text.titleLarge),
                if (!overview.pending)
                  Text(
                    overview.active ? 'Продлить' : 'Оформить',
                    style: context.text.labelMedium?.copyWith(color: c.accent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuySheet extends ConsumerStatefulWidget {
  const _BuySheet({required this.plan, required this.overview});

  final CardPlan plan;
  final CardOverview overview;

  @override
  ConsumerState<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends ConsumerState<_BuySheet> {
  bool _usePeaks = false;
  bool _busy = false;
  bool _linkOpened = false;

  Future<void> _buy({PickedImage? image}) async {
    setState(() => _busy = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('card.buy', {
        'plan': widget.plan.id,
        'usePeaks': _usePeaks,
        if (image != null) 'image': base64Encode(image.bytes),
        if (image != null) 'filename': image.name,
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
    final p = widget.plan;
    final c = context.colors;
    final canPeaks = p.peaksSpend > 0;
    final free = _usePeaks && p.peaksCoverFully;
    final due = _usePeaks ? p.peaksRemainder : p.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          'BOXING CARD · ${p.name}',
          subtitle: '${p.trainings} групповых + ${p.individual} индивидуальная',
        ),
        const SizedBox(height: Space.l),
        Text(free ? '0 ₽' : Fmt.money(due), style: context.text.displayMedium),
        if (canPeaks) ...[
          const SizedBox(height: Space.m),
          OptionTile(
            icon: _usePeaks ? Icons.check_circle_rounded : Icons.landscape_rounded,
            title: 'Списать ${Fmt.number(p.peaksSpend)} ⛰️',
            subtitle: p.peaksCoverFully
                ? 'Покроет абонемент целиком'
                : 'Останется доплатить ${Fmt.money(p.peaksRemainder)}',
            tone: _usePeaks ? c.accent : c.inkMuted,
            trailing: const SizedBox.shrink(),
            onTap: () => setState(() => _usePeaks = !_usePeaks),
          ),
        ],
        const SizedBox(height: Space.xl),
        if (free)
          PrimaryButton(
            label: 'Оформить за ${Fmt.number(p.peaksSpend)} ⛰️',
            loading: _busy,
            onTap: _buy,
          )
        else ...[
          SecondaryButton(
            label: _linkOpened ? 'Оплатить ещё раз по СБП' : 'Оплатить ${Fmt.money(due)} по СБП',
            icon: Icons.open_in_new_rounded,
            expand: true,
            onTap: () {
              ref.read(telegramProvider).openLink(widget.overview.sbpLink);
              setState(() => _linkOpened = true);
            },
          ),
          const SizedBox(height: Space.s),
          PrimaryButton(
            label: 'Прикрепить чек',
            loading: _busy,
            onTap: () async {
              final image = await pickImage();
              if (image != null && mounted) {
                await _buy(image: image);
              }
            },
          ),
          const SizedBox(height: Space.s),
          Text(
            'После проверки чека абонемент включится, ответ придёт в чат.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}
