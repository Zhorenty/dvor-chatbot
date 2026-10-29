import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/format/formatters.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/sheets.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _CatalogCategory extends Notifier<EventCategory> {
  @override
  EventCategory build() => EventCategory.trainings;

  void set(EventCategory value) => state = value;
}

final catalogCategoryProvider = NotifierProvider<_CatalogCategory, EventCategory>(
  _CatalogCategory.new,
);

/// Schedule rows straight from Google Sheets, editable in place.
class AdminScheduleScreen extends ConsumerWidget {
  const AdminScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(catalogCategoryProvider);
    final items = ref.watch(adminCatalogProvider(category));
    final inset = ref.watch(safeAreaProvider);
    final c = context.colors;
    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.surface,
      edgeOffset: inset.top,
      onRefresh: () async {
        ref.invalidate(adminCatalogProvider(category));
        await ref.read(adminCatalogProvider(category).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Space.gutter, inset.top + Space.l, Space.gutter, 0),
              child: Row(
                children: [
                  Expanded(child: Text('РАСПИСАНИЕ', style: context.text.displayMedium)),
                  Pressable(
                    onTap: () => context.push('/admin/schedule/edit'),
                    semanticLabel: 'Добавить событие',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: Icon(Icons.add_rounded, color: c.onAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.m),
              child: ChoiceChips<EventCategory>(
                options: const [
                  (EventCategory.trainings, 'Тренировки'),
                  (EventCategory.hikes, 'Походы'),
                  (EventCategory.trails, 'Кэмпы'),
                ],
                selected: category,
                onSelected: ref.read(catalogCategoryProvider.notifier).set,
              ),
            ),
          ),
          ...switch (items) {
            AsyncValue(:final value?) when value.isEmpty => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.event_note_outlined,
                  title: 'Пусто',
                  body: 'В этой вкладке таблицы нет будущих событий.',
                ),
              ),
            ],
            AsyncValue(:final value?) => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                  itemBuilder: (context, i) => _CatalogTile(item: value[i]),
                ),
              ),
            ],
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(adminCatalogProvider(category)),
                ),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.separated(
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                  itemBuilder: (_, _) => const Skeleton(height: 64, radius: Radii.tile),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: 120 + inset.bottom)),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = splitTitleEmoji(item.title);
    final when = item.category.isOutdoor
        ? Fmt.dayMonth(item.startsAt)
        : '${Fmt.weekdayShort(ClubTime.dayOf(item.startsAt))}, ${Fmt.dayMonthShort(item.startsAt)} · ${Fmt.time(item.startsAt)}';
    return Pressable(
      onTap: () => context.push('/admin/schedule/edit', extra: item),
      scale: 0.99,
      child: DvorCard(
        radius: Radii.tile,
        padding: const EdgeInsets.all(Space.m),
        child: Row(
          children: [
            EventGlyph(emoji: title.emoji, category: item.category, size: 38),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  Text(
                    '$when · строка ${item.row}',
                    style: context.text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 18, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}
