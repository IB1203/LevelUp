import '../core/game_rules.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum ExperienceLevel {
  beginner('Beginner', 'New to training, or back after a long break'),
  intermediate('Intermediate', 'Training fairly regularly for 6+ months'),
  advanced('Advanced', 'Years of consistent training');

  const ExperienceLevel(this.label, this.hint);
  final String label;
  final String hint;
}

enum FitnessGoal {
  generalFitness('General fitness'),
  strength('Get stronger'),
  muscle('Build muscle'),
  endurance('Build endurance'),
  flexibility('Move and bend better'),
  weight('Manage weight'),
  activeLifestyle('Stay active');

  const FitnessGoal(this.label);
  final String label;
}

/// Bodyweight is always available, so it is not listed.
enum Equipment {
  dumbbells('Dumbbells'),
  bands('Resistance bands'),
  pullUpBar('Pull-up bar'),
  bench('Bench or sturdy chair');

  const Equipment(this.label);
  final String label;
}

enum Limitation {
  knee('Knees'),
  shoulder('Shoulders'),
  lowerBack('Lower back'),
  wrist('Wrists'),
  ankle('Ankles');

  const Limitation(this.label);
  final String label;
}

enum Attribute {
  strength('Strength', 'STR'),
  endurance('Endurance', 'END'),
  agility('Agility', 'AGI'),
  vitality('Vitality', 'VIT'),
  recovery('Recovery', 'REC');

  const Attribute(this.label, this.short);
  final String label;
  final String short;
}

enum ExerciseCategory {
  strength('Strength'),
  core('Core'),
  cardio('Cardio'),
  mobility('Mobility');

  const ExerciseCategory(this.label);
  final String label;
}

enum MovementPattern {
  horizontalPush('Horizontal push'),
  verticalPush('Vertical push'),
  horizontalPull('Horizontal pull'),
  verticalPull('Vertical pull'),
  squat('Squat'),
  lunge('Lunge'),
  hinge('Hip hinge'),
  core('Core'),
  cardio('Cardio'),
  walk('Walking'),
  mobilityUpper('Upper-body mobility'),
  mobilityLower('Lower-body mobility'),
  mobilitySpine('Spine mobility'),
  breath('Breathing');

  const MovementPattern(this.label);
  final String label;
}

enum Tracking { reps, seconds }

enum Impact { low, medium, high }

enum QuestKind { daily, comeback, bonus }

enum QuestStatus { pending, completed, missed }

enum QuestFocus {
  fullBody('Full body'),
  upper('Upper body'),
  lower('Lower body'),
  cardio('Cardio'),
  mobility('Mobility'),
  recovery('Recovery');

  const QuestFocus(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

// ---------------------------------------------------------------------------
// Exercise
// ---------------------------------------------------------------------------

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.pattern,
    required this.muscles,
    required this.steps,
    required this.cue,
    this.equipment = const {},
    this.difficulty = 1,
    this.tracking = Tracking.reps,
    this.impact = Impact.low,
    this.stresses = const {},
    this.perSide = false,
  });

  final String id;
  final String name;
  final ExerciseCategory category;
  final MovementPattern pattern;
  final String muscles;
  final List<String> steps;
  final String cue;

  /// Equipment required. Empty means bodyweight only.
  final Set<Equipment> equipment;

  /// 1 = beginner, 2 = intermediate, 3 = advanced.
  final int difficulty;
  final Tracking tracking;
  final Impact impact;

  /// Body areas this movement loads noticeably. Used to keep an exercise out
  /// of quests when the player has flagged that area. This is a training
  /// filter, not medical clearance.
  final Set<Limitation> stresses;
  final bool perSide;

  Attribute get attribute {
    switch (category) {
      case ExerciseCategory.strength:
        return Attribute.strength;
      case ExerciseCategory.core:
        return Attribute.vitality;
      case ExerciseCategory.cardio:
        return pattern == MovementPattern.walk
            ? Attribute.vitality
            : Attribute.endurance;
      case ExerciseCategory.mobility:
        return pattern == MovementPattern.breath
            ? Attribute.recovery
            : Attribute.agility;
    }
  }

  String get difficultyLabel =>
      const ['Beginner', 'Intermediate', 'Advanced'][difficulty - 1];

  String get equipmentLabel => equipment.isEmpty
      ? 'Bodyweight'
      : equipment.map((e) => e.label).join(' + ');
}

// ---------------------------------------------------------------------------
// Quest
// ---------------------------------------------------------------------------

class QuestTask {
  QuestTask({
    required this.exerciseId,
    required this.sets,
    required this.target,
    required this.tracking,
    required this.restSeconds,
    this.setsDone = 0,
    this.skipped = false,
    this.swappedFrom,
  });

  String exerciseId;
  int sets;

  /// Reps or seconds per set, depending on [tracking].
  int target;
  Tracking tracking;
  int restSeconds;
  int setsDone;
  bool skipped;
  String? swappedFrom;

  bool get finished => skipped || setsDone >= sets;

  String get targetLabel {
    final amount = tracking == Tracking.reps ? '$target reps' : formatSeconds(target);
    return sets > 1 ? '$sets × $amount' : amount;
  }

  /// Rough time this task takes, in seconds.
  int get estimatedSeconds {
    final work = tracking == Tracking.reps ? target * 3 : target;
    return sets * work + (sets - 1) * restSeconds + 20;
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'target': target,
        'tracking': tracking.name,
        'restSeconds': restSeconds,
        'setsDone': setsDone,
        'skipped': skipped,
        'swappedFrom': swappedFrom,
      };

  factory QuestTask.fromJson(Map<String, dynamic> j) => QuestTask(
        exerciseId: j['exerciseId'] as String,
        sets: j['sets'] as int,
        target: j['target'] as int,
        tracking: _enumByName(Tracking.values, j['tracking'], Tracking.reps),
        restSeconds: j['restSeconds'] as int? ?? 30,
        setsDone: j['setsDone'] as int? ?? 0,
        skipped: j['skipped'] as bool? ?? false,
        swappedFrom: j['swappedFrom'] as String?,
      );
}

class Quest {
  Quest({
    required this.id,
    required this.dateKey,
    required this.kind,
    required this.focus,
    required this.title,
    required this.minutes,
    required this.tasks,
    required this.xpReward,
    required this.reason,
    this.safetyNote,
    this.status = QuestStatus.pending,
    this.xpEarned = 0,
    List<String>? personalBests,
  }) : personalBests = personalBests ?? [];

  final String id;
  final String dateKey;
  final QuestKind kind;
  final QuestFocus focus;
  final String title;
  final int minutes;
  final List<QuestTask> tasks;
  final int xpReward;

  /// Plain-language explanation of why the System chose this quest.
  final String reason;
  final String? safetyNote;
  QuestStatus status;
  int xpEarned;

  /// Exercise ids where the player beat a previous best during this quest.
  final List<String> personalBests;

  bool get isRecovery => focus == QuestFocus.recovery;

  int get totalSets => tasks.fold(0, (a, t) => a + t.sets);
  int get doneSets =>
      tasks.fold(0, (a, t) => a + (t.setsDone > t.sets ? t.sets : t.setsDone));
  double get progress => totalSets == 0 ? 0 : doneSets / totalSets;
  bool get started => doneSets > 0 || tasks.any((t) => t.skipped);
  bool get allTasksFinished => tasks.every((t) => t.finished);

  String get difficultyLabel {
    if (isRecovery) return 'Easy';
    if (minutes <= 15) return 'Light';
    if (minutes <= 30) return 'Standard';
    return 'Hard';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'kind': kind.name,
        'focus': focus.name,
        'title': title,
        'minutes': minutes,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'xpReward': xpReward,
        'reason': reason,
        'safetyNote': safetyNote,
        'status': status.name,
        'xpEarned': xpEarned,
        'personalBests': personalBests,
      };

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
        id: j['id'] as String,
        dateKey: j['dateKey'] as String,
        kind: _enumByName(QuestKind.values, j['kind'], QuestKind.daily),
        focus: _enumByName(QuestFocus.values, j['focus'], QuestFocus.fullBody),
        title: j['title'] as String,
        minutes: j['minutes'] as int,
        tasks: (j['tasks'] as List)
            .map((t) => QuestTask.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        xpReward: j['xpReward'] as int,
        reason: j['reason'] as String? ?? '',
        safetyNote: j['safetyNote'] as String?,
        status: _enumByName(QuestStatus.values, j['status'], QuestStatus.pending),
        xpEarned: j['xpEarned'] as int? ?? 0,
        personalBests: List<String>.from(j['personalBests'] as List? ?? const []),
      );
}

// ---------------------------------------------------------------------------
// Readiness
// ---------------------------------------------------------------------------

/// The daily check-in. Every scale runs 1–3.
class Readiness {
  const Readiness({
    required this.dateKey,
    required this.energy,
    required this.soreness,
    required this.sleep,
    required this.pain,
  });

  final String dateKey;

  /// 1 = drained, 3 = full of energy.
  final int energy;

  /// 1 = fresh, 3 = very sore.
  final int soreness;

  /// 1 = poor, 3 = slept well.
  final int sleep;

  /// The player reported pain, injury or illness.
  final bool pain;

  /// 3 (worst) to 9 (best).
  int get score => energy + (4 - soreness) + sleep;

  String get statusLabel {
    if (pain) return 'Rest advised';
    if (score <= 4) return 'Low';
    if (score <= 6) return 'Moderate';
    return 'Ready';
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'energy': energy,
        'soreness': soreness,
        'sleep': sleep,
        'pain': pain,
      };

  factory Readiness.fromJson(Map<String, dynamic> j) => Readiness(
        dateKey: j['dateKey'] as String,
        energy: j['energy'] as int? ?? 2,
        soreness: j['soreness'] as int? ?? 2,
        sleep: j['sleep'] as int? ?? 2,
        pain: j['pain'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

class XpEvent {
  const XpEvent(this.at, this.amount, this.label);
  final String at;
  final int amount;
  final String label;

  Map<String, dynamic> toJson() => {'at': at, 'amount': amount, 'label': label};
  factory XpEvent.fromJson(Map<String, dynamic> j) =>
      XpEvent(j['at'] as String, j['amount'] as int, j['label'] as String);
}

class Player {
  Player({
    required this.name,
    required this.experience,
    required this.goal,
    required this.equipment,
    required this.minutes,
    required this.limitations,
    this.emblem = 0,
    this.level = 1,
    this.xp = 0,
    this.totalXp = 0,
    Map<Attribute, int>? attributes,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastActiveKey,
    this.streakCountedKey,
    this.questsCompleted = 0,
    this.recoveryQuests = 0,
    this.comebacks = 0,
    this.swapsUsed = 0,
    this.activeMinutes = 0,
    Map<String, String>? achievements,
    Map<String, int>? records,
    this.animations = true,
    this.haptics = true,
    this.createdKey = '',
  })  : attributes = attributes ?? {for (final a in Attribute.values) a: 0},
        achievements = achievements ?? {},
        records = records ?? {};

  String name;
  ExperienceLevel experience;
  FitnessGoal goal;
  Set<Equipment> equipment;

  /// Preferred quest length in minutes.
  int minutes;
  Set<Limitation> limitations;
  int emblem;

  int level;

  /// XP earned inside the current level.
  int xp;
  int totalXp;
  final Map<Attribute, int> attributes;

  int streak;
  int bestStreak;
  String? lastActiveKey;
  String? streakCountedKey;

  int questsCompleted;
  int recoveryQuests;
  int comebacks;
  int swapsUsed;
  int activeMinutes;

  /// Achievement id -> date unlocked.
  final Map<String, String> achievements;

  /// Exercise id -> best single set (reps or seconds) the player has logged.
  final Map<String, int> records;

  bool animations;
  bool haptics;
  String createdKey;

  RankRule get rank => GameRules.rankForLevel(level);
  int get xpToNext => GameRules.xpToNextLevel(level);
  double get levelProgress => (xp / xpToNext).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'name': name,
        'experience': experience.name,
        'goal': goal.name,
        'equipment': equipment.map((e) => e.name).toList(),
        'minutes': minutes,
        'limitations': limitations.map((e) => e.name).toList(),
        'emblem': emblem,
        'level': level,
        'xp': xp,
        'totalXp': totalXp,
        'attributes': {for (final e in attributes.entries) e.key.name: e.value},
        'streak': streak,
        'bestStreak': bestStreak,
        'lastActiveKey': lastActiveKey,
        'streakCountedKey': streakCountedKey,
        'questsCompleted': questsCompleted,
        'recoveryQuests': recoveryQuests,
        'comebacks': comebacks,
        'swapsUsed': swapsUsed,
        'activeMinutes': activeMinutes,
        'achievements': achievements,
        'records': records,
        'animations': animations,
        'haptics': haptics,
        'createdKey': createdKey,
      };

  factory Player.fromJson(Map<String, dynamic> j) {
    final attrs = Map<String, dynamic>.from(j['attributes'] as Map? ?? {});
    return Player(
      name: j['name'] as String? ?? 'Hunter',
      experience: _enumByName(
          ExperienceLevel.values, j['experience'], ExperienceLevel.beginner),
      goal: _enumByName(FitnessGoal.values, j['goal'], FitnessGoal.generalFitness),
      equipment: {
        for (final n in (j['equipment'] as List? ?? const []))
          for (final e in Equipment.values)
            if (e.name == n) e
      },
      minutes: j['minutes'] as int? ?? 15,
      limitations: {
        for (final n in (j['limitations'] as List? ?? const []))
          for (final e in Limitation.values)
            if (e.name == n) e
      },
      emblem: j['emblem'] as int? ?? 0,
      level: j['level'] as int? ?? 1,
      xp: j['xp'] as int? ?? 0,
      totalXp: j['totalXp'] as int? ?? 0,
      attributes: {
        for (final a in Attribute.values) a: attrs[a.name] as int? ?? 0
      },
      streak: j['streak'] as int? ?? 0,
      bestStreak: j['bestStreak'] as int? ?? 0,
      lastActiveKey: j['lastActiveKey'] as String?,
      streakCountedKey: j['streakCountedKey'] as String?,
      questsCompleted: j['questsCompleted'] as int? ?? 0,
      recoveryQuests: j['recoveryQuests'] as int? ?? 0,
      comebacks: j['comebacks'] as int? ?? 0,
      swapsUsed: j['swapsUsed'] as int? ?? 0,
      activeMinutes: j['activeMinutes'] as int? ?? 0,
      achievements: Map<String, String>.from(j['achievements'] as Map? ?? {}),
      records: Map<String, int>.from(j['records'] as Map? ?? {}),
      animations: j['animations'] as bool? ?? true,
      haptics: j['haptics'] as bool? ?? true,
      createdKey: j['createdKey'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

class AppState {
  AppState({
    this.player,
    List<Quest>? today,
    List<Quest>? history,
    List<XpEvent>? xpLog,
    this.readiness,
    this.loaded = false,
  })  : today = today ?? [],
        history = history ?? [],
        xpLog = xpLog ?? [];

  Player? player;

  /// Today's quests: the daily quest first, then any bonus quests.
  List<Quest> today;

  /// Past quests, newest first.
  List<Quest> history;

  /// Newest first.
  List<XpEvent> xpLog;
  Readiness? readiness;
  bool loaded;

  Quest? get dailyQuest {
    for (final q in today) {
      if (q.kind != QuestKind.bonus) return q;
    }
    return null;
  }

  Quest? findQuest(String id) {
    for (final q in today) {
      if (q.id == id) return q;
    }
    for (final q in history) {
      if (q.id == id) return q;
    }
    return null;
  }

  int get bonusQuestsToday =>
      today.where((q) => q.kind == QuestKind.bonus).length;

  /// A new wrapper around the same data, so listeners see a change.
  AppState touch() => AppState(
        player: player,
        today: today,
        history: history,
        xpLog: xpLog,
        readiness: readiness,
        loaded: loaded,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'player': player?.toJson(),
        'today': today.map((q) => q.toJson()).toList(),
        'history': history.map((q) => q.toJson()).toList(),
        'xpLog': xpLog.map((e) => e.toJson()).toList(),
        'readiness': readiness?.toJson(),
      };

  factory AppState.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (j[key] as List? ?? const [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    return AppState(
      player: j['player'] == null
          ? null
          : Player.fromJson(Map<String, dynamic>.from(j['player'] as Map)),
      today: list('today', Quest.fromJson),
      history: list('history', Quest.fromJson),
      xpLog: list('xpLog', XpEvent.fromJson),
      readiness: j['readiness'] == null
          ? null
          : Readiness.fromJson(Map<String, dynamic>.from(j['readiness'] as Map)),
      loaded: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// Whole days from [from] to [to]. Null-safe: a missing date is "long ago".
int dayGap(String? from, String to) {
  if (from == null || from.isEmpty) return 9999;
  return parseDateKey(to).difference(parseDateKey(from)).inDays;
}

String formatSeconds(int s) {
  if (s < 60) return '$s sec';
  final m = s ~/ 60;
  final r = s % 60;
  return r == 0 ? '$m min' : '$m min $r sec';
}
