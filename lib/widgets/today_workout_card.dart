import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../screens/routines_screen.dart' show showTodayPlanMenu;
import '../screens/start_sheet.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'body_map.dart';
import 'svg_icon.dart';
import 'ui_kit.dart';

/// Today's training mission: the planned routine (or the suggested focus when
/// nothing is planned) with the one button that starts it. Shown at the top of
/// Home and of the Train hub, so starting a workout is always one tap away.
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({super.key});

  /// Whether there is anything to show: the focus card is on, or a routine is planned.
  static bool get visible => fit.showFocus || fit.todayRoutine?.exerciseIds.isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final resting = fit.restingToday;
    final next = resting && !fit.rotating ? fit.nextPlannedAfter(DateTime.now()) : null;
    final rest = !resting ? null : next?.routine ?? fit.rotationUpcoming;
    final routine = fit.rotating ? rest ?? fit.todayRoutine : fit.todayRoutine;
    final focus = fit.suggestedFocus;
    final isRoutine = routine != null && routine.exerciseIds.isNotEmpty;
    final label = rest != null
        ? (fit.rotating ? t.rotationTitle : t.weeklyPlan)
        : isRoutine
            ? t.todaysRoutine
            : t.todaysFocus;
    final title = rest != null
        ? t.restDayShort
        : isRoutine
            ? fit.routineTitle(routine)
            : focus.title;
    final today = fit.routinesOn(DateTime.now());
    final done = rest == null && isRoutine && fit.pendingRoutinesOn(DateTime.now()).isEmpty;
    final subtitle = rest != null
        ? [
            t.rotationRestUpNext(fit.routineTitle(rest)),
            if (next != null)
              t.weekdayShort(next.day.weekday)
            else
              t.rotationPlace(fit.rotationStep + 1, fit.rotationSteps.length),
          ].join(' · ')
        : done
            ? t.routineDoneToday
            : isRoutine
            ? [
                t.exerciseCount(routine.exerciseIds.length),
                if (fit.rotating)
                  t.rotationPlace(fit.rotationStep + 1, fit.rotationSteps.length)
                else if (today.length > 1)
                  t.routineOfDay(today.indexOf(routine) + 1, today.length),
            ].join(' · ')
        : (fit.hasData
            ? '${focus.subtitle} · ${t.exerciseCount(fit.getFilteredExercises(focus.muscles).length)}'
            : t.firstSessionHint);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: gc.border, width: 1),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -40,
              top: 20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: gc.accentSoft, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: -24,
              top: -16,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: gc.info.withValues(alpha: 0.10), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 8,
              top: 12,
              bottom: 80,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset('assets/img/runner.png', fit: BoxFit.fitHeight),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (done) ...[
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: gc.sage, shape: BoxShape.circle),
                        child: Center(child: SvgPathIcon(Ic.checkBold, size: 10, color: gc.onEmber)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (rest != null) ...[
                      Icon(PhosphorIconsFill.bed, size: 14, color: gc.sage),
                      const SizedBox(width: 8),
                    ],
                    Text(label.toUpperCase(),
                        style: AppTheme.f(10.5,
                            weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
                  ]),
                  const SizedBox(height: 10),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(28,
                          weight: FontWeight.w800, color: gc.text, height: 1.1)),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (isRoutine && rest == null && fit.showMiniBody) ...[
                      MiniBody(sets: fit.routineMuscleSets(routine), height: 38),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: PrimaryButton(
                        label: rest != null
                            ? t.trainAnyway
                            : done
                                ? t.trainAgain
                                : t.startWorkout,
                        icon: Ic.play,
                        height: 52,
                        bg: done || rest != null ? gc.bgRaised2 : null,
                        fg: done || rest != null ? gc.text : null,
                        onTap: next != null
                            ? () => showStartSheet(context)
                            : isRoutine
                                ? () => fit.startRoutine(routine)
                                : fit.startFocusWorkout,
                      ),
                    ),
                    if (isRoutine && !done && rest == null) ...[
                      const SizedBox(width: 10),
                      RoundAction(
                        label: t.moreOptions,
                        size: 52,
                        onTap: () => showTodayPlanMenu(context, routine),
                        child: Icon(PhosphorIconsBold.dotsThree, size: 22, color: gc.textSecondary),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
