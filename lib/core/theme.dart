import 'package:flutter/material.dart';

/// Brand + accent palette. Screens pick accents from here, never raw hex.
/// (The user's chosen app color is [AppAccent], not [brand].)
class AppColors {
  static const brand = Color(0xFF5B5BF0);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF59E0B);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF10B981);
  static const pink = Color(0xFFEC4899);
  static const teal = Color(0xFF14B8A6);
  static const red = Color(0xFFEF4444);
}

extension AppColorX on Color {
  /// A soft two-tone gradient starting at this color.
  LinearGradient get gradient {
    final hsl = HSLColor.fromColor(this);
    final end = hsl
        .withHue((hsl.hue + 28) % 360)
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0).toDouble())
        .toColor();
    return LinearGradient(
      colors: [this, end],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

/// The app color the user picked in Settings. Same in light and dark mode,
/// so gradients and banners keep their contrast. Read it with [AppAccent.of].
class AppAccent extends ThemeExtension<AppAccent> {
  final Color color;
  const AppAccent(this.color);

  static Color of(BuildContext context) =>
      Theme.of(context).extension<AppAccent>()?.color ?? AppColors.brand;

  @override
  AppAccent copyWith({Color? color}) => AppAccent(color ?? this.color);

  @override
  AppAccent lerp(ThemeExtension<AppAccent>? other, double t) => other is AppAccent
      ? AppAccent(Color.lerp(color, other.color, t) ?? color)
      : this;
}

class AppTheme {
  static ThemeData light(Color accent) => _build(Brightness.light, accent);
  static ThemeData dark(Color accent) => _build(Brightness.dark, accent);

  static ThemeData _build(Brightness b, Color accent) {
    final isDark = b == Brightness.dark;
    var scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b);
    scheme = scheme.copyWith(
      surface: isDark ? const Color(0xFF171A26) : Colors.white,
      primary: isDark ? null : accent,
      onPrimary: isDark ? null : Colors.white,
    );
    final background = isDark ? const Color(0xFF0E1018) : const Color(0xFFF3F4FB);
    const sheetShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: [AppAccent(accent)],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
            color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: sheetShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 68,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      ),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
