import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/services.dart';

import '../app/app_shell.dart' show playWorkout;
import '../models/exercise.dart';
import '../screens/progress_screen.dart' show showBodyweightSheet;
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/ui_kit.dart';
import 'hunter_catalog.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'hunter_rules.dart';
import 'system_widgets.dart';

Widget sheetTitle(BuildContext context, String kicker, String title) {
  final gc = context.gc;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionLabel(kicker, color: context.sx.mana),
      const SizedBox(height: 4),
      Text(
        title,
        style: AppTheme.f(24, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.2),
      ),
      const SizedBox(height: 14),
    ],
  );
}

Future<void> _sheet(BuildContext context, WidgetBuilder builder) =>
    showAppSheet<void>(context: context, isScrollControlled: true, builder: builder);

void _toast(BuildContext context, String text) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

/// What tapping a data-validated quest does: takes you to where you log it.
void runDataQuest(BuildContext context, Quest q) {
  HapticFeedback.selectionClick();
  switch (q.check) {
    case 'water':
      fit.addWater();
      _toast(context, '+${fit.activeGoals.glassMl} ml logged');
    case 'protein' || 'food':
      // Logging food needs the Nutrition tab; turn it on if it was off.
      if (!fit.nutritionBeta) fit.setNutritionBeta(true);
      fit.goNutrition();
    case 'sleep':
      showSleepSheet(context);
    case 'weigh':
      showBodyweightSheet(context);
    case 'checkin':
      showCheckInSheet(context);
    case 'pushReps' || 'cardioMin' || 'effortSets' || 'coreSets':
      playWorkout(context);
    case 'steps':
      _toast(context, "Steps are counted from your phone's step sensor. Just walk!");
    default:
      break;
  }
}

String questStatusLabel(Quest q) => switch (q.status) {
  QuestStatus.offered => 'New',
  QuestStatus.accepted => 'Accepted',
  QuestStatus.active => hunter.isQuestLive(q.id) ? 'In progress' : 'Paused',
  QuestStatus.completed => 'Complete',
  QuestStatus.partial => q.completion > 0 ? 'Partial ${(q.completion * 100).round()}%' : 'Incomplete',
  QuestStatus.skipped => 'Skipped',
  QuestStatus.expired => 'Expired',
};

String attrRewardText(Map<Attr, int> m) => [for (final e in m.entries) '+${e.value} ${e.key.short}'].join(' · ');

// --- Quest detail ----------------------------------------------------------------

Future<void> showQuestSheet(BuildContext context, String questId) =>
    _sheet(context, (_) => _QuestSheet(questId, host: context));

class _QuestSheet extends StatelessWidget {
  const _QuestSheet(this.id, {required this.host});
  final String id;

  /// The screen that opened the sheet. Actions that open another screen or
  /// sheet run from here after this sheet closes, so they appear on top.
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hunter,
      builder: (context, _) {
        final gc = context.gc;
        final q = hunter.questById(id);
        if (q == null) return const AppSheet(children: [Text('Quest not found')]);
        final live = hunter.isQuestLive(q.id);
        final open = !q.done && q.status != QuestStatus.skipped && q.status != QuestStatus.expired;
        final progress = hunter.questProgress(q);
        return AppSheet(
          maxHeight: 0.92,
          children: [
            sheetTitle(context, q.category.label.toUpperCase(), q.name),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SystemChip('${q.difficulty}-Rank', color: context.sx.rank(q.difficulty)),
                SystemChip(questStatusLabel(q), color: q.done ? context.sx.vital : context.sx.mana),
                if (q.minutes > 0) SystemChip('~${q.minutes} min', color: context.sx.violet),
                if (q.shortened) SystemChip('Shortened', color: context.sx.gold),
                if (q.rescheduled) SystemChip('Rescheduled', color: context.sx.gold),
              ],
            ),
            const SizedBox(height: 12),
            Text(q.description, style: AppTheme.s(14, color: gc.textSecondary)),
            const SizedBox(height: 14),
            if (q.isWorkout) ...[
              Text('OBJECTIVES', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
              const SizedBox(height: 6),
              for (var i = 0; i < q.objectives.length; i++) _objectiveRow(context, q, i, canReplace: open && !live),
              if (q.status == QuestStatus.partial || q.done) ...[
                const SizedBox(height: 8),
                SystemBar(value: q.completion),
                const SizedBox(height: 4),
                Text(
                  '${(q.completion * 100).round()}% of planned sets completed',
                  style: AppTheme.s(12, color: gc.textTertiary),
                ),
              ],
            ] else ...[
              Text('OBJECTIVE', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
              const SizedBox(height: 6),
              SystemBar(value: q.target <= 0 ? 0 : (progress / q.target).clamp(0, 1).toDouble()),
              const SizedBox(height: 4),
              Text(
                '${progress is double ? progress.toStringAsFixed(1) : progress} / ${q.target} ${q.unit}',
                style: AppTheme.s(13, color: gc.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Validated from what you log. It completes on its own.',
                style: AppTheme.s(12, color: gc.textTertiary),
              ),
            ],
            const SizedBox(height: 16),
            SystemWindow(
              title: 'Reward',
              accent: context.sx.gold,
              glow: false,
              child: Text(
                '${q.xp} XP${q.attrXp.isEmpty ? '' : ' · ${attrRewardText(q.attrXp)}'}'
                '\n+${HunterRules.dailyQuestBonus} XP completion bonus',
                style: Sx.disp(16, color: gc.text, spacing: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            if (open && q.isWorkout) ...[
              if (q.status == QuestStatus.offered)
                PrimaryButton(label: 'Accept quest', onTap: () => hunter.acceptQuest(q.id))
              else
                PrimaryButton(
                  label: live ? 'Resume' : (q.status == QuestStatus.active ? 'Resume quest' : 'Start quest'),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!hunter.startQuest(q.id)) _toast(context, 'Finish or close your current workout first.');
                  },
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (live) TextButton(onPressed: hunter.pauseQuest, child: const Text('Pause')),
                  if (!q.shortened && !live)
                    TextButton(onPressed: () => hunter.shortenQuest(q.id), child: const Text('Shorten')),
                  if (!q.rescheduled && !live)
                    TextButton(onPressed: () => hunter.rescheduleQuest(q.id), child: const Text('Reschedule')),
                  if (!live)
                    TextButton(
                      onPressed: () {
                        hunter.skipQuest(q.id);
                        Navigator.of(context).pop();
                      },
                      child: Text('Skip', style: TextStyle(color: gc.textSecondary)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Skipping or missing a quest never removes XP or levels. Rest days are part of training.',
                textAlign: TextAlign.center,
                style: AppTheme.s(12, color: gc.textTertiary),
              ),
            ],
            if (open && !q.isWorkout)
              PrimaryButton(
                label: 'Log it',
                onTap: () {
                  Navigator.of(context).pop();
                  if (host.mounted) runDataQuest(host, q);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _objectiveRow(BuildContext context, Quest q, int i, {required bool canReplace}) {
    final gc = context.gc;
    final o = q.objectives[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(PhosphorIconsBold.caretRight, color: context.sx.mana, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                fit.openExercise(o.exerciseId);
              },
              child: Text(
                o.text,
                style: AppTheme.s(14.5, color: gc.text, weight: FontWeight.w600),
              ),
            ),
          ),
          if (canReplace)
            IconButton(
              tooltip: 'Replace exercise',
              icon: Icon(PhosphorIconsRegular.arrowsLeftRight, color: gc.textSecondary, size: 20),
              onPressed: () => _showReplace(context, q.id, i),
            ),
        ],
      ),
    );
  }
}

void _showReplace(BuildContext context, String questId, int index) {
  final options = hunter.alternativesFor(questId, index);
  _sheet(context, (ctx) {
    final gc = ctx.gc;
    return AppSheet(
      children: [
        sheetTitle(ctx, 'REPLACE', 'Choose an alternative'),
        if (options.isEmpty)
          Text('No alternative fits your equipment and limitations.', style: AppTheme.s(14, color: gc.textSecondary)),
        for (final e in options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              exerciseName(e),
              style: AppTheme.s(14.5, color: gc.text, weight: FontWeight.w600),
            ),
            subtitle: Text('${e.equipment} · ${e.difficulty}', style: AppTheme.s(12, color: gc.textTertiary)),
            onTap: () {
              hunter.replaceExercise(questId, index, e.id);
              Navigator.of(ctx).pop();
            },
          ),
      ],
    );
  });
}

// --- Attribute detail -------------------------------------------------------------

Future<void> showAttributeSheet(BuildContext context, Attr attr) => _sheet(context, (ctx) {
  final gc = ctx.gc;
  final s = hunter.status;
  final st = s.attrs[attr]!;
  final history = [
    for (final t in s.ledger)
      if ((t.attrs[attr] ?? 0) > 0) t,
  ];
  final skills = [
    for (final k in s.skills)
      if (k.def.attr == attr ||
          k.def.tree ==
              switch (attr) {
                Attr.strength => 'Strength',
                Attr.endurance => 'Endurance',
                Attr.mobility => 'Mobility',
                Attr.consistency => 'Discipline',
                Attr.recovery => 'Recovery',
              })
        k,
  ];
  final exercises = <String, int>{};
  for (final f in s.facts) {
    for (final e in f.session.exercises) {
      final ex = fit.exerciseById(e.id);
      final kind = ex == null ? 'strength' : fit.kindOf(ex);
      final fits = switch (attr) {
        Attr.strength => kind == 'strength' || kind == 'calisthenics',
        Attr.endurance => kind == 'cardio' || kind == 'sport',
        Attr.mobility || Attr.recovery => kind == 'stretch',
        Attr.consistency => true,
      };
      if (fits) exercises[e.name] = (exercises[e.name] ?? 0) + e.workingSets.length;
    }
  }
  final topEx = exercises.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final quests = [
    for (final t in history)
      if (t.questId != null && t.id.startsWith('quest:')) t,
  ];
  // Weekly cumulative attribute XP for the graph.
  final now = DateTime.now();
  final weeks = [
    for (var i = 11; i >= 0; i--)
      history
          .where((t) => t.at.isBefore(now.subtract(Duration(days: 7 * i))))
          .fold<int>(0, (n, t) => n + (t.attrs[attr] ?? 0))
          .toDouble(),
  ];
  const milestones = [5, 10, 20, 30, 50];
  final next = milestones.where((m) => m > st.level).firstOrNull;
  return AppSheet(
    maxHeight: 0.92,
    children: [
      sheetTitle(ctx, attr.short, attr.label),
      Text(attr.blurb, style: AppTheme.s(13.5, color: gc.textSecondary)),
      const SizedBox(height: 14),
      Row(
        children: [
          Text('LV ${st.level}', style: Sx.disp(34, color: context.sx.mana, spacing: 0)),
          const Spacer(),
          Text('${st.into} / ${st.need} XP', style: AppTheme.s(13, color: gc.textSecondary)),
        ],
      ),
      const SizedBox(height: 6),
      SystemBar(value: st.ratio),
      const SizedBox(height: 6),
      Text(
        next == null ? 'All milestones reached.' : 'Next milestone: level $next',
        style: AppTheme.s(12.5, color: gc.textTertiary),
      ),
      const SizedBox(height: 16),
      Text('HISTORY (12 WEEKS)', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
      const SizedBox(height: 8),
      SizedBox(
        height: 90,
        child: CustomPaint(painter: _LinePainter(weeks, context.sx.mana, gc.border), size: Size.infinite),
      ),
      const SizedBox(height: 16),
      if (topEx.isNotEmpty) ...[
        Text('RELATED EXERCISES', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final e in topEx.take(8)) SystemChip('${e.key} · ${e.value}', color: context.sx.violet)],
        ),
        const SizedBox(height: 16),
      ],
      Text('UNLOCKABLE SKILLS', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
      const SizedBox(height: 6),
      for (final k in skills)
        Text(
          '${k.learned ? '✓' : (k.learnable ? '◆' : '·')}  ${k.def.name} — ${k.def.requirement}',
          style: AppTheme.s(13, color: k.learned ? context.sx.vital : gc.text),
        ),
      const SizedBox(height: 16),
      Text('XP HISTORY', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
      const SizedBox(height: 6),
      if (history.isEmpty)
        Text('No XP yet. Complete a related activity.', style: AppTheme.s(13, color: gc.textTertiary)),
      for (final t in history.take(25))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(t.reason, style: AppTheme.s(13, color: gc.text)),
              ),
              Text('+${t.attrs[attr]}  ', style: Sx.disp(14, color: context.sx.mana)),
              Text(dayKey(t.at), style: AppTheme.s(11.5, color: gc.textTertiary)),
            ],
          ),
        ),
      if (quests.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('${quests.length} related quests completed', style: AppTheme.s(12.5, color: gc.textTertiary)),
      ],
    ],
  );
});

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.color, this.grid);
  final List<double> values;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = grid);
    final top = values.fold(0.0, math.max);
    if (top <= 0 || values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final o = Offset(size.width * i / (values.length - 1), size.height - size.height * 0.9 * values[i] / top);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}

// --- Comeback -------------------------------------------------------------------------

Future<void> showComebackSheet(BuildContext context) => _sheet(context, (_) => const _ComebackSheet());

class _ComebackSheet extends StatefulWidget {
  const _ComebackSheet();

  @override
  State<_ComebackSheet> createState() => _ComebackSheetState();
}

class _ComebackSheetState extends State<_ComebackSheet> {
  String _reason = kComebackReasons.first;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final s = hunter.status;
    final target = s.player?.weeklyTarget ?? 3;
    return AppSheet(
      children: [
        sheetTitle(context, 'SYSTEM MESSAGE', 'Welcome back, Hunter'),
        Text(
          'Your journey has not ended. Your accumulated experience and achievements remain safe: '
          'Level ${s.level}, ${s.rank.letter}-Rank, ${s.totalXp} XP.\n\nLet\'s restart with a suitable training plan.',
          style: AppTheme.s(14.5, color: gc.text),
        ),
        const SizedBox(height: 14),
        Text('WHAT KEPT YOU AWAY?', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in kComebackReasons)
              ChoiceChip(label: Text(r), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
          ],
        ),
        const SizedBox(height: 14),
        SystemWindow(
          title: 'Proposed comeback plan',
          accent: context.sx.vital,
          child: Text(
            '• ${HunterRules.comebackPlanDays} days of lighter, shorter quests\n'
            '• Weekly target ${math.max(2, target - 1)} days instead of $target\n'
            '• Difficulty one step easier until you are back in rhythm'
            '${_reason == 'Injury' || _reason == 'Illness' ? '\n• Get cleared by a clinician if you are not fully recovered' : ''}',
            style: AppTheme.s(14, color: gc.text),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Approve plan',
          onTap: () {
            hunter.acceptComeback(_reason);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              hunter.dismissComeback();
              Navigator.of(context).pop();
            },
            child: Text('Not now', style: TextStyle(color: gc.textSecondary)),
          ),
        ),
      ],
    );
  }
}

// --- Notifications & settings -------------------------------------------------------

Future<void> showInboxSheet(BuildContext context) => _sheet(context, (ctx) {
  final gc = ctx.gc;
  final notes = hunter.status.notes;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (notes.any((n) => !n.read)) hunter.markNotesRead();
  });
  return AppSheet(
    maxHeight: 0.9,
    children: [
      sheetTitle(ctx, 'SYSTEM', 'Notifications'),
      if (notes.isEmpty) Text('Nothing yet.', style: AppTheme.s(14, color: gc.textSecondary)),
      for (final n in notes.take(60))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SystemWindow(
            glow: false,
            accent: n.read ? gc.border : context.sx.mana,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SectionLabel(n.title, color: context.sx.mana)),
                    Text(dayKey(n.at), style: AppTheme.s(11, color: gc.textTertiary)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(n.body, style: AppTheme.s(13.5, color: gc.text)),
              ],
            ),
          ),
        ),
    ],
  );
});

Future<void> showSystemSettingsSheet(BuildContext context) => _sheet(
  context,
  (ctx) => ListenableBuilder(
    listenable: hunter,
    builder: (ctx, _) {
      final gc = ctx.gc;
      return AppSheet(
        children: [
          sheetTitle(ctx, 'SYSTEM', 'Notification settings'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound effects'),
            value: hunter.soundOn,
            onChanged: (v) => hunter.setSetting('sound', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Animations and particles'),
            subtitle: Text(
              'Also off when your phone asks for reduced motion.',
              style: AppTheme.s(12, color: gc.textTertiary),
            ),
            value: hunter.animationsOn,
            onChanged: (v) => hunter.setSetting('anim', v),
          ),
          const SizedBox(height: 8),
          Text('POP-UPS', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
          const SizedBox(height: 8),
          SegToggle([
            SegOption('All', hunter.alertLevel == 'all', () => hunter.setSetting('freq', 'all')),
            SegOption('Important', hunter.alertLevel == 'important', () => hunter.setSetting('freq', 'important')),
            SegOption('Off', hunter.alertLevel == 'off', () => hunter.setSetting('freq', 'off')),
          ]),
          const SizedBox(height: 8),
          Text(
            'Important = level-ups, rank promotions and achievements. Everything stays in the inbox either way.',
            style: AppTheme.s(12, color: gc.textTertiary),
          ),
          const SizedBox(height: 20),
          Text('REMINDERS', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily quest board'),
            subtitle: Text(
              "One nudge when the day's quests are ready.",
              style: AppTheme.s(12, color: gc.textTertiary),
            ),
            value: hunter.reminderDailyOn,
            onChanged: (v) => hunter.setReminder(daily: v),
          ),
          if (hunter.reminderDailyOn)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder time'),
              trailing: Text(
                TimeOfDay(hour: hunter.reminderAt ~/ 60, minute: hunter.reminderAt % 60).format(ctx),
                style: Sx.disp(16, color: gc.text),
              ),
              onTap: () => _pickReminderTime(ctx),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Streak at risk'),
            subtitle: Text(
              fit.currentStreak > 0
                  ? 'Last call at 21:00 while your ${fit.currentStreak}-day streak is alive.'
                  : 'Last call at 21:00, once you have a streak to protect.',
              style: AppTheme.s(12, color: gc.textTertiary),
            ),
            value: hunter.reminderStreakOn,
            onChanged: (v) => hunter.setReminder(streak: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekly missions close'),
            subtitle: Text(
              'Evening reminder on ${_weekEndName(fit.weekStartDay)} to finish the week.',
              style: AppTheme.s(12, color: gc.textTertiary),
            ),
            value: hunter.reminderWeeklyOn,
            onChanged: (v) => hunter.setReminder(weekly: v),
          ),
          const SizedBox(height: 4),
          Text(
            'Local notifications only: nothing leaves your phone. If none arrive, allow notifications for Level Up '
            'in Android settings.',
            style: AppTheme.s(12, color: gc.textTertiary),
          ),
        ],
      );
    },
  ),
);

String _weekEndName(int weekStartDay) =>
    const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][(weekStartDay + 5) % 7];

Future<void> _pickReminderTime(BuildContext context) async {
  final at = hunter.reminderAt;
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: at ~/ 60, minute: at % 60),
    helpText: 'Daily quest reminder',
  );
  if (picked == null) return;
  hunter.setReminder(minuteOfDay: picked.hour * 60 + picked.minute);
}

Future<void> showTitlesSheet(BuildContext context) => _sheet(
  context,
  (ctx) => ListenableBuilder(
    listenable: hunter,
    builder: (ctx, _) {
      final gc = ctx.gc;
      final s = hunter.status;
      final legendary = s.achievements.any((a) => a.unlocked && a.def.rarity == Rarity.legendary);
      bool frameOpen((String, String, String) f) =>
          f.$3 == 'legendary' ? legendary : rankIndex(s.rank.letter) >= rankIndex(f.$3);
      return AppSheet(
        maxHeight: 0.9,
        children: [
          sheetTitle(ctx, 'COSMETICS', 'Titles & frames'),
          Text('TITLE', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
          for (final t in s.titles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: t.unlocked,
              leading: Icon(
                s.currentTitle?.id == t.def.id
                    ? PhosphorIconsFill.checkCircle
                    : (t.unlocked ? PhosphorIconsRegular.circle : PhosphorIconsRegular.lockSimple),
                color: t.unlocked ? context.sx.gold : gc.textTertiary,
              ),
              title: Text(t.def.name, style: Sx.disp(16, color: t.unlocked ? gc.text : gc.textTertiary)),
              subtitle: Text(t.def.requirement, style: AppTheme.s(12, color: gc.textTertiary)),
              onTap: t.unlocked ? () => hunter.equipTitle(t.def.id) : null,
            ),
          const SizedBox(height: 10),
          Text('PROFILE FRAME', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in kFrames)
                GestureDetector(
                  onTap: frameOpen(f) ? () => hunter.setFrame(f.$1) : null,
                  child: Opacity(
                    opacity: frameOpen(f) ? 1 : 0.35,
                    child: Column(
                      children: [
                        FramedEmblem(letter: s.rank.letter, frame: f.$1, size: 40),
                        const SizedBox(height: 4),
                        Text(
                          frameOpen(f) ? f.$2 : (f.$3 == 'legendary' ? 'Legendary' : '${f.$3}-Rank'),
                          style: AppTheme.s(11.5, color: s.frame == f.$1 ? context.sx.mana : gc.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  ),
);

// --- Readiness, sleep, injuries, safety ------------------------------------------------

Future<void> showCheckInSheet(BuildContext context) => _sheet(context, (_) => const _CheckInSheet());

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet();

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  late final Map<String, dynamic> _prev = hunter.checkOn(DateTime.now()) ?? const {};
  late double _sleep = hunter.sleepOn(DateTime.now()) ?? 7;
  late int _energy = ((_prev['en'] as num?) ?? 3).toInt();
  late int _sore = ((_prev['so'] as num?) ?? 2).toInt();
  late int _stress = ((_prev['st'] as num?) ?? 2).toInt();
  late bool _pain = _prev['pain'] == true;

  Widget _scale(String label, String low, String high, int value, ValueChanged<int> on) {
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Pressable(
                      onTap: () => on(i),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: i == value ? context.sx.mana.withValues(alpha: 0.2) : gc.bgRaised2,
                          shape: BeveledRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: i == value ? context.sx.mana : gc.border),
                          ),
                        ),
                        child: Text('$i', style: Sx.disp(17, color: i == value ? context.sx.mana : gc.text)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(low, style: AppTheme.s(11.5, color: gc.textTertiary)),
              const Spacer(),
              Text(high, style: AppTheme.s(11.5, color: gc.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return AppSheet(
      children: [
        sheetTitle(context, 'DAILY CHECK-IN', 'How is the hunter?'),
        Text('SLEEP LAST NIGHT', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _sleep,
                min: 0,
                max: 12,
                divisions: 24,
                activeColor: context.sx.mana,
                onChanged: (v) => setState(() => _sleep = v),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text('${_sleep.toStringAsFixed(1)} h', style: Sx.disp(20, color: gc.text)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _scale('Energy', 'Drained', 'Charged', _energy, (v) => setState(() => _energy = v)),
        _scale('Soreness', 'None', 'Very sore', _sore, (v) => setState(() => _sore = v)),
        _scale('Stress', 'Calm', 'Overloaded', _stress, (v) => setState(() => _stress = v)),
        Row(
          children: [
            Expanded(
              child: Text('Any pain (not normal muscle soreness)?', style: AppTheme.s(14, color: gc.text)),
            ),
            Switch(value: _pain, activeThumbColor: context.sx.alert, onChanged: (v) => setState(() => _pain = v)),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Report to the System',
          onTap: () {
            hunter.logCheckIn(energy: _energy, soreness: _sore, stress: _stress, pain: _pain, sleep: _sleep);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

Future<void> showSleepSheet(BuildContext context) => _sheet(context, (_) => const _SleepSheet());

class _SleepSheet extends StatefulWidget {
  const _SleepSheet();

  @override
  State<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends State<_SleepSheet> {
  late double _h = hunter.sleepOn(DateTime.now()) ?? 7.5;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return AppSheet(
      children: [
        sheetTitle(context, 'MANA REGENERATION', 'Hours slept'),
        Center(
          child: Text(
            '${_h.toStringAsFixed(1)} h',
            style: Sx.disp(48, color: _h >= HunterRules.sleepTargetHours ? context.sx.vital : gc.text),
          ),
        ),
        Slider(
          value: _h,
          min: 0,
          max: 12,
          divisions: 24,
          activeColor: context.sx.mana,
          onChanged: (v) => setState(() => _h = v),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Log sleep',
          onTap: () {
            hunter.logSleep(_h);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

Future<void> showInjurySheet(BuildContext context) => _sheet(context, (_) => const _InjurySheet());

class _InjurySheet extends StatefulWidget {
  const _InjurySheet();

  @override
  State<_InjurySheet> createState() => _InjurySheetState();
}

class _InjurySheetState extends State<_InjurySheet> {
  String _area = kMuscles.first.id;
  double _sev = 3;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return AppSheet(
      children: [
        sheetTitle(context, 'INJURY LOG', 'Where does it hurt?'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in kMuscles)
              ChoiceChip(
                label: Text(muscleLabel(m.id)),
                selected: _area == m.id,
                selectedColor: context.sx.alert.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _area = m.id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('SEVERITY ${_sev.round()}/10', style: Sx.disp(13, color: gc.textSecondary, spacing: 1.6)),
        Slider(
          value: _sev,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: _sev >= 7 ? context.sx.alert : (_sev >= 4 ? context.sx.gold : context.sx.vital),
          onChanged: (v) => setState(() => _sev = v),
        ),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'What aggravates it? Any clinician advice?'),
        ),
        const SizedBox(height: 8),
        Text(
          'Quests stop loading this area while the injury is active (severity 4+).',
          style: AppTheme.s(12, color: gc.textTertiary),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Add to log',
          onTap: () {
            hunter.addInjury(_area, _sev.round(), _note.text.trim());
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

Future<void> showRedFlagsSheet(BuildContext context) => _sheet(context, (ctx) {
  final gc = ctx.gc;
  return AppSheet(
    children: [
      sheetTitle(ctx, 'WARNING', 'Stop and get help'),
      Text(
        'If you notice any of these, stop exercising and seek urgent medical care. '
        'This is not a workout problem and the System will not suggest one.',
        style: AppTheme.s(14, color: gc.textSecondary),
      ),
      const SizedBox(height: 12),
      for (final f in kRedFlags)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.warning, color: context.sx.alert, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(f, style: AppTheme.s(14.5, color: gc.text)),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Text(
        'Level Up is a training log, not medical care. Ranks, levels and attributes are game classifications, '
        'not medical or professional fitness assessments.',
        style: AppTheme.s(12.5, color: gc.textTertiary),
      ),
    ],
  );
});
