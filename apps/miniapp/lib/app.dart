import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/rpc_models.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:dvor_miniapp/core/theme/app_theme.dart';
import 'package:dvor_miniapp/core/widgets/fps_meter.dart';
import 'package:dvor_miniapp/core/widgets/widgets.dart';
import 'package:dvor_miniapp/features/admin/admin.dart' deferred as admin;
import 'package:dvor_miniapp/features/bookings/bookings_screen.dart';
import 'package:dvor_miniapp/features/card/card_screen.dart';
import 'package:dvor_miniapp/features/profile/help_screen.dart';
import 'package:dvor_miniapp/features/profile/profile_screen.dart';
import 'package:dvor_miniapp/features/profile/team_screen.dart';
import 'package:dvor_miniapp/features/schedule/event_screen.dart';
import 'package:dvor_miniapp/features/schedule/schedule_screen.dart';
import 'package:dvor_miniapp/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter({String initialLocation = '/', bool isAdmin = false}) {
  return isAdmin ? _adminRouter(initialLocation) : _memberRouter(initialLocation);
}

GoRoute _page(String path, Widget Function(GoRouterState state) build) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => MaterialPage(child: build(state)),
  );
}

StatefulShellBranch _branch(String path, Widget Function() build) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => build())],
  );
}

GoRouter _memberRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation.startsWith('/admin') ? '/' : initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MemberShell(shell: shell),
        branches: [
          _branch('/', () => const ScheduleScreen()),
          _branch('/bookings', () => const BookingsScreen()),
          _branch('/profile', () => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/event',
        redirect: (_, state) => state.extra is ClubEvent ? null : '/',
        pageBuilder: (context, state) =>
            MaterialPage(child: EventScreen(initial: state.extra! as ClubEvent)),
      ),
      _page('/card', (_) => const CardScreen()),
      _page('/team', (_) => const TeamScreen()),
      _page('/help', (_) => const HelpScreen()),
    ],
  );
}

/// Admins get only the admin section; its code is a deferred chunk.
GoRouter _adminRouter(String initialLocation) {
  Widget lazy(Widget Function() build) => DeferredScreen(load: admin.loadLibrary, builder: build);
  return GoRouter(
    initialLocation: initialLocation.startsWith('/admin') ? initialLocation : '/admin/payments',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdminShell(shell: shell),
        branches: [
          _branch(
            '/admin/payments',
            () => lazy(() => admin.AdminScreen(section: admin.AdminSection.payments)),
          ),
          _branch(
            '/admin/attendance',
            () => lazy(() => admin.AdminScreen(section: admin.AdminSection.sessions)),
          ),
          _branch('/admin/schedule', () => lazy(() => admin.AdminScheduleScreen())),
          _branch('/admin/bookings', () => lazy(() => admin.AdminBookingsScreen())),
          _branch('/admin/tools', () => lazy(() => admin.AdminToolsScreen())),
        ],
      ),
      GoRoute(
        path: '/admin/session',
        redirect: (_, state) => state.extra is AdminSession ? null : '/admin/attendance',
        pageBuilder: (context, state) => MaterialPage(
          child: lazy(() => admin.RosterScreen(initial: state.extra! as AdminSession)),
        ),
      ),
      GoRoute(
        path: '/admin/schedule/edit',
        pageBuilder: (context, state) => MaterialPage(
          child: lazy(() => admin.ScheduleEditScreen(item: state.extra as CatalogItem?)),
        ),
      ),
      GoRoute(
        path: '/admin/report',
        redirect: (_, state) => state.extra is String ? null : '/admin/tools',
        pageBuilder: (context, state) =>
            MaterialPage(child: lazy(() => admin.ReportScreen(kind: state.extra! as String))),
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
