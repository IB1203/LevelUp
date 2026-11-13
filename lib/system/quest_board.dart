import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'system_sheets.dart';
import 'system_widgets.dart';

/// Colour and glyph pair that gives each quest category its own quiet
/// identity while keeping the same card layout.
class QuestVisual {
  const QuestVisual(this.color, this.icon);

  final Color color;
  final IconData icon;

  static QuestVisual of(BuildContext context, QuestCategory category) {
    final sx = context.sx;
    return switch (category) {
      QuestCategory.main => QuestVisual(sx.mana, PhosphorIconsRegular.flagPennant),
      QuestCategory.side => QuestVisual(sx.holo, PhosphorIconsRegular.target),
      QuestCategory.strength => QuestVisual(sx.alert, PhosphorIconsRegular.barbell),
      QuestCategory.endurance => QuestVisual(sx.violet, PhosphorIconsRegular.personSimpleRun),
      QuestCategory.mobility => QuestVisual(sx.holo, PhosphorIconsRegular.flowerLotus),
      QuestCategory.recovery => QuestVisual(sx.vital, PhosphorIconsRegular.heartbeat),
      QuestCategory.discipline => QuestVisual(sx.gold, PhosphorIconsRegular.calendarCheck),
      QuestCategory.bonus => QuestVisual(sx.violet, PhosphorIconsRegular.sparkle),
      QuestCategory.trial => QuestVisual(sx.gold, PhosphorIconsRegular.trophy),
      QuestCategory.boss => QuestVisual(sx.alert, PhosphorIconsRegular.shield),
    };
  }
}

/// Status colour/glyph for a quest. Kept next to the card so the sheet, board
/// and profile can share the same semantics.
({Color color, IconData icon}) questStatusVisual(BuildContext context, Quest q) {
  final sx = context.sx;
  return switch (q.status) {
    QuestStatus.offered => (color: sx.mana, icon: PhosphorIconsRegular.plusCircle),
    QuestStatus.accepted => (color: sx.holo, icon: PhosphorIconsRegular.flag),
    QuestStatus.active => (color: sx.mana, icon: PhosphorIconsFill.lightning),
    QuestStatus.completed => (color: sx.vital, icon: PhosphorIconsFill.checkCircle),
    QuestStatus.partial => (color: sx.gold, icon: PhosphorIconsRegular.circleHalf),
    QuestStatus.skipped => (color: sx.muted, icon: PhosphorIconsRegular.prohibit),
    QuestStatus.expired => (color: sx.muted, icon: PhosphorIconsRegular.xCircle),
  };
}

/// The daily mission board summary: completion, total XP still on the table
/// and a one-tap readiness check-in.
class QuestBoardHeader extends StatelessWidget {
  const QuestBoardHeader({super.key, required this.quests, required this.readiness, this.onCheckIn});

  final List<Quest> quests;
  final Readiness readiness;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final sx = context.sx;
    final total = quests.length;
    final done = quests.where((q) => q.done).length;
    final ratio = total == 0 ? 0.0 : done / total;
    final open = quests.where(
      (q) => !q.done && q.status != QuestStatus.skipped && q.status != QuestStatus.expired,
    );
    final xp = open.fold<int>(0, (n, q) => n + q.xp);
    final tone = total > 0 && done == total ? sx.vital : sx.mana;
    final readyTone = !readiness.logged
        ? sx.holo
        : readiness.low
        ? sx.gold
        : sx.vital;
    final readyLabel = !readiness.logged ? 'Readiness check-in' : 'Readiness ${readiness.score}';

    final readyChip = Semantics(
      button: onCheckIn != null,
      label: !readiness.logged
          ? 'Do a readiness check-in so quests match how you feel today'
          : 'Readiness score ${readiness.score}. ${readiness.verdict}. Tap to check in again.',
      excludeSemantics: true,
      child: Pressable(
        onTap: onCheckIn,
        scale: 0.96,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: readyTone.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: readyTone.withValues(alpha: 0.28)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsRegular.heartbeat, size: 13, color: readyTone),
                const SizedBox(width: 5),
                Text(
                  readyLabel,
                  maxLines: 1,
                  style: AppTheme.f(11.5, weight: FontWeight.w800, color: readyTone),
                ),
                if (!readiness.logged) ...[
                  const SizedBox(width: 3),
                  Icon(PhosphorIconsBold.caretRight, size: 10, color: readyTone),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(tone.withValues(alpha: 0.09), gc.bgRaised), gc.bgRaised],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY QUESTS',
                      style: AppTheme.f(10.5, weight: FontWeight.w800, color: tone, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total == 0 ? 'The board is quiet' : '$done of $total complete',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(14.5, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _BoardRing(value: ratio, label: '$done/$total', color: tone),
            ],
          ),
          const SizedBox(height: 12),
          SystemBar(
            value: ratio,
            height: 5,
            color: tone,
            semanticsLabel: 'Daily quest completion, $done of $total',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (xp > 0) XpPill(xp: xp, label: 'available'),
              readyChip,
            ],
          ),
          if (readiness.low) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(PhosphorIconsRegular.warningCircle, size: 13, color: sx.gold),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Readiness is low today: difficulty has been reduced.',
                    style: AppTheme.s(11.5, color: sx.gold, height: 1.3),
                  ),
                ),
              ],
            ),
          ] else if (!readiness.logged) ...[
            const SizedBox(height: 8),
            Text(
              'A 10-second check-in tunes today\'s quests to how you feel.',
              style: AppTheme.s(11.5, color: gc.textTertiary, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoardRing extends StatelessWidget {
  const _BoardRing({required this.value, required this.label, required this.color});

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: context.gc.mutedFill,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          Text(
            label,
            style: AppTheme.f(11.5, weight: FontWeight.w800, color: context.gc.text),
          ),
        ],
      ),
    );
  }
}

/// One quest on the board. The card is intentionally compact: identity,
/// reward and state on the first two lines, objectives in the middle and
/// supporting metadata at the bottom.
class QuestCard extends StatelessWidget {
  const QuestCard(this.q, {super.key});

  final Quest q;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final sx = context.sx;
    final visual = QuestVisual.of(context, q.category);
    final status = questStatusVisual(context, q);
    final closed = q.status == QuestStatus.skipped || q.status == QuestStatus.expired;
    final done = q.done;
    final tone = done ? sx.vital : visual.color;
    final progress = _progress();
    final objectives = q.isWorkout ? q.objectives.map((o) => o.text).join('. ') : q.description;
    final semantics =
        '${q.category.label}: ${q.name}. ${questStatusLabel(q)}. '
        '${q.xp} XP${q.minutes > 0 ? ', about ${q.minutes} minutes' : ''}. '
        '${objectives.isEmpty ? '' : '$objectives. '}'
        'Tap for quest details.';

    return Semantics(
      container: true,
      button: true,
      label: semantics,
      hint: 'Opens quest details',
      excludeSemantics: true,
      child: Opacity(
        opacity: closed ? 0.52 : 1,
        child: Pressable(
          onTap: () => showQuestSheet(context, q.id),
          scale: 0.985,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              color: gc.bgRaised,
              border: Border.all(
                color: done
                    ? sx.vital.withValues(alpha: 0.34)
                    : q.category == QuestCategory.main && !closed
                    ? tone.withValues(alpha: 0.4)
                    : gc.border.withValues(alpha: 0.85),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tone.withValues(alpha: done ? 0.1 : 0.055), gc.bgRaised),
                  gc.bgRaised,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: done ? 0.85 : 0.95),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 23,
                            height: 23,
                            decoration: BoxDecoration(
                              color: visual.color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(visual.icon, size: 12, color: visual.color),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              q.category.label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.f(
                                9.6,
                                weight: FontWeight.w800,
                                color: visual.color,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                          RankEmblem(
                            letter: q.difficulty,
                            size: 25,
                            semanticsLabel: '${q.difficulty} rank difficulty',
                          ),
                          const SizedBox(width: 7),
                          StatusChip(
                            label: questStatusLabel(q),
                            color: status.color,
                            icon: status.icon,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              q.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.f(
                                16.5,
                                weight: FontWeight.w800,
                                color: gc.text,
                                letterSpacing: -0.15,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: XpPill(xp: q.xp, dense: true, muted: closed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (q.isWorkout && q.objectives.isNotEmpty) ...[
                        for (final o in q.objectives.take(2))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: tone.withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    o.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.s(12.3, color: gc.textSecondary, height: 1.28),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (q.objectives.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(left: 11, top: 1),
                            child: Text(
                              '+${q.objectives.length - 2} more ${q.objectives.length - 2 == 1 ? 'exercise' : 'exercises'}',
                              style: AppTheme.f(10.8, weight: FontWeight.w700, color: gc.textTertiary),
                            ),
                          ),
                      ] else if (q.description.isNotEmpty)
                        Text(
                          q.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.s(12.3, color: gc.textSecondary, height: 1.28),
                        ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (q.minutes > 0)
                            MetaChip(label: '~${q.minutes} min', icon: PhosphorIconsRegular.clock),
                          if (!q.isWorkout && q.target > 0)
                            MetaChip(
                              label: '${q.target} ${q.unit}'.trim(),
                              icon: PhosphorIconsRegular.target,
                            ),
                          for (final e in q.attrXp.entries)
                            MetaChip(label: '+${e.value} ${e.key.short}', color: sx.violet),
                        ],
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SystemBar(
                                value: progress.value,
                                height: 4,
                                color: done ? sx.vital : visual.color,
                                semanticsLabel: 'Quest progress',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              progress.label,
                              style: AppTheme.f(10.3, weight: FontWeight.w700, color: gc.textTertiary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({double value, String label})? _progress() {
    if (q.isWorkout) {
      if (q.completion <= 0 && q.status != QuestStatus.active) return null;
      final value = q.completion.clamp(0.0, 1.0).toDouble();
      return (value: value, label: '${(value * 100).round()}% sets');
    }
    if (q.target <= 0) return null;
    final raw = hunter.questProgress(q);
    final value = (raw / q.target).clamp(0.0, 1.0).toDouble();
    final shown = raw is double ? raw.toStringAsFixed(1) : '$raw';
    return (value: value, label: '$shown/${q.target} ${q.unit}'.trim());
  }
}

/// Empty board state, still inviting the check-in.
class QuestEmptyState extends StatelessWidget {
  const QuestEmptyState({super.key, this.onCheckIn});

  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final sx = context.sx;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gc.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: sx.mana.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: sx.mana.withValues(alpha: 0.22)),
            ),
            child: Icon(PhosphorIconsRegular.flagPennant, size: 20, color: sx.mana),
          ),
          const SizedBox(height: 12),
          Text(
            'No quests on the board right now',
            textAlign: TextAlign.center,
            style: AppTheme.f(14.5, weight: FontWeight.w800, color: gc.text),
          ),
          const SizedBox(height: 4),
          Text(
            'New quests are assigned at the start of each day. Rest is part of the plan.',
            textAlign: TextAlign.center,
            style: AppTheme.s(12.3, color: gc.textSecondary, height: 1.35),
          ),
          if (onCheckIn != null) ...[
            const SizedBox(height: 12),
            GhostButton(label: 'Readiness check-in', icon: PhosphorIconsRegular.heartbeat, onTap: onCheckIn!),
          ],
        ],
      ),
    );
  }
}

/// Weekly mission card: same visual language as the daily board, with a
/// compact checklist instead of a quest sheet.
class WeeklyCard extends StatelessWidget {
  const WeeklyCard(this.m, {super.key});

  final WeeklyMission m;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final sx = context.sx;
    final done = m.done;
    final met = m.objectives.where((o) => o.met).length;
    final ratio = m.objectives.isEmpty ? 0.0 : met / m.objectives.length;
    final tone = done ? sx.vital : sx.gold;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: done ? sx.vital.withValues(alpha: 0.3) : gc.border.withValues(alpha: 0.85)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(tone.withValues(alpha: done ? 0.09 : 0.045), gc.bgRaised),
            gc.bgRaised,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  done ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.trophy,
                  size: 14,
                  color: tone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY MISSION',
                      style: AppTheme.f(9, weight: FontWeight.w800, color: tone, letterSpacing: 1),
                    ),
                    Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(14.5, weight: FontWeight.w800, color: gc.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              XpPill(xp: m.xp, dense: true),
            ],
          ),
          const SizedBox(height: 8),
          SystemBar(value: ratio, height: 4, color: tone, semanticsLabel: 'Weekly mission progress'),
          const SizedBox(height: 7),
          for (final o in m.objectives)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    o.met ? PhosphorIconsFill.checkSquare : PhosphorIconsRegular.square,
                    size: 15,
                    color: o.met ? sx.vital : gc.textTertiary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      o.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.s(12.3, color: o.met ? gc.textSecondary : gc.text, height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${o.have}/${o.need}',
                    style: AppTheme.f(11, weight: FontWeight.w700, color: gc.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
