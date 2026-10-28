import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

TelegramPlatform createPlatform() => StubTelegramPlatform();

/// Used in tests and when the app is opened outside Telegram.
class StubTelegramPlatform implements TelegramPlatform {
  StubTelegramPlatform({this.brightness = Brightness.dark});

  final List<String> openedLinks = <String>[];
  final List<HapticKind> haptics = <HapticKind>[];
  MainButtonState? mainButton;
  VoidCallback? mainButtonTap;
  bool backVisible = false;
  bool confirmResult = true;

  @override
  bool get isAvailable => false;

  @override
  String get initData => '';

  @override
  String? get startParam => null;

  @override
  final Brightness brightness;

  @override
  EdgeInsets get safeArea => EdgeInsets.zero;

  @override
  late final ValueListenable<Brightness> brightnessListenable = ValueNotifier(brightness);

  @override
  final ValueListenable<EdgeInsets> safeAreaListenable = ValueNotifier(EdgeInsets.zero);

  @override
  void ready() {}

  @override
  void setColors({required Color header, required Color background, required Color bottomBar}) {}

  @override
  void setMainButton(
    MainButtonState? state, {
    VoidCallback? onTap,
    required Color color,
    required Color textColor,
  }) {
    mainButton = state;
    mainButtonTap = onTap;
  }

  @override
  void setBackButton({required bool visible, VoidCallback? onTap}) {
    backVisible = visible;
  }

  @override
  void haptic(HapticKind kind) => haptics.add(kind);

  @override
  Future<bool> confirm(String message) async => confirmResult;

  @override
  void openLink(String url) => openedLinks.add(url);

  @override
  void openTelegramLink(String url) => openedLinks.add(url);

  @override
  void close() {}
}
