/// Every number that balances the Hunter System lives here.
///
/// Pure Dart, no Flutter imports. Nothing in the screens hardcodes XP,
/// thresholds or rewards: change them here. Rules that always hold:
///   * real, logged activity is the only source of XP;
///   * XP, levels and rank are never taken away;
///   * the player's level never makes workouts harder by itself.
library;

class HunterRules {
  const HunterRules._();

  // --- Player levels --------------------------------------------------------
  static const int levelBaseXp = 100;
  static const int levelStepXp = 25;

  /// XP needed to go from [level] to [level] + 1: 100 + 25 × (level − 1).
  static int xpToNext(int level) => levelBaseXp + levelStepXp * (level - 1);

  /// Converts lifetime XP into (level, xp into this level, xp needed).
  /// Excess XP carries forward; several level-ups at once work.
  static ({int level, int into, int need}) levelFor(int totalXp) {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToNext(level)) {
      left -= xpToNext(level);
      level++;
    }
    return (level: level, into: left, need: xpToNext(level));
  }

  /// Lifetime XP at which [level] starts.
  static int xpAtLevel(int level) {
    var xp = 0;
    for (var l = 1; l < level; l++) {
      xp += xpToNext(l);
    }
    return xp;
  }

  // --- Attributes -----------------------------------------------------------
  static const int attrBaseXp = 75;
  static const int attrStepXp = 15;

  /// Attribute XP for the next attribute level: 75 + 15 × (level − 1).
  static int attrXpToNext(int level) => attrBaseXp + attrStepXp * (level - 1);

  static ({int level, int into, int need}) attrLevelFor(int xp) {
    var level = 1;
    var left = xp < 0 ? 0 : xp;
    while (left >= attrXpToNext(level)) {
      left -= attrXpToNext(level);
      level++;
    }
    return (level: level, into: left, need: attrXpToNext(level));
  }

  // --- Workout XP -----------------------------------------------------------
  /// (minimum minutes, XP). A workout earns the highest tier it reaches.
  /// Over 60 minutes earns nothing extra: long is not better.
  static const List<(int, int)> workoutTiers = [(5, 20), (10, 35), (20, 50), (30, 70), (45, 85)];

  static int workoutXp(int minutes) {
    var xp = 0;
    for (final (min, reward) in workoutTiers) {
      if (minutes >= min) xp = reward;
    }
    return xp;
  }

  /// Recovery session: 25 at 5 minutes up to 35 at 20+.
  static int recoveryXp(int minutes) => minutes < 5 ? 0 : (25 + ((minutes - 5) * 10 ~/ 15)).clamp(25, 35);

  /// Mobility session: 20 at 5 minutes up to 30 at 20+.
  static int mobilityXp(int minutes) => minutes < 5 ? 0 : (20 + ((minutes - 5) * 10 ~/ 15)).clamp(20, 30);

  /// Logged sets with no timer still count: estimated minutes per set.
  static const double minutesPerSet = 2.5;

  /// Max XP from workouts on one calendar day. Stops over-training farming.
  static const int dailyWorkoutXpCap = 150;

  /// Max attribute XP per attribute per day.
  static const int dailyAttrXpCap = 60;

  static const int prXp = 10;
  static const int maxPrsPerSession = 3;

  // --- Quests -----------------------------------------------------------------
  static const int dailyQuestBonus = 15;

  /// Below this share of a quest's planned sets, no quest reward.
  static const double questMinCompletion = 0.34;

  /// At or above this share, a quest counts as fully complete.
  static const double questFullCompletion = 0.8;
  static const double trialPassCompletion = 0.8;
  static const double bossWinCompletion = 0.9;

  // --- Habits ---------------------------------------------------------------
  static const int sleepTargetHours = 7;
  static const int sleepXp = 5;
  static const int restDayXp = 10;
  static const int checkInXp = 2;
  static const double proteinTolerance = 0.9;

  // --- Comeback & mana --------------------------------------------------------
  static const int comebackDays = 7;
  static const int comebackPlanDays = 14;
  static const int manaDepletionDays = 4;

  // --- Load management -----------------------------------------------------------
  static const double loadSpikeRatio = 1.5;
  static const int loadSpikeSlack = 5;

  // --- Shadow army -----------------------------------------------------------------
  static const int shadowWindowDays = 30;
  static const double shadowBelowMedian = 0.4;
  static const double soldierAtMedian = 0.7;
  static const int shadowMinTotalSets = 20;
}

String roman(int n) => const ['—', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'][n.clamp(0, 10)];
