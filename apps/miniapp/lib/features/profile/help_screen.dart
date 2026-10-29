import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/bookings/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Club rules in short, the same as the bot's help and the business cheat sheet.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  static const _sections = <(IconData, String, List<String>)>[
    (
      Icons.event_available_rounded,
      'Запись',
      [
        'Выбери событие в афише и нажми «Записаться».',
        'Друзей можно записать вместе с собой — до 5 друзей, одна оплата за всех.',
      ],
    ),
    (
      Icons.payments_rounded,
      'Оплата',
      [
        'Оплати по СБП и прикрепи скриншот чека.',
        'Чек проверяет администратор, ответ придёт в чат с ботом.',
        'Для походов и кэмпов можно внести предоплату, остаток — на месте.',
      ],
    ),
    (
      Icons.event_busy_rounded,
      'Отмена и перенос',
      [
        'Платную тренировку можно отменить не позже чем за 24 часа: оплата вернётся вершинками.',
        'Бесплатную тренировку можно только отменить, в любой момент.',
        'Однодневный поход или кэмп — не позже чем за 7 дней, многодневный — за 10. Внутри срока предоплата не возвращается.',
        'Платную тренировку можно перенести только на другую с той же ценой.',
      ],
    ),
    (
      Icons.landscape_rounded,
      'Вершинки ⛰️',
      [
        '2 ⛰️ = 1 ₽. Начисляются за тренировки, отзывы и друзей.',
        'Тренировку закрывают только целиком, поход или кэмп — скидка до 30%.',
        'Живут 45 дней с последней активности. За 7 дней до сгорания придёт напоминание.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text('ПРАВИЛА', style: context.text.displayMedium),
            const SizedBox(height: Space.l),
            for (final (icon, title, lines) in _sections) ...[
              DvorCard(
                radius: Radii.tile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20, color: c.accent),
                        const SizedBox(width: Space.s),
                        Text(title.toUpperCase(), style: context.text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: Space.s),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Text(line, style: context.text.bodyMedium),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.m),
            ],
            SecondaryButton(
              label: 'Написать в чат с ботом',
              icon: Icons.chat_bubble_outline_rounded,
              expand: true,
              onTap: () => openBotChat(ref),
            ),
          ],
        ),
      ),
    );
  }
}
