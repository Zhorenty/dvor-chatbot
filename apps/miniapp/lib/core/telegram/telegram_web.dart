import 'dart:async';
import 'dart:js_interop';

import 'package:dvor_miniapp/core/telegram/telegram.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

TelegramPlatform createPlatform() => WebTelegramPlatform();

@JS('Telegram.WebApp')
external _WebApp? get _webAppOrNull;

extension type _WebApp._(JSObject _) implements JSObject {
  external String get initData;
  external String get colorScheme;
  external _InitDataUnsafe get initDataUnsafe;
  external _Insets? get safeAreaInset;
  external _Insets? get contentSafeAreaInset;
  // ignore: non_constant_identifier_names
  external _MainButton get MainButton;
  // ignore: non_constant_identifier_names
  external _BackButton get BackButton;
  // ignore: non_constant_identifier_names
  external _Haptic get HapticFeedback;
  external bool isVersionAtLeast(String version);
  external void ready();
  external void expand();
  external void close();
  external void disableVerticalSwipes();
  external void setHeaderColor(String color);
  external void setBackgroundColor(String color);
  external void setBottomBarColor(String color);
  external void openLink(String url);
  external void openTelegramLink(String url);
  external void showConfirm(String message, JSFunction callback);
  external void onEvent(String event, JSFunction handler);
}

extension type _InitDataUnsafe._(JSObject _) implements JSObject {
  // ignore: non_constant_identifier_names
  external String? get start_param;
}

extension type _Insets._(JSObject _) implements JSObject {
  external num? get top;
  external num? get bottom;
  external num? get left;
  external num? get right;
}

extension type _MainButton._(JSObject _) implements JSObject {
  external void setParams(JSObject params);
  external void show();
  external void hide();
  external void showProgress(bool leaveActive);
  external void hideProgress();
  external void onClick(JSFunction handler);
  external void offClick(JSFunction handler);
}

extension type _BackButton._(JSObject _) implements JSObject {
  external void show();
  external void hide();
  external void onClick(JSFunction handler);
  external void offClick(JSFunction handler);
}

extension type _Haptic._(JSObject _) implements JSObject {
  external void impactOccurred(String style);
  external void notificationOccurred(String type);
  external void selectionChanged();
}

class WebTelegramPlatform implements TelegramPlatform {
  WebTelegramPlatform() : _app = _readApp() {
    final app = _app;
    if (app == null) {
      return;
    }
    _brightness.value = brightness;
    _safeArea.value = safeArea;
    app.onEvent('themeChanged', _syncBrightness.toJS);
    for (final event in const ['safeAreaChanged', 'contentSafeAreaChanged']) {
      app.onEvent(event, _syncSafeArea.toJS);
    }
  }

  static _WebApp? _readApp() {
    try {
      return _webAppOrNull;
    } on Object {
      return null;
    }
  }

  final _WebApp? _app;
  final ValueNotifier<Brightness> _brightness = ValueNotifier(Brightness.dark);
  final ValueNotifier<EdgeInsets> _safeArea = ValueNotifier(EdgeInsets.zero);
  JSFunction? _mainHandler;
  JSFunction? _backHandler;

  void _syncBrightness() {
    _brightness.value = brightness;
  }

  void _syncSafeArea() {
    _safeArea.value = safeArea;
  }

  bool _supports(String version) => _app?.isVersionAtLeast(version) ?? false;

  @override
  bool get isAvailable => (_app?.initData ?? '').isNotEmpty;

  @override
  String get initData => _app?.initData ?? '';

  @override
  String? get startParam => _app?.initDataUnsafe.start_param;

  @override
  Brightness get brightness => _app?.colorScheme == 'light' ? Brightness.light : Brightness.dark;

  @override
  EdgeInsets get safeArea {
    final app = _app;
    if (app == null || !_supports('8.0')) {
      return EdgeInsets.zero;
    }
    double side(num? a, num? b) => ((a ?? 0) + (b ?? 0)).toDouble();
    final device = app.safeAreaInset;
    final content = app.contentSafeAreaInset;
    return EdgeInsets.fromLTRB(
      side(device?.left, content?.left),
      side(device?.top, content?.top),
      side(device?.right, content?.right),
      side(device?.bottom, content?.bottom),
    );
  }

  @override
  ValueListenable<Brightness> get brightnessListenable => _brightness;

  @override
  ValueListenable<EdgeInsets> get safeAreaListenable => _safeArea;

  @override
  void ready() {
    final app = _app;
    if (app == null) {
      return;
    }
    app.ready();
    app.expand();
    if (_supports('7.7')) {
      app.disableVerticalSwipes();
    }
  }

  @override
  void setColors({required Color header, required Color background, required Color bottomBar}) {
    final app = _app;
    if (app == null || !_supports('6.1')) {
      return;
    }
    app.setHeaderColor(_hex(header));
    app.setBackgroundColor(_hex(background));
    if (_supports('7.10')) {
      app.setBottomBarColor(_hex(bottomBar));
    }
  }

  @override
  void setMainButton(
    MainButtonState? state, {
    VoidCallback? onTap,
    required Color color,
    required Color textColor,
  }) {
    final app = _app;
    if (app == null) {
      return;
    }
    final button = app.MainButton;
    final previous = _mainHandler;
    if (previous != null) {
      button.offClick(previous);
      _mainHandler = null;
    }
    if (state == null) {
      button.hideProgress();
      button.hide();
      return;
    }
    final params = <String, Object?>{
      'text': state.text,
      'color': _hex(color),
      'text_color': _hex(textColor),
      'is_active': state.enabled,
      'is_visible': true,
      if (_supports('7.10')) 'has_shine_effect': state.enabled && !state.loading,
    };
    button.setParams(params.jsify()! as JSObject);
    if (state.loading) {
      button.showProgress(false);
    } else {
      button.hideProgress();
    }
    if (onTap != null) {
      final handler = onTap.toJS;
      _mainHandler = handler;
      button.onClick(handler);
    }
  }

  @override
  void setBackButton({required bool visible, VoidCallback? onTap}) {
    final app = _app;
    if (app == null || !_supports('6.1')) {
      return;
    }
    final button = app.BackButton;
    final previous = _backHandler;
    if (previous != null) {
      button.offClick(previous);
      _backHandler = null;
    }
    if (!visible) {
      button.hide();
      return;
    }
    if (onTap != null) {
      final handler = onTap.toJS;
      _backHandler = handler;
      button.onClick(handler);
    }
    button.show();
  }

  @override
  void haptic(HapticKind kind) {
    final app = _app;
    if (app == null || !_supports('6.1')) {
      return;
    }
    final haptic = app.HapticFeedback;
    switch (kind) {
      case HapticKind.selection:
        haptic.selectionChanged();
      case HapticKind.light:
        haptic.impactOccurred('light');
      case HapticKind.medium:
        haptic.impactOccurred('medium');
      case HapticKind.success:
        haptic.notificationOccurred('success');
      case HapticKind.warning:
        haptic.notificationOccurred('warning');
      case HapticKind.error:
        haptic.notificationOccurred('error');
    }
  }

  @override
  Future<bool> confirm(String message) {
    final app = _app;
    if (app == null || !_supports('6.2')) {
      return Future<bool>.value(true);
    }
    final completer = Completer<bool>();
    app.showConfirm(message, ((JSBoolean ok) => completer.complete(ok.toDart)).toJS);
    return completer.future;
  }

  @override
  void openLink(String url) => _app?.openLink(url);

  @override
  void openTelegramLink(String url) => _app?.openTelegramLink(url);

  @override
  void close() => _app?.close();

  static String _hex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}
