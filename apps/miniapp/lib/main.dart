import 'package:dvor_miniapp/app.dart';
import 'package:dvor_miniapp/core/api/demo_repository.dart';
import 'package:dvor_miniapp/core/api/models.dart';
import 'package:dvor_miniapp/core/api/repository.dart';
import 'package:dvor_miniapp/core/providers.dart';
import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Local preview without Telegram: `flutter run -d chrome --dart-define=DVOR_DEMO=true`.
const bool kDemo = bool.fromEnvironment('DVOR_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Telegram passes launch data in the URL hash; keep routing on the path.
  usePathUrlStrategy();
  await initializeDateFormatting('ru');

  final tg = createTelegramPlatform();
  if (!tg.isAvailable && !kDemo) {
    runApp(const OpenInTelegramApp());
    return;
  }
  tg.ready();

  final DvorRepository repository = tg.isAvailable
      ? ApiRepository(initData: tg.initData)
      : DemoRepository();
  final container = ProviderContainer(
    overrides: [
      telegramProvider.overrideWithValue(tg),
      repositoryProvider.overrideWithValue(repository),
    ],
  );

  // startapp deep links: ?startapp=bookings | profile | admin | hikes | trails | trainings | fps
  final start = tg.startParam;
  var initialLocation = '/';
  switch (start) {
    case 'bookings':
      initialLocation = '/bookings';
    case 'profile':
      initialLocation = '/profile';
    case 'admin':
      initialLocation = '/admin';
    case 'hikes' || 'trails' || 'trainings':
      container.read(categoryFilterProvider.notifier).select(EventCategory.parse(start));
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: DvorApp(
        router: buildRouter(initialLocation: initialLocation),
        showFps: start == 'fps' || const bool.fromEnvironment('DVOR_FPS'),
      ),
    ),
  );
}
