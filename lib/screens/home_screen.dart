import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/day_off_sheet.dart';
import '../widgets/entrance.dart';
import '../widgets/exercise_media.dart';
import '../widgets/home_folder.dart';
import '../widgets/routine_folder.dart';
import '../widgets/scroll_away.dart';
import '../widgets/steps_card.dart';
import '../widgets/svg_icon.dart';
import '../widgets/today_workout_card.dart';
import '../widgets/ui_kit.dart';
import 'progress_screen.dart';
import 'routines_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final recommended = fit.recommendedExercises(8);
    final routines = fit.routinesByLastDone;

    return RiseScope(
      id: 'home',
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('home'),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: riseAll([
              _hubHeader(gc),
              const SizedBox(height: 18),
              if (TodayWorkoutCard.visible) ...[
                const TodayWorkoutCard(),
                const SizedBox(height: 14),
              ],
              _hubLinks(gc),
              const SizedBox(height: 14),
              if (fit.photoDue) ...[
                const SizedBox(height: 14),
                _photoNudge(gc),
              ],
              ..._homeBlocks(context, gc, routines, recommended),
            ]),
          ),
        ),
      ),
    );
  }

  // --- Hub header -------------------------------------------------------------

  Widget _hubHeader(GymColors gc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.longDate(DateTime.now()).toUpperCase(),
            style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text(titleCase(t.train),
            style: AppTheme.f(28, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.4)),
      ],
    );
  }

  // --- Library, custom workout and history ------------------------------------

  Widget _hubLinks(GymColors gc) {
    final library = fit.allExercises.where((e) => !fit.isArchived(e.id)).length;
    final rows = <(IconData, String, String, VoidCallback)>[
      (PhosphorIconsRegular.books, titleCase(t.exercises), t.libraryCount(library), fit.goExercises),
      (PhosphorIconsRegular.listPlus, 'Build a workout', 'Pick muscles or exercises and start', () => fit.startWorkout()),
      (
        PhosphorIconsRegular.clockCounterClockwise,
        t.historyTitle,
        fit.sessions.isEmpty ? 'No workouts logged yet' : '${fit.sessions.length} logged',
        () => fit.goHistory(),
      ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: gc.bgRaised,
        child: Column(
          children: [
            for (final (i, (icon, title, detail, onTap)) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 62, endIndent: 16, color: gc.border),
              Semantics(
                button: true,
                label: '$title, $detail',
                excludeSemantics: true,
                child: Pressable(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: gc.accentSoft, borderRadius: BorderRadius.circular(11)),
                            child: Icon(icon, size: 18, color: gc.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: AppTheme.f(15, weight: FontWeight.w700, color: gc.text)),
                                const SizedBox(height: 2),
                                Text(detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
                              ],
                            ),
                          ),
                          Icon(PhosphorIconsBold.caretRight, size: 14, color: gc.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Remaining home blocks --------------------------------------------------

  List<Widget> _homeBlocks(BuildContext context, GymColors gc, List<Routine> routines,
      List<Exercise> recommended) {
    final blocks = <String, List<Widget>>{
      'weekdays': [_away(_weekCard(context, gc))],
      'steps': [
            if (fit.stepsOn && fit.stepsAvailable) _away(StepsCard()),
      ],
      'week': [
            if (fit.showWeekStats) ...[
              _section(gc, t.thisWeek, _weekStatsCompact(gc)),
            ],
      ],
      'routines': [
            if (fit.showRoutineRow && routines.isNotEmpty) ...[
              _section(gc, t.routines, LayoutBuilder(
                builder: (context, box) => SizedBox(
                  height: routineFolderHeight(context),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: routines.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(
                      width: (box.maxWidth - 12) / 2,
                      child: RoutineFolder(
                        routine: routines[i],
                        lastDone: true,
                        onMenu: () => showRoutineMenu(context, routines[i]),
                      ),
                    ),
                  ),
                ),
              ),
              onMore: fit.goRoutines,
            ),
            ],
      ],
      'activity': [
            _section(gc, t.activityLabel, SoftCard(
              radius: 22,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: fit.heatmapYear
                  ? HeatmapYear(
                      levels: fit.heatmapShown,
                      firstDay: fit.heatmapShownDate(0),
                      weekdays: fit.heatmapLabels,
                      onTapDay: (i) => showDaySheet(context, fit.heatmapShownDate(i)),
                    )
                  : Heatmap(
                      levels: fit.heatmapWeeks,
                      firstDay: fit.heatmapWeekDate(0),
                      labels: fit.heatmapLabels,
                      onTapDay: (i) => showDaySheet(context, fit.heatmapWeekDate(i)),
                    ),
            )),
      ],
      'recommended': [
            if (fit.showRecommended && recommended.isNotEmpty) ...[
              _section(gc, t.recommended, SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recommended.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _recCard(gc, recommended[i]),
                ),
              )),
            ],
      ],
      'folders': [
            _away(Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: HomeFolder(
                    title: _tc(t.routines),
                    detail: t.routineCount(fit.activeRoutines.length),
                    peek: const RoutinesPeek(),
                    onTap: fit.goRoutines,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HomeFolder(
                    title: _tc(t.tools),
                    detail: t.calculatorsInside,
                    peek: const ToolsPeek(),
                    onTap: fit.goTools,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HomeFolder(
                    title: _tc(t.journal),
                    detail: t.noteCount(fit.notes.length),
                    peek: const NotesPeek(),
                    onTap: fit.goNotes,
                  ),
                ),
              ],
            ), dim: 0),
      ],
      'nutrition': [
            if (fit.nutritionBeta) ...[
              HomeFolder(
                title: _tc(t.nutrition),
                detail: _nutritionDetail,
                peek: const NutritionPeek(),
                badge: BetaTag(t.sectionBeta, small: true),
                onTap: fit.goNutrition,
              ),
            ],
      ],
    };
    final out = <Widget>[];
    String? last;
    for (final id in fit.homeOrderShown) {
      final b = blocks[id];
      if (b == null || b.isEmpty) continue;
      final card = id == 'weekdays' || id == 'steps';
      final gap = last == null
          ? (fit.photoDue ? (card ? 14.0 : 30.0) : (card ? 0.0 : 16.0))
          : (card && (last == 'weekdays' || last == 'steps'))
              ? 14.0
              : id == 'nutrition' && last == 'folders'
                  ? 12.0
                  : 30.0;
      out.add(SizedBox(height: gap));
      out.addAll(b);
      last = id;
    }
    return out;
  }

  // --- Compact weekly stats ---------------------------------------------------

  Widget _weekStatsCompact(GymColors gc) {
    return SoftCard(
      radius: 22,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _stat(gc, t.volume, fit.volumeValue(fit.volumeThisWeekKg),
                    unit: fit.volumeUnit)),
                Expanded(child: _stat(gc, t.statSets, '${fit.weekSetCount}')),
                Expanded(child: _stat(gc, t.prs, '${fit.prsThisWeek}')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              GoalRing(pct: fit.goalPct.toDouble(), size: 44),
              const SizedBox(height: 7),
              Text(t.goalDaysShort(fit.daysDoneThisWeek, fit.weeklyTarget),
                  style: AppTheme.f(11, weight: FontWeight.w700, color: gc.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Shared helpers ---------------------------------------------------------

  Widget _away(Widget child, {double dim = 0.45}) => ScrollAway(radius: 22, dim: dim, child: child);

  Widget _section(GymColors gc, String title, Widget child, {VoidCallback? onMore}) => _away(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(gc, title, onMore: onMore),
            const SizedBox(height: 12),
            child,
          ],
        ),
        dim: 0,
      );

  String _tc(String s) => titleCase(s);

  String get _nutritionDetail {
    final now = DateTime.now();
    final total = fit.totalOn(now);
    final water = fit.waterOn(now);
    if (total.isEmpty && water == 0) return t.nutritionHomeEmpty;
    return t.nutritionHomeDetail('${fit.energyOf(total.kcal)} ${fit.energyUnit}', total.protein.round());
  }

  Widget _heading(GymColors gc, String title, {VoidCallback? onMore}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMore,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: SizedBox(
          height: 30,
          child: Row(
            children: [
              Text(titleCase(title),
                  style: AppTheme.f(13, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 0)),
              const Spacer(),
              if (onMore != null)
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(14)),
                  child: Text(t.healthSeeAll, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(GymColors gc, String label, String value, {String unit = ''}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FitText(label.toUpperCase(),
              style: AppTheme.f(9.5,
                  weight: FontWeight.w600, color: gc.textTertiary, letterSpacing: 0.9)),
          const SizedBox(height: 6),
          Ltr(child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RollIn(value, style: AppTheme.f(23, weight: FontWeight.w800, color: gc.text)),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(unit,
                    style: AppTheme.f(11, weight: FontWeight.w600, color: gc.textSecondary)),
              ],
            ],
          )),
        ],
      ),
    );
  }

  Widget _photoNudge(GymColors gc) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: fit.goMoments,
      child: SoftCard(
        radius: 22,
        borderColor: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Icon(PhosphorIconsRegular.camera, size: 19, color: gc.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.photoDueNow, style: AppTheme.f(14.5, color: gc.text)),
                  const SizedBox(height: 2),
                  Text(t.photoInterval(fit.photoIntervalDays),
                      style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
                ],
              ),
            ),
            Icon(PhosphorIconsBold.caretRight, size: 14, color: gc.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _weekCard(BuildContext context, GymColors gc) {
    return SoftCard(
      radius: 22,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (int i = 0; i < 7; i++) _weekDay(context, gc, i)],
      ),
    );
  }

  Widget _weekDay(BuildContext context, GymColors gc, int i) {
    final done = fit.isDayDone(i) && !fit.isDayPartial(i);
    final isToday = i == fit.todayIndex;
    final isFuture = i > fit.todayIndex;
    final date = fit.dateForWeekday(i);
    final off = fit.dayOffOn(date);
    final session = fit.isSessionDay(i);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: session
          ? () => showDaySheet(context, date)
          : isToday && off == null
              ? () => fit.toggleCheckin(i)
              : fit.isCheckedIn(date)
                  ? () => fit.toggleCheckin(i)
                  : () => showDayOffSheet(context, date),
      onLongPress: session ? null : () => showDayOffSheet(context, date),
      child: Opacity(
        opacity: isFuture ? 0.5 : 1,
        child: Column(
          children: [
            Text(t.weekdayInitial(fit.weekdayAt(i)),
                style: AppTheme.f(10,
                    weight: FontWeight.w700,
                    color: isToday ? gc.text : gc.textTertiary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done ? gc.ember : gc.bgRaised2,
                shape: BoxShape.circle,
                border: isToday && !done ? Border.all(color: gc.ember, width: 2) : null,
              ),
              child: done
                  ? Center(child: SvgPathIcon(Ic.checkBold, size: 13, color: gc.onEmber))
                  : off != null
                      ? Icon(dayOffIcon(off), size: 15, color: gc.textSecondary)
                      : fit.restOn(date)
                          ? Icon(PhosphorIconsFill.bed, size: 14, color: gc.sage)
                          : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recCard(GymColors gc, Exercise ex) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => fit.openExercise(ex.id),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExerciseMedia(ex: ex, height: 88, radius: 12),
            const SizedBox(height: 9),
            Expanded(
              child: Text(exerciseName(ex),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(12, weight: FontWeight.w600, color: gc.text, height: 1.25)),
            ),
          ],
        ),
      ),
    );
  }
}
