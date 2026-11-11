import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Hunter accents on top of the theme tokens. Everything else follows the
/// GymMane design language: rounded soft cards, Nunito, pill controls.
class Sx {
  const Sx._();
  static const mana = Color(0xFF5CC8FF);
  static const violet = Color(0xFF9B8CFF);
  static const gold = Color(0xFFF4C95D);
  static const vital = Color(0xFF5EE6B0);
  static const alert = Color(0xFFFF6B81);

  static Color rank(String letter) => switch (letter) {
    'E' => const Color(0xFF93A1C8),
    'D' => vital,
    'C' => mana,
    'B' => violet,
    'A' => gold,
    'S' => alert,
    _ => mana,
  };

  /// Display text in GymMane's type: Nunito, heavy, tight tracking.
  static TextStyle disp(double size, {Color? color, FontWeight weight = FontWeight.w800, double spacing = 0}) =>
      AppTheme.f(
        size,
        weight: size >= 20 ? FontWeight.w800 : weight,
        color: color,
        letterSpacing: spacing > 1 ? 0.6 : spacing * 0.5,
        height: 1.15,
      );
}

/// A GymMane soft card. [title] renders as a small section label with an
/// accent dot; [glow] marks the card as the one that needs attention.
class SystemWindow extends StatelessWidget {
  const SystemWindow({
    super.key,
    required this.child,
    this.title,
    this.accent = Sx.mana,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.onTap,
    this.trailing,
    this.glow = false,
  });

  final Widget child;
  final String? title;
  final Color accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
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
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

bool fitDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// The rank badge: a rounded hexagon with the rank letter.
class RankEmblem extends StatelessWidget {
  const RankEmblem({super.key, required this.letter, this.size = 64});
  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Sx.rank(letter);
    return SizedBox(
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

/// GymMane-style rounded progress bar.
class SystemBar extends StatelessWidget {
  const SystemBar({super.key, required this.value, this.color = Sx.mana, this.height = 7});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return ClipRRect(
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
    );
  }
}

/// Small label + big value, like GymMane's stat cells.
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
  const SystemChip(this.text, {super.key, this.color = Sx.mana});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
    child: Text(
      titleCase(text),
      style: AppTheme.f(11.5, weight: FontWeight.w700, color: color),
    ),
  );
}

/// Badge glyphs for achievements (names come from the catalog).
IconData badgeIcon(String name) => switch (name) {
  'star' => Icons.star_rounded,
  'bolt' => Icons.bolt_rounded,
  'fitness' => Icons.fitness_center_rounded,
  'run' => Icons.directions_run_rounded,
  'walk' => Icons.directions_walk_rounded,
  'spa' => Icons.spa_rounded,
  'calendar' => Icons.event_available_rounded,
  'trophy' => Icons.emoji_events_rounded,
  'shield' => Icons.shield_rounded,
  'replay' => Icons.replay_rounded,
  'up' => Icons.trending_up_rounded,
  'flag' => Icons.flag_rounded,
  _ => Icons.military_tech_rounded,
};

Color rarityColor(String rarity) => switch (rarity) {
  'common' => const Color(0xFF93A1C8),
  'uncommon' => Sx.vital,
  'rare' => Sx.mana,
  'epic' => Sx.violet,
  'legendary' => Sx.gold,
  _ => Sx.mana,
};

/// Colour of a cosmetic profile frame.
Color frameColor(String id) => switch (id) {
  'verdant' => Sx.vital,
  'azure' => Sx.mana,
  'violet' => Sx.violet,
  'gilded' => Sx.gold,
  'crimson' => Sx.alert,
  'holo' => const Color(0xFF7DF9FF),
  _ => const Color(0xFF93A1C8),
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
    final c = frameColor(widget.frame);
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
                ? const [Color(0xFF7DF9FF), Sx.violet, Sx.gold, Color(0xFF7DF9FF)]
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
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
