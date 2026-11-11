import 'dart:math';

import '../core/game_rules.dart';
import 'exercise_catalog.dart';
import 'models.dart';

/// Decides *what* the player should do today.
///
/// This is the fitness side of the app. It knows nothing about XP beyond
/// attaching a reward at the end, and its safety decisions (recovery days,
/// avoiding flagged body areas) can never be overridden by the reward system.
class QuestGenerator {
  const QuestGenerator._();

  static const String painSafetyNote =
      'Sharp, persistent or worsening pain is a reason to stop and speak to a '
      'doctor or physiotherapist. Resting today costs you nothing: your streak '
      'is protected.';

  static Quest generate({
    required Player player,
    required String date,
    QuestKind kind = QuestKind.daily,
    Readiness? readiness,
    List<Quest> recent = const [],
    int? minutes,
    QuestFocus? focus,
    int salt = 0,
  }) {
    final rng = Random(date.hashCode ^ (salt * 7919) ^ (player.questsCompleted * 31));
    final reasons = <String>[];

    final pain = readiness?.pain ?? false;
    final lowReadiness = readiness != null && readiness.score <= 4;
    final moderate = readiness != null && readiness.score <= 6;
    final trainingRun = consecutiveTrainingDays(recent, date);
    final overloaded = trainingRun >= GameRules.maxConsecutiveTrainingDays;

    var chosenFocus = focus;
    String? safetyNote;

    // Safety first: these override whatever was requested.
    if (pain) {
      chosenFocus = QuestFocus.recovery;
      safetyNote = painSafetyNote;
      reasons.add('You reported pain or illness, so today is gentle movement only.');
    } else if (lowReadiness) {
      chosenFocus = QuestFocus.recovery;
      reasons.add('Your check-in shows low readiness, so today focuses on recovery.');
    } else if (overloaded && focus == null) {
      chosenFocus = QuestFocus.recovery;
      reasons.add('You have trained $trainingRun days in a row. Recovery is scheduled.');
    }

    chosenFocus ??= _rotation(player);
    final recovery = chosenFocus == QuestFocus.recovery;
    final easy = !recovery && (moderate || kind == QuestKind.comeback);

    var budget = minutes ?? player.minutes;
    if (kind == QuestKind.comeback && minutes == null) budget = min(budget, 15);
    if (recovery) budget = min(budget, pain ? 10 : 20);

    if (!recovery) {
      if (kind == QuestKind.comeback) {
        reasons.add('Welcome back. This quest is lighter than usual to ease you in.');
      } else if (moderate) {
        reasons.add('Your check-in was moderate, so volume and difficulty are reduced.');
      } else if (focus == null) {
        reasons.add('${chosenFocus.label} is next in your plan for "${player.goal.label}".');
      } else {
        reasons.add('You asked for a ${chosenFocus.label.toLowerCase()} quest.');
      }
      if (player.limitations.isNotEmpty) {
        reasons.add('Exercises that load your '
            '${player.limitations.map((l) => l.label.toLowerCase()).join(', ')} are left out.');
      }
      reasons.add(player.equipment.isEmpty
          ? 'Bodyweight only.'
          : 'Uses your ${player.equipment.map((e) => e.label.toLowerCase()).join(', ')}.');
    }

    final tasks = recovery
        ? _recoveryTasks(player, budget, pain, rng)
        : _trainingTasks(player, chosenFocus, budget, easy, rng);

    final seconds = tasks.fold<int>(0, (a, t) => a + t.estimatedSeconds);
    final actualMinutes = max(1, (seconds / 60).round());
    final rate = recovery
        ? GameRules.xpPerRecoveryMinute
        : GameRules.xpPerTrainingMinute;
    var xp = actualMinutes * rate;
    if (kind == QuestKind.comeback) xp *= 1 + GameRules.comebackBonus;
    if (kind == QuestKind.bonus) xp *= GameRules.bonusQuestMultiplier;
    final reward = max(5, (xp / 5).round() * 5);

    return Quest(
      id: '$date-${kind.name}-$salt-${rng.nextInt(1 << 20)}',
      dateKey: date,
      kind: kind,
      focus: chosenFocus,
      title: _title(player, kind, chosenFocus),
      minutes: actualMinutes,
      tasks: tasks,
      xpReward: reward,
      reason: reasons.join(' '),
      safetyNote: safetyNote,
    );
  }

  /// How many days in a row, ending yesterday, had a completed training quest.
  static int consecutiveTrainingDays(List<Quest> recent, String date) {
    final trained = <String>{
      for (final q in recent)
        if (q.status == QuestStatus.completed && !q.isRecovery) q.dateKey
    };
    var count = 0;
    var day = parseDateKey(date).subtract(const Duration(days: 1));
    while (trained.contains(dateKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Highest exercise difficulty this player should be handed.
  static int maxDifficulty(Player p, {bool easy = false}) {
    int d;
    switch (p.experience) {
      case ExperienceLevel.beginner:
        d = p.level >= 8 ? 2 : 1;
      case ExperienceLevel.intermediate:
        d = p.level >= 12 ? 3 : 2;
      case ExperienceLevel.advanced:
        d = 3;
    }
    if (easy) d = max(1, d - 1);
    return d;
  }

  static bool _usable(Player p, Exercise e) =>
      p.equipment.containsAll(e.equipment) &&
      e.stresses.intersection(p.limitations).isEmpty;

  /// Exercises that could stand in for [current], easiest first.
  static List<Exercise> alternatives(
    Player player,
    Exercise current, {
    Set<String> exclude = const {},
  }) {
    final cap = max(current.difficulty, maxDifficulty(player));
    List<Exercise> find(MovementPattern pattern) => ExerciseCatalog.all
        .where((e) =>
            e.pattern == pattern &&
            e.id != current.id &&
            !exclude.contains(e.id) &&
            e.difficulty <= cap &&
            _usable(player, e))
        .toList()
      ..sort((a, b) => a.difficulty.compareTo(b.difficulty));

    var found = find(current.pattern);
    var fallback = _fallback[current.pattern];
    while (found.isEmpty && fallback != null) {
      found = find(fallback);
      fallback = _fallback[fallback];
    }
    return found.take(6).toList();
  }

  /// Builds a task for [e] with targets sized to the player.
  static QuestTask taskFor(Player p, Exercise e, {required int sets, bool easy = false}) {
    final exp = p.experience.index;
    final scale = easy ? 0.75 : 1.0;
    int target;
    int rest;
    var taskSets = sets;

    switch (e.category) {
      case ExerciseCategory.mobility:
        rest = 5;
        if (e.pattern == MovementPattern.breath) {
          taskSets = 1;
          target = 120;
        } else if (e.tracking == Tracking.seconds) {
          taskSets = e.perSide ? 2 : 1;
          target = 30;
        } else {
          taskSets = 1;
          target = 10;
        }
      case ExerciseCategory.cardio:
        rest = 20;
        if (e.pattern == MovementPattern.walk) {
          taskSets = 1;
          target = 180;
        } else if (e.tracking == Tracking.seconds) {
          target = _round5(([30, 40, 50][exp] + min(p.level, 30)) * scale);
        } else {
          target = max(4, (([6, 8, 10][exp] + min(p.level ~/ 5, 5)) * scale).round());
        }
      case ExerciseCategory.strength:
      case ExerciseCategory.core:
        rest = e.category == ExerciseCategory.core ? 30 : 45;
        if (e.tracking == Tracking.seconds) {
          target = _round5(([20, 30, 40][exp] + min(p.level ~/ 2, 20)) * scale);
        } else {
          var reps = [8, 10, 12][exp] + min(p.level ~/ 4, 6);
          if (e.difficulty == 3) reps -= 2;
          target = max(5, (reps * scale).round());
        }
    }
    return QuestTask(
      exerciseId: e.id,
      sets: max(1, taskSets),
      target: target,
      tracking: e.tracking,
      restSeconds: rest,
    );
  }

  // -------------------------------------------------------------------------

  static int _round5(num v) => max(10, (v / 5).round() * 5);

  static const Map<MovementPattern, MovementPattern> _fallback = {
    MovementPattern.verticalPull: MovementPattern.horizontalPull,
    MovementPattern.verticalPush: MovementPattern.horizontalPush,
    MovementPattern.horizontalPull: MovementPattern.core,
    MovementPattern.horizontalPush: MovementPattern.core,
    MovementPattern.lunge: MovementPattern.squat,
    MovementPattern.squat: MovementPattern.hinge,
    MovementPattern.hinge: MovementPattern.core,
    MovementPattern.cardio: MovementPattern.walk,
    MovementPattern.mobilityUpper: MovementPattern.mobilitySpine,
    MovementPattern.mobilityLower: MovementPattern.mobilitySpine,
  };

  static QuestFocus _rotation(Player p) {
    const f = QuestFocus.fullBody;
    const u = QuestFocus.upper;
    const l = QuestFocus.lower;
    const c = QuestFocus.cardio;
    const m = QuestFocus.mobility;
    final List<QuestFocus> cycle;
    switch (p.goal) {
      case FitnessGoal.generalFitness:
        cycle = const [f, c, f, m];
      case FitnessGoal.strength:
      case FitnessGoal.muscle:
        cycle = const [u, l, f];
      case FitnessGoal.endurance:
        cycle = const [c, f, c, l];
      case FitnessGoal.flexibility:
        cycle = const [m, f, m, c];
      case FitnessGoal.weight:
        cycle = const [f, c, l, c];
      case FitnessGoal.activeLifestyle:
        cycle = const [f, c, m];
    }
    return cycle[p.questsCompleted % cycle.length];
  }

  static String _title(Player p, QuestKind kind, QuestFocus focus) {
    if (kind == QuestKind.comeback) return 'Return of the hunter';
    if (p.questsCompleted == 0 && kind == QuestKind.daily && focus != QuestFocus.recovery) {
      return 'The awakening';
    }
    switch (focus) {
      case QuestFocus.fullBody:
        return 'Basic training';
      case QuestFocus.upper:
        return 'Upper-body training';
      case QuestFocus.lower:
        return 'Lower-body training';
      case QuestFocus.cardio:
        return 'Endurance trial';
      case QuestFocus.mobility:
        return 'Mobility flow';
      case QuestFocus.recovery:
        return 'Recovery protocol';
    }
  }

  static Exercise? _pick(
    Player p,
    MovementPattern pattern,
    int maxDiff,
    bool lowImpactOnly,
    Set<String> used,
    Random rng,
  ) {
    MovementPattern? current = pattern;
    while (current != null) {
      final c = ExerciseCatalog.all
          .where((e) =>
              e.pattern == current &&
              e.difficulty <= maxDiff &&
              !used.contains(e.id) &&
              (!lowImpactOnly || e.impact == Impact.low) &&
              _usable(p, e))
          .toList();
      if (c.isNotEmpty) {
        final top = c.map((e) => e.difficulty).reduce(max);
        final best = c.where((e) => e.difficulty == top).toList();
        return best[rng.nextInt(best.length)];
      }
      current = _fallback[current];
    }
    return null;
  }

  static List<QuestTask> _trainingTasks(
    Player p,
    QuestFocus focus,
    int minutes,
    bool easy,
    Random rng,
  ) {
    const hp = MovementPattern.horizontalPush;
    const vp = MovementPattern.verticalPush;
    const hl = MovementPattern.horizontalPull;
    const vl = MovementPattern.verticalPull;
    const sq = MovementPattern.squat;
    const lu = MovementPattern.lunge;
    const hi = MovementPattern.hinge;
    const co = MovementPattern.core;
    const ca = MovementPattern.cardio;
    const mu = MovementPattern.mobilityUpper;
    const ml = MovementPattern.mobilityLower;
    const ms = MovementPattern.mobilitySpine;

    final List<MovementPattern> main;
    final List<MovementPattern> extras;
    final MovementPattern cool;
    switch (focus) {
      case QuestFocus.upper:
        main = const [hp, hl, vp, co];
        extras = const [vl, hp, hl, co, vp];
        cool = mu;
      case QuestFocus.lower:
        main = const [sq, hi, lu, co];
        extras = const [sq, hi, co, lu];
        cool = ml;
      case QuestFocus.cardio:
        main = const [ca, co, ca, sq];
        extras = const [ca, co, ca, hi];
        cool = ml;
      case QuestFocus.mobility:
        main = const [ms, ml, mu, ml, ms, co];
        extras = const [ml, mu, ms, co, ml];
        cool = MovementPattern.breath;
      case QuestFocus.fullBody:
      case QuestFocus.recovery:
        main = const [sq, hp, hi, hl, co];
        extras = const [ca, lu, vp, co, sq, hp];
        cool = ms;
    }

    final maxDiff = maxDifficulty(p, easy: easy);
    final used = <String>{};
    var sets = minutes <= 15 ? 2 : 3;
    final budget = minutes * 60;

    QuestTask? build(MovementPattern pattern) {
      final e = _pick(p, pattern, maxDiff, easy, used, rng);
      if (e == null) return null;
      used.add(e.id);
      final t = taskFor(p, e, sets: sets, easy: easy);
      if (minutes <= 10 && t.restSeconds > 30) t.restSeconds = 30;
      return t;
    }

    final warm = ExerciseCatalog.byId('march_in_place');
    used.add(warm.id);
    final warmTask = QuestTask(
      exerciseId: warm.id,
      sets: 1,
      target: minutes <= 10 ? 60 : 90,
      tracking: Tracking.seconds,
      restSeconds: 10,
    );

    final mains = <QuestTask>[
      for (final pattern in main)
        if (build(pattern) case final QuestTask t) t,
    ];
    final coolTask = build(cool);

    int total() =>
        warmTask.estimatedSeconds +
        (coolTask?.estimatedSeconds ?? 0) +
        mains.fold<int>(0, (a, t) => a + t.estimatedSeconds);

    // Too long: drop tasks from the end, then trim sets.
    while (total() > budget * 1.1 && mains.length > 2) {
      mains.removeLast();
    }
    while (total() > budget * 1.1 && sets > 1) {
      sets--;
      for (final t in mains) {
        if (t.sets > sets) t.sets = sets;
      }
    }
    // Too short: add from the extras list.
    var i = 0;
    while (total() < budget * 0.85 && i < extras.length * 2 && mains.length < 12) {
      final t = build(extras[i % extras.length]);
      if (t != null) {
        mains.add(t);
        if (total() > budget * 1.1) {
          mains.removeLast();
          break;
        }
      }
      i++;
    }

    return [warmTask, ...mains, if (coolTask != null) coolTask];
  }

  static List<QuestTask> _recoveryTasks(Player p, int minutes, bool pain, Random rng) {
    final used = <String>{};
    final tasks = <QuestTask>[];

    void add(MovementPattern pattern) {
      final e = _pick(p, pattern, 1, true, used, rng);
      if (e == null) return;
      used.add(e.id);
      tasks.add(taskFor(p, e, sets: 1, easy: true));
    }

    if (!pain) {
      final walk = taskFor(p, ExerciseCatalog.byId('walk'), sets: 1);
      walk.target = minutes >= 15 ? 420 : 240;
      tasks.add(walk);
      used.add('walk');
    }
    add(MovementPattern.mobilitySpine);
    add(MovementPattern.mobilityLower);
    add(MovementPattern.mobilityUpper);
    if (minutes >= 15) {
      add(MovementPattern.mobilityLower);
      add(MovementPattern.mobilitySpine);
    }
    add(MovementPattern.breath);
    return tasks;
  }
}
