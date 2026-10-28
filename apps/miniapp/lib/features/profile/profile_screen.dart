import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/bookings/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Club links shared with the bot copy (`MessageCopy`).
abstract final class ClubLinks {
  static const String group = 'https://t.me/+n4ksCb3kFRQ5MTcy';
  static const String instagram = 'https://www.instagram.com/dvor.sport/';
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final inset = ref.watch(telegramProvider).safeArea;
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      onRefresh: () async {
        ref.invalidate(meProvider);
        await ref.read(meProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(Space.gutter, inset.top + Space.xl, Space.gutter, 120),
        children: switch (me) {
          AsyncValue(:final value?) => _content(context, ref, value),
          AsyncValue(:final error?) => [
            ErrorState(error: error, onRetry: () => ref.invalidate(meProvider)),
          ],
          _ => const [
            Skeleton(height: 72, width: 72, radius: 36),
            SizedBox(height: Space.l),
            Skeleton(height: 28, width: 180),
            SizedBox(height: Space.xl),
            Skeleton(height: 96),
            SizedBox(height: Space.m),
            Skeleton(height: 140),
          ],
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, Me me) {
    final c = context.colors;
    final tg = ref.read(telegramProvider);
    return [
      Row(
        children: [
          _Avatar(me: me),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [me.firstName, me.lastName].whereType<String>().join(' ').toUpperCase(),
                  style: context.text.headlineMedium,
                ),
                if (me.username != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${me.username}',
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.xl),
      Row(
        children: [
          Expanded(
            child: _Stat(value: '${me.peaks}', label: 'Вершинки', highlight: true),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: _Stat(
              value: '${me.visits}',
              label: Fmt.plural(me.visits, 'Тренировка', 'Тренировки', 'Тренировок'),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: _Stat(value: '${me.invited}', label: 'Друзей позвал'),
          ),
        ],
      ),
      if (me.referralLink != null) ...[
        const SizedBox(height: Space.m),
        _ReferralCard(link: me.referralLink!),
      ],
      const SizedBox(height: Space.xl),
      Text('DVOR', style: context.text.labelSmall?.copyWith(color: c.inkFaint)),
      const SizedBox(height: Space.s),
      DvorCard(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          children: [
            _LinkRow(
              icon: Icons.forum_outlined,
              title: 'Чат DVOR',
              subtitle: 'Новости, анонсы, свои',
              onTap: () => tg.openTelegramLink(ClubLinks.group),
            ),
            Divider(height: 1, color: c.stroke, indent: 62),
            _LinkRow(
              icon: Icons.photo_camera_outlined,
              title: 'Instagram',
              subtitle: '@dvor.sport',
              onTap: () => tg.openLink(ClubLinks.instagram),
            ),
            Divider(height: 1, color: c.stroke, indent: 62),
            _LinkRow(
              icon: Icons.smart_toy_outlined,
              title: me.isAdmin ? 'Бот и админка' : 'Чат с ботом',
              subtitle: me.isAdmin ? 'Оплаты, списки, рассылки' : 'Оплаты, бонусы, промокоды',
              onTap: () => openBotChat(ref),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.xxl),
      const Center(child: DvorLogo(height: 18)),
    ];
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.55)]),
      ),
      child: Text(me.initials, style: context.text.headlineMedium?.copyWith(color: c.onAccent)),
    );
    final url = me.photoUrl;
    if (url == null) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.highlight = false});

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DvorCard(
      padding: const EdgeInsets.all(Space.m + 2),
      radius: Radii.tile,
      color: highlight ? c.accent : null,
      borderColor: highlight ? c.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
            duration: Motion.slow * 2,
            curve: Motion.curve,
            builder: (context, v, _) => Text(
              v.round().toString(),
              style: context.text.headlineMedium?.copyWith(color: highlight ? c.onAccent : c.ink),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              fontSize: 11,
              height: 1.2,
              color: highlight ? c.onAccent.withValues(alpha: 0.75) : c.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends ConsumerWidget {
  const _ReferralCard({required this.link});

  final String link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tg = ref.read(telegramProvider);
    final share = Uri.https('t.me', '/share/url', {
      'url': link,
      'text': 'Тренируюсь с DVOR. Залетай:',
    }).toString();
    return DvorCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ПОЗОВИ ДРУГА', style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Ссылка ведёт в бота — приглашение засчитается тебе.',
                  style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Pressable(
            onTap: () => tg.openTelegramLink(share),
            semanticLabel: 'Поделиться ссылкой',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.ios_share_rounded, color: c.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.accent),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  Text(
                    subtitle,
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}
