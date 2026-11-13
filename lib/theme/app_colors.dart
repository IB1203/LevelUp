import 'package:flutter/material.dart';

@immutable
class GymColors extends ThemeExtension<GymColors> {
  const GymColors({
    required this.pageBg,
    required this.bg,
    required this.bgRaised,
    required this.bgRaised2,
    required this.border,
    required this.navBg,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.ember,
    required this.emberDeep,
    required this.onEmber,
    required this.emberSoft,
    required this.emberShadow,
    required this.accent,
    required this.accentSoft,
    required this.brass,
    required this.sage,
    required this.sageSoft,
    required this.mutedFill,
    required this.heatEmpty,
    required this.info,
    required this.warn,
    required this.danger,
  });

  final Color pageBg;
  final Color bg;
  final Color bgRaised;
  final Color bgRaised2;
  final Color border;
  final Color navBg;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color ember;
  final Color emberDeep;
  final Color onEmber;
  final Color emberSoft;
  final Color emberShadow;
  final Color accent;
  final Color accentSoft;
  final Color brass;
  final Color sage;
  final Color sageSoft;
  final Color mutedFill;
  final Color heatEmpty;
  final Color info;
  final Color warn;
  final Color danger;

  static const dark = GymColors(
    pageBg: Color(0xFF0C111D),
    bg: Color(0xFF0C111D),
    bgRaised: Color(0xFF1A2130),
    bgRaised2: Color(0xFF141A27),
    border: Color(0xFF2A3244),
    navBg: Color(0xE60C111D),
    text: Color(0xFFF5F7FF),
    textSecondary: Color(0xFFA3ADC2),
    textTertiary: Color(0xFF66718A),
    ember: Color(0xFFFF7A45),
    emberDeep: Color(0xFFF05F2A),
    onEmber: Color(0xFF1A0A03),
    emberSoft: Color(0x1FFF7A45),
    emberShadow: Color(0x80000000),
    accent: Color(0xFFFF7A45),
    accentSoft: Color(0x29FF7A45),
    brass: Color(0xFFF4C95D),
    sage: Color(0xFF35D49A),
    sageSoft: Color(0x2935D49A),
    mutedFill: Color(0xFF161D2C),
    heatEmpty: Color(0xFF131A28),
    info: Color(0xFF8B9BFF),
    warn: Color(0xFFF4C95D),
    danger: Color(0xFFFF6B81),
  );

  static const amoled = GymColors(
    pageBg: Color(0xFF000000),
    bg: Color(0xFF000000),
    bgRaised: Color(0xFF161C29),
    bgRaised2: Color(0xFF0B0F18),
    border: Color(0xFF222938),
    navBg: Color(0xE6000000),
    text: Color(0xFFF5F7FF),
    textSecondary: Color(0xFFA3ADC2),
    textTertiary: Color(0xFF66718A),
    ember: Color(0xFFFF7A45),
    emberDeep: Color(0xFFF05F2A),
    onEmber: Color(0xFF1A0A03),
    emberSoft: Color(0x1FFF7A45),
    emberShadow: Color(0x80000000),
    accent: Color(0xFFFF7A45),
    accentSoft: Color(0x29FF7A45),
    brass: Color(0xFFF4C95D),
    sage: Color(0xFF35D49A),
    sageSoft: Color(0x2935D49A),
    mutedFill: Color(0xFF0F141F),
    heatEmpty: Color(0xFF0C111B),
    info: Color(0xFF8B9BFF),
    warn: Color(0xFFF4C95D),
    danger: Color(0xFFFF6B81),
  );

  static const light = GymColors(
    pageBg: Color(0xFFF7F9FF),
    bg: Color(0xFFEEF2FB),
    bgRaised: Color(0xFFFFFFFF),
    bgRaised2: Color(0xFFE2E8F6),
    border: Color(0xFFD0D8EA),
    navBg: Color(0xF2F7F9FF),
    text: Color(0xFF0B1430),
    textSecondary: Color(0xFF4A5678),
    textTertiary: Color(0xFF7A86A6),
    ember: Color(0xFF0B1430),
    emberDeep: Color(0xFF000000),
    onEmber: Color(0xFFFFFFFF),
    emberSoft: Color(0x120B1430),
    emberShadow: Color(0x1F0B1430),
    accent: Color(0xFFA83B0A),
    accentSoft: Color(0x1FA83B0A),
    brass: Color(0xFFF4C95D),
    sage: Color(0xFF35D49A),
    sageSoft: Color(0x1F35D49A),
    mutedFill: Color(0xFFE3E9F5),
    heatEmpty: Color(0xFFDFE5F1),
    info: Color(0xFF5B4BD6),
    warn: Color(0xFFF4C95D),
    danger: Color(0xFFC0392B),
  );

  @override
  GymColors copyWith({
    Color? pageBg,
    Color? bg,
    Color? bgRaised,
    Color? bgRaised2,
    Color? border,
    Color? navBg,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? ember,
    Color? emberDeep,
    Color? onEmber,
    Color? emberSoft,
    Color? emberShadow,
    Color? accent,
    Color? accentSoft,
    Color? brass,
    Color? sage,
    Color? sageSoft,
    Color? mutedFill,
    Color? heatEmpty,
    Color? info,
    Color? warn,
    Color? danger,
  }) {
    return GymColors(
      pageBg: pageBg ?? this.pageBg,
      bg: bg ?? this.bg,
      bgRaised: bgRaised ?? this.bgRaised,
      bgRaised2: bgRaised2 ?? this.bgRaised2,
      border: border ?? this.border,
      navBg: navBg ?? this.navBg,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      ember: ember ?? this.ember,
      emberDeep: emberDeep ?? this.emberDeep,
      onEmber: onEmber ?? this.onEmber,
      emberSoft: emberSoft ?? this.emberSoft,
      emberShadow: emberShadow ?? this.emberShadow,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      brass: brass ?? this.brass,
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      mutedFill: mutedFill ?? this.mutedFill,
      heatEmpty: heatEmpty ?? this.heatEmpty,
      info: info ?? this.info,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  GymColors lerp(GymColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GymColors(
      pageBg: c(pageBg, other.pageBg),
      bg: c(bg, other.bg),
      bgRaised: c(bgRaised, other.bgRaised),
      bgRaised2: c(bgRaised2, other.bgRaised2),
      border: c(border, other.border),
      navBg: c(navBg, other.navBg),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      ember: c(ember, other.ember),
      emberDeep: c(emberDeep, other.emberDeep),
      onEmber: c(onEmber, other.onEmber),
      emberSoft: c(emberSoft, other.emberSoft),
      emberShadow: c(emberShadow, other.emberShadow),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      brass: c(brass, other.brass),
      sage: c(sage, other.sage),
      sageSoft: c(sageSoft, other.sageSoft),
      mutedFill: c(mutedFill, other.mutedFill),
      heatEmpty: c(heatEmpty, other.heatEmpty),
      info: c(info, other.info),
      warn: c(warn, other.warn),
      danger: c(danger, other.danger),
    );
  }
}

extension GymColorsX on BuildContext {
  GymColors get gc => Theme.of(this).extension<GymColors>()!;
}
