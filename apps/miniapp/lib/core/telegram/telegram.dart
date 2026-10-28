import 'package:dvor_miniapp/core/telegram/telegram_stub.dart'
    if (dart.library.js_interop) 'package:dvor_miniapp/core/telegram/telegram_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum HapticKind { selection, light, medium, success, warning, error }

/// Native bottom button state (Telegram MainButton).
@immutable
class MainButtonState {
  const MainButtonState({required this.text, this.enabled = true, this.loading = false});

  final String text;
  final bool enabled;
  final bool loading;
}

/// Telegram Mini App runtime. Outside Telegram every call is a no-op and
/// [isAvailable] is false so the UI can fall back to Flutter widgets.
abstract interface class TelegramPlatform {
  bool get isAvailable;

  String get initData;

  String? get startParam;

  Brightness get brightness;

  /// Device safe area plus Telegram content safe area (fullscreen headers).
  EdgeInsets get safeArea;

  /// Changes only when Telegram switches light/dark. Viewport events
  /// (dozens per second while the sheet expands) never touch it.
  ValueListenable<Brightness> get brightnessListenable;

  /// Changes only when the safe-area insets actually change.
  ValueListenable<EdgeInsets> get safeAreaListenable;

  void ready();

  void setColors({required Color header, required Color background, required Color bottomBar});

  void setMainButton(
    MainButtonState? state, {
    VoidCallback? onTap,
    required Color color,
    required Color textColor,
  });

  void setBackButton({required bool visible, VoidCallback? onTap});

  void haptic(HapticKind kind);

  Future<bool> confirm(String message);

  void openLink(String url);

  void openTelegramLink(String url);

  void close();
}

TelegramPlatform createTelegramPlatform() => createPlatform();
