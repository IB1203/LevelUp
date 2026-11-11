import 'dart:math' as math;

import '../catalog/exercise_catalog.dart';
import '../models/exercise.dart';
import '../state/fit_state.dart';
import 'hunter_catalog.dart';
import 'hunter_models.dart';
import 'hunter_rules.dart';

/// Builds quests from the player's real situation: experience, available
/// time, equipment at the active place, limitations and injuries,
/// readiness, recent training and comeback status.
///
/// Difficulty comes from experience (lowered by low readiness or a
/// comeback). The player's level never raises it.
class QuestGenerator {
  QuestGenerator({
    required this.fit,
    required this.player,
    required this.day,
    required this.avoid,
    required this.lowReadiness,
    required this.restDay,
    required this.comeback,
    required this.learned,
    required this.attrLevels,
    required this.recentMuscles,
  }) : _rand = math.Random(day.year * 10000 + day.month * 100 + day.day + player.id.hashCode);

  final FitState fit;
  final HunterPlayer player;
  final DateTime day;

  /// Muscles to keep load off (limitations + active injuries).
  final Set<String> avoid;
  final bool lowReadiness;
  final bool restDay;
  final bool comeback;
  final Set<String> learned;
  final Map<Attr, int> attrLevels;

  /// Muscles trained in the last 24–48 h (rested first).
  final Set<String> recentMuscles;
  final math.Random _rand;

  String get dayId => '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

  String get difficulty {
    var i = kExperienceDifficulty[player.experience.clamp(0, 4)];
    var idx = rankIndex(i);
    if (lowReadiness || comeback) idx = math.max(0, idx - 1);
    return kRanks[idx].letter;
  }

  int get _diffIdx => rankIndex(difficulty).clamp(0, 4);

  ({int sets, int reps, int hold}) get _volume => const [
    (sets: 2, reps: 8, hold: 20),
    (sets: 2, reps: 10, hold: 30),
    (sets: 3, reps: 10, hold: 40),
    (sets: 3, reps: 12, hold: 50),
    (sets: 4, reps: 10, hold: 60),
  ][_diffIdx];

  int get _cardioMinutes => const [10, 15, 20, 25, 30][_diffIdx];

  Set<String> get _allowedDifficulty => switch (_diffIdx) {
    0 || 1 => {'Beginner'},
    2 || 3 => {'Beginner', 'Intermediate'},
    _ => {'Beginner', 'Intermediate', 'Advanced'},
  };

  // --- Exercise picking ---------------------------------------------------------

  bool _isStretch(Exercise e) => kStretchIds.contains(e.id) || fit.kindOf(e) == 'stretch';
  bool _isCardio(Exercise e) => fit.kindOf(e) == 'cardio';

  List<Exercise> candidates(Slot slot, {Set<String> exclude = const {}}) {
    final muscles = switch (slot) {
      Slot.push => const {'chest', 'shoulders', 'triceps'},
      Slot.pull => const {'back', 'biceps'},
      Slot.legs => const {'quads', 'calves'},
      Slot.hinge => const {'hamstrings', 'glutes', 'lowerback'},
      Slot.core => const {'abdomen', 'obliques'},
      Slot.cardio || Slot.stretch => const <String>{},
    };
    final out = <Exercise>[];
    for (final e in fit.allExercises) {
      if (exclude.contains(e.id) || fit.archived.contains(e.id)) continue;
      if (!fit.fitsHere(e)) continue;
      if (slot == Slot.stretch) {
        if (_isStretch(e) && !avoid.contains(e.primary)) out.add(e);
        continue;
      }
      if (slot == Slot.cardio) {
        if (!_isCardio(e) || fit.kindOf(e) == 'sport') continue;
        final n = e.name.toLowerCase();
        final running = n.contains('run') || n.contains('sprint');
        if (running && !learned.contains('running') && player.experience < 2) continue;
        if (avoid.contains('quads') && (running || n.contains('jump') || n.contains('burpee'))) continue;
        out.add(e);
        continue;
      }
      if (_isStretch(e) || _isCardio(e)) continue;
      if (!muscles.contains(e.primary) || avoid.contains(e.primary)) continue;
      if (e.secondary.any(avoid.contains) && avoid.isNotEmpty) continue;
      if (!_allowedDifficulty.contains(e.difficulty)) continue;
      out.add(e);
    }
    // Prefer exercises the hunter already knows, then a stable shuffle.
    final known = {
      for (final s in fit.sessions)
        for (final e in s.exercises) e.id,
    };
    out.shuffle(_rand);
    out.sort((a, b) => (known.contains(b.id) ? 1 : 0) - (known.contains(a.id) ? 1 : 0));
    return out;
  }

  Exercise? pick(Slot slot, Set<String> used) {
    final c = candidates(slot, exclude: used);
    if (c.isEmpty) return null;
    // Some variety: choose among the top few.
    return c[_rand.nextInt(math.min(3, c.length))];
  }

  QuestObjective objectiveFor(Exercise e, SlotSpec spec) {
    final mode = fit.modeOf(e.id);
    final timed = mode == 'time' || mode == 'cardio' || spec.slot == Slot.cardio || spec.slot == Slot.stretch;
    if (timed) {
      return QuestObjective(e.id, exerciseName(e), spec.sets, seconds: spec.seconds ?? 30);
    }
    return QuestObjective(e.id, exerciseName(e), spec.sets, reps: spec.reps ?? 10);
  }

  List<QuestObjective> fromSlots(List<SlotSpec> specs) {
    final used = <String>{};
    final out = <QuestObjective>[];
    for (final spec in specs) {
      final e = pick(spec.slot, used);
      if (e == null) continue;
      used.add(e.id);
      out.add(objectiveFor(e, spec));
    }
    return out;
  }

  /// Objective list for a bodyweight-style session of [n] exercises.
  List<QuestObjective> _session(List<Slot> order, int n, {int? setsOverride}) {
    final v = _volume;
    final specs = <SlotSpec>[];
    for (final slot in order.take(n)) {
      final sets = setsOverride ?? v.sets;
      specs.add(switch (slot) {
        Slot.cardio => SlotSpec(slot, 1, seconds: _cardioMinutes * 60),
        Slot.core || Slot.stretch => SlotSpec(slot, sets, seconds: v.hold),
        _ => SlotSpec(slot, sets, reps: v.reps),
      });
    }
    return fromSlots(specs);
  }

  List<Slot> get _rotation {
    // Rest muscles trained in the last day or two; lead with the others.
    final base = [Slot.legs, Slot.push, Slot.pull, Slot.core, Slot.hinge];
    bool recent(Slot s) => switch (s) {
      Slot.push => recentMuscles.any(const {'chest', 'shoulders', 'triceps'}.contains),
      Slot.pull => recentMuscles.any(const {'back', 'biceps'}.contains),
      Slot.legs => recentMuscles.any(const {'quads', 'calves'}.contains),
      Slot.hinge => recentMuscles.any(const {'hamstrings', 'glutes'}.contains),
      _ => false,
    };
    base.shuffle(_rand);
    base.sort((a, b) => (recent(a) ? 1 : 0) - (recent(b) ? 1 : 0));
    return base;
  }

  static int estimateMinutes(List<QuestObjective> objs) {
    var m = 0.0;
    for (final o in objs) {
      m += o.seconds != null && o.sets == 1 ? o.seconds! / 60 : o.sets * (o.seconds != null ? 1.2 : 2.0);
    }
    return math.max(5, m.round());
  }

  Quest _quest(
    QuestCategory cat,
    String name,
    String desc,
    List<QuestObjective> objs,
    int xp,
    Map<Attr, int> attrs, {
    String? check,
    num target = 0,
    String unit = '',
  }) => Quest(
    id: 'q$dayId-${cat.name}',
    day:
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    category: cat,
    name: name,
    description: desc,
    difficulty: difficulty,
    objectives: objs,
    xp: xp,
    attrXp: attrs,
    minutes: objs.isEmpty ? 0 : estimateMinutes(objs),
    check: check,
    target: target,
    unit: unit,
  );

  Map<Attr, int> _attrsFor(List<QuestObjective> objs, {int consistency = 10}) {
    var str = 0, end = 0, mob = 0;
    for (final o in objs) {
      final e = fit.exerciseById(o.exerciseId);
      if (e == null) continue;
      if (_isCardio(e)) {
        end += 10;
      } else if (_isStretch(e)) {
        mob += 5;
      } else {
        str += 5;
      }
    }
    return {
      if (str > 0) Attr.strength: str,
      if (end > 0) Attr.endurance: end,
      if (mob > 0) Attr.mobility: mob,
      Attr.consistency: consistency,
    };
  }

  // --- Daily set ---------------------------------------------------------------

  List<Quest> daily() {
    final quests = <Quest>[];
    final minutes = comeback ? math.min(player.minutes, 20) : player.minutes;
    final recovering = restDay || lowReadiness;

    // Main quest.
    if (recovering) {
      final objs = fromSlots([
        const SlotSpec(Slot.cardio, 1, seconds: 10 * 60),
        SlotSpec(Slot.stretch, 2, seconds: _volume.hold),
        SlotSpec(Slot.stretch, 2, seconds: _volume.hold),
        SlotSpec(Slot.stretch, 2, seconds: _volume.hold),
      ]);
      quests.add(
        _quest(
          QuestCategory.main,
          'Active Recovery',
          restDay
              ? 'Planned rest day. Easy movement keeps the hunter sharp without adding fatigue.'
              : 'Your readiness is low today. The System lowers the load: move gently and recover.',
          objs,
          40,
          {Attr.recovery: 20, Attr.mobility: 10, Attr.consistency: 10},
        ),
      );
    } else {
      final n = (minutes ~/ 8).clamp(2, 6);
      final order = [..._rotation];
      if (minutes >= 30) order.insert(0, Slot.cardio);
      final objs = _session(order, n);
      if (learned.contains('cooldown') || learned.contains('core_dev')) {
        final extra = learned.contains('cooldown') ? Slot.stretch : Slot.core;
        objs.addAll(
          fromSlots([
            SlotSpec(extra, 1, seconds: _volume.hold),
          ]).where((o) => objs.every((x) => x.exerciseId != o.exerciseId)),
        );
      }
      quests.add(
        _quest(
          QuestCategory.main,
          minutes <= 15 ? 'Basic Training' : 'Daily Training',
          'Your main mission for today, sized to $minutes minutes and your experience.',
          objs,
          20 + minutes,
          _attrsFor(objs),
        ),
      );
    }

    // Side quest: 5–10 minutes, always short.
    final side = _session([..._rotation.reversed], 2, setsOverride: 2);
    quests.add(
      _quest(
        QuestCategory.side,
        'Quick Drill',
        'A short extra. Five to ten minutes still counts.',
        side,
        20,
        _attrsFor(side, consistency: 5),
      ),
    );

    // Category quest: rotate, leaning towards the weakest attribute.
    final pool = <QuestCategory>[
      if (!recovering) QuestCategory.strength,
      QuestCategory.endurance,
      QuestCategory.mobility,
    ];
    QuestCategory catFor() {
      Attr attrOf(QuestCategory c) => switch (c) {
        QuestCategory.strength => Attr.strength,
        QuestCategory.endurance => Attr.endurance,
        _ => Attr.mobility,
      };
      pool.sort((a, b) => (attrLevels[attrOf(a)] ?? 1).compareTo(attrLevels[attrOf(b)] ?? 1));
      return _rand.nextInt(3) == 0 ? pool[_rand.nextInt(pool.length)] : pool.first;
    }

    final cat = catFor();
    switch (cat) {
      case QuestCategory.strength:
        final upper = learned.contains('upper_body') && (!learned.contains('lower_body') || _rand.nextBool());
        final lower = !upper && learned.contains('lower_body');
        final slots = upper
            ? [Slot.push, Slot.pull, Slot.push]
            : lower
            ? [Slot.legs, Slot.hinge, Slot.legs]
            : [Slot.legs, Slot.push, Slot.pull];
        final objs = fromSlots([for (final s in slots) SlotSpec(s, _volume.sets, reps: _volume.reps)]);
        quests.add(
          _quest(
            QuestCategory.strength,
            upper ? 'Upper Body Assault' : (lower ? 'Lower Body Siege' : 'Strength Trial'),
            'Three strength movements at your level.',
            objs,
            30,
            {Attr.strength: 15, Attr.consistency: 5},
          ),
        );
      case QuestCategory.endurance:
        final mins = comeback ? 10 : _cardioMinutes;
        final objs = fromSlots([SlotSpec(Slot.cardio, 1, seconds: mins * 60)]);
        quests.add(
          _quest(QuestCategory.endurance, 'Long Corridor', 'Steady cardio at a pace you can talk at.', objs, 30, {
            Attr.endurance: 15,
            Attr.consistency: 5,
          }),
        );
      default:
        final count = learned.contains('advanced_mobility') ? 5 : 4;
        final objs = fromSlots([for (var i = 0; i < count; i++) SlotSpec(Slot.stretch, 2, seconds: _volume.hold)]);
        quests.add(
          _quest(QuestCategory.mobility, 'Flowing Form', 'Slow, controlled stretches. Never into pain.', objs, 25, {
            Attr.mobility: 15,
            Attr.consistency: 5,
          }),
        );
    }

    // Recovery quest.
    final rec = fromSlots([
      const SlotSpec(Slot.stretch, 1, seconds: 45),
      const SlotSpec(Slot.stretch, 1, seconds: 45),
      const SlotSpec(Slot.stretch, 1, seconds: 45),
    ]);
    quests.add(
      _quest(QuestCategory.recovery, 'Cooldown Ritual', 'A short cooldown to recover from training.', rec, 25, {
        Attr.recovery: 15,
        Attr.mobility: 5,
      }),
    );

    // Discipline quest (validated from logged data).
    final d = kDisciplineQuests[_rand.nextInt(kDisciplineQuests.length)];
    final goals = fit.goalsFor(day);
    final (num target, String unit) = switch (d.$1) {
      'water' => (goals.waterMl, 'ml'),
      'protein' => ((goals.protein * HunterRules.proteinTolerance).round(), 'g'),
      'sleep' => (HunterRules.sleepTargetHours, 'h'),
      'food' => (3, 'foods'),
      _ => (1, ''),
    };
    quests.add(
      _quest(
        QuestCategory.discipline,
        d.$2,
        d.$3,
        const [],
        15,
        {Attr.consistency: 5, if (d.$1 == 'sleep') Attr.recovery: 10},
        check: d.$1,
        target: target,
        unit: unit,
      ),
    );

    // Bonus quest.
    final bonusPool = [
      for (final b in kBonusQuests)
        if (b.$1 != 'steps' || fit.stepsOn) b,
    ];
    final b = bonusPool[_rand.nextInt(bonusPool.length)];
    quests.add(
      _quest(
        QuestCategory.bonus,
        b.$2,
        b.$3,
        const [],
        30,
        {Attr.consistency: 5},
        check: b.$1,
        target: b.$4,
        unit: b.$5,
      ),
    );
    return quests;
  }

  /// Objectives for a rank trial or a boss, adapted to experience.
  List<QuestObjective> fromSpecs(List<SlotSpec> specs, {bool beginner = false}) => fromSlots([
    for (final s in specs) beginner && s.sets > 2 ? SlotSpec(s.slot, s.sets - 1, reps: s.reps, seconds: s.seconds) : s,
  ]);
}
