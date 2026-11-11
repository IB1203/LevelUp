/// Data entities of the Hunter System (spec §20). All JSON-serialisable and
/// stored under `fit.hunterData`, so they persist, back up and restore with
/// the rest of the training log.
library;

enum Attr { strength, endurance, mobility, consistency, recovery }

extension AttrInfo on Attr {
  String get label => switch (this) {
    Attr.strength => 'Strength',
    Attr.endurance => 'Endurance',
    Attr.mobility => 'Mobility',
    Attr.consistency => 'Consistency',
    Attr.recovery => 'Recovery Mastery',
  };

  String get short => switch (this) {
    Attr.strength => 'STR',
    Attr.endurance => 'END',
    Attr.mobility => 'MOB',
    Attr.consistency => 'CON',
    Attr.recovery => 'REC',
  };

  String get blurb => switch (this) {
    Attr.strength => 'Resistance training: push-ups, squats, presses, pulls, deadlifts, dumbbells.',
    Attr.endurance => 'Cardio and sustained activity: walking, running, cycling, swimming, rowing, jump rope.',
    Attr.mobility => 'Stretching, yoga-style work, hip and shoulder mobility, flexibility routines.',
    Attr.consistency => 'Showing up as planned: planned workouts, weekly goals, comebacks.',
    Attr.recovery => 'Recovery habits: recovery sessions, cooldowns, sleep, planned rest days, check-ins.',
  };
}

Attr? attrByName(String? n) {
  for (final a in Attr.values) {
    if (a.name == n) return a;
  }
  return null;
}

/// PlayerProgression + profile fields chosen at registration.
class HunterPlayer {
  HunterPlayer({
    required this.id,
    required this.name,
    required this.created,
    this.experience = 0,
    this.classId = 'hypertrophy',
    this.minutes = 30,
    this.weeklyTarget = 3,
    this.limitations = const [],
  });

  final String id;
  String name;
  final DateTime created;

  /// 0 = brand new, 1 = < 6 months, 2 = 6–24 months, 3 = 2–5 years, 4 = 5+ years.
  int experience;
  String classId;
  int minutes;
  int weeklyTarget;

  /// Muscle ids the player asked the System to avoid loading.
  List<String> limitations;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created': created.toIso8601String(),
    'exp': experience,
    'class': classId,
    'min': minutes,
    'week': weeklyTarget,
    'lim': limitations,
  };

  static HunterPlayer? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final created = DateTime.tryParse('${raw['created']}');
    if (created == null) return null;
    return HunterPlayer(
      id: '${raw['id']}',
      name: '${raw['name'] ?? 'Hunter'}',
      created: created,
      experience: ((raw['exp'] as num?) ?? 0).toInt().clamp(0, 4),
      classId: '${raw['class'] ?? 'hypertrophy'}',
      minutes: ((raw['min'] as num?) ?? 30).toInt(),
      weeklyTarget: ((raw['week'] as num?) ?? 3).toInt(),
      limitations: [for (final l in (raw['lim'] as List?) ?? const []) '$l'],
    );
  }
}

/// One auditable XP grant. [id] doubles as the idempotency reference: the
/// same activity always produces the same id, so it can never pay twice.
class XpTransaction {
  XpTransaction({
    required this.id,
    required this.xp,
    required this.category,
    required this.reason,
    required this.at,
    this.activityId,
    this.questId,
    this.attrs = const {},
  });

  final String id;
  final int xp;
  final String category;
  final String reason;
  final DateTime at;
  final String? activityId;
  final String? questId;
  final Map<Attr, int> attrs;

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'c': category,
    'r': reason,
    'at': at.toIso8601String(),
    if (activityId != null) 'act': activityId,
    if (questId != null) 'q': questId,
    if (attrs.isNotEmpty) 'a': {for (final e in attrs.entries) e.key.name: e.value},
  };

  static XpTransaction? fromJson(String id, Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    return XpTransaction(
      id: id,
      xp: ((raw['xp'] as num?) ?? 0).toInt(),
      category: '${raw['c'] ?? ''}',
      reason: '${raw['r'] ?? ''}',
      at: at,
      activityId: raw['act'] as String?,
      questId: raw['q'] as String?,
      attrs: {
        for (final e in ((raw['a'] as Map?) ?? const {}).entries) ?attrByName('${e.key}'): (e.value as num).toInt(),
      },
    );
  }
}

enum QuestCategory { main, side, strength, endurance, mobility, recovery, discipline, bonus, trial, boss }

extension QuestCategoryInfo on QuestCategory {
  String get label => switch (this) {
    QuestCategory.main => 'Main Quest',
    QuestCategory.side => 'Side Quest',
    QuestCategory.strength => 'Strength Quest',
    QuestCategory.endurance => 'Endurance Quest',
    QuestCategory.mobility => 'Mobility Quest',
    QuestCategory.recovery => 'Recovery Quest',
    QuestCategory.discipline => 'Discipline Quest',
    QuestCategory.bonus => 'Bonus Quest',
    QuestCategory.trial => 'Promotion Trial',
    QuestCategory.boss => 'Boss Quest',
  };

  /// Workout quests are completed by logging a session started from them;
  /// the others are validated from logged data.
  bool get isWorkout => this != QuestCategory.discipline && this != QuestCategory.bonus;
}

QuestCategory questCategoryByName(String? n) =>
    QuestCategory.values.firstWhere((c) => c.name == n, orElse: () => QuestCategory.side);

/// One exercise inside a quest: sets of reps, or sets of seconds.
class QuestObjective {
  QuestObjective(this.exerciseId, this.name, this.sets, {this.reps, this.seconds});
  String exerciseId;
  String name;
  int sets;
  final int? reps;
  final int? seconds;

  String get text {
    if (seconds != null) {
      final s = seconds!;
      final amount = s >= 120 ? '${s ~/ 60} min' : '$s s';
      return sets == 1 ? '$name: $amount' : '$name: $sets × $amount';
    }
    return '$name: $sets × ${reps ?? 10}';
  }

  Map<String, dynamic> toJson() => {
    'ex': exerciseId,
    'n': name,
    's': sets,
    if (reps != null) 'r': reps,
    if (seconds != null) 't': seconds,
  };

  static QuestObjective fromJson(Map raw) => QuestObjective(
    '${raw['ex']}',
    '${raw['n']}',
    ((raw['s'] as num?) ?? 1).toInt(),
    reps: (raw['r'] as num?)?.toInt(),
    seconds: (raw['t'] as num?)?.toInt(),
  );
}

enum QuestStatus { offered, accepted, active, completed, partial, skipped, expired }

class Quest {
  Quest({
    required this.id,
    required this.day,
    required this.category,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.objectives,
    required this.xp,
    required this.attrXp,
    required this.minutes,
    this.status = QuestStatus.offered,
    this.shortened = false,
    this.rescheduled = false,
    this.check,
    this.target = 0,
    this.unit = '',
    this.completion = 0,
  });

  final String id;

  /// yyyy-mm-dd the quest belongs to (changes on reschedule; id does not).
  String day;
  final QuestCategory category;
  final String name;
  final String description;

  /// E–S difficulty label, chosen from experience and readiness, not level.
  final String difficulty;
  final List<QuestObjective> objectives;
  final int xp;
  final Map<Attr, int> attrXp;
  int minutes;
  QuestStatus status;
  bool shortened;
  bool rescheduled;

  /// Data-validated quests: what to check ('water', 'sleep', 'food', ...).
  final String? check;
  final num target;
  final String unit;

  /// 0–1 share of planned sets done in the linked session.
  double completion;

  bool get isWorkout => category.isWorkout;
  bool get done => status == QuestStatus.completed || status == QuestStatus.partial;
  int get plannedSets => objectives.fold(0, (n, o) => n + o.sets);

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'cat': category.name,
    'n': name,
    'd': description,
    'diff': difficulty,
    'obj': [for (final o in objectives) o.toJson()],
    'xp': xp,
    'ax': {for (final e in attrXp.entries) e.key.name: e.value},
    'min': minutes,
    'st': status.name,
    if (shortened) 'short': true,
    if (rescheduled) 'resch': true,
    if (check != null) 'chk': check,
    if (target != 0) 'tg': target,
    if (unit.isNotEmpty) 'u': unit,
    if (completion > 0) 'cmp': completion,
  };

  static Quest? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    return Quest(
      id: '${raw['id']}',
      day: '${raw['day']}',
      category: questCategoryByName(raw['cat'] as String?),
      name: '${raw['n']}',
      description: '${raw['d'] ?? ''}',
      difficulty: '${raw['diff'] ?? 'E'}',
      objectives: [
        for (final o in (raw['obj'] as List?) ?? const [])
          if (o is Map) QuestObjective.fromJson(o),
      ],
      xp: ((raw['xp'] as num?) ?? 0).toInt(),
      attrXp: {
        for (final e in ((raw['ax'] as Map?) ?? const {}).entries) ?attrByName('${e.key}'): (e.value as num).toInt(),
      },
      minutes: ((raw['min'] as num?) ?? 10).toInt(),
      status: QuestStatus.values.firstWhere((s) => s.name == raw['st'], orElse: () => QuestStatus.offered),
      shortened: raw['short'] == true,
      rescheduled: raw['resch'] == true,
      check: raw['chk'] as String?,
      target: (raw['tg'] as num?) ?? 0,
      unit: '${raw['u'] ?? ''}',
      completion: ((raw['cmp'] as num?) ?? 0).toDouble(),
    );
  }
}

class RankChange {
  const RankChange(this.from, this.to, this.at);
  final String from;
  final String to;
  final DateTime at;

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'at': at.toIso8601String()};

  static RankChange? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    return at == null ? null : RankChange('${raw['from']}', '${raw['to']}', at);
  }
}

enum RecordType { maxWeight, maxReps, repsAtWeight, longestHold, longestDistance }

extension RecordTypeInfo on RecordType {
  String get label => switch (this) {
    RecordType.maxWeight => 'Heaviest weight',
    RecordType.maxReps => 'Most reps in a set',
    RecordType.repsAtWeight => 'Best reps at weight',
    RecordType.longestHold => 'Longest hold',
    RecordType.longestDistance => 'Longest distance',
  };
}

/// One exercise-specific record with the value it replaced.
class HunterRecord {
  const HunterRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.type,
    required this.value,
    required this.unit,
    required this.at,
    this.previous,
    this.atWeight,
  });
  final String exerciseId;
  final String exerciseName;
  final RecordType type;
  final double value;
  final String unit;
  final DateTime at;
  final double? previous;

  /// For [RecordType.repsAtWeight]: the weight the reps were done at, so
  /// only comparable sets are compared.
  final double? atWeight;

  String get key => '$exerciseId|${type.name}|${atWeight ?? ''}';
}

class HunterNote {
  HunterNote(this.id, this.kind, this.title, this.body, this.at, {this.read = false});
  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime at;
  bool read;

  Map<String, dynamic> toJson() => {
    'id': id,
    'k': kind,
    't': title,
    'b': body,
    'at': at.toIso8601String(),
    if (read) 'r': true,
  };

  static HunterNote? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    return HunterNote('${raw['id']}', '${raw['k']}', '${raw['t']}', '${raw['b']}', at, read: raw['r'] == true);
  }
}
