/// Every number that balances the game lives here, in one place.
///
/// Nothing in the UI hardcodes XP, thresholds or bonuses. When a backend is
/// added, this class is the single thing to replace with a remote config.
class GameRules {
  const GameRules._();

  // --- Levels -------------------------------------------------------------
  static const int baseXpPerLevel = 100;
  static const int xpGrowthPerLevel = 40;

  /// XP needed to go from [level] to [level] + 1.
  static int xpToNextLevel(int level) =>
      baseXpPerLevel + xpGrowthPerLevel * (level - 1);

  // --- Ranks --------------------------------------------------------------
  /// Minimum level for each rank, lowest first.
  static const List<RankRule> ranks = [
    RankRule('E', 'Beginner', 1),
    RankRule('D', 'Novice', 5),
    RankRule('C', 'Intermediate', 12),
    RankRule('B', 'Advanced', 22),
    RankRule('A', 'Elite', 35),
    RankRule('S', 'Master', 50),
  ];

  static RankRule rankForLevel(int level) {
    var current = ranks.first;
    for (final r in ranks) {
      if (level >= r.minLevel) current = r;
    }
    return current;
  }

  static RankRule? nextRank(int level) {
    for (final r in ranks) {
      if (r.minLevel > level) return r;
    }
    return null;
  }

  // --- Quest rewards ------------------------------------------------------
  static const double xpPerTrainingMinute = 4;
  static const double xpPerRecoveryMinute = 3;
  static const double comebackBonus = 0.20;
  static const double bonusQuestMultiplier = 0.5;
  static const int maxBonusQuestsPerDay = 2;

  /// Streak bonus: +2% per day, capped at +20%.
  static double streakMultiplier(int streak) {
    final pct = (streak * 0.02).clamp(0.0, 0.20);
    return 1 + pct;
  }

  // --- Streaks ------------------------------------------------------------
  /// Missing one day puts the streak "at risk": it survives if the comeback
  /// quest is completed the next day. Missing more resets it. XP is never
  /// taken away.
  static const int streakGraceGapDays = 2;

  // --- Training load ------------------------------------------------------
  /// After this many training days in a row the System schedules recovery.
  static const int maxConsecutiveTrainingDays = 3;

  static const List<int> questDurations = [10, 15, 30, 45];
}

class RankRule {
  const RankRule(this.letter, this.title, this.minLevel);
  final String letter;
  final String title;
  final int minLevel;
}
