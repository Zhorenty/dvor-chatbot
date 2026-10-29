import 'dart:convert';

import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/media/image_picker.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/bookings/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Reports, member lookup, peaks and broadcasts.
class AdminToolsScreen extends ConsumerWidget {
  const AdminToolsScreen({super.key});

  static const _reports = <(String, IconData, String, String)>[
    ('overview', Icons.insights_rounded, 'Общая аналитика', 'Записи, оплаты, активность'),
    ('bookings', Icons.event_available_rounded, 'Бронирования', 'По категориям и статусам'),
    ('economic_current_week', Icons.payments_rounded, 'Экономика · неделя', 'Текущая неделя'),
    (
      'economic_previous_week',
      Icons.payments_outlined,
      'Экономика · прошлая неделя',
      'Закрытая неделя',
    ),
    ('economic_current_month', Icons.calendar_month_rounded, 'Экономика · месяц', 'Текущий месяц'),
    (
      'economic_previous_month',
      Icons.calendar_today_rounded,
      'Экономика · прошлый месяц',
      'Закрытый месяц',
    ),
    ('peaks', Icons.landscape_rounded, 'Вершинки', 'Начисления, списания, сгорания'),
    ('cards', Icons.sports_mma_rounded, 'BOXING CARD', 'Активные, продления, заявки'),
    ('funnel', Icons.filter_alt_rounded, 'Воронка онбординга', 'От Start до первой записи'),
    ('feedback', Icons.rate_review_rounded, 'Анонимный фидбэк', 'Оценки после тренировок'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inset = ref.watch(safeAreaProvider);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        inset.top + Space.l,
        Space.gutter,
        120 + inset.bottom,
      ),
      children: [
        Text('ИНСТРУМЕНТЫ', style: context.text.displayMedium),
        const GroupLabel('Люди'),
        OptionTile(
          icon: Icons.person_search_rounded,
          title: 'Найти участника',
          subtitle: 'Записи, вершинки и BOXING CARD по @username',
          onTap: () => showDvorSheet<void>(context, (_) => const _UserLookupSheet()),
        ),
        const SizedBox(height: Space.s),
        OptionTile(
          icon: Icons.landscape_rounded,
          title: 'Начислить или списать вершинки',
          subtitle: 'Суммы кратны 10',
          onTap: () => showDvorSheet<void>(context, (_) => const _PeaksGrantSheet()),
        ),
        const SizedBox(height: Space.s),
        OptionTile(
          icon: Icons.campaign_rounded,
          title: 'Рассылка',
          subtitle: 'В личку, в группу или везде',
          onTap: () => showDvorSheet<void>(context, (_) => const _BroadcastSheet()),
        ),
        const GroupLabel('Отчёты'),
        for (final (kind, icon, title, subtitle) in _reports) ...[
          OptionTile(
            icon: icon,
            title: title,
            subtitle: subtitle,
            onTap: () => context.push('/admin/report', extra: kind),
          ),
          const SizedBox(height: Space.s),
        ],
        const GroupLabel('Бот'),
        OptionTile(
          icon: Icons.smart_toy_outlined,
          title: 'Чат с ботом',
          subtitle: 'Онбординг-видео и уведомления админам',
          onTap: () => openBotChat(ref),
        ),
      ],
    );
  }
}

class _UserLookupSheet extends ConsumerStatefulWidget {
  const _UserLookupSheet();

  @override
  ConsumerState<_UserLookupSheet> createState() => _UserLookupSheetState();
}

class _UserLookupSheetState extends ConsumerState<_UserLookupSheet> {
  final _query = TextEditingController();
  Map<String, Object?>? _result;
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) {
      return;
    }
    setState(() => _busy = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(repositoryProvider).rpc('admin.user', {'user': _query.text.trim()}),
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = _result;
    final bookings = (r?['bookings'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(Booking.fromJson)
        .toList();
    final card = r?['card'] as Map<String, Object?>?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Участник'),
        const SizedBox(height: Space.m),
        DvorTextField(
          controller: _query,
          hint: 'username или Telegram id',
          prefixText: '@',
          autofocus: true,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: Space.m),
        PrimaryButton(label: 'Найти', loading: _busy, onTap: _search),
        if (r != null) ...[
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              if (r['userId'] != null) Pill(label: 'id ${r['userId']}'),
              if (r['peaks'] != null) Pill(label: '${r['peaks']} ⛰️', color: c.accent),
              if (card != null)
                Pill(
                  label: 'BOXING CARD ${card['plan']}${card['active'] == true ? '' : ' · истекла'}',
                  color: card['active'] == true ? c.accent : c.inkMuted,
                ),
            ],
          ),
          const GroupLabel('Записи'),
          if (bookings.isEmpty)
            Text(
              'Записей не нашлось.',
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
          for (final b in bookings)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Fmt.dayMonthShort(b.startsAt)} · ${splitTitleEmoji(b.title).text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                  ),
                  Text(
                    b.status.label,
                    style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PeaksGrantSheet extends ConsumerStatefulWidget {
  const _PeaksGrantSheet();

  @override
  ConsumerState<_PeaksGrantSheet> createState() => _PeaksGrantSheetState();
}

class _PeaksGrantSheetState extends ConsumerState<_PeaksGrantSheet> {
  final _user = TextEditingController();
  final _amount = TextEditingController();
  bool _debit = false;
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _user.text.trim().isEmpty) {
      showToast(context, 'Нужны @username и сумма.');
      return;
    }
    setState(() => _busy = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('admin.peaks.grant', {
        'user': _user.text.trim(),
        'amount': _debit ? -amount : amount,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Вершинки', subtitle: '2 ⛰️ = 1 ₽. Сумма кратна 10.'),
        const GroupLabel('Действие'),
        ChoiceChips<bool>(
          options: const [(false, 'Начислить'), (true, 'Списать')],
          selected: _debit,
          onSelected: (v) => setState(() => _debit = v),
        ),
        const SizedBox(height: Space.m),
        DvorTextField(controller: _user, hint: 'username', prefixText: '@'),
        const SizedBox(height: Space.m),
        DvorTextField(controller: _amount, hint: '500', keyboardType: TextInputType.number),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: _debit ? 'Списать' : 'Начислить', loading: _busy, onTap: _apply),
      ],
    );
  }
}

class _BroadcastSheet extends ConsumerStatefulWidget {
  const _BroadcastSheet();

  @override
  ConsumerState<_BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends ConsumerState<_BroadcastSheet> {
  final _text = TextEditingController();
  String _audience = 'users';
  PickedImage? _image;
  bool _busy = false;

  static const _audiences = <(String, String)>[
    ('users', 'Всем в личку'),
    ('outdoor', 'Outdoor'),
    ('group', 'Только группа'),
    ('all', 'Личка и группа'),
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty && _image == null) {
      showToast(context, 'Нужен текст или фото.');
      return;
    }
    final label = _audiences.firstWhere((a) => a.$1 == _audience).$2.toLowerCase();
    if (!await confirmAction(context, ref, 'Отправить рассылку: $label?')) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('admin.broadcast', {
        'audience': _audience,
        'text': _text.text.trim(),
        if (_image != null) 'image': base64Encode(_image!.bytes),
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
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Рассылка', subtitle: 'С фото текст станет подписью.'),
        const GroupLabel('Кому'),
        ChoiceChips<String>(
          options: _audiences,
          selected: _audience,
          onSelected: (v) => setState(() => _audience = v),
        ),
        const GroupLabel('Текст'),
        DvorTextField(controller: _text, hint: 'Что сообщаем', maxLines: 8),
        const SizedBox(height: Space.m),
        OptionTile(
          icon: _image == null ? Icons.add_photo_alternate_outlined : Icons.image_rounded,
          title: _image == null ? 'Добавить фото' : 'Фото добавлено',
          subtitle: _image == null
              ? null
              : '${(_image!.bytes.length / 1024).round()} КБ · нажми, чтобы убрать',
          tone: _image == null ? c.inkMuted : c.accent,
          onTap: () async {
            if (_image != null) {
              setState(() => _image = null);
              return;
            }
            final picked = await pickImage(maxSide: 2048);
            if (picked != null && mounted) {
              setState(() => _image = picked);
            }
          },
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Отправить', loading: _busy, onTap: _send),
      ],
    );
  }
}
