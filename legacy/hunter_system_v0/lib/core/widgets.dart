import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

/// A System window: cut corners, hairline border, optional glow.
class SystemPanel extends StatelessWidget {
  const SystemPanel({
    super.key,
    required this.child,
    this.accent = Hx.line,
    this.glow = false,
    this.padding = const EdgeInsets.all(16),
    this.color = Hx.panel,
    this.onTap,
  });

  final Widget child;
  final Color accent;
  final bool glow;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = Hx.cut(side: accent, corner: 12);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: color,
        shadows: glow
            ? [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 22)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A line in the System's voice, e.g. "[ Daily quest has arrived ]".
class SystemLine extends StatelessWidget {
  const SystemLine(this.text, {super.key, this.color = Hx.mana, this.center = false});

  final String text;
  final Color color;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      '[ $text ]',
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.titleSmall!.copyWith(color: color),
    );
  }
}

/// Small tag such as "Recovery" or "15 min".
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color = Hx.textDim, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        shape: Hx.cut(side: color.withValues(alpha: 0.55), corner: 4),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Hexagonal rank badge with the rank letter.
class RankEmblem extends StatelessWidget {
  const RankEmblem({super.key, required this.letter, this.size = 84, this.variant = 0});

  final String letter;
  final double size;

  /// 0–3: which inner pattern to draw. Cosmetic only.
  final int variant;

  static Color colorFor(String letter) {
    switch (letter) {
      case 'S':
        return Hx.gold;
      case 'A':
        return Hx.alert;
      case 'B':
        return Hx.violet;
      case 'C':
        return Hx.vital;
      default:
        return Hx.mana;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(letter);
    return Semantics(
      label: 'Rank $letter',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _EmblemPainter(color, variant),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                letter,
                style: TextStyle(
                  fontFamily: Hx.display,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.5,
                  height: 1,
                  color: color,
                  shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 14)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.color, this.variant);
  final Color color;
  final int variant;

  Path _hex(Offset c, double r, [double rotation = -math.pi / 2]) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = rotation + i * math.pi / 3;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final outer = _hex(c, r * 0.96);

    canvas.drawPath(
      outer,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(outer, Paint()..color = Hx.abyss);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.45);
    switch (variant % 4) {
      case 0:
        canvas.drawPath(_hex(c, r * 0.78), inner);
      case 1:
        canvas.drawPath(_hex(c, r * 0.78, 0), inner);
      case 2:
        canvas.drawCircle(c, r * 0.7, inner);
      case 3:
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          canvas.drawLine(
            Offset(c.dx + r * 0.72 * math.cos(a), c.dy + r * 0.72 * math.sin(a)),
            Offset(c.dx + r * 0.92 * math.cos(a), c.dy + r * 0.92 * math.sin(a)),
            inner,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.color != color || old.variant != variant;
}

/// Segmented experience bar.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, this.color = Hx.mana, this.height = 10});

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${(progress * 100).round()} percent',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _XpBarPainter(progress.clamp(0.0, 1.0), color)),
      ),
    );
  }
}

class _XpBarPainter extends CustomPainter {
  _XpBarPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 20;
    const gap = 2.0;
    final w = (size.width - gap * (segments - 1)) / segments;
    final slant = size.height * 0.35;
    for (var i = 0; i < segments; i++) {
      final x = i * (w + gap);
      final filled = (i + 1) / segments <= progress + 0.0001;
      final partial = !filled && i / segments < progress;
      final path = Path()
        ..moveTo(x + slant, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w - slant, size.height)
        ..lineTo(x, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = filled
              ? color
              : partial
                  ? color.withValues(alpha: 0.45)
                  : Hx.panelHigh,
      );
    }
  }

  @override
  bool shouldRepaint(_XpBarPainter old) => old.progress != progress || old.color != color;
}

/// Five-point attribute chart.
class StatRadar extends StatelessWidget {
  const StatRadar({super.key, required this.values, this.size = 220});

  final Map<Attribute, int> values;
  final double size;

  @override
  Widget build(BuildContext context) {
    final summary = Attribute.values
        .map((a) => '${a.label} ${values[a] ?? 0}')
        .join(', ');
    return Semantics(
      label: 'Attribute chart. $summary',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RadarPainter(values)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.values);
  final Map<Attribute, int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 26;
    const n = 5;
    Offset point(int i, double f) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return Offset(c.dx + r * f * math.cos(a), c.dy + r * f * math.sin(a));
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Hx.line;
    for (final f in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, f);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, point(i, 1), grid);
    }

    // Scale to the strongest attribute so the shape shows balance, with a
    // floor so a brand-new player does not get a misleadingly full chart.
    final peak = math.max(
      20,
      Attribute.values.map((a) => values[a] ?? 0).reduce(math.max),
    );
    final shape = Path();
    for (var i = 0; i < n; i++) {
      final v = (values[Attribute.values[i]] ?? 0) / peak;
      final p = point(i, 0.08 + 0.92 * v.clamp(0.0, 1.0));
      i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color = Hx.mana.withValues(alpha: 0.22));
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Hx.mana,
    );

    for (var i = 0; i < n; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: Attribute.values[i].short,
          style: const TextStyle(
            fontFamily: Hx.display,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Hx.textDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = point(i, 1.2);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => true;
}

/// Heading used between groups of content on a screen.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: Hx.mana),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pick one value from a short list.
class SingleChoice<T> extends StatelessWidget {
  const SingleChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(label(o)),
            selected: o == selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(o),
          ),
      ],
    );
  }
}

/// Pick any number of values from a short list.
class MultiChoice<T> extends StatelessWidget {
  const MultiChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T) label;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(label(o)),
            selected: selected.contains(o),
            onSelected: (on) {
              final next = {...selected};
              on ? next.add(o) : next.remove(o);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

String formatClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String friendlyDate(String key, String today) {
  final gap = dayGap(key, today);
  if (gap == 0) return 'Today';
  if (gap == 1) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = parseDateKey(key);
  return '${d.day} ${months[d.month - 1]}';
}
