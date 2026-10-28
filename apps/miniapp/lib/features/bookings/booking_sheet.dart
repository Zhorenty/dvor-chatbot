import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the bot chat where payment cards, receipts and bonuses live.
void openBotChat(WidgetRef ref) {
  final username = ref.read(meProvider).value?.botUsername;
  final tg = ref.read(telegramProvider);
  if (username == null) {
    tg.close();
    return;
  }
  tg.openTelegramLink('https://t.me/$username');
}

Future<void> showBookingResultSheet(
  BuildContext context,
  WidgetRef ref, {
  required ClubEvent event,
  required ActionResult result,
}) {
  final booking = result.booking;
  final needsPayment = booking?.status.needsPayment ?? false;
  final String title;
  final String body;
  if (result.outcome == ActionOutcome.exists) {
    title = 'Ты уже в списке';
    body = needsPayment
        ? 'Запись ждёт оплаты. Карточка с реквизитами — в чате с ботом.'
        : 'Статус: ${booking?.status.label.toLowerCase() ?? 'записан'}.';
  } else if (needsPayment) {
    title = 'Место за тобой';
    body =
        'Карточка оплаты уже в чате с ботом. Там же можно списать вершинки, '
        'применить бонус или промокод.';
  } else {
    title = 'Ты в списке';
    body = booking?.boxingCard == true
        ? 'Списали тренировку с BOXING CARD. До встречи на площадке.'
        : 'Оплата не нужна. До встречи на площадке.';
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final c = sheetContext.colors;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: needsPayment
                        ? c.warning.withValues(alpha: 0.16)
                        : c.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    needsPayment ? Icons.receipt_long_rounded : Icons.check_rounded,
                    size: 38,
                    color: needsPayment ? c.warning : c.accent,
                  ),
                ),
              ),
              const SizedBox(height: Space.l),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: sheetContext.text.headlineMedium,
              ),
              const SizedBox(height: Space.s),
              Text(
                '${event.title} · ${event.category.isOutdoor ? Fmt.dateRange(event.startsAt, event.endsAt) : '${Fmt.dayMonth(event.startsAt)}, ${Fmt.time(event.startsAt)}'}',
                textAlign: TextAlign.center,
                style: sheetContext.text.labelLarge?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Space.l),
              Text(body, textAlign: TextAlign.center, style: sheetContext.text.bodyLarge),
              const SizedBox(height: Space.xl),
              if (needsPayment) ...[
                PrimaryButton(
                  label: 'Перейти к оплате',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openBotChat(ref);
                  },
                ),
                const SizedBox(height: Space.s),
                SecondaryButton(
                  label: 'Позже',
                  expand: true,
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ] else
                PrimaryButton(label: 'Отлично', onTap: () => Navigator.of(sheetContext).pop()),
            ],
          ),
        ),
      );
    },
  );
}
