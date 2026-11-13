import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Hunter accent colours on top of the theme tokens.
///
/// The neon arcade palette only clears WCAG AA against the dark surfaces, so
/// light mode swaps in deeper variants of the same hues. Resolve it through
/// `context.sx` instead of hard-coding a colour.
@immutable
class HunterPalette {
  const HunterPalette({
    required this.mana,
    required this.violet,
    required this.gold,
    required this.vital,
    required this.alert,
    required this.muted,
    required this.holo,
  });

  final Color mana;
  final Color violet;
  final Color gold;
  final Color vital;
  final Color alert;

  /// Neutral grey-blue shared by E-rank, common rarity and the basic frame.
  final Color muted;

  /// Cool cyan: the holographic frame and C-rank, so rank colours stay distinct
  /// from the coral action colour.
  final Color holo;

  static const dark = HunterPalette(
    mana: Color(0xFFFF7A45),
    violet: Color(0xFF8B9BFF),
    gold: Color(0xFFF4C95D),
    vital: Color(0xFF35D49A),
    alert: Color(0xFFFF6B81),
    muted: Color(0xFFA3ADC2),
    holo: Color(0xFF5CC8FF),
  );

  static const light = HunterPalette(
    mana: Color(0xFFA83B0A),
    violet: Color(0xFF5B4BD6),
    gold: Color(0xFF7A5600),
    vital: Color(0xFF0A6E4F),
    alert: Color(0xFFB3182E),
    muted: Color(0xFF4A5678),
    holo: Color(0xFF1A5FB4),
  );

  Color rank(String letter) => switch (letter) {
    'E' => muted,
    'D' => vital,
    'C' => holo,
    'B' => violet,
    'A' => gold,
    'S' => alert,
    _ => mana,
  };
}

extension HunterPaletteX on BuildContext {
  /// Accent palette that matches the current brightness.
  HunterPalette get sx => fitDark(this) ? HunterPalette.dark : HunterPalette.light;
}

/// Display text in the Hunter System's type: rounded, heavy, tight tracking.
class Sx {
  const Sx._();

  static TextStyle disp(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w800,
    double spacing = 0,
  }) => AppTheme.f(
    size,
    weight: size >= 20 ? FontWeight.w800 : weight,
    color: color,
    letterSpacing: spacing > 1 ? 0.6 : spacing * 0.5,
    height: 1.15,
  );
}

/// A soft Hunter System card. [title] renders as a small section label with an
/// accent dot; [glow] marks the card as the one that needs attention.
class SystemWindow extends StatelessWidget {
  const SystemWindow({
    super.key,
    required this.child,
    this.title,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.onTap,
    this.trailing,
    this.glow = false,
    this.semanticsLabel,
  });

  final Widget child;
  final String? title;
  final Color? accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool glow;

  /// Screen-reader label for tappable windows and compact tiles.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final accent = this.accent ?? context.sx.mana;
    final card = SoftCard(
      radius: 22,
      padding: padding,
      borderColor: glow ? accent.withValues(alpha: 0.55) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: SectionLabel(title!, color: gc.textSecondary)),
                ?trailing,
                if (onTap != null && trailing == null)
                  Icon(PhosphorIconsBold.caretRight, size: 13, color: gc.textTertiary),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
    final widget = onTap == null ? card : Pressable(onTap: onTap, child: card);
    if (semanticsLabel == null) return widget;
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: widget,
    );
  }
}

bool fitDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// The rank badge: a rounded hexagon with the rank letter.
class RankEmblem extends StatelessWidget {
  const RankEmblem({super.key, required this.letter, this.size = 64, this.semanticsLabel});
  final String letter;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.sx.rank(letter);
    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel ?? '$letter rank emblem',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _HexPainter(c, context.gc.bgRaised2),
          child: Center(
            child: Text(
              letter,
              style: AppTheme.f(size * 0.44, weight: FontWeight.w900, color: c),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.color, this.fill);
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.94;
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 2;
      final o = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = Color.alphaBlend(color.withValues(alpha: 0.14), fill));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.045
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color || old.fill != fill;
}

/// Rounded Hunter System progress bar.
class SystemBar extends StatelessWidget {
  const SystemBar({super.key, required this.value, this.color, this.height = 7, this.semanticsLabel});
  final double value;
  final Color? color;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final color = this.color ?? context.sx.mana;
    return Semantics(
      label: semanticsLabel ?? 'Progress',
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: height,
          color: gc.mutedFill,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small label + big value, like the System stat cells.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTheme.f(20, weight: FontWeight.w800, color: color ?? gc.text),
        ),
        const SizedBox(height: 2),
        SectionLabel(label),
      ],
    );
  }
}

/// A small pill tag.
class SystemChip extends StatelessWidget {
  const SystemChip(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.sx.mana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        titleCase(text),
        style: AppTheme.f(11.5, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// A compact gold XP reward label. Used on quest cards, weekly missions and
/// reward rows so every XP figure in the System reads the same.
class XpPill extends StatelessWidget {
  const XpPill({super.key, required this.xp, this.label = 'XP', this.dense = false, this.muted = false});

  final int xp;
  final String label;
  final bool dense;

  /// Dims the pill for closed or completed quests without hiding the reward.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final gold = muted ? context.gc.textSecondary : context.sx.gold;
    return Container(
      height: dense ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: gold.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsFill.lightning, size: dense ? 10 : 12, color: gold),
          const SizedBox(width: 3),
          Text(
            '+$xp $label',
            style: AppTheme.f(dense ? 11 : 12.5, weight: FontWeight.w800, color: gold),
          ),
        ],
      ),
    );
  }
}

/// A status pill with an optional glyph. Colours stay in the Hunter palette;
/// only the meaning changes between quest, weekly and profile states.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: dense ? 21 : 25,
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 10 : 11.5, color: color), const SizedBox(width: 4)],
          Text(
            label,
            maxLines: 1,
            style: AppTheme.f(dense ? 10 : 10.8, weight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// A quiet metadata chip (duration, attribute reward, unit).
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final tone = color ?? gc.textSecondary;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: gc.bgRaised2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 10.5, color: tone), const SizedBox(width: 4)],
          Text(
            label,
            style: AppTheme.f(10.8, weight: FontWeight.w700, color: tone),
          ),
        ],
      ),
    );
  }
}

/// A responsive profile statistic. Label above value, glyph at the leading
/// edge: the same cell works at 120 dp and at 320 dp.
class HunterStatTile extends StatelessWidget {
  const HunterStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final tone = color ?? context.sx.mana;
    return Semantics(
      container: true,
      label: '$label: $value${hint == null ? '' : '. $hint'}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: gc.bgRaised2.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gc.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 15, color: tone),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: AppTheme.f(18, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(
                      9.2,
                      weight: FontWeight.w700,
                      color: gc.textTertiary,
                      letterSpacing: 0.7,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with an optional count and text action, used by the quest
/// board and the profile.
class HunterSectionHeader extends StatelessWidget {
  const HunterSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.accent,
    this.countColor,
  });

  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;
  final Color? countColor;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Row(
      children: [
        if (accent != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kickerStyle(gc, color: accent ?? gc.textTertiary),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          Text(
            count!,
            style: AppTheme.f(11, weight: FontWeight.w800, color: countColor ?? gc.textTertiary),
          ),
        ],
        const Spacer(),
        if (actionLabel != null && onAction != null)
          Pressable(
            onTap: onAction,
            scale: 0.94,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: AppTheme.f(12, weight: FontWeight.w700, color: context.sx.mana),
                  ),
                  const SizedBox(width: 2),
                  Icon(PhosphorIconsBold.caretRight, size: 11, color: context.sx.mana),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Badge glyphs for achievements (names come from the catalog).
/// Achievement glyphs, from the same icon family as the rest of the app.
IconData badgeIcon(String name) => switch (name) {
  'star' => PhosphorIconsFill.star,
  'bolt' => PhosphorIconsFill.lightning,
  'fitness' => PhosphorIconsFill.barbell,
  'run' => PhosphorIconsFill.personSimpleRun,
  'walk' => PhosphorIconsFill.personSimpleWalk,
  'spa' => PhosphorIconsFill.flowerLotus,
  'calendar' => PhosphorIconsFill.calendarCheck,
  'trophy' => PhosphorIconsFill.trophy,
  'shield' => PhosphorIconsFill.shield,
  'replay' => PhosphorIconsFill.arrowCounterClockwise,
  'up' => PhosphorIconsFill.trendUp,
  'flag' => PhosphorIconsFill.flag,
  _ => PhosphorIconsFill.medal,
};

Color rarityColor(String rarity, HunterPalette sx) => switch (rarity) {
  'common' => sx.muted,
  'uncommon' => sx.vital,
  'rare' => sx.mana,
  'epic' => sx.violet,
  'legendary' => sx.gold,
  _ => sx.mana,
};

/// Colour of a cosmetic profile frame.
Color frameColor(String id, HunterPalette sx) => switch (id) {
  'verdant' => sx.vital,
  'azure' => sx.holo,
  'violet' => sx.violet,
  'gilded' => sx.gold,
  'crimson' => sx.alert,
  'holo' => sx.holo,
  _ => sx.muted,
};

/// A ring frame around the rank emblem; the holographic frame shimmers.
class FramedEmblem extends StatefulWidget {
  const FramedEmblem({super.key, required this.letter, required this.frame, this.size = 76});
  final String letter;
  final String frame;
  final double size;

  @override
  State<FramedEmblem> createState() => _FramedEmblemState();
}

class _FramedEmblemState extends State<FramedEmblem> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (widget.frame == 'holo' && !still) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sx = context.sx;
    final c = frameColor(widget.frame, sx);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        width: widget.size + 12,
        height: widget.size + 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            transform: GradientRotation(_c.value * 2 * math.pi),
            colors: widget.frame == 'holo'
                ? [sx.holo, sx.violet, sx.gold, sx.holo]
                : [c, c.withValues(alpha: 0.35), c],
          ),
        ),
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.gc.bg),
          alignment: Alignment.center,
          child: child,
        ),
      ),
      child: RankEmblem(letter: widget.letter, size: widget.size),
    );
  }
}

/// A one-shot burst of glowing particles. Renders nothing when the user
/// asked for reduced motion or turned System animations off.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({super.key, required this.color, this.enabled = true, this.count = 36});
  final Color color;
  final bool enabled;
  final int count;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _rand = math.Random();
  late final List<(double, double, double)> _p = [
    for (var i = 0; i < widget.count; i++)
      (_rand.nextDouble() * 2 * math.pi, 0.4 + _rand.nextDouble() * 0.6, 1.5 + _rand.nextDouble() * 2.5),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.of(context).disableAnimations) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _BurstPainter(_p, Curves.easeOutCubic.transform(_c.value), widget.color)),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.p, this.t, this.color);
  final List<(double, double, double)> p;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final reach = size.shortestSide * 0.55;
    for (final (angle, speed, r) in p) {
      final o = c + Offset(math.cos(angle), math.sin(angle)) * reach * speed * t;
      canvas.drawCircle(
        o,
        r * (1 - t * 0.5),
        Paint()
          ..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
