import 'package:flutter/material.dart';

/// DVOR design tokens: olive-lime accent from the club's stories,
/// Montserrat Black headlines, calm dark/light surfaces.
@immutable
class DvorColors extends ThemeExtension<DvorColors> {
  const DvorColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.stroke,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.hike,
    required this.trail,
    required this.danger,
    required this.warning,
    required this.success,
  });

  static const Color lime = Color(0xFFADB838);

  static const DvorColors dark = DvorColors(
    background: Color(0xFF0D0E0B),
    surface: Color(0xFF171812),
    surfaceRaised: Color(0xFF20221A),
    stroke: Color(0x14FFFFFF),
    ink: Color(0xFFF4F5EE),
    inkMuted: Color(0xB3F4F5EE),
    inkFaint: Color(0x66F4F5EE),
    accent: lime,
    onAccent: Color(0xFF0D0E0B),
    hike: Color(0xFF7DB8A2),
    trail: Color(0xFFE2A75B),
    danger: Color(0xFFEF6B5B),
    warning: Color(0xFFE8C14E),
    success: Color(0xFFB9C845),
  );

  static const DvorColors light = DvorColors(
    background: Color(0xFFF3F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF8F8F2),
    stroke: Color(0x14111209),
    ink: Color(0xFF111209),
    inkMuted: Color(0xA6111209),
    inkFaint: Color(0x59111209),
    accent: Color(0xFF8F9A22),
    onAccent: Color(0xFFFFFFFF),
    hike: Color(0xFF2F8466),
    trail: Color(0xFFC0771C),
    danger: Color(0xFFD2412F),
    warning: Color(0xFFB7880F),
    success: Color(0xFF6E7B12),
  );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color stroke;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color accent;
  final Color onAccent;
  final Color hike;
  final Color trail;
  final Color danger;
  final Color warning;
  final Color success;

  @override
  DvorColors copyWith() => this;

  @override
  DvorColors lerp(DvorColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return DvorColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      stroke: mix(stroke, other.stroke),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      hike: mix(hike, other.hike),
      trail: mix(trail, other.trail),
      danger: mix(danger, other.danger),
      warning: mix(warning, other.warning),
      success: mix(success, other.success),
    );
  }
}

abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 16;
}

abstract final class Radii {
  static const double chip = 999;
  static const double card = 24;
  static const double tile = 18;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
}

extension DvorThemeX on BuildContext {
  DvorColors get colors => Theme.of(this).extension<DvorColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? DvorColors.dark : DvorColors.light;
  const family = 'Montserrat';
  TextStyle style(double size, FontWeight weight, {double height = 1.25, double spacing = 0}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: c.ink,
      );

  final textTheme = TextTheme(
    displayLarge: style(40, FontWeight.w900, height: 0.98, spacing: -1),
    displayMedium: style(32, FontWeight.w900, height: 1.0, spacing: -0.8),
    headlineMedium: style(24, FontWeight.w900, height: 1.05, spacing: -0.4),
    titleLarge: style(18, FontWeight.w800, height: 1.15, spacing: -0.2),
    titleMedium: style(15, FontWeight.w800, height: 1.2),
    bodyLarge: style(15, FontWeight.w500, height: 1.45),
    bodyMedium: style(14, FontWeight.w500, height: 1.4),
    labelLarge: style(14, FontWeight.w800, spacing: 0.2),
    labelMedium: style(12, FontWeight.w800, spacing: 0.4),
    labelSmall: style(11, FontWeight.w800, spacing: 0.8),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: family,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DvorColors.lime,
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.ink,
      error: c.danger,
    ),
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [c],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: style(14, FontWeight.w800).copyWith(color: c.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
