import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Links of the partner «Южный гараж»; the same set as the bot's `/cars`.
abstract final class PartnerLinks {
  static const String instagram = 'https://www.instagram.com/yugarazh/';
  static const String telegram = 'https://t.me/YuGarazh';
  static const String max = 'https://max.ru/channel_YuGarazh';
  static const String price = 'https://yugarazh.ru/#rec1761805161';
  static const String write = 'https://t.me/+79010400000';
  static const String site = 'https://yugarazh.ru/';
  static const String reviews = 'https://yandex.ru/maps/org/yuzhny_garazh/37144404851/reviews/';
  static const String phone = '+7 901 040-00-00';
  static const String phoneRaw = '+79010400000';
}

/// Partner section: cars from China and South Korea, DVOR × Южный гараж.
class PartnerScreen extends ConsumerWidget {
  const PartnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inset = ref.watch(safeAreaProvider);
    final tg = ref.watch(telegramProvider);
    final c = context.colors;

    Widget link(IconData icon, String title, String subtitle, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: OptionTile(icon: icon, title: title, subtitle: subtitle, onTap: onTap),
      );
    }

    return TelegramBackButton(
      onBack: () => context.pop(),
      child: Scaffold(
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(Space.gutter, inset.top + Space.l, Space.gutter, 48),
          children: [
            if (!tg.isAvailable)
              Align(
                alignment: Alignment.centerLeft,
                child: Pressable(
                  onTap: () => context.pop(),
                  child: Icon(Icons.arrow_back_rounded, color: c.ink),
                ),
              ),
            Text('АВТО', style: context.text.displayMedium),
            const SizedBox(height: Space.l),
            DvorCard(
              radius: Radii.tile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DVOR × ЮЖНЫЙ ГАРАЖ',
                    style: context.text.labelMedium?.copyWith(color: c.accent),
                  ),
                  const SizedBox(height: Space.s),
                  Text('Авто из Китая и Южной Кореи', style: context.text.titleLarge),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Подбирают, проверяют и привозят. Доставка по всей России. Краснодар.',
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.l),
            const GroupLabel('Автомобили и цены'),
            link(
              Icons.send_rounded,
              'Каталог в Telegram',
              'Новые предложения каждый день',
              () => tg.openTelegramLink(PartnerLinks.telegram),
            ),
            link(
              Icons.directions_car_outlined,
              'Каталог в MAX',
              'Автомобили и актуальные цены',
              () => tg.openLink(PartnerLinks.max),
            ),
            link(
              Icons.calculate_outlined,
              'Узнать цену',
              'Рассчитаем стоимость под ключ',
              () => tg.openLink(PartnerLinks.price),
            ),
            const SizedBox(height: Space.m),
            const GroupLabel('Связаться'),
            link(
              Icons.chat_bubble_outline_rounded,
              'Написать в Telegram',
              'Обсудим ваш автомобиль',
              () => tg.openTelegramLink(PartnerLinks.write),
            ),
            link(
              Icons.phone_outlined,
              PartnerLinks.phone,
              'Нажми, чтобы скопировать номер',
              () async {
                await Clipboard.setData(const ClipboardData(text: PartnerLinks.phoneRaw));
                if (context.mounted) {
                  showToast(context, 'Номер скопирован');
                }
              },
            ),
            const SizedBox(height: Space.m),
            const GroupLabel('Ещё'),
            link(
              Icons.language_rounded,
              'Наш сайт',
              'О компании, подборе и доставке',
              () => tg.openLink(PartnerLinks.site),
            ),
            link(
              Icons.star_outline_rounded,
              'Отзывы клиентов',
              'Яндекс Карты · адрес салона',
              () => tg.openLink(PartnerLinks.reviews),
            ),
            link(
              Icons.photo_camera_outlined,
              'Instagram',
              '@yugarazh',
              () => tg.openLink(PartnerLinks.instagram),
            ),
          ],
        ),
      ),
    );
  }
}
