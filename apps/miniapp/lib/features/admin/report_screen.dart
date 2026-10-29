import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/telegram_main_button.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _reportProvider = FutureProvider.autoDispose.family<String, String>((ref, kind) async {
  final json = await ref.watch(repositoryProvider).rpc('admin.report', {'kind': kind});
  return (json['text'] as String?) ?? '';
});

/// A bot report rendered in the app: the same text admins get in chat.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(_reportProvider(kind));
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
            ref.invalidate(_reportProvider(kind));
            await ref.read(_reportProvider(kind).future);
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
              Text('ОТЧЁТ', style: context.text.displayMedium),
              const SizedBox(height: Space.l),
              switch (report) {
                AsyncValue(:final value?) => DvorCard(
                  child: SelectableText(
                    value.isEmpty ? 'Бот не прислал отчёт.' : value,
                    style: context.text.bodyLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                AsyncValue(:final error?) => ErrorState(
                  error: error is ApiException ? error : error,
                  onRetry: () => ref.invalidate(_reportProvider(kind)),
                ),
                _ => const Skeleton(height: 320),
              },
            ],
          ),
        ),
      ),
    );
  }
}
