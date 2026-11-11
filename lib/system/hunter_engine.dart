import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../catalog/exercise_catalog.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../state/fit_state.dart';
import 'hunter_catalog.dart';
import 'hunter_models.dart';
import 'hunter_rules.dart';
import 'quest_generator.dart';

/// The Hunter System: a progression layer driven by the real training log.
///
/// XP lives in a persistent ledger of [XpTransaction]s. Every reward has a
/// deterministic id (its idempotency reference): a session, a quest, a day's
/// habit, an achievement. [_sync] adds only references that are missing, so
///   * the same activity never pays twice (restarts, re-imports, edits);
///   * deleting or editing history never removes XP already earned;
///   * the whole history is auditable.
final hunter = HunterSystem(fit);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _parseDay(Object? raw) {
  if (raw is! String) return null;
  final d = DateTime.tryParse(raw);
  return d == null ? null : _day(d);
}

// --- Derived facts about one logged session -------------------------------------

class SessionFacts {
  SessionFacts(this.session);
  final LoggedSession session;
  String get ref => 'session:${session.date.millisecondsSinceEpoch}';
  DateTime get day => _day(session.day);

  int minutes = 0;
  int strengthSets = 0;
  int mobilitySets = 0;
  int workingSets = 0;
  double cardioMinutes = 0;
  double km = 0;
  bool planned = false;
  bool recovery = false;
  bool mobility = false;
  bool cooldown = false;
  bool upper = false, lower = false, core = false, balance = false, walk = false, run = false;
  int pushUpMax = 0, pullUpMax = 0, squatReps = 0;
  double walkKm = 0, runKm = 0;
  int prs = 0;
  final Set<String> muscles = {};

  bool get valid => (workingSets > 0 || cardioMinutes >= 5) && minutes >= 5;
  bool get strength => strengthSets > 0;
  bool get cardio => cardioMinutes >= 5 || km > 0;

  String get category => recovery ? 'recovery' : (mobility ? 'mobility' : 'workout');

  int get rawXp => !valid
      ? 0
      : recovery
      ? HunterRules.recoveryXp(minutes)
      : mobility
      ? HunterRules.mobilityXp(minutes)
      : HunterRules.workoutXp(minutes);

  Map<Attr, int> get rawAttrs => {
    if (strengthSets > 0) Attr.strength: math.min(40, strengthSets * 2),
    if (cardioMinutes > 0) Attr.endurance: math.min(40, cardioMinutes.round()),
    if (mobilitySets > 0) Attr.mobility: math.min(30, mobilitySets * 3),
    Attr.consistency: planned ? 10 : 5,
    if (recovery || mobility || cooldown) Attr.recovery: recovery ? 20 : (mobility ? 10 : 5),
  };
}

// --- View models ------------------------------------------------------------------

class AttrState {
  const AttrState(this.attr, this.xp);
  final Attr attr;
  final int xp;
  ({int level, int into, int need}) get _l => HunterRules.attrLevelFor(xp);
  int get level => _l.level;
  int get into => _l.into;
  int get need => _l.need;
  double get ratio => need <= 0 ? 0 : into / need;
}

class Requirement {
  const Requirement(this.label, this.have, this.need);
  final String label;
  final num have;
  final num need;
  bool get met => have >= need;
}

class AchievementState {
  const AchievementState(this.def, this.progress, this.unlockedAt);
  final AchievementDef def;
  final num progress;
  final DateTime? unlockedAt;
  bool get unlocked => unlockedAt != null;
}

class SkillState {
  const SkillState(this.def, this.progress, this.learnedAt, this.prereqMet, this.attrMet);
  final SkillDef def;
  final num progress;
  final DateTime? learnedAt;
  final bool prereqMet;
  final bool attrMet;
  bool get learned => learnedAt != null;
  bool get conditionMet => progress >= def.threshold && attrMet;
  bool get learnable => !learned && conditionMet && prereqMet;
}

class TitleState {
  const TitleState(this.def, this.unlocked);
  final TitleDef def;
  final bool unlocked;
}

class BossState {
  const BossState(this.def, this.wonBeginner, this.wonAdvanced, this.questsMet);
  final BossDef def;
  final bool wonBeginner;
  final bool wonAdvanced;
  final bool questsMet;
}

enum GateStatus { available, active, cleared, failed, locked }

class GateRun {
  const GateRun(this.def, this.start, this.progress, this.status);
  final GateDef def;
  final DateTime? start;
  final num progress;
  final GateStatus status;
  DateTime? get end => start?.add(Duration(days: def.days));
  int get daysLeft => end == null ? def.days : math.max(0, end!.difference(_day(DateTime.now())).inDays);
}

class WeeklyMission {
  const WeeklyMission(this.id, this.name, this.objectives, this.xp, this.attrs);
  final String id;
  final String name;
  final List<Requirement> objectives;
  final int xp;
  final Map<Attr, int> attrs;
  bool get done => objectives.every((o) => o.met);
}

class MuscleBalance {
  const MuscleBalance(this.muscle, this.sets, this.ratio, this.injured);
  final String muscle;
  final double sets;
  final double ratio;
  final bool injured;
}

class Readiness {
  const Readiness(this.score, this.verdict, this.advice, {this.pain = false, this.logged = true});
  final int score;
  final String verdict;
  final String advice;
  final bool pain;
  final bool logged;
  bool get low => logged && (pain || score < 55);
}

class Briefing {
  const Briefing(this.what, this.howHard, this.recovering, this.working);
  final String what;
  final String howHard;
  final String recovering;
  final String working;
}

class Injury {
  Injury(this.id, this.area, this.severity, this.note, this.at, this.resolved);
  final String id;
  final String area;
  final int severity;
  final String note;
  final DateTime at;
  final bool resolved;

  Map<String, dynamic> toJson() => {
    'id': id,
    'area': area,
    'sev': severity,
    'note': note,
    'at': dayKey(at),
    if (resolved) 'done': true,
  };

  static Injury? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = _parseDay(raw['at']);
    if (at == null) return null;
    return Injury(
      '${raw['id'] ?? at.millisecondsSinceEpoch}',
      '${raw['area'] ?? ''}',
      ((raw['sev'] as num?) ?? 1).toInt().clamp(1, 10),
      '${raw['note'] ?? ''}',
      at,
      raw['done'] == true,
    );
  }

  String get guidance {
    if (severity >= 7) {
      return 'High severity. Stop loading this area and see a qualified clinician before returning to training.';
    }
    if (severity >= 4) {
      return 'Moderate. Train around it and keep anything that touches it pain-free and light. '
          'If it is not improving in a week, get it checked.';
    }
    return 'Mild. Keep moving within a pain-free range and build back gradually over 1–2 weeks.';
  }
}

class TimelineEvent {
  const TimelineEvent(this.at, this.title, this.kind, {this.xp = 0});
  final DateTime at;
  final String title;
  final String kind;
  final int xp;
}

class HunterStatus {
  HunterStatus({
    required this.player,
    required this.totalXp,
    required this.level,
    required this.into,
    required this.need,
    required this.rank,
    required this.attrs,
    required this.ledger,
    required this.todayQuests,
    required this.weekly,
    required this.promotion,
    required this.promotionReady,
    required this.trialPassed,
    required this.rankHistory,
    required this.achievements,
    required this.skills,
    required this.skillPoints,
    required this.titles,
    required this.currentTitle,
    required this.frame,
    required this.records,
    required this.bosses,
    required this.gates,
    required this.workouts,
    required this.activeMinutes,
    required this.questsDone,
    required this.weeklyDone,
    required this.streak,
    required this.comebackDue,
    required this.daysAway,
    required this.comebackActive,
    required this.weeklyProposal,
    required this.muscles,
    required this.readiness,
    required this.briefing,
    required this.injuries,
    required this.weekSets,
    required this.avgWeekSets,
    required this.loadSpike,
    required this.notes,
    required this.facts,
  });

  final HunterPlayer? player;
  final int totalXp;
  final int level;
  final int into;
  final int need;
  final RankDef rank;
  final Map<Attr, AttrState> attrs;
  final List<XpTransaction> ledger;
  final List<Quest> todayQuests;
  final List<WeeklyMission> weekly;
  final List<Requirement> promotion;
  final bool promotionReady;
  final bool trialPassed;
  final List<RankChange> rankHistory;
  final List<AchievementState> achievements;
  final List<SkillState> skills;
  final int skillPoints;
  final List<TitleState> titles;
  final TitleDef? currentTitle;
  final String frame;
  final List<HunterRecord> records;
  final List<BossState> bosses;
  final List<GateRun> gates;
  final int workouts;
  final int activeMinutes;
  final int questsDone;
  final int weeklyDone;
  final int streak;
  final bool comebackDue;
  final int daysAway;
  final bool comebackActive;
  final ({int from, int to})? weeklyProposal;
  final List<MuscleBalance> muscles;
  final Readiness readiness;
  final Briefing briefing;
  final List<Injury> injuries;
  final int weekSets;
  final double avgWeekSets;
  final bool loadSpike;
  final List<HunterNote> notes;
  final List<SessionFacts> facts;

  bool get registered => player != null;
  RankDef? get nextRank => nextRankOf(rank.letter);
  double get levelRatio => need <= 0 ? 0 : into / need;
  int get xpForNextLevel => HunterRules.xpAtLevel(level + 1);
  int get achievementsUnlocked => achievements.where((a) => a.unlocked).length;
  int get skillsLearned => skills.where((s) => s.learned).length;
  int get titlesUnlocked => titles.where((t) => t.unlocked).length;
  int get unreadNotes => notes.where((n) => !n.read).length;
  List<Injury> get activeInjuries => injuries.where((i) => !i.resolved).toList();
  List<MuscleBalance> get shadows =>
      muscles.where((m) => !m.injured && m.ratio < HunterRules.shadowBelowMedian).toList();

  List<TimelineEvent> get timeline {
    final out = <TimelineEvent>[];
    if (player != null) out.add(TimelineEvent(player!.created, 'Hunter Awakening', 'start'));
    final sorted = [...ledger]..sort((a, b) => a.at.compareTo(b.at));
    var total = 0;
    var lv = 1;
    for (final t in sorted) {
      total += t.xp;
      final now = HunterRules.levelFor(total).level;
      final kind = switch (t.id.split(':').first) {
        'ach' => 'achievement',
        'quest' => 'quest',
        'weekly' => 'weekly',
        'boss' || 'trial' || 'gate' => 'boss',
        'pr' => 'record',
        _ => null,
      };
      if (kind != null) out.add(TimelineEvent(t.at, t.reason, kind, xp: t.xp));
      if (now > lv) {
        out.add(TimelineEvent(t.at, 'Level $now achieved', 'level'));
        lv = now;
      }
    }
    for (final r in rankHistory) {
      out.add(TimelineEvent(r.at, '${r.to}-Rank promotion', 'rank'));
    }
    for (final s in skills.where((s) => s.learned)) {
      out.add(TimelineEvent(s.learnedAt!, 'Skill learned: ${s.def.name}', 'skill'));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

class HunterSystem extends ChangeNotifier {
  HunterSystem(this.fit) {
    fit.addListener(_onFit);
  }

  final FitState fit;

  HunterStatus? _cache;
  Object? _cacheKey;
  int _rev = 0;
  bool _saveQueued = false;

  Map<String, dynamic> get _data => fit.hunterData;

  void _onFit() => notifyListeners();

  /// Forces the next read of [status] to recompute.
  void invalidate() {
    _cache = null;
    _rev++;
  }

  void _changed() {
    _rev++;
    _cache = null;
    if (_saveQueued) return;
    _saveQueued = true;
    scheduleMicrotask(() {
      _saveQueued = false;
      fit.saveHunterData();
    });
  }

  HunterPlayer? get player => HunterPlayer.fromJson(_data['player']);
  bool get registered => player != null;

  Object _key() => (fit.dataRev, dayKey(DateTime.now()), fit.sessions.length, fit.bodyweight.length, _rev);

  HunterStatus get status {
    if (_cache != null && _cacheKey == _key()) return _cache!;
    final facts = _facts();
    if (registered && _sync(facts)) _changed();
    _cacheKey = _key();
    return _cache = _compute(facts);
  }

  // ===========================================================================
  // Registration & player settings
  // ===========================================================================

  void register({
    required String name,
    required int experience,
    required String classId,
    required int minutes,
    required int weeklyTarget,
    required List<String> limitations,
    required List<bool> screening,
  }) {
    final now = DateTime.now();
    final existing = player;
    final p = HunterPlayer(
      id: existing?.id ?? 'H-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      name: name.trim().isEmpty ? 'Hunter' : name.trim(),
      created: existing?.created ?? now,
      experience: experience,
      classId: classId,
      minutes: minutes,
      weeklyTarget: weeklyTarget,
      limitations: limitations,
    );
    _data['player'] = p.toJson();
    _data['rank'] ??= 'E';
    _data['screen'] = {'a': screening, 'at': dayKey(now)};
    if (fit.profile.name != p.name) fit.updateProfile(name: p.name);
    final delta = weeklyTarget - fit.profile.weeklyGoal;
    if (delta != 0) fit.updateProfile(weeklyGoalDelta: delta);
    if (existing == null) {
      _note('system', 'SYSTEM INITIALIZATION', 'Player detected. Hunter System activated. Your journey starts now.');
    }
    _changed();
  }

  void updatePlayer({int? experience, int? minutes, String? classId, List<String>? limitations, String? name}) {
    final p = player;
    if (p == null) return;
    if (experience != null) p.experience = experience;
    if (minutes != null) p.minutes = minutes;
    if (classId != null) p.classId = classId;
    if (limitations != null) p.limitations = limitations;
    if (name != null && name.trim().isNotEmpty) {
      p.name = name.trim();
      fit.updateProfile(name: p.name);
    }
    _data['player'] = p.toJson();
    _changed();
  }

  bool get screeningFlagged {
    final s = _data['screen'];
    final a = s is Map ? s['a'] : null;
    return a is List && a.any((v) => v == true);
  }

  List<bool> get screeningAnswers {
    final s = _data['screen'];
    final a = s is Map ? s['a'] : null;
    return [for (var i = 0; i < kScreeningQuestions.length; i++) a is List && i < a.length && a[i] == true];
  }

  void setScreening(List<bool> answers) {
    _data['screen'] = {'a': answers, 'at': dayKey(DateTime.now())};
    _changed();
  }

  Map<String, dynamic> get settings => ((_data['settings'] as Map?) ?? const {}).cast<String, dynamic>();
  bool get soundOn => settings['sound'] != false;
  bool get animationsOn => settings['anim'] != false;

  /// 'all', 'important' or 'off'.
  String get alertLevel => settings['freq'] as String? ?? 'all';

  void setSetting(String key, Object value) {
    _data['settings'] = {...settings, key: value};
    _changed();
  }

  // ===========================================================================
  // Habits: check-in, sleep, injuries
  // ===========================================================================

  double? sleepOn(DateTime d) => ((_data['sleep'] as Map?)?[dayKey(d)] as num?)?.toDouble();

  void logSleep(double hours, {DateTime? on}) {
    final m = Map<String, dynamic>.from((_data['sleep'] as Map?) ?? const {});
    m[dayKey(on ?? DateTime.now())] = double.parse(hours.toStringAsFixed(1));
    _data['sleep'] = m;
    _changed();
  }

  Map<String, dynamic>? checkOn(DateTime d) => ((_data['check'] as Map?)?[dayKey(d)] as Map?)?.cast<String, dynamic>();

  void logCheckIn({
    required int energy,
    required int soreness,
    required int stress,
    required bool pain,
    double? sleep,
  }) {
    final m = Map<String, dynamic>.from((_data['check'] as Map?) ?? const {});
    m[dayKey(DateTime.now())] = {'en': energy, 'so': soreness, 'st': stress, if (pain) 'pain': true};
    _data['check'] = m;
    if (sleep != null) logSleep(sleep);
    _changed();
  }

  List<Injury> get injuries => [for (final r in (_data['injuries'] as List?) ?? const []) ?Injury.fromJson(r)];

  void addInjury(String area, int severity, String note) {
    _data['injuries'] = [
      ...[for (final i in injuries) i.toJson()],
      Injury('${DateTime.now().millisecondsSinceEpoch}', area, severity, note, DateTime.now(), false).toJson(),
    ];
    _changed();
  }

  void resolveInjury(String id, {bool resolved = true}) {
    _data['injuries'] = [
      for (final i in injuries)
        if (i.id == id) Injury(i.id, i.area, i.severity, i.note, i.at, resolved).toJson() else i.toJson(),
    ];
    _changed();
  }

  void deleteInjury(String id) {
    _data['injuries'] = [
      for (final i in injuries)
        if (i.id != id) i.toJson(),
    ];
    _changed();
  }

  // ===========================================================================
  // Quests
  // ===========================================================================

  Map<String, Quest> get _quests => {
    for (final e in ((_data['quests'] as Map?) ?? const {}).entries) '${e.key}': ?Quest.fromJson(e.value),
  };

  void _putQuest(Quest q) {
    _data['quests'] = {...((_data['quests'] as Map?) ?? const {}), q.id: q.toJson()};
  }

  /// A quest after any pending rewards are processed.
  Quest? questById(String id) {
    status;
    return _quests[id];
  }

  void acceptQuest(String id) {
    final q = _quests[id];
    if (q == null || q.status != QuestStatus.offered) return;
    q.status = QuestStatus.accepted;
    _putQuest(q);
    _changed();
  }

  void skipQuest(String id) {
    final q = _quests[id];
    if (q == null || q.done) return;
    q.status = QuestStatus.skipped;
    _putQuest(q);
    _changed();
  }

  /// Moves the quest to tomorrow. It keeps its id and reward rules.
  void rescheduleQuest(String id) {
    final q = _quests[id];
    if (q == null || q.done || q.rescheduled) return;
    final tomorrow = _day(DateTime.now()).add(const Duration(days: 1));
    q
      ..day = dayKey(tomorrow)
      ..rescheduled = true
      ..status = QuestStatus.accepted;
    _putQuest(q);
    _changed();
  }

  static int _volumeOf(List<QuestObjective> objs) =>
      objs.fold<int>(0, (n, o) => n + (o.sets == 1 && o.seconds != null ? math.max(1, o.seconds! ~/ 60) : o.sets));

  /// Halves the sets (and cardio time). The reward shrinks in proportion.
  void shortenQuest(String id) {
    final q = _quests[id];
    if (q == null || q.done || q.shortened || !q.isWorkout) return;
    final objs = [
      for (final o in q.objectives)
        o.sets > 1
            ? QuestObjective(o.exerciseId, o.name, math.max(1, (o.sets / 2).ceil()), reps: o.reps, seconds: o.seconds)
            : QuestObjective(
                o.exerciseId,
                o.name,
                1,
                reps: o.reps,
                seconds: o.seconds == null ? null : math.max(60, o.seconds! ~/ 2),
              ),
    ];
    final before = _volumeOf(q.objectives);
    final f = before <= 0 ? 0.5 : _volumeOf(objs) / before;
    _putQuest(
      Quest(
        id: q.id,
        day: q.day,
        category: q.category,
        name: q.name,
        description: q.description,
        difficulty: q.difficulty,
        objectives: objs,
        xp: math.max(5, (q.xp * f).round()),
        attrXp: {for (final e in q.attrXp.entries) e.key: math.max(1, (e.value * f).round())},
        minutes: QuestGenerator.estimateMinutes(objs),
        status: q.status == QuestStatus.offered ? QuestStatus.accepted : q.status,
        shortened: true,
        rescheduled: q.rescheduled,
      ),
    );
    _changed();
  }

  /// Alternatives for one objective: same movement pattern, fits equipment.
  List<Exercise> alternativesFor(String questId, int index) {
    final q = _quests[questId];
    if (q == null || index >= q.objectives.length) return const [];
    final current = fit.exerciseById(q.objectives[index].exerciseId);
    if (current == null) return const [];
    final avoid = _avoidMuscles();
    final used = {for (final o in q.objectives) o.exerciseId};
    final kind = fit.kindOf(current);
    return [
      for (final e in fit.allExercises)
        if (!used.contains(e.id) &&
            fit.fitsHere(e) &&
            !avoid.contains(e.primary) &&
            fit.kindOf(e) == kind &&
            (kind == 'cardio' || kind == 'stretch' || e.primary == current.primary))
          e,
    ].take(12).toList();
  }

  void replaceExercise(String questId, int index, String exerciseId) {
    final q = _quests[questId];
    final e = fit.exerciseById(exerciseId);
    if (q == null || e == null || q.done || index >= q.objectives.length) return;
    q.objectives[index]
      ..exerciseId = e.id
      ..name = exerciseName(e);
    _putQuest(q);
    _changed();
  }

  Routine _routineFor(String routineId, String name, List<QuestObjective> objs) => Routine(
    routineId,
    name,
    [for (final o in objs) o.exerciseId],
    sets: {for (final o in objs) o.exerciseId: o.sets},
    plan: {
      for (final o in objs)
        o.exerciseId: [
          for (var i = 0; i < o.sets; i++) o.seconds != null ? PlannedSet(sec: o.seconds) : PlannedSet(reps: o.reps),
        ],
    },
  );

  /// Starts the real workout for a quest. The logged session links back via
  /// its routine id, which is how completion is validated.
  bool startQuest(String id) {
    final q = _quests[id];
    if (q == null || !q.isWorkout || q.done || q.objectives.isEmpty) return false;
    return _start(
      'quest:$id',
      q.name,
      q.objectives,
      onStarted: () {
        q.status = QuestStatus.active;
        _putQuest(q);
        _changed();
      },
    );
  }

  bool _start(String routineId, String name, List<QuestObjective> objs, {VoidCallback? onStarted}) {
    final live = fit.session;
    if (live != null && !live.complete && live.routineId == routineId) {
      fit.stepBackIntoSession();
      return true;
    }
    fit.startRoutine(_routineFor(routineId, name, objs));
    final s = fit.session;
    if (s == null || s.routineId != routineId) return false;
    s.name = name;
    onStarted?.call();
    return true;
  }

  /// Pause = park the live session; it resumes exactly where it was.
  void pauseQuest() => fit.parkSession();

  bool isQuestLive(String id) {
    final s = fit.session;
    return s != null && !s.complete && s.routineId == 'quest:$id';
  }

  // --- Trials & bosses ------------------------------------------------------------

  bool startTrial() {
    final p = player;
    if (p == null) return false;
    final rank = _data['rank'] as String? ?? 'E';
    final specs = kRankTrials[rank];
    if (specs == null) return false;
    final beginner = p.experience < 2;
    final objs = _generator(DateTime.now()).fromSpecs(specs, beginner: beginner);
    if (objs.isEmpty) return false;
    _data['trialPlan'] = {
      'rank': rank,
      'obj': [for (final o in objs) o.toJson()],
    };
    _changed();
    return _start('trial:$rank:${beginner ? 'b' : 'a'}', '$rank-Rank Promotion Trial', objs);
  }

  bool bossUnlocked(BossDef b, HunterStatus s, {required bool advanced}) =>
      s.questsDone >= b.questsNeeded && !s.readiness.low && (!advanced || (player?.experience ?? 0) >= 2);

  bool startBoss(String id, {required bool advanced}) {
    final b = bossById(id);
    if (b == null || player == null) return false;
    final objs = _generator(DateTime.now()).fromSpecs(advanced ? b.advanced : b.beginner);
    if (objs.isEmpty) return false;
    final plans = Map<String, dynamic>.from((_data['bossPlans'] as Map?) ?? const {});
    plans['$id:${advanced ? 'a' : 'b'}'] = [for (final o in objs) o.toJson()];
    _data['bossPlans'] = plans;
    _changed();
    return _start('boss:$id:${advanced ? 'a' : 'b'}', b.name, objs);
  }

  // --- Gates ------------------------------------------------------------------------

  List<Map<String, dynamic>> _gateRuns() => [
    for (final r in (_data['gateRuns'] as List?) ?? const [])
      if (r is Map) r.cast<String, dynamic>(),
  ];

  void enterGate(String id) {
    final runs = [
      for (final r in _gateRuns())
        if (r['id'] != id) r,
    ];
    runs.add({'id': id, 'start': dayKey(DateTime.now())});
    _data['gateRuns'] = runs;
    _changed();
  }

  void abandonGate(String id) {
    _data['gateRuns'] = [
      for (final r in _gateRuns())
        if (r['id'] != id) r,
    ];
    _changed();
  }

  // --- Rank promotion, skills, titles, cosmetics ---------------------------------------

  List<RankChange> get rankHistory => [
    for (final r in (_data['rankHistory'] as List?) ?? const []) ?RankChange.fromJson(r),
  ];

  /// Promotes the hunter when every requirement is met. Never demotes.
  RankChange? promote() {
    final s = status;
    final next = s.nextRank;
    if (!s.promotionReady || next == null) return null;
    final change = RankChange(s.rank.letter, next.letter, DateTime.now());
    _data['rank'] = next.letter;
    _data['rankHistory'] = [
      ...[for (final r in rankHistory) r.toJson()],
      change.toJson(),
    ];
    _grant(
      XpTransaction(
        id: 'rank:${next.letter}',
        xp: kRankPromotionXp,
        category: 'rank',
        reason: 'Promoted to ${next.letter}-Rank',
        at: change.at,
        attrs: const {Attr.consistency: 20},
      ),
    );
    _note(
      'rank',
      'HUNTER RANK PROMOTION',
      'Previous Rank: ${change.from} · New Rank: ${change.to}',
      id: 'rank:${change.to}',
    );
    _changed();
    return change;
  }

  Map<String, DateTime> get _learned => {
    for (final e in ((_data['skills'] as Map?) ?? const {}).entries) '${e.key}': ?DateTime.tryParse('${e.value}'),
  };

  bool learnSkill(String id) {
    final s = status;
    final st = s.skills.where((k) => k.def.id == id).firstOrNull;
    if (st == null || !st.learnable || s.skillPoints < 1) return false;
    _data['skills'] = {...((_data['skills'] as Map?) ?? const {}), id: DateTime.now().toIso8601String()};
    _note('skill', 'NEW SKILL LEARNED', st.def.name, id: 'skill:$id');
    _changed();
    return true;
  }

  void equipTitle(String id) {
    _data['title'] = id;
    _changed();
  }

  void setFrame(String id) {
    _data['frame'] = id;
    _changed();
  }

  // --- Weekly target review & comeback ---------------------------------------------

  void answerWeeklyProposal(bool approve) {
    final prop = _data['proposal'];
    if (prop is! Map) return;
    if (approve) {
      final to = (prop['to'] as num).toInt();
      final p = player;
      if (p != null) {
        p.weeklyTarget = to;
        _data['player'] = p.toJson();
        final delta = to - fit.profile.weeklyGoal;
        if (delta != 0) fit.updateProfile(weeklyGoalDelta: delta);
      }
    }
    _data['proposal'] = {...prop, 'answered': true};
    _changed();
  }

  List<Map<String, dynamic>> get _comebacks => [
    for (final c in (_data['comebacks'] as List?) ?? const [])
      if (c is Map) c.cast<String, dynamic>(),
  ];

  /// Accepts a comeback plan: lighter quests and a reduced weekly target
  /// for two weeks. Nothing earned is touched.
  void acceptComeback(String reason) {
    final today = _day(DateTime.now());
    final p = player;
    final reduced = math.max(2, (p?.weeklyTarget ?? 3) - 1);
    _data['comebacks'] = [
      ..._comebacks,
      {
        'start': dayKey(today),
        'until': dayKey(today.add(const Duration(days: HunterRules.comebackPlanDays))),
        'reason': reason,
        'target': reduced,
        'prevTarget': p?.weeklyTarget ?? 3,
      },
    ];
    if (p != null) {
      p.weeklyTarget = reduced;
      _data['player'] = p.toJson();
    }
    // Today's untouched quests are rebuilt with the lighter plan.
    final qs = Map<String, dynamic>.from((_data['quests'] as Map?) ?? const {});
    qs.removeWhere((k, v) => v is Map && v['day'] == dayKey(today) && v['st'] == QuestStatus.offered.name);
    _data['quests'] = qs;
    _note('system', 'WELCOME BACK, HUNTER', 'Comeback plan active for ${HunterRules.comebackPlanDays} days.');
    _changed();
  }

  void dismissComeback() {
    _data['comebackDismissed'] = dayKey(DateTime.now());
    _changed();
  }

  // --- Notifications -------------------------------------------------------------------

  List<HunterNote> get notes => [for (final n in (_data['notes'] as List?) ?? const []) ?HunterNote.fromJson(n)];

  int _noteSeq = 0;

  void _note(String kind, String title, String body, {String? id}) {
    final list = [
      for (final n in (_data['notes'] as List?) ?? const [])
        if (n is Map) n,
    ];
    final nid = id ?? '$kind:${DateTime.now().microsecondsSinceEpoch}:${_noteSeq++}';
    if (list.any((n) => n['id'] == nid)) return;
    list.add(HunterNote(nid, kind, title, body, DateTime.now()).toJson());
    _data['notes'] = list.length > 120 ? list.sublist(list.length - 120) : list;
  }

  Set<String> get _shown => {for (final e in (_data['shown'] as List?) ?? const []) '$e'};

  /// Notifications of [kinds] not yet shown as a pop-up, oldest first.
  List<HunterNote> pendingAlerts(Set<String> kinds) {
    status;
    final shown = _shown;
    return [
      for (final n in notes)
        if (kinds.contains(n.kind) && !shown.contains(n.id)) n,
    ];
  }

  /// Records pop-ups as shown so they never replay on the next launch.
  void markShown(Iterable<String> ids) {
    final all = [..._shown, ...ids];
    _data['shown'] = all.length > 300 ? all.sublist(all.length - 300) : all;
    _changed();
  }

  void markNotesRead([Iterable<String>? ids]) {
    final set = ids?.toSet();
    _data['notes'] = [for (final n in notes) (n..read = n.read || set == null || set.contains(n.id)).toJson()];
    _changed();
  }

  // ===========================================================================
  // Facts
  // ===========================================================================

  String _kind(LoggedExercise e) {
    final ex = fit.exerciseById(e.id);
    if (ex != null) return kStretchIds.contains(ex.id) ? 'stretch' : fit.kindOf(ex);
    if (fit.isCardio(e.id) || e.sets.any((s) => (s.km ?? 0) > 0)) return 'cardio';
    return 'strength';
  }

  static bool _has(String n, List<String> words) => words.any(n.contains);

  List<SessionFacts> _facts() {
    final since = player?.created;
    // One activity per timestamp: a duplicated or re-imported session is
    // the same activity and never counts twice.
    final seen = <int>{};
    final sessions = [
      for (final s in fit.sessions)
        if ((since == null || !s.date.isBefore(since)) && seen.add(s.date.millisecondsSinceEpoch)) s,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final quests = _quests;
    final bestW = <String, double>{};
    final bestR = <String, int>{};
    final out = <SessionFacts>[];
    for (final s in sessions) {
      final f = SessionFacts(s);
      var cardioSec = 0.0;
      final exs = s.exercises;
      for (var i = 0; i < exs.length; i++) {
        final e = exs[i];
        final work = e.workingSets;
        if (work.isEmpty) continue;
        final kind = _kind(e);
        final n = e.name.toLowerCase();
        f.workingSets += work.length;
        f.muscles.add(e.primary);
        if (kind == 'cardio' || kind == 'sport') {
          for (final x in work) {
            if ((x.sec ?? 0) > 0) {
              cardioSec += x.sec!;
            } else if ((x.km ?? 0) > 0) {
              cardioSec += x.km! * 6 * 60;
            }
            f.km += x.km ?? 0;
          }
          final kmMax = work.map((x) => x.km ?? 0).fold(0.0, math.max);
          if (e.id == 'running' || e.id == 'outdoor-run' || _has(n, const ['run', 'jog'])) {
            f.run = true;
            f.runKm = math.max(f.runKm, kmMax);
          } else if (const {'walking', 'outdoor-walk', 'hiking'}.contains(e.id) || _has(n, const ['walk', 'hike'])) {
            f.walk = true;
            f.walkKm = math.max(f.walkKm, kmMax);
          }
          continue;
        }
        if (kind == 'stretch') {
          f.mobilitySets += work.length;
          if (i == exs.length - 1) f.cooldown = true;
          continue;
        }
        f.strengthSets += work.length;
        if (const {'chest', 'shoulders', 'triceps', 'back', 'biceps', 'trapezius'}.contains(e.primary)) f.upper = true;
        if (const {'quads', 'hamstrings', 'glutes', 'calves'}.contains(e.primary)) f.lower = true;
        if (const {'abdomen', 'obliques'}.contains(e.primary)) f.core = true;
        if (_has(n, const [
          'single',
          'pistol',
          'split squat',
          'lunge',
          'balance',
          'one-leg',
          'one leg',
          'step-up',
          'step up',
        ])) {
          f.balance = true;
        }
        final maxReps = work.map((x) => x.reps).fold(0, math.max);
        if (_has(n, const ['push-up', 'push up']) && !_has(n, const ['wall', 'knee', 'incline'])) {
          f.pushUpMax = math.max(f.pushUpMax, maxReps);
        }
        if (_has(n, const ['pull-up', 'pull up', 'chin-up', 'chin up']) &&
            !_has(n, const ['assisted', 'negative', 'band', 'scapular', 'inverted'])) {
          f.pullUpMax = math.max(f.pullUpMax, maxReps);
        }
        if (n.contains('squat')) f.squatReps += work.fold(0, (a, x) => a + x.reps);
        // Personal records (comparable sets only) count towards XP.
        final weighted = work.where((x) => x.weight > 0 && x.reps > 0);
        if (weighted.isNotEmpty) {
          final top = weighted.map((x) => x.weight).reduce(math.max);
          final prev = bestW[e.id];
          if (prev != null && top > prev + 0.01) f.prs++;
          if (prev == null || top > prev) bestW[e.id] = top;
        } else {
          final prev = bestR[e.id];
          if (prev != null && maxReps > prev) f.prs++;
          if (prev == null || maxReps > prev) bestR[e.id] = maxReps;
        }
      }
      f.cardioMinutes = cardioSec / 60;
      final logged = s.durationSec ~/ 60;
      f.minutes = logged > 0
          ? logged
          : ((f.strengthSets + f.mobilitySets) * HunterRules.minutesPerSet).round() + f.cardioMinutes.round();
      final rid = s.routineId;
      f.planned = rid != null || fit.hasPlanOn(s.day);
      final linked = rid != null && rid.startsWith('quest:') ? quests[rid.substring(6)] : null;
      f.recovery = s.deload || linked?.category == QuestCategory.recovery;
      f.mobility = !f.recovery && f.mobilitySets > 0 && f.mobilitySets >= f.strengthSets && f.cardioMinutes < 10;
      out.add(f);
    }
    return out;
  }

  /// Share (0–1) of [objs] done in [s]. Unmatched logged exercises fill
  /// unmatched objectives in order, so an in-session swap still counts.
  double completionOf(LoggedSession s, List<QuestObjective> objs) {
    if (objs.isEmpty) return 0;
    final logged = [
      for (final e in s.exercises)
        if (e.workingSets.isNotEmpty) e,
    ];
    final used = <LoggedExercise>{};
    double score(QuestObjective o, LoggedExercise e) {
      final work = e.workingSets;
      if (o.seconds != null && o.sets == 1) {
        final sec = work.fold<double>(0, (a, x) => a + ((x.sec ?? 0) > 0 ? x.sec! : (x.km ?? 0) * 360));
        return (sec / o.seconds!).clamp(0.0, 1.0);
      }
      return math.min(work.length, o.sets).toDouble();
    }

    var done = 0.0;
    final pending = <QuestObjective>[];
    for (final o in objs) {
      final m = logged.where((e) => e.id == o.exerciseId && !used.contains(e)).firstOrNull;
      if (m == null) {
        pending.add(o);
      } else {
        used.add(m);
        done += score(o, m);
      }
    }
    final rest = logged.where((e) => !used.contains(e)).toList();
    for (var i = 0; i < pending.length && i < rest.length; i++) {
      done += score(pending[i], rest[i]);
    }
    final planned = objs.fold<int>(0, (n, o) => n + o.sets);
    return planned == 0 ? 0 : (done / planned).clamp(0.0, 1.0);
  }

  Set<String> _avoidMuscles() => {
    for (final l in player?.limitations ?? const <String>[]) ...kLimitations[l] ?? [l],
    for (final i in injuries)
      if (!i.resolved && i.severity >= 4) i.area,
  };

  Map<Attr, int> _attrXpTotals() {
    final out = {for (final a in Attr.values) a: 0};
    for (final v in ((_data['ledger'] as Map?) ?? const {}).values) {
      if (v is! Map) continue;
      for (final e in ((v['a'] as Map?) ?? const {}).entries) {
        final a = attrByName('${e.key}');
        if (a != null) out[a] = out[a]! + (e.value as num).toInt();
      }
    }
    return out;
  }

  QuestGenerator _generator(DateTime day) {
    final today = _day(day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recent = {
      for (final s in fit.sessions)
        if (!_day(s.day).isBefore(yesterday))
          for (final e in s.exercises) e.primary,
    };
    final totals = _attrXpTotals();
    return QuestGenerator(
      fit: fit,
      player: player!,
      day: today,
      avoid: _avoidMuscles(),
      lowReadiness: _readiness(today).low,
      restDay: fit.dayOffOn(today) != null,
      comeback: _comebackActive(today),
      learned: _learned.keys.toSet(),
      attrLevels: {for (final e in totals.entries) e.key: HunterRules.attrLevelFor(e.value).level},
      recentMuscles: recent,
    );
  }

  bool _comebackActive(DateTime today) => _comebacks.any((c) {
    final until = _parseDay(c['until']);
    final start = _parseDay(c['start']);
    return start != null && until != null && !today.isBefore(start) && today.isBefore(until);
  });

  // ===========================================================================
  // Ledger
  // ===========================================================================

  Map<String, XpTransaction> get _ledger => {
    for (final e in ((_data['ledger'] as Map?) ?? const {}).entries)
      '${e.key}': ?XpTransaction.fromJson('${e.key}', e.value),
  };

  bool hasTransaction(String id) => ((_data['ledger'] as Map?) ?? const {}).containsKey(id);

  /// Adds a transaction once. Returns false if that reference already paid.
  bool _grant(XpTransaction t) {
    final ledger = (_data['ledger'] as Map?)?.cast<String, dynamic>();
    if (ledger != null && ledger.containsKey(t.id)) return false;
    final next = Map<String, dynamic>.from(ledger ?? const {});
    next[t.id] = t.toJson();
    _data['ledger'] = next;
    return true;
  }

  int get _totalXp => ((_data['ledger'] as Map?) ?? const {}).values.fold<int>(
    0,
    (n, v) => n + (v is Map ? ((v['xp'] as num?) ?? 0).toInt() : 0),
  );

  int _countLedger(String prefix) =>
      ((_data['ledger'] as Map?) ?? const {}).keys.where((k) => '$k'.startsWith(prefix)).length;

  /// Cheap change detector for [_sync].
  int _fingerprint() => Object.hash(
    ((_data['ledger'] as Map?) ?? const {}).length,
    ((_data['notes'] as List?) ?? const []).length,
    Object.hashAll(((_data['quests'] as Map?) ?? const {}).values.map((v) => v is Map ? '${v['st']}${v['cmp']}' : '')),
    ((_data['quests'] as Map?) ?? const {}).length,
    _data['proposal'] is Map ? (_data['proposal'] as Map)['week'] : null,
  );

  /// Adds every missing reward. Returns true if anything changed.
  bool _sync(List<SessionFacts> facts) {
    final p = player!;
    final today = _day(DateTime.now());
    final levelBefore = HunterRules.levelFor(_totalXp).level;
    final before = _fingerprint();
    final ledgerNow = _ledger;

    // Per-day caps, from what the ledger already holds.
    final dayXp = <String, int>{};
    final dayAttr = <String, Map<Attr, int>>{};
    for (final t in ledgerNow.values) {
      if (!t.id.startsWith('session:')) continue;
      final k = dayKey(t.at);
      dayXp[k] = (dayXp[k] ?? 0) + t.xp;
      final m = dayAttr.putIfAbsent(k, () => {});
      for (final e in t.attrs.entries) {
        m[e.key] = (m[e.key] ?? 0) + e.value;
      }
    }

    for (final f in facts) {
      final s = f.session;
      // 1. The workout itself.
      if (f.valid && !ledgerNow.containsKey(f.ref)) {
        final k = dayKey(s.date);
        final used = dayXp[k] ?? 0;
        final xp = math.max(0, math.min(f.rawXp, HunterRules.dailyWorkoutXpCap - used));
        final usedAttr = dayAttr.putIfAbsent(k, () => {});
        final attrs = <Attr, int>{};
        for (final e in f.rawAttrs.entries) {
          final v = math.max(0, math.min(e.value, HunterRules.dailyAttrXpCap - (usedAttr[e.key] ?? 0)));
          if (v > 0) attrs[e.key] = v;
          usedAttr[e.key] = (usedAttr[e.key] ?? 0) + v;
        }
        dayXp[k] = used + xp;
        final label = switch (f.category) {
          'recovery' => 'Recovery session',
          'mobility' => 'Mobility session',
          _ => 'Workout',
        };
        _grant(
          XpTransaction(
            id: f.ref,
            xp: xp,
            category: f.category,
            reason: '$label · ${f.minutes} min${xp < f.rawXp ? ' (daily limit reached)' : ''}',
            at: s.date,
            activityId: f.ref,
            attrs: attrs,
          ),
        );
      }
      // 2. Personal records.
      if (f.prs > 0) {
        final n = math.min(f.prs, HunterRules.maxPrsPerSession);
        if (_grant(
          XpTransaction(
            id: 'pr:${s.date.millisecondsSinceEpoch}',
            xp: n * HunterRules.prXp,
            category: 'record',
            reason: n == 1 ? 'New personal record' : '$n new personal records',
            at: s.date,
            activityId: f.ref,
            attrs: {f.strength ? Attr.strength : Attr.endurance: n * 5},
          ),
        )) {
          _note(
            'record',
            'PERSONAL RECORD ACHIEVED',
            'Your previous record has been surpassed.',
            id: 'pr:${s.date.millisecondsSinceEpoch}',
          );
        }
      }
      // 3. Linked quest, trial or boss.
      final rid = s.routineId ?? '';
      if (rid.startsWith('quest:')) {
        final q = _quests[rid.substring(6)];
        if (q != null && q.isWorkout) _settleQuest(q, completionOf(s, q.objectives), s.date, f.ref);
      } else if (rid.startsWith('trial:')) {
        final parts = rid.split(':');
        final plan = _data['trialPlan'];
        final objs = plan is Map && plan['rank'] == parts[1]
            ? [
                for (final o in (plan['obj'] as List?) ?? const [])
                  if (o is Map) QuestObjective.fromJson(o),
              ]
            : <QuestObjective>[];
        if (objs.isNotEmpty && completionOf(s, objs) >= HunterRules.trialPassCompletion) {
          if (_grant(
            XpTransaction(
              id: 'trial:${parts[1]}',
              xp: kTrialXp,
              category: 'trial',
              reason: '${parts[1]}-Rank promotion trial passed',
              at: s.date,
              activityId: f.ref,
              attrs: const {Attr.consistency: 15},
            ),
          )) {
            _note('trial', 'TRIAL PASSED', '${parts[1]}-Rank promotion trial cleared.', id: 'trial:${parts[1]}');
          }
        }
      } else if (rid.startsWith('boss:')) {
        final parts = rid.split(':');
        final b = bossById(parts.length > 1 ? parts[1] : '');
        final variant = parts.length > 2 ? parts[2] : 'b';
        final plan = ((_data['bossPlans'] as Map?) ?? const {})['${parts.length > 1 ? parts[1] : ''}:$variant'];
        final objs = [
          for (final o in (plan as List?) ?? const [])
            if (o is Map) QuestObjective.fromJson(o),
        ];
        if (b != null && objs.isNotEmpty && completionOf(s, objs) >= HunterRules.bossWinCompletion) {
          final adv = variant == 'a';
          if (_grant(
            XpTransaction(
              id: 'boss:${b.id}:$variant',
              xp: adv ? (b.xp * 1.5).round() : b.xp,
              category: 'boss',
              reason: '${b.name} defeated${adv ? ' (advanced)' : ''}',
              at: s.date,
              activityId: f.ref,
              attrs: {b.attr: 30},
            ),
          )) {
            _note('boss', 'BOSS DEFEATED', b.name, id: 'boss:${b.id}:$variant');
          }
        }
      }
    }

    // 4. Daily habits since registration.
    final since = _day(p.created);
    final checks = (_data['check'] as Map?) ?? const {};
    final sessionDays = {for (final f in facts) dayKey(f.day)};
    for (var d = since; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      final k = dayKey(d);
      final sl = sleepOn(d);
      if (sl != null && sl >= HunterRules.sleepTargetHours) {
        _grant(
          XpTransaction(
            id: 'sleep:$k',
            xp: HunterRules.sleepXp,
            category: 'habit',
            reason: 'Slept ${sl}h',
            at: d.add(const Duration(hours: 8)),
            attrs: const {Attr.recovery: 10},
          ),
        );
      }
      if (fit.dayOffOn(d) == 'rest' && !sessionDays.contains(k) && d.isBefore(today)) {
        _grant(
          XpTransaction(
            id: 'rest:$k',
            xp: HunterRules.restDayXp,
            category: 'habit',
            reason: 'Planned rest day honoured',
            at: d.add(const Duration(hours: 20)),
            attrs: const {Attr.recovery: 10, Attr.consistency: 5},
          ),
        );
      }
      if (checks.containsKey(k)) {
        _grant(
          XpTransaction(
            id: 'check:$k',
            xp: HunterRules.checkInXp,
            category: 'habit',
            reason: 'Readiness check-in',
            at: d.add(const Duration(hours: 9)),
            attrs: const {Attr.recovery: 3},
          ),
        );
      }
    }

    // 5. Today's quest board, then data-validated quests and expiry.
    final tk = dayKey(today);
    final prefix = 'q${tk.replaceAll('-', '')}-';
    if (!_quests.keys.any((id) => id.startsWith(prefix))) {
      for (final q in _generator(today).daily()) {
        _putQuest(q);
      }
      _note('quest', 'SYSTEM ALERT', 'New daily quests generated.', id: 'quests:$tk');
    }
    for (final q in _quests.values) {
      final qd = _parseDay(q.day) ?? today;
      if (!q.isWorkout &&
          !q.done &&
          q.status != QuestStatus.skipped &&
          q.status != QuestStatus.expired &&
          !qd.isAfter(today)) {
        if (_dataQuestProgress(q, qd, facts) >= q.target) {
          _settleQuest(q, 1, qd == today ? DateTime.now() : qd.add(const Duration(hours: 21)), null);
          continue;
        }
      }
      if (qd.isBefore(today) &&
          (q.status == QuestStatus.offered || q.status == QuestStatus.accepted) &&
          !isQuestLive(q.id)) {
        q.status = QuestStatus.expired;
        _putQuest(q);
      }
    }

    // 6. Weekly missions for every week since registration.
    for (var ws = _weekStart(since); !ws.isAfter(today); ws = ws.add(const Duration(days: 7))) {
      final end = ws.add(const Duration(days: 7));
      for (final m in _weeklyFor(ws, facts)) {
        if (m.done &&
            _grant(
              XpTransaction(
                id: 'weekly:${dayKey(ws)}:${m.id}',
                xp: m.xp,
                category: 'weekly',
                reason: 'Weekly mission: ${m.name}',
                at: end.isAfter(DateTime.now()) ? DateTime.now() : end.subtract(const Duration(hours: 1)),
                attrs: m.attrs,
              ),
            )) {
          _note('weekly', 'WEEKLY MISSION COMPLETE', m.name, id: 'weekly:${dayKey(ws)}:${m.id}');
        }
      }
    }

    // 7. Gates.
    for (final r in _gateRuns()) {
      final g = gateById('${r['id']}');
      final start = _parseDay(r['start']);
      if (g == null || start == null) continue;
      if (_gateProgress(g, start, facts) >= g.target &&
          _grant(
            XpTransaction(
              id: 'gate:${g.id}:${dayKey(start)}',
              xp: g.xp,
              category: 'gate',
              reason: 'Dungeon cleared: ${g.name}',
              at: DateTime.now(),
              attrs: const {Attr.consistency: 20},
            ),
          )) {
        _note('gate', 'DUNGEON CLEARED', g.name, id: 'gate:${g.id}:${dayKey(start)}');
      }
    }

    // 8. Achievements (an achievement can level you up, which can unlock another).
    for (var pass = 0; pass < 3; pass++) {
      final stats = _stats(facts);
      var any = false;
      for (final a in kAchievements) {
        if ((stats[a.stat] ?? 0) >= a.threshold &&
            _grant(
              XpTransaction(
                id: 'ach:${a.id}',
                xp: a.xp,
                category: 'achievement',
                reason: 'Achievement: ${a.name}',
                at: DateTime.now(),
              ),
            )) {
          _note('achievement', 'ACHIEVEMENT UNLOCKED', a.name, id: 'ach:${a.id}');
          any = true;
        }
      }
      if (!any) break;
    }

    // 9. Level-ups, skills ready, promotion available, recovery advice.
    final levelAfter = HunterRules.levelFor(_totalXp).level;
    if (levelAfter > levelBefore) {
      _note('level', 'LEVEL UP!', '$levelBefore → $levelAfter', id: 'level:$levelAfter');
    }
    final sstats = _skillStats(facts);
    final totals = _attrXpTotals();
    final learned = _learned;
    for (final sk in kSkills) {
      final attrOk = sk.attr == null || HunterRules.attrLevelFor(totals[sk.attr!]!).level >= sk.attrLevel;
      if ((sstats[sk.stat] ?? 0) >= sk.threshold && attrOk && !learned.containsKey(sk.id)) {
        _note('skillready', 'NEW SKILL UNLOCKED', '${sk.name} can now be learned.', id: 'skillready:${sk.id}');
      }
    }
    final rank = _data['rank'] as String? ?? 'E';
    if (nextRankOf(rank) != null && _promotionRequirements(rank, facts).every((r) => r.met)) {
      _note('promo', 'RANK PROMOTION AVAILABLE', 'You have fulfilled your promotion requirements.', id: 'promo:$rank');
    }
    if (_readiness(today).low) {
      _note(
        'recovery',
        'RECOVERY RECOMMENDATION',
        'Consider a lighter activity today based on your recent training and readiness.',
        id: 'recovery:$tk',
      );
    }

    // 10. Weekly target review (once a week, the player approves).
    final ws = _weekStart(today);
    final prop = _data['proposal'];
    if (!(prop is Map && prop['week'] == dayKey(ws)) && ws.difference(since).inDays >= 14) {
      final last = [for (var i = 1; i <= 2; i++) _activeDays(ws.subtract(Duration(days: 7 * i)), facts)];
      final target = p.weeklyTarget;
      int? to;
      if (last.every((n) => n >= target + 1) && target < 6) to = target + 1;
      if (last.every((n) => n < target - 1) && target > 1) to = target - 1;
      if (to != null) _data['proposal'] = {'week': dayKey(ws), 'from': target, 'to': to};
    }

    return _fingerprint() != before;
  }

  void _settleQuest(Quest q, double ratio, DateTime at, String? activity) {
    if (q.done) return;
    q.completion = ratio;
    if (ratio < HunterRules.questMinCompletion) {
      q.status = QuestStatus.partial;
      _putQuest(q);
      return;
    }
    final full = ratio >= HunterRules.questFullCompletion;
    q.status = full ? QuestStatus.completed : QuestStatus.partial;
    _putQuest(q);
    final f = full ? 1.0 : ratio;
    _grant(
      XpTransaction(
        id: 'quest:${q.id}',
        xp: (q.xp * f).round(),
        category: 'quest',
        reason: '${q.category.label}: ${q.name}${full ? '' : ' (${(ratio * 100).round()}%)'}',
        at: at,
        activityId: activity,
        questId: q.id,
        attrs: {for (final e in q.attrXp.entries) e.key: (e.value * f).round()},
      ),
    );
    if (full) {
      _grant(
        XpTransaction(
          id: 'qbonus:${q.id}',
          xp: HunterRules.dailyQuestBonus,
          category: 'quest',
          reason: 'Daily quest completion bonus',
          at: at,
          questId: q.id,
        ),
      );
      _note('questdone', 'QUEST COMPLETE', '${q.name} · mission completed successfully.', id: 'questdone:${q.id}');
    }
  }

  num _dataQuestProgress(Quest q, DateTime d, List<SessionFacts> facts) {
    final day = [
      for (final f in facts)
        if (f.day == d) f.session,
    ];
    int sets(bool Function(LoggedExercise) t) =>
        day.fold(0, (n, s) => n + s.exercises.where(t).fold(0, (m, e) => m + e.workingSets.length));
    return switch (q.check) {
      'water' => fit.waterOn(d),
      'protein' => fit.totalOn(d).protein.round(),
      'sleep' => sleepOn(d) ?? 0,
      'weigh' => fit.bodyweight.any((b) => _day(b.date) == d) ? 1 : 0,
      'food' => fit.entriesOn(d).length,
      'checkin' => checkOn(d) == null ? 0 : 1,
      'pushReps' => day.fold<int>(
        0,
        (n, s) =>
            n +
            s.exercises
                .where(
                  (e) =>
                      e.name.toLowerCase().contains('push') &&
                      const {'chest', 'triceps', 'shoulders'}.contains(e.primary),
                )
                .fold<int>(0, (m, e) => m + e.workingSets.fold<int>(0, (r, x) => r + x.reps)),
      ),
      'cardioMin' => [
        for (final f in facts)
          if (f.day == d) f.cardioMinutes,
      ].fold(0.0, (a, b) => a + b).round(),
      'steps' => fit.stepsOnDay(d),
      'effortSets' => day.fold<int>(
        0,
        (n, s) => n + s.exercises.fold<int>(0, (m, e) => m + e.workingSets.where((x) => x.rpe != null).length),
      ),
      'coreSets' => sets((e) => e.primary == 'abdomen' || e.primary == 'obliques'),
      _ => 0,
    };
  }

  num questProgress(Quest q) =>
      q.isWorkout ? q.completion : _dataQuestProgress(q, _parseDay(q.day) ?? _day(DateTime.now()), status.facts);

  DateTime _weekStart(DateTime d) => DateTime(d.year, d.month, d.day - ((d.weekday - fit.weekStartDay + 7) % 7));

  int _activeDays(DateTime ws, List<SessionFacts> facts) => {
    for (final f in facts)
      if (!f.day.isBefore(ws) && f.day.isBefore(ws.add(const Duration(days: 7)))) dayKey(f.day),
  }.length;

  List<WeeklyMission> _weeklyFor(DateTime ws, List<SessionFacts> facts) {
    final we = ws.add(const Duration(days: 7));
    final inWeek = [
      for (final f in facts)
        if (!f.day.isBefore(ws) && f.day.isBefore(we)) f,
    ];
    final t = player?.weeklyTarget ?? 3;
    final strength = math.max(1, (t / 2).ceil());
    final mobility = t >= 4 ? 2 : 1;
    final cardio = t >= 5 ? 2 : 1;
    final planned = math.max(1, t - 1);
    return [
      WeeklyMission(
        'mission_a',
        'Balanced Hunter',
        [
          Requirement('Strength workouts', inWeek.where((f) => f.strength).length, strength),
          Requirement('Mobility sessions', inWeek.where((f) => f.mobilitySets > 0).length, mobility),
          Requirement('Cardio sessions', inWeek.where((f) => f.cardio).length, cardio),
          Requirement('Active days (weekly target)', _activeDays(ws, facts), t),
        ],
        250,
        const {Attr.consistency: 30, Attr.strength: 10, Attr.endurance: 10, Attr.mobility: 10},
      ),
      WeeklyMission(
        'mission_b',
        'Disciplined Training',
        [
          Requirement('Planned workouts', inWeek.where((f) => f.planned).length, planned),
          Requirement('Workouts logged', inWeek.length, math.min(3, t)),
          Requirement(
            'Recovery or mobility session',
            inWeek.where((f) => f.recovery || f.mobility || f.cooldown).length,
            1,
          ),
        ],
        200,
        const {Attr.consistency: 30, Attr.recovery: 15},
      ),
    ];
  }

  num _gateProgress(GateDef g, DateTime start, List<SessionFacts> facts) {
    final end = start.add(Duration(days: g.days));
    final inGate = [
      for (final f in facts)
        if (!f.day.isBefore(start) && f.day.isBefore(end)) f,
    ];
    switch (g.goal) {
      case GateGoal.sessions:
        return inGate.length;
      case GateGoal.workingSets:
        return inGate.fold<int>(0, (n, f) => n + f.workingSets);
      case GateGoal.cardioSessions:
        return inGate.where((f) => f.cardio).length;
      case GateGoal.mobilitySessions:
        return inGate.where((f) => f.mobilitySets > 0).length;
      case GateGoal.nutritionDays:
        final today = _day(DateTime.now());
        var n = 0;
        for (var d = start; d.isBefore(end) && !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
          if (fit.entriesOn(d).isEmpty) continue;
          final kcal = fit.totalOn(d).kcal;
          final budget = fit.kcalBudgetOn(d);
          // Eating-disorder safeguard: very low intake never counts.
          if (kcal <= budget * 1.05 && kcal >= budget * 0.7) n++;
        }
        return n;
    }
  }

  int _questsDone() => _countLedger('quest:');
  int _weeklyDone() => _countLedger('weekly:');

  int _recoveryQuestsDone() {
    final quests = _quests;
    return ((_data['ledger'] as Map?) ?? const {}).keys
        .where((k) => '$k'.startsWith('quest:') && quests['$k'.substring(6)]?.category == QuestCategory.recovery)
        .length;
  }

  Map<Stat, num> _stats(List<SessionFacts> facts) => {
    Stat.registered: registered ? 1 : 0,
    Stat.questsDone: _questsDone(),
    Stat.workouts: facts.length,
    Stat.level: HunterRules.levelFor(_totalXp).level,
    Stat.weeklyDone: _weeklyDone(),
    Stat.maxPushUpSet: facts.fold(0, (a, f) => math.max(a, f.pushUpMax)),
    Stat.maxSquatRepsSession: facts.fold(0, (a, f) => math.max(a, f.squatReps)),
    Stat.maxPullUpSet: facts.fold(0, (a, f) => math.max(a, f.pullUpMax)),
    Stat.maxWalkKm: facts.fold(0.0, (a, f) => math.max(a, f.walkKm)),
    Stat.maxRunKm: facts.fold(0.0, (a, f) => math.max(a, f.runKm)),
    Stat.cardioSessions: facts.where((f) => f.cardio).length,
    Stat.strengthSessions: facts.where((f) => f.strength).length,
    Stat.plannedWorkouts: facts.where((f) => f.planned).length,
    Stat.recoveryQuests: _recoveryQuestsDone(),
    Stat.recoverySessions: facts.where((f) => f.recovery || f.mobility).length,
    Stat.recoveryHabits: _countLedger('sleep:') + _countLedger('rest:'),
    Stat.comebacks: _comebacks.where((c) {
      final start = _parseDay(c['start']);
      return start != null && facts.any((f) => !f.day.isBefore(start));
    }).length,
    Stat.bossesWon: _countLedger('boss:'),
    Stat.prs: facts.fold(0, (a, f) => a + f.prs),
  };

  Map<SkillStat, num> _skillStats(List<SessionFacts> facts) => {
    SkillStat.strengthSessions: facts.where((f) => f.strength).length,
    SkillStat.upperSessions: facts.where((f) => f.upper).length,
    SkillStat.lowerSessions: facts.where((f) => f.lower).length,
    SkillStat.coreSessions: facts.where((f) => f.core).length,
    SkillStat.walkSessions: facts.where((f) => f.walk).length,
    SkillStat.runSessions: facts.where((f) => f.run).length,
    SkillStat.cardioSessions: facts.where((f) => f.cardio).length,
    SkillStat.totalKm: facts.fold(0.0, (a, f) => a + f.km),
    SkillStat.mobilitySessions: facts.where((f) => f.mobilitySets > 0).length,
    SkillStat.balanceSessions: facts.where((f) => f.balance).length,
    SkillStat.plannedWorkouts: facts.where((f) => f.planned).length,
    SkillStat.weeklyDone: _weeklyDone(),
    SkillStat.workouts: facts.length,
    SkillStat.comebackDone: _comebacks.where((c) {
      final start = _parseDay(c['start']);
      final until = _parseDay(c['until']);
      return start != null &&
          until != null &&
          facts.where((f) => !f.day.isBefore(start) && f.day.isBefore(until)).length >= 3;
    }).length,
    SkillStat.cooldownSessions: facts.where((f) => f.cooldown).length,
    SkillStat.recoveryQuests: _recoveryQuestsDone(),
    SkillStat.checkIns: ((_data['check'] as Map?) ?? const {}).length,
  };

  List<Requirement> _promotionRequirements(String rank, List<SessionFacts> facts) {
    final r = rankByLetter(rank);
    final level = HunterRules.levelFor(_totalXp).level;
    final cats = [
      facts.where((f) => f.strength).length,
      facts.where((f) => f.cardio).length,
      facts.where((f) => f.mobilitySets > 0).length,
    ].where((n) => n >= kCategoryProofSessions).length;
    return [
      if (r.promoLevel > 0) Requirement('Reach level ${r.promoLevel}', level, r.promoLevel),
      if (r.promoQuests > 0) Requirement('Complete ${r.promoQuests} quests', _questsDone(), r.promoQuests),
      if (r.promoWeekly > 0) Requirement('Complete ${r.promoWeekly} weekly missions', _weeklyDone(), r.promoWeekly),
      if (r.promoWorkouts > 0) Requirement('Complete ${r.promoWorkouts} workouts', facts.length, r.promoWorkouts),
      if (r.promoCategories > 0)
        Requirement(
          'Train ${r.promoCategories} fitness categories ($kCategoryProofSessions+ sessions each)',
          cats,
          r.promoCategories,
        ),
      if (kRankTrials.containsKey(rank))
        Requirement('Pass the $rank-Rank promotion trial', hasTransaction('trial:$rank') ? 1 : 0, 1),
    ];
  }

  Readiness _readiness(DateTime today) {
    final c = checkOn(today);
    final sleepToday = sleepOn(today);
    final active = injuries.where((i) => !i.resolved);
    if (c == null && sleepToday == null) {
      return const Readiness(
        0,
        'Unknown',
        'Do a quick check-in so the System can size today\'s effort.',
        logged: false,
      );
    }
    final en = ((c?['en'] as num?) ?? 3).toInt();
    final so = ((c?['so'] as num?) ?? 2).toInt();
    final st = ((c?['st'] as num?) ?? 2).toInt();
    final pain = c?['pain'] == true;
    final sl = sleepToday ?? 7;
    final score = ((math.min(sl, 8) / 8) * 40 + (en / 5) * 25 + ((6 - so) / 5) * 20 + ((6 - st) / 5) * 15)
        .round()
        .clamp(0, 100);
    if (pain || active.any((i) => i.severity >= 7)) {
      return Readiness(
        score,
        'Protect',
        'You reported pain. Train around the area or take a recovery day. Severe or worsening pain needs a clinician.',
        pain: true,
      );
    }
    if (score >= 75) return Readiness(score, 'Push', 'Well recovered. A good day for quality work.');
    if (score >= 55) return Readiness(score, 'Steady', 'Train as planned. Keep 1–2 reps in reserve.');
    if (score >= 35) return Readiness(score, 'Go light', 'Cut a set or two and keep effort easy today.');
    return Readiness(score, 'Recover', 'Mobility, an easy walk and an early night. Recovery is training too.');
  }

  // ===========================================================================
  // Status
  // ===========================================================================

  HunterStatus _compute(List<SessionFacts> facts) {
    final p = player;
    final today = _day(DateTime.now());
    final ledgerMap = _ledger;
    final ledger = ledgerMap.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    final total = ledger.fold<int>(0, (n, t) => n + t.xp);
    final lv = HunterRules.levelFor(total);
    final rankLetter = _data['rank'] as String? ?? 'E';
    final rank = rankByLetter(rankLetter);
    final totals = _attrXpTotals();
    final attrs = {for (final a in Attr.values) a: AttrState(a, totals[a]!)};
    final tk = dayKey(today);
    final todayQuests = _quests.values.where((q) => q.day == tk).toList()
      ..sort((a, b) => a.category.index.compareTo(b.category.index));

    final stats = _stats(facts);
    final achievements = [
      for (final a in kAchievements) AchievementState(a, stats[a.stat] ?? 0, ledgerMap['ach:${a.id}']?.at),
    ];

    final sstats = _skillStats(facts);
    final learned = _learned;
    final skills = [
      for (final s in kSkills)
        SkillState(
          s,
          sstats[s.stat] ?? 0,
          learned[s.id],
          prerequisiteOf(s) == null || learned.containsKey(prerequisiteOf(s)!.id),
          s.attr == null || attrs[s.attr!]!.level >= s.attrLevel,
        ),
    ];
    final history = rankHistory;
    final skillPoints = math.max(0, (lv.level - 1) + history.length - learned.length);

    final rIdx = rankIndex(rankLetter);
    final gateOrBoss = ledgerMap.keys.any((k) => k.startsWith('gate:') || k.startsWith('boss:'));
    final titles = [
      for (final t in kTitles)
        TitleState(
          t,
          p != null &&
              switch (t.rule) {
                TitleRule.registered => true,
                TitleRule.rank => rIdx >= rankIndex(t.rank!),
                TitleRule.workouts => facts.length >= t.n,
                TitleRule.attrLevel => attrs[t.attr!]!.level >= t.n,
                TitleRule.gateOrBoss => gateOrBoss,
              },
        ),
    ];
    final titleId = _data['title'] as String? ?? 'awakened';
    final current =
        titles.where((t) => t.unlocked && t.def.id == titleId).firstOrNull?.def ??
        titles.where((t) => t.unlocked).firstOrNull?.def;

    final qDone = _questsDone();
    final bosses = [
      for (final b in kBossQuests)
        BossState(
          b,
          ledgerMap.containsKey('boss:${b.id}:b'),
          ledgerMap.containsKey('boss:${b.id}:a'),
          qDone >= b.questsNeeded,
        ),
    ];
    final gates = <GateRun>[];
    final runs = _gateRuns();
    for (final g in kGates) {
      final mine = runs.where((r) => r['id'] == g.id).toList();
      final start = _parseDay(mine.isEmpty ? null : mine.last['start']);
      if (start != null) {
        final prog = _gateProgress(g, start, facts);
        final end = start.add(Duration(days: g.days));
        gates.add(
          GateRun(
            g,
            start,
            prog,
            prog >= g.target ? GateStatus.cleared : (today.isBefore(end) ? GateStatus.active : GateStatus.failed),
          ),
        );
      } else {
        gates.add(GateRun(g, null, 0, rankIndex(g.rank) > rIdx + 1 ? GateStatus.locked : GateStatus.available));
      }
    }

    // Comeback.
    final lastActive = facts.isEmpty ? _day(p?.created ?? today) : facts.last.day;
    final away = today.difference(lastActive).inDays;
    final dismissed = _parseDay(_data['comebackDismissed']);
    final planStarted = _comebacks.any((c) => !(_parseDay(c['start']) ?? DateTime(2000)).isBefore(lastActive));
    final comebackDue =
        p != null &&
        away >= HunterRules.comebackDays &&
        !planStarted &&
        (dismissed == null || dismissed.isBefore(lastActive));

    // Muscle balance (shadows).
    final injuriesNow = injuries;
    final injured = {
      for (final i in injuriesNow)
        if (!i.resolved) i.area,
    };
    final from = today.subtract(const Duration(days: HunterRules.shadowWindowDays));
    final sets = {for (final m in kMuscles) m.id: 0.0};
    for (final s in fit.sessions) {
      if (s.day.isBefore(from)) continue;
      for (final e in s.exercises) {
        final n = e.workingSets.length.toDouble();
        if (n == 0) continue;
        sets[e.primary] = (sets[e.primary] ?? 0) + n;
        for (final sec in fit.exerciseById(e.id)?.secondary ?? const <String>[]) {
          sets[sec] = (sets[sec] ?? 0) + n * 0.5;
        }
      }
    }
    final totalSets = sets.values.fold(0.0, (a, b) => a + b);
    final trained = sets.values.where((v) => v > 0).toList()..sort();
    final median = trained.isEmpty ? 0.0 : trained[trained.length ~/ 2];
    final muscles = [
      for (final m in kMuscles)
        MuscleBalance(
          m.id,
          sets[m.id] ?? 0,
          totalSets < HunterRules.shadowMinTotalSets || median <= 0 ? 1 : (sets[m.id] ?? 0) / median,
          injured.contains(m.id),
        ),
    ]..sort((a, b) => a.ratio.compareTo(b.ratio));

    // Load.
    final ws = _weekStart(today);
    int setsIn(DateTime start) => fit.sessions
        .where((s) => !s.day.isBefore(start) && s.day.isBefore(start.add(const Duration(days: 7))))
        .fold(0, (n, s) => n + s.setCount);
    final weekSets = setsIn(ws);
    final avg = [for (var i = 1; i <= 4; i++) setsIn(ws.subtract(Duration(days: 7 * i)))].fold(0, (a, b) => a + b) / 4;
    final spike = avg > 0 && weekSets > avg * HunterRules.loadSpikeRatio + HunterRules.loadSpikeSlack;

    // Briefing: the four daily questions.
    final readiness = _readiness(today);
    final shadow = muscles.where((m) => !m.injured && m.ratio < HunterRules.shadowBelowMedian).firstOrNull;
    final main = todayQuests.where((q) => q.category == QuestCategory.main).firstOrNull;
    final what = fit.dayOffOn(today) != null
        ? 'Planned rest day. Walk, stretch, sleep.'
        : main != null
        ? 'Main quest: ${main.name} (~${main.minutes} min).'
        : shadow != null
        ? 'Your weakest area is ${muscleLabel(shadow.muscle).toLowerCase()}.'
        : 'Pick any quest on the board.';
    final sleeps = [for (var i = 0; i < 7; i++) ?sleepOn(today.subtract(Duration(days: i)))];
    final avgSleep = sleeps.isEmpty ? null : sleeps.reduce((a, b) => a + b) / sleeps.length;
    final recovering = spike
        ? 'Load spike: $weekSets sets this week vs ${avg.toStringAsFixed(0)} average. Hold volume steady.'
        : avgSleep == null
        ? 'Log your sleep to track recovery.'
        : 'Sleep averages ${avgSleep.toStringAsFixed(1)} h'
              '${avgSleep >= HunterRules.sleepTargetHours ? '. Recovery looks good.' : '. Aim for 7+.'}';
    final prs30 = facts
        .where((f) => !f.day.isBefore(today.subtract(const Duration(days: 30))))
        .fold<int>(0, (a, f) => a + f.prs);
    final working =
        '${_activeDays(ws, facts)} of ${p?.weeklyTarget ?? fit.weeklyTarget} training days this week · '
        '$prs30 PRs in 30 days.';

    final prop = _data['proposal'];
    final proposal = prop is Map && prop['answered'] != true && prop['week'] == dayKey(ws)
        ? (from: (prop['from'] as num).toInt(), to: (prop['to'] as num).toInt())
        : null;

    final promo = p == null ? <Requirement>[] : _promotionRequirements(rankLetter, facts);
    return HunterStatus(
      player: p,
      totalXp: total,
      level: lv.level,
      into: lv.into,
      need: lv.need,
      rank: rank,
      attrs: attrs,
      ledger: ledger,
      todayQuests: todayQuests,
      weekly: p == null ? const [] : _weeklyFor(ws, facts),
      promotion: promo,
      promotionReady: promo.isNotEmpty && promo.every((r) => r.met) && nextRankOf(rankLetter) != null,
      trialPassed: ledgerMap.containsKey('trial:$rankLetter'),
      rankHistory: history,
      achievements: achievements,
      skills: skills,
      skillPoints: skillPoints,
      titles: titles,
      currentTitle: current,
      frame: _data['frame'] as String? ?? 'plain',
      records: _records(),
      bosses: bosses,
      gates: gates,
      workouts: facts.length,
      activeMinutes: facts.fold(0, (a, f) => a + f.minutes),
      questsDone: qDone,
      weeklyDone: _weeklyDone(),
      streak: fit.currentStreak,
      comebackDue: comebackDue,
      daysAway: away,
      comebackActive: _comebackActive(today),
      weeklyProposal: proposal,
      muscles: muscles,
      readiness: readiness,
      briefing: Briefing(
        what,
        readiness.logged ? '${readiness.verdict}: ${readiness.advice}' : readiness.advice,
        recovering,
        working,
      ),
      injuries: injuriesNow,
      weekSets: weekSets,
      avgWeekSets: avg,
      loadSpike: spike,
      notes: notes.reversed.toList(),
      facts: facts,
    );
  }

  /// Exercise records with the value each replaced. Only comparable sets are
  /// compared: reps-at-weight only against the same weight.
  List<HunterRecord> _records() {
    final sessions = [...fit.sessions]..sort((a, b) => a.date.compareTo(b.date));
    final best = <String, HunterRecord>{};
    void consider(HunterRecord r) {
      final prev = best[r.key];
      if (prev == null || r.value > prev.value + 1e-9) {
        best[r.key] = HunterRecord(
          exerciseId: r.exerciseId,
          exerciseName: r.exerciseName,
          type: r.type,
          value: r.value,
          unit: r.unit,
          at: r.at,
          previous: prev?.value,
          atWeight: r.atWeight,
        );
      }
    }

    for (final s in sessions) {
      for (final e in s.exercises) {
        final work = e.workingSets;
        if (work.isEmpty) continue;
        final kind = _kind(e);
        HunterRecord rec(RecordType t, double v, String unit, {double? w}) => HunterRecord(
          exerciseId: e.id,
          exerciseName: e.name,
          type: t,
          value: v,
          unit: unit,
          at: s.date,
          atWeight: w,
        );
        for (final x in work) {
          if ((x.km ?? 0) > 0) consider(rec(RecordType.longestDistance, x.km!, 'km'));
          if ((x.sec ?? 0) > 0 && kind != 'cardio') consider(rec(RecordType.longestHold, x.sec!.toDouble(), 's'));
          if (kind == 'cardio' || kind == 'stretch') continue;
          if (x.weight > 0 && x.reps > 0) {
            consider(rec(RecordType.maxWeight, x.weight, 'kg'));
            consider(rec(RecordType.repsAtWeight, x.reps.toDouble(), 'reps', w: x.weight));
          } else if (x.weight == 0 && x.reps > 0) {
            consider(rec(RecordType.maxReps, x.reps.toDouble(), 'reps'));
          }
        }
      }
    }
    // Keep reps-at-weight only for each exercise's top weight.
    final out = best.values.where((r) => r.type != RecordType.repsAtWeight).toList();
    final topW = {for (final r in out.where((r) => r.type == RecordType.maxWeight)) r.exerciseId: r.value};
    out.addAll(best.values.where((r) => r.type == RecordType.repsAtWeight && r.atWeight == topW[r.exerciseId]));
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}
