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
    final inset = ref.watch(safeAreaProvider);
    return RefreshIndicator(
      color: context.colors.accent,
      backgroundColor: context.colors.surface,
      edgeOffset: inset.top,
      onRefresh: () async {
        ref.invalidate(meProvider);
        await ref.read(meProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          inset.top + Space.l,
          Space.gutter,
          120 + inset.bottom,
        ),
        children: switch (me) {
          AsyncValue(:final value?) => _content(context, ref, value),
          AsyncValue(:final error?) => [
            ErrorState(error: error, onRetry: () => ref.invalidate(meProvider)),
          ],
          _ => const [
            Skeleton(height: 56, width: 56, radius: 28),
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
                const SizedBox(height: 2),
                Text(
                  [
                    if (me.username != null) '@${me.username}',
                    '${me.visits} ${Fmt.plural(me.visits, 'тренировка', 'тренировки', 'тренировок')}',
                  ].join(' · '),
                  style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.xl),
      _PeaksCard(me: me),
      if (me.peaksHistory.isNotEmpty) ...[
        const SizedBox(height: Space.s),
        _PeaksHistory(history: me.peaksHistory),
      ],
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
              subtitle: me.isAdmin
                  ? 'Рассылки, расписание, аналитика'
                  : 'Оплаты, бонусы, промокоды',
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
      width: 56,
      height: 56,
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
        width: 56,
        height: 56,
        cacheWidth: 168,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Balance with its ruble value (2 ⛰️ = 1 ₽) and when it burns.
class _PeaksCard extends StatelessWidget {
  const _PeaksCard({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expires = me.peaksExpireAt;
    final rub = me.peaks ~/ 2;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: coverDecoration(context, c.accent).copyWith(
        color: c.accent,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c.accent, Colors.white, 0.18)!, c.accent],
        ),
        border: Border.all(color: c.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ВЕРШИНКИ',
            style: context.text.labelSmall?.copyWith(color: c.onAccent.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: me.peaks.toDouble()),
            duration: Motion.slow * 2,
            curve: Motion.curve,
            builder: (context, v, _) => Text(
              '${Fmt.number(v.round())} ⛰️',
              style: context.text.displayMedium?.copyWith(color: c.onAccent),
            ),
          ),
          Text(
            me.peaks > 0
                ? '≈ ${Fmt.money(rub)} · 2 ⛰️ = 1 ₽'
                : 'Копятся за тренировки, отзывы и друзей',
            style: context.text.labelLarge?.copyWith(color: c.onAccent.withValues(alpha: 0.75)),
          ),
          if (expires != null && me.peaks > 0) ...[
            const SizedBox(height: Space.m),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.onAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Сгорят ${Fmt.dayMonth(expires)}, если не будет активности',
                style: context.text.labelMedium?.copyWith(color: c.onAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeaksHistory extends StatelessWidget {
  const _PeaksHistory({required this.history});

  final List<PeaksChange> history;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = history.take(5).toList();
    return DvorCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
      radius: Radii.tile,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.stroke),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: context.text.labelLarge?.copyWith(color: c.inkMuted),
                    ),
                  ),
                  Text(
                    Fmt.dayMonthShort(rows[i].createdAt),
                    style: context.text.labelMedium?.copyWith(color: c.inkFaint),
                  ),
                  const SizedBox(width: Space.m),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${rows[i].amount > 0 ? '+' : '−'}${Fmt.number(rows[i].amount.abs())}',
                      textAlign: TextAlign.right,
                      style: context.text.labelLarge?.copyWith(
                        color: rows[i].amount > 0 ? c.accent : c.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
