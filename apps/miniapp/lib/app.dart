import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/fps_meter.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/admin/admin.dart' deferred as admin;
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
          // Tab is shown only to admins; the API enforces access.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (_, _) =>
                    DeferredScreen(load: admin.loadLibrary, builder: () => admin.AdminScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/session',
        redirect: (_, state) => state.extra is AdminSession ? null : '/admin',
        pageBuilder: (context, state) => MaterialPage(
          child: DeferredScreen(
            load: admin.loadLibrary,
            builder: () => admin.RosterScreen(initial: state.extra! as AdminSession),
          ),
        ),
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
  const DvorApp({super.key, required this.router, this.showFps = false});

  final GoRouter router;

  /// Frame-rate overlay for measuring inside Telegram (`?startapp=fps`).
  final bool showFps;

  @override
  ConsumerState<DvorApp> createState() => _DvorAppState();
}

class _DvorAppState extends ConsumerState<DvorApp> {
  late final TelegramPlatform _tg = ref.read(telegramProvider);

  @override
  void initState() {
    super.initState();
    _tg.brightnessListenable.addListener(_syncTelegramColors);
    _syncTelegramColors();
  }

  @override
  void dispose() {
    _tg.brightnessListenable.removeListener(_syncTelegramColors);
    super.dispose();
  }

  /// Telegram header and background follow the app palette; called only
  /// when the theme changes, never per frame or per viewport event.
  void _syncTelegramColors() {
    final palette = _tg.brightnessListenable.value == Brightness.dark
        ? DvorColors.dark
        : DvorColors.light;
    _tg.setColors(
      header: palette.background,
      background: palette.background,
      bottomBar: palette.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brightness>(
      valueListenable: _tg.brightnessListenable,
      builder: (context, telegramBrightness, _) {
        final brightness = _tg.isAvailable
            ? telegramBrightness
            : MediaQuery.platformBrightnessOf(context);
        return MaterialApp.router(
          title: 'DVOR',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(brightness),
          routerConfig: widget.router,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => widget.showFps ? FpsMeter(child: child!) : child!,
        );
      },
    );
  }
}

/// Admin code ships in a separate chunk and loads only when an admin opens it.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.builder});

  final Future<void> Function() load;
  final Widget Function() builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _loaded = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loaded,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorState(
              error: snapshot.error!,
              onRetry: () => setState(() => _loaded = widget.load()),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return widget.builder();
      },
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
