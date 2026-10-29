import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Coaches first, then the DVOR team — the bot's «Тренерский штаб» sheet.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider);
    final inset = ref.watch(safeAreaProvider);
    final c = context.colors;
    return TelegramBackButton(
      onBack: () => context.pop(),
      child: Scaffold(
        body: ListView(
          physics: const BouncingScrollPhysics(),
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
            Text('КОМАНДА', style: context.text.displayMedium),
            ...switch (team) {
              AsyncValue(:final value?) => [
                if (value.any((p) => p.isTrainer)) const GroupLabel('Тренеры'),
                for (final p in value.where((p) => p.isTrainer)) _PersonCard(person: p),
                if (value.any((p) => !p.isTrainer)) const GroupLabel('Команда DVOR'),
                for (final p in value.where((p) => !p.isTrainer)) _PersonCard(person: p),
              ],
              AsyncValue(:final error?) => [
                ErrorState(error: error, onRetry: () => ref.invalidate(teamProvider)),
              ],
              _ => const [SizedBox(height: Space.l), Skeleton(height: 220)],
            },
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({required this.person});

  final TeamPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final link = person.link;
    final initials = person.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first)
        .join()
        .toUpperCase();
    void open() {
      if (link == null) {
        return;
      }
      final tg = ref.read(telegramProvider);
      link.contains('t.me/') ? tg.openTelegramLink(link) : tg.openLink(link);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Pressable(
        onTap: link == null ? null : open,
        scale: 0.99,
        child: DvorCard(
          radius: Radii.tile,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: person.isTrainer ? c.accent : c.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials.isEmpty ? 'D' : initials,
                  style: context.text.titleMedium?.copyWith(
                    color: person.isTrainer ? c.onAccent : c.ink,
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name, style: context.text.titleMedium),
                    if (person.role.isNotEmpty)
                      Text(person.role, style: context.text.labelMedium?.copyWith(color: c.accent)),
                    if (person.description != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        person.description!,
                        style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (link != null) Icon(Icons.send_rounded, size: 18, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
