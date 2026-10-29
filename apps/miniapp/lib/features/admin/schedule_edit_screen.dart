import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/admin/admin_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sheet column, its label, hint and keyboard. Keys are the bot's field ids.
typedef _Field = (String key, String label, String hint, TextInputType type, int lines);

const List<_Field> _trainingFields = [
  ('title', 'Название', '🥊 BOXING DVOR', TextInputType.text, 1),
  ('date', 'Дата', '19.08.2026', TextInputType.datetime, 1),
  ('time', 'Время', '19:30', TextInputType.datetime, 1),
  ('location', 'Место', 'БК Варг (Ул. Школьная, 62)', TextInputType.text, 1),
  ('map', 'Ссылка на карту', 'https://yandex.ru/maps/…', TextInputType.url, 1),
  ('coach', 'Тренер', 'Имя Фамилия', TextInputType.text, 1),
  ('price', 'Цена, ₽', '600 или 0 — бесплатно', TextInputType.number, 1),
  ('limit', 'Лимит мест', 'Пусто — без лимита', TextInputType.number, 1),
  ('notes', 'Заметки', 'Что взять, как найти', TextInputType.multiline, 4),
];

const List<_Field> _outdoorFields = [
  ('title', 'Название', 'Поход: …', TextInputType.text, 1),
  ('date_from', 'Начало', '19.08.2026', TextInputType.datetime, 1),
  ('date_to', 'Конец', 'Пусто — однодневный', TextInputType.datetime, 1),
  ('location', 'Место', 'Теберда', TextInputType.text, 1),
  ('price', 'Цена, ₽', '22500', TextInputType.number, 1),
  ('prepay', 'Предоплата, %', '50', TextInputType.number, 1),
  ('limit', 'Лимит мест', '20', TextInputType.number, 1),
  ('description', 'Описание', 'Маршрут, уровень, что входит', TextInputType.multiline, 5),
  ('equipment', 'Что взять', 'Рюкзак, спальник…', TextInputType.multiline, 4),
  ('itinerary', 'Программа', 'День 1 — …', TextInputType.multiline, 5),
];

/// Create or edit one schedule row. Saving writes to Google Sheets through
/// the bot, which validates each field like the chat editor does.
class ScheduleEditScreen extends ConsumerStatefulWidget {
  const ScheduleEditScreen({super.key, this.item});

  final CatalogItem? item;

  @override
  ConsumerState<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends ConsumerState<ScheduleEditScreen> {
  late EventCategory _category = widget.item?.category ?? ref.read(catalogCategoryProvider);
  final Map<String, TextEditingController> _controllers = {};
  Map<String, String> _errors = const {};
  bool _saving = false;

  bool get _isNew => widget.item == null;

  List<_Field> get _fields => _category.isOutdoor ? _outdoorFields : _trainingFields;

  TextEditingController _controller(String key) => _controllers.putIfAbsent(
    key,
    () => TextEditingController(text: widget.item?.fields[key] ?? ''),
  );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final fields = <String, String>{};
    for (final (key, _, _, _, _) in _fields) {
      final value = _controller(key).text.trim();
      final initial = widget.item?.fields[key] ?? '';
      if (_isNew ? value.isNotEmpty : value != initial) {
        fields[key] = value;
      }
    }
    if (!_isNew && fields.isEmpty) {
      context.pop();
      return;
    }
    setState(() => _saving = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('admin.schedule.save', {
        'category': _category.name,
        'row': ?widget.item?.row,
        'fields': fields,
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    final errors = result?['errors'];
    if (errors is Map<String, Object?>) {
      setState(() => _errors = {for (final e in errors.entries) e.key: '${e.value}'});
      ref.read(telegramProvider).haptic(HapticKind.warning);
      return;
    }
    if (result != null) {
      context.pop();
    }
  }

  Future<void> _delete() async {
    if (!await confirmAction(context, ref, 'Удалить «${widget.item!.title}» из таблицы?')) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = true);
    final result = await runAction(
      context,
      ref,
      () => ref.read(rpcProvider).call('admin.schedule.delete', {
        'category': _category.name,
        'row': widget.item!.row,
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (result != null) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = ref.watch(safeAreaProvider);
    final tg = ref.watch(telegramProvider);
    final c = context.colors;
    return TelegramBackButton(
      onBack: () => context.pop(),
      child: Scaffold(
        bottomNavigationBar: TelegramMainButton(
          state: MainButtonState(text: _isNew ? 'Добавить' : 'Сохранить', loading: _saving),
          onTap: _save,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(Space.gutter, inset.top + Space.l, Space.gutter, 40),
          children: [
            if (!tg.isAvailable)
              Align(
                alignment: Alignment.centerLeft,
                child: Pressable(
                  onTap: () => context.pop(),
                  child: Icon(Icons.arrow_back_rounded, color: c.ink),
                ),
              ),
            SheetTitle(
              _isNew ? 'Новое событие' : 'Правка',
              subtitle: _isNew
                  ? 'Строка появится в Google Sheets и в афише.'
                  : 'Строка ${widget.item!.row} в Google Sheets.',
            ),
            if (_isNew) ...[
              const GroupLabel('Вкладка'),
              ChoiceChips<EventCategory>(
                options: const [
                  (EventCategory.trainings, 'Тренировки'),
                  (EventCategory.hikes, 'Походы'),
                  (EventCategory.trails, 'Кэмпы'),
                ],
                selected: _category,
                onSelected: (v) => setState(() {
                  _category = v;
                  _errors = const {};
                }),
              ),
            ],
            for (final (key, label, hint, type, lines) in _fields) ...[
              const SizedBox(height: Space.m),
              DvorTextField(
                controller: _controller(key),
                label: label,
                hint: hint,
                keyboardType: type,
                maxLines: lines,
                error: _errors[key],
              ),
            ],
            if (!_isNew) ...[
              const SizedBox(height: Space.xl),
              SecondaryButton(
                label: 'Удалить из таблицы',
                icon: Icons.delete_outline_rounded,
                color: c.danger,
                expand: true,
                onTap: _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
