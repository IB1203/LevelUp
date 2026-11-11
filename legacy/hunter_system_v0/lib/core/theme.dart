import 'package:flutter/material.dart';

/// The Hunter System palette. Deep-water navy, a cold "mana" blue for the
/// System's own voice, violet for rank, and gold reserved for rewards.
class Hx {
  const Hx._();

  static const Color abyss = Color(0xFF070C1C);
  static const Color panel = Color(0xFF0E1730);
  static const Color panelHigh = Color(0xFF16213F);
  static const Color line = Color(0xFF27365F);
  static const Color mana = Color(0xFF5CC8FF);
  static const Color violet = Color(0xFF9B8CFF);
  static const Color gold = Color(0xFFF4C95D);
  static const Color vital = Color(0xFF5EE6B0);
  static const Color alert = Color(0xFFFF6B81);
  static const Color text = Color(0xFFE8EEFF);
  static const Color textDim = Color(0xFF93A1C8);

  static const String display = 'Rajdhani';

  /// The cut-corner outline every System window uses.
  static BeveledRectangleBorder cut({Color? side, double corner = 10, double width = 1}) =>
      BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(corner),
        side: side == null ? BorderSide.none : BorderSide(color: side, width: width),
      );
}

ThemeData buildHunterTheme() {
  const scheme = ColorScheme.dark(
    primary: Hx.mana,
    onPrimary: Color(0xFF03101F),
    secondary: Hx.violet,
    onSecondary: Color(0xFF0B0720),
    tertiary: Hx.gold,
    error: Hx.alert,
    surface: Hx.panel,
    onSurface: Hx.text,
    outline: Hx.line,
  );

  TextStyle display(double size, FontWeight weight, {double spacing = 0, double? height}) =>
      TextStyle(
        fontFamily: Hx.display,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: Hx.text,
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Hx.abyss,
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displaySmall: display(40, FontWeight.w700, height: 1.0),
          headlineMedium: display(30, FontWeight.w700, height: 1.05),
          headlineSmall: display(24, FontWeight.w700, height: 1.1),
          titleLarge: display(21, FontWeight.w600, spacing: 0.2),
          titleMedium: display(18, FontWeight.w600, spacing: 0.2),
          titleSmall: display(15, FontWeight.w600, spacing: 0.4),
          labelLarge: display(16, FontWeight.w700, spacing: 0.6),
          labelMedium: display(14, FontWeight.w600, spacing: 0.4),
          labelSmall: display(13, FontWeight.w600, spacing: 0.4),
        )
        .apply(bodyColor: Hx.text, displayColor: Hx.text),
    appBarTheme: AppBarTheme(
      backgroundColor: Hx.abyss,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: display(22, FontWeight.w700, spacing: 0.4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0A1125),
      surfaceTintColor: Colors.transparent,
      indicatorColor: Hx.mana.withValues(alpha: 0.16),
      indicatorShape: Hx.cut(corner: 6),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => display(13, FontWeight.w600, spacing: 0.4).copyWith(
          color: states.contains(WidgetState.selected) ? Hx.mana : Hx.textDim,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Hx.mana : Hx.textDim,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Hx.mana,
        foregroundColor: const Color(0xFF03101F),
        disabledBackgroundColor: Hx.line,
        disabledForegroundColor: Hx.textDim,
        minimumSize: const Size(64, 52),
        shape: Hx.cut(corner: 8),
        textStyle: display(18, FontWeight.w700, spacing: 0.8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Hx.mana,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: Hx.line),
        shape: Hx.cut(corner: 8),
        textStyle: display(16, FontWeight.w700, spacing: 0.6),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Hx.mana,
        textStyle: display(16, FontWeight.w700, spacing: 0.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Hx.panel,
      selectedColor: Hx.mana.withValues(alpha: 0.18),
      checkmarkColor: Hx.mana,
      side: const BorderSide(color: Hx.line),
      shape: Hx.cut(corner: 6),
      labelStyle: display(15, FontWeight.w600, spacing: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Hx.panel,
      hintStyle: const TextStyle(color: Hx.textDim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Hx.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Hx.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Hx.mana, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Hx.panel,
      surfaceTintColor: Colors.transparent,
      shape: Hx.cut(corner: 14, side: Hx.line),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Hx.panel,
      surfaceTintColor: Colors.transparent,
      shape: Hx.cut(corner: 12, side: Hx.line),
      titleTextStyle: display(22, FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Hx.panelHigh,
      contentTextStyle: display(16, FontWeight.w600).copyWith(color: Hx.text),
      behavior: SnackBarBehavior.floating,
      shape: Hx.cut(corner: 8, side: Hx.mana),
    ),
    dividerTheme: const DividerThemeData(color: Hx.line, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Hx.mana : Hx.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Hx.mana.withValues(alpha: 0.3)
            : Hx.panelHigh,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Hx.mana,
      linearTrackColor: Hx.panelHigh,
    ),
  );
}
