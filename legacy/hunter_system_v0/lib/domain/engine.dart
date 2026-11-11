import '../core/game_rules.dart';
import 'exercise_catalog.dart';
import 'models.dart';
import 'quest_generator.dart';

/// Decides *how activity is rewarded*: XP, levels, ranks, streaks and
/// achievements. Pure Dart with no Flutter imports, so every rule here can be
/// unit-tested without a device.
class Engine {
  const Engine._();

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  static void startNewPlayer(AppState s, Player player, String today) {
    player.createdKey = today;
    s.player = player;
    s.today = [];
    s.history = [];
    s.xpLog = [];
    s.readiness = null;
    s.today.add(QuestGenerator.generate(player: player, date: today));
  }

  /// Call when the app opens or returns to the foreground. Archives
  /// yesterday's quests and prepares today's. Returns true if anything changed.
  static bool rollover(AppState s, String today) {
    final player = s.player;
    if (player == null) return false;
    var changed = false;

    if (s.readiness != null && s.readiness!.dateKey != today) {
      s.readiness = null;
      changed = true;
    }

    final stale = s.today.where((q) => q.dateKey != today).toList();
    if (stale.isNotEmpty) {
      for (final q in stale) {
        if (q.status == QuestStatus.pending) {
          // Work that was done still counts; untouched quests are just missed.
          finishQuest(s, q, at: '${q.dateKey}T23:59:00');
        }
      }
      s.today.removeWhere((q) => q.dateKey != today);
      s.history.insertAll(0, stale.reversed);
      if (s.history.length > 120) s.history.removeRange(120, s.history.length);
      changed = true;
    }

    final gap = dayGap(player.lastActiveKey, today);
    if (gap > GameRules.streakGraceGapDays && player.streak != 0) {
      player.streak = 0; // XP and level are never taken away.
      changed = true;
    }

    if (s.dailyQuest == null) {
      final returning = player.questsCompleted > 0 && gap >= 2;
      s.today.insert(
        0,
        QuestGenerator.generate(
          player: player,
          date: today,
          kind: returning ? QuestKind.comeback : QuestKind.daily,
          readiness: s.readiness,
          recent: s.history,
        ),
      );
      changed = true;
    }
    return changed;
  }

  /// True when the player missed exactly one day and can still save the streak.
  static bool streakAtRisk(AppState s, String today) {
    final p = s.player;
    if (p == null || p.streak == 0) return false;
    return dayGap(p.lastActiveKey, today) == GameRules.streakGraceGapDays;
  }

  // -------------------------------------------------------------------------
  // Readiness and quest changes
  // -------------------------------------------------------------------------

  static void submitReadiness(AppState s, Readiness r) {
    final player = s.player;
    if (player == null) return;
    s.readiness = r;

    // Reporting pain or illness protects the streak for the day.
    if (r.pain &&
        dayGap(player.lastActiveKey, r.dateKey) <= GameRules.streakGraceGapDays) {
      player.lastActiveKey = r.dateKey;
    }
    regenerateDaily(s, r.dateKey);
  }

  /// Rebuilds today's main quest. Does nothing once it has been started.
  static bool regenerateDaily(AppState s, String today, {int? minutes, QuestFocus? focus}) {
    final player = s.player;
    final current = s.dailyQuest;
    if (player == null) return false;
    if (current != null && (current.started || current.status != QuestStatus.pending)) {
      return false;
    }
    final quest = QuestGenerator.generate(
      player: player,
      date: today,
      kind: current?.kind ?? QuestKind.daily,
      readiness: s.readiness,
      recent: s.history,
      minutes: minutes,
      focus: focus,
      salt: s.today.length + (minutes ?? 0) + (focus?.index ?? 0) * 100,
    );
    if (current != null) s.today.remove(current);
    s.today.insert(0, quest);
    return true;
  }

  static bool canAddBonusQuest(AppState s) {
    final daily = s.dailyQuest;
    return s.player != null &&
        daily != null &&
        daily.status != QuestStatus.pending &&
        !(s.readiness?.pain ?? false) &&
        s.bonusQuestsToday < GameRules.maxBonusQuestsPerDay &&
        s.today.every((q) => q.status != QuestStatus.pending);
  }

  static Quest? addBonusQuest(AppState s, String today, {required int minutes, QuestFocus? focus}) {
    if (!canAddBonusQuest(s)) return null;
    final quest = QuestGenerator.generate(
      player: s.player!,
      date: today,
      kind: QuestKind.bonus,
      readiness: s.readiness,
      recent: s.history,
      minutes: minutes,
      focus: focus,
      salt: 50 + s.today.length,
    );
    s.today.add(quest);
    return quest;
  }

  // -------------------------------------------------------------------------
  // During a workout
  // -------------------------------------------------------------------------

  /// Records one finished set. [amount] is the reps or seconds actually done.
  /// Returns true when it beats the player's previous best for that exercise.
  static bool logSet(AppState s, Quest quest, int taskIndex, int amount) {
    final player = s.player;
    if (player == null || quest.status != QuestStatus.pending) return false;
    final task = quest.tasks[taskIndex];
    if (task.finished) return false;
    task.setsDone++;

    final exercise = ExerciseCatalog.byId(task.exerciseId);
    player.attributes[exercise.attribute] =
        (player.attributes[exercise.attribute] ?? 0) + 1;
    if (quest.isRecovery) {
      player.attributes[Attribute.recovery] =
          (player.attributes[Attribute.recovery] ?? 0) + 1;
    }

    final previous = player.records[exercise.id];
    if (previous == null || amount > previous) {
      player.records[exercise.id] = amount;
      // A first-ever entry sets the baseline; it is not a "new best".
      if (previous != null && exercise.category != ExerciseCategory.mobility) {
        if (!quest.personalBests.contains(exercise.id)) {
          quest.personalBests.add(exercise.id);
        }
        return true;
      }
    }
    return false;
  }

  static void skipTask(Quest quest, int taskIndex) {
    if (quest.status != QuestStatus.pending) return;
    quest.tasks[taskIndex].skipped = true;
  }

  /// Replaces an exercise. A valid swap never fails the quest: the task keeps
  /// its full XP value.
  static void swapTask(AppState s, Quest quest, int taskIndex, String newExerciseId) {
    final player = s.player;
    if (player == null || quest.status != QuestStatus.pending) return;
    final old = quest.tasks[taskIndex];
    if (old.setsDone > 0) return;
    final replacement = QuestGenerator.taskFor(
      player,
      ExerciseCatalog.byId(newExerciseId),
      sets: old.sets,
      easy: quest.isRecovery,
    );
    replacement.swappedFrom = old.swappedFrom ?? old.exerciseId;
    quest.tasks[taskIndex] = replacement;
    player.swapsUsed++;
  }

  // -------------------------------------------------------------------------
  // Completion and rewards
  // -------------------------------------------------------------------------

  /// Closes a quest and pays out. Safe to call twice: the second call returns
  /// null and awards nothing.
  static QuestResult? finishQuest(AppState s, Quest quest, {required String at}) {
    final player = s.player;
    if (player == null || quest.status != QuestStatus.pending) return null;

    if (quest.doneSets == 0) {
      quest.status = QuestStatus.missed;
      return null;
    }

    quest.status = QuestStatus.completed;
    final day = quest.dateKey;
    final oldRank = player.rank;
    final oldLevel = player.level;

    // Streak.
    if (player.streakCountedKey != day) {
      final gap = dayGap(player.lastActiveKey, day);
      player.streak = gap <= GameRules.streakGraceGapDays ? player.streak + 1 : 1;
      player.streakCountedKey = day;
      if (player.streak > player.bestStreak) player.bestStreak = player.streak;
    }
    player.lastActiveKey = day;

    // Counters.
    player.questsCompleted++;
    if (quest.isRecovery) player.recoveryQuests++;
    if (quest.kind == QuestKind.comeback) player.comebacks++;
    player.activeMinutes += (quest.minutes * quest.progress).round();

    // XP is proportional to the work actually done.
    final base = (quest.xpReward * quest.progress).round();
    final bonus =
        (base * (GameRules.streakMultiplier(player.streak) - 1)).round();
    quest.xpEarned = base + bonus;
    _addXp(s, quest.xpEarned, quest.title, at);

    final unlocked = _evaluateAchievements(s, at);

    return QuestResult(
      quest: quest,
      baseXp: base,
      streakBonusXp: bonus,
      levelBefore: oldLevel,
      levelAfter: player.level,
      rankBefore: oldRank,
      rankAfter: player.rank,
      streak: player.streak,
      achievements: unlocked,
    );
  }

  static void _addXp(AppState s, int amount, String label, String at) {
    final p = s.player!;
    if (amount <= 0) return;
    p.xp += amount;
    p.totalXp += amount;
    while (p.xp >= p.xpToNext) {
      p.xp -= p.xpToNext; // excess carries forward
      p.level++;
    }
    s.xpLog.insert(0, XpEvent(at, amount, label));
    if (s.xpLog.length > 100) s.xpLog.removeRange(100, s.xpLog.length);
  }

  static List<Achievement> _evaluateAchievements(AppState s, String at) {
    final p = s.player!;
    final unlocked = <Achievement>[];
    var again = true;
    while (again) {
      again = false;
      for (final a in achievements) {
        if (!p.achievements.containsKey(a.id) && a.earned(s)) {
          p.achievements[a.id] = at.substring(0, 10);
          unlocked.add(a);
          _addXp(s, a.xp, 'Achievement: ${a.title}', at);
          again = true; // XP may have unlocked a level-based achievement
        }
      }
    }
    return unlocked;
  }

  // -------------------------------------------------------------------------
  // Read-only summaries
  // -------------------------------------------------------------------------

  static WeekStats weekStats(AppState s, String today) {
    var quests = 0;
    var minutes = 0;
    var xp = 0;
    for (final q in [...s.today, ...s.history]) {
      if (q.status != QuestStatus.completed) continue;
      final gap = dayGap(q.dateKey, today);
      if (gap >= 0 && gap < 7) {
        quests++;
        minutes += (q.minutes * q.progress).round();
        xp += q.xpEarned;
      }
    }
    return WeekStats(quests, minutes, xp);
  }

  static bool _anyPersonalBest(AppState s) =>
      s.today.any((q) => q.personalBests.isNotEmpty) ||
      s.history.any((q) => q.personalBests.isNotEmpty);

  static final List<Achievement> achievements = [
    Achievement('first_quest', 'First awakening', 'Complete your first quest.', 50,
        (s) => s.player!.questsCompleted >= 1),
    Achievement('quests_10', 'Ember of habit', 'Complete 10 quests.', 100,
        (s) => s.player!.questsCompleted >= 10),
    Achievement('quests_30', 'Tempered', 'Complete 30 quests.', 200,
        (s) => s.player!.questsCompleted >= 30),
    Achievement('streak_3', 'Three in a row', 'Stay active 3 days running.', 30,
        (s) => s.player!.bestStreak >= 3),
    Achievement('streak_7', 'Unbroken week', 'Stay active 7 days running.', 100,
        (s) => s.player!.bestStreak >= 7),
    Achievement('streak_30', 'Iron routine', 'Stay active 30 days running.', 300,
        (s) => s.player!.bestStreak >= 30),
    Achievement('level_5', 'Rising hunter', 'Reach level 5.', 0,
        (s) => s.player!.level >= 5),
    Achievement('rank_c', 'C-rank awakening', 'Reach rank C.', 0,
        (s) => s.player!.level >= GameRules.ranks[2].minLevel),
    Achievement('rank_b', 'B-rank awakening', 'Reach rank B.', 0,
        (s) => s.player!.level >= GameRules.ranks[3].minLevel),
    Achievement('recovery_5', 'Knows when to rest', 'Complete 5 recovery quests.', 75,
        (s) => s.player!.recoveryQuests >= 5),
    Achievement('comeback', 'Comeback hunter', 'Return after a break and finish a quest.', 75,
        (s) => s.player!.comebacks >= 1),
    Achievement('adaptable', 'Adaptable', 'Swap an exercise for one that suits you.', 20,
        (s) => s.player!.swapsUsed >= 1),
    Achievement('personal_best', 'Stronger than yesterday', 'Beat one of your own bests.', 50,
        _anyPersonalBest),
    Achievement('minutes_300', 'Five hours in', 'Log 300 active minutes.', 100,
        (s) => s.player!.activeMinutes >= 300),
    Achievement('strength_100', 'Forged', 'Earn 100 Strength points.', 100,
        (s) => (s.player!.attributes[Attribute.strength] ?? 0) >= 100),
    Achievement('endurance_100', 'Second wind', 'Earn 100 Endurance points.', 100,
        (s) => (s.player!.attributes[Attribute.endurance] ?? 0) >= 100),
  ];
}

class Achievement {
  const Achievement(this.id, this.title, this.description, this.xp, this.earned);
  final String id;
  final String title;
  final String description;
  final int xp;
  final bool Function(AppState) earned;
}

class QuestResult {
  const QuestResult({
    required this.quest,
    required this.baseXp,
    required this.streakBonusXp,
    required this.levelBefore,
    required this.levelAfter,
    required this.rankBefore,
    required this.rankAfter,
    required this.streak,
    required this.achievements,
  });

  final Quest quest;
  final int baseXp;
  final int streakBonusXp;
  final int levelBefore;
  final int levelAfter;
  final RankRule rankBefore;
  final RankRule rankAfter;
  final int streak;
  final List<Achievement> achievements;

  bool get leveledUp => levelAfter > levelBefore;
  bool get rankedUp => rankAfter.letter != rankBefore.letter;
  int get achievementXp => achievements.fold(0, (a, b) => a + b.xp);
}

class WeekStats {
  const WeekStats(this.quests, this.minutes, this.xp);
  final int quests;
  final int minutes;
  final int xp;
}
