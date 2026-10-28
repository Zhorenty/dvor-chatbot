import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/bookings/bookings_screen.dart';
import 'package:dvor_miniapp/features/profile/profile_screen.dart';
import 'package:dvor_miniapp/features/schedule/event_screen.dart';
import 'package:dvor_miniapp/features/schedule/schedule_screen.dart';
import 'package:dvor_miniapp/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const ScheduleScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/event',
        redirect: (_, state) => state.extra is ClubEvent ? null : '/',
        pageBuilder: (context, state) =>
            MaterialPage(child: EventScreen(initial: state.extra! as ClubEvent)),
      ),
    ],
  );
}

class DvorApp extends ConsumerStatefulWidget {
  const DvorApp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<DvorApp> createState() => _DvorAppState();
}

class _DvorAppState extends ConsumerState<DvorApp> {
  late final TelegramPlatform _tg = ref.read(telegramProvider);

  @override
  void initState() {
    super.initState();
    _tg.changes.addListener(_onTelegramChanged);
  }

  @override
  void dispose() {
    _tg.changes.removeListener(_onTelegramChanged);
    super.dispose();
  }

  void _onTelegramChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final brightness = _tg.isAvailable ? _tg.brightness : MediaQuery.platformBrightnessOf(context);
    final palette = brightness == Brightness.dark ? DvorColors.dark : DvorColors.light;
    _tg.setColors(
      header: palette.background,
      background: palette.background,
      bottomBar: palette.background,
    );
    return MaterialApp.router(
      title: 'DVOR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      routerConfig: widget.router,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Shown when the page is opened in a browser instead of Telegram.
class OpenInTelegramApp extends StatelessWidget {
  const OpenInTelegramApp({super.key, this.botUrl});

  final String? botUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.dark),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DvorLogo(height: 36),
                  const SizedBox(height: Space.xl),
                  Text(
                    'ОТКРОЙ В TELEGRAM',
                    textAlign: TextAlign.center,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    'Приложение DVOR работает внутри бота: кнопка меню слева от поля ввода.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
