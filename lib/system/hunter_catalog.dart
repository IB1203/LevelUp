/// Static content for the Hunter System: ranks, classes, achievements,
/// titles, skill trees, bosses, trials, gates and quest pools. Every
/// threshold here is configurable. All names and copy are original.
library;

import 'hunter_models.dart';

// --- Ranks (spec §4) -----------------------------------------------------------

class RankDef {
  const RankDef({
    required this.letter,
    required this.title,
    required this.minLevel,
    required this.maxLevel,
    this.promoLevel = 0,
    this.promoQuests = 0,
    this.promoWeekly = 0,
    this.promoWorkouts = 0,
    this.promoCategories = 0,
  });
  final String letter;
  final String title;
  final int minLevel;
  final int maxLevel;

  /// Requirements to be promoted OUT of this rank into the next one.
  final int promoLevel;
  final int promoQuests;
  final int promoWeekly;
  final int promoWorkouts;

  /// Distinct fitness categories (strength / endurance / mobility) with
  /// at least [kCategoryProofSessions] sessions each.
  final int promoCategories;
}

const int kCategoryProofSessions = 3;

const List<RankDef> kRanks = [
  RankDef(letter: 'E', title: 'Awakened', minLevel: 1, maxLevel: 10, promoLevel: 10, promoQuests: 15, promoWeekly: 3),
  RankDef(
    letter: 'D',
    title: 'Hunter',
    minLevel: 11,
    maxLevel: 20,
    promoLevel: 20,
    promoWorkouts: 30,
    promoCategories: 2,
  ),
  RankDef(letter: 'C', title: 'Veteran', minLevel: 21, maxLevel: 35, promoLevel: 35, promoWorkouts: 50, promoWeekly: 6),
  RankDef(
    letter: 'B',
    title: 'Elite',
    minLevel: 36,
    maxLevel: 50,
    promoLevel: 50,
    promoWorkouts: 80,
    promoCategories: 3,
  ),
  RankDef(
    letter: 'A',
    title: 'Champion',
    minLevel: 51,
    maxLevel: 75,
    promoLevel: 75,
    promoWorkouts: 120,
    promoWeekly: 15,
  ),
  RankDef(letter: 'S', title: 'Sovereign', minLevel: 76, maxLevel: 100),
];

RankDef rankByLetter(String letter) => kRanks.firstWhere((r) => r.letter == letter, orElse: () => kRanks.first);

RankDef? nextRankOf(String letter) {
  final i = kRanks.indexWhere((r) => r.letter == letter);
  return i < 0 || i + 1 >= kRanks.length ? null : kRanks[i + 1];
}

int rankIndex(String letter) => kRanks.indexWhere((r) => r.letter == letter);

const int kRankPromotionXp = 150;

// --- Registration choices ---------------------------------------------------------

const List<(String, String)> kExperienceLevels = [
  ('Brand new', 'Never trained regularly'),
  ('Beginner', 'Less than 6 months'),
  ('Intermediate', '6 months to 2 years'),
  ('Advanced', '2 to 5 years'),
  ('Expert', 'More than 5 years'),
];

/// Quest difficulty for an experience level (spec §8). Level never changes it.
const List<String> kExperienceDifficulty = ['E', 'D', 'C', 'B', 'A'];

const List<int> kSessionMinutes = [10, 20, 30, 45, 60];

/// Limitations offered at registration → muscles the System avoids loading.
const Map<String, List<String>> kLimitations = {
  'Shoulders': ['shoulders'],
  'Wrists / elbows': ['forearm'],
  'Lower back': ['lowerback'],
  'Knees': ['quads'],
  'Hips': ['glutes'],
  'Neck': ['trapezius'],
};

class HunterClass {
  const HunterClass(this.id, this.name, this.focus, this.story, this.attr);
  final String id;
  final String name;
  final String focus;
  final String story;

  /// The attribute this class leans towards when quests rotate.
  final Attr attr;
}

const List<HunterClass> kHunterClasses = [
  HunterClass(
    'hypertrophy',
    'Berserker',
    'Build muscle',
    'You grow by volume. Every set is a wave against the gate.',
    Attr.strength,
  ),
  HunterClass(
    'strength',
    'Juggernaut',
    'Get stronger',
    'You grow by force. Heavy, controlled, measured in good reps.',
    Attr.strength,
  ),
  HunterClass('endurance', 'Ranger', 'Endurance', 'You grow by distance. Your heart is the engine.', Attr.endurance),
  HunterClass(
    'fatloss',
    'Shadowblade',
    'Lose fat',
    'You grow by discipline. Steady training and patience, never crash diets.',
    Attr.consistency,
  ),
  HunterClass(
    'mobility',
    'Monk',
    'Mobility',
    'You grow by control. Range and recovery first; strength follows.',
    Attr.mobility,
  ),
];

HunterClass hunterClassById(String? id) =>
    kHunterClasses.firstWhere((c) => c.id == id, orElse: () => kHunterClasses.first);

// --- Achievements (spec §10) ------------------------------------------------------

enum Rarity { common, uncommon, rare, epic, legendary }

extension RarityInfo on Rarity {
  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Measured stats achievements are checked against.
enum Stat {
  registered,
  questsDone,
  workouts,
  level,
  weeklyDone,
  maxPushUpSet,
  maxSquatRepsSession,
  maxPullUpSet,
  maxWalkKm,
  maxRunKm,
  cardioSessions,
  strengthSessions,
  plannedWorkouts,
  recoveryQuests,
  recoverySessions,
  recoveryHabits,
  comebacks,
  bossesWon,
  prs,
}

class AchievementDef {
  const AchievementDef(
    this.id,
    this.name,
    this.description,
    this.category,
    this.stat,
    this.threshold,
    this.xp,
    this.rarity,
    this.icon,
  );
  final String id;
  final String name;
  final String description;
  final String category;
  final Stat stat;
  final num threshold;
  final int xp;
  final Rarity rarity;

  /// Badge glyph name (see the UI's icon map).
  final String icon;
}

// Badge glyph names, mapped to icons by the UI (keeps this file pure Dart).
const _star = 'star', _bolt = 'bolt', _fitness = 'fitness', _run = 'run', _walk = 'walk', _spa = 'spa';
const _calendar = 'calendar', _trophy = 'trophy', _shield = 'shield', _replay = 'replay', _up = 'up', _flag = 'flag';

const List<AchievementDef> kAchievements = [
  // Beginner
  AchievementDef(
    'first_awakening',
    'First Awakening',
    'Register as a hunter.',
    'Beginner',
    Stat.registered,
    1,
    0,
    Rarity.common,
    _star,
  ),
  AchievementDef(
    'first_quest',
    'First Quest',
    'Complete your first quest.',
    'Beginner',
    Stat.questsDone,
    1,
    25,
    Rarity.common,
    _flag,
  ),
  AchievementDef(
    'first_workout',
    'First Workout',
    'Log your first workout.',
    'Beginner',
    Stat.workouts,
    1,
    25,
    Rarity.common,
    _fitness,
  ),
  AchievementDef(
    'first_level_up',
    'First Level Up',
    'Reach level 2.',
    'Beginner',
    Stat.level,
    2,
    25,
    Rarity.common,
    _up,
  ),
  AchievementDef(
    'first_weekly',
    'First Weekly Mission',
    'Complete a weekly mission.',
    'Beginner',
    Stat.weeklyDone,
    1,
    50,
    Rarity.uncommon,
    _calendar,
  ),
  // Strength
  AchievementDef(
    'pushups_10',
    'First 10 Push-ups',
    '10 push-ups in one set.',
    'Strength',
    Stat.maxPushUpSet,
    10,
    25,
    Rarity.common,
    _fitness,
  ),
  AchievementDef(
    'pushups_20',
    'First 20 Push-ups',
    '20 push-ups in one set.',
    'Strength',
    Stat.maxPushUpSet,
    20,
    50,
    Rarity.uncommon,
    _fitness,
  ),
  AchievementDef(
    'squats_50',
    'First 50 Squats',
    '50 squat reps in one session.',
    'Strength',
    Stat.maxSquatRepsSession,
    50,
    50,
    Rarity.uncommon,
    _fitness,
  ),
  AchievementDef(
    'first_pullup',
    'First Pull-up',
    'One strict, unassisted pull-up.',
    'Strength',
    Stat.maxPullUpSet,
    1,
    100,
    Rarity.rare,
    _bolt,
  ),
  AchievementDef(
    'strength_milestone',
    'Strength Milestone',
    'Complete 25 strength sessions.',
    'Strength',
    Stat.strengthSessions,
    25,
    150,
    Rarity.epic,
    _bolt,
  ),
  // Endurance
  AchievementDef(
    'walk_1k',
    'First 1 KM Walk',
    'Walk 1 km in one go.',
    'Endurance',
    Stat.maxWalkKm,
    1,
    25,
    Rarity.common,
    _walk,
  ),
  AchievementDef(
    'walk_3k',
    'First 3 KM Walk',
    'Walk 3 km in one go.',
    'Endurance',
    Stat.maxWalkKm,
    3,
    40,
    Rarity.uncommon,
    _walk,
  ),
  AchievementDef(
    'walk_5k',
    'First 5 KM Walk',
    'Walk 5 km in one go.',
    'Endurance',
    Stat.maxWalkKm,
    5,
    75,
    Rarity.rare,
    _walk,
  ),
  AchievementDef(
    'run_5k',
    'First 5 KM Run',
    'Run 5 km in one go.',
    'Endurance',
    Stat.maxRunKm,
    5,
    150,
    Rarity.epic,
    _run,
  ),
  AchievementDef(
    'endurance_milestone',
    'Endurance Milestone',
    'Complete 20 cardio sessions.',
    'Endurance',
    Stat.cardioSessions,
    20,
    100,
    Rarity.rare,
    _run,
  ),
  // Consistency
  AchievementDef(
    'workouts_3',
    '3 Workouts Completed',
    'Log 3 workouts.',
    'Consistency',
    Stat.workouts,
    3,
    25,
    Rarity.common,
    _calendar,
  ),
  AchievementDef(
    'planned_7',
    '7 Planned Sessions',
    'Complete 7 planned sessions (routines or quests).',
    'Consistency',
    Stat.plannedWorkouts,
    7,
    50,
    Rarity.uncommon,
    _calendar,
  ),
  AchievementDef(
    'workouts_30',
    '30 Workout Sessions',
    'Log 30 workouts.',
    'Consistency',
    Stat.workouts,
    30,
    100,
    Rarity.rare,
    _calendar,
  ),
  AchievementDef(
    'workouts_100',
    '100 Workout Sessions',
    'Log 100 workouts.',
    'Consistency',
    Stat.workouts,
    100,
    150,
    Rarity.legendary,
    _trophy,
  ),
  AchievementDef(
    'weekly_mastery',
    'Weekly Mastery',
    'Complete 8 weekly missions.',
    'Consistency',
    Stat.weeklyDone,
    8,
    150,
    Rarity.epic,
    _trophy,
  ),
  // Recovery
  AchievementDef(
    'first_recovery',
    'First Recovery Quest',
    'Complete a recovery quest.',
    'Recovery',
    Stat.recoveryQuests,
    1,
    25,
    Rarity.common,
    _spa,
  ),
  AchievementDef(
    'recovery_10',
    '10 Recovery Sessions',
    'Complete 10 recovery or mobility sessions.',
    'Recovery',
    Stat.recoverySessions,
    10,
    60,
    Rarity.uncommon,
    _spa,
  ),
  AchievementDef(
    'recovery_consistency',
    'Recovery Consistency',
    'Log 20 recovery habits (sleep 7h+, rest days).',
    'Recovery',
    Stat.recoveryHabits,
    20,
    100,
    Rarity.rare,
    _spa,
  ),
  // Special
  AchievementDef(
    'comeback',
    'Return of the Hunter',
    'Come back after 7+ days away.',
    'Special',
    Stat.comebacks,
    1,
    75,
    Rarity.rare,
    _replay,
  ),
  AchievementDef(
    'boss_slayer',
    'Boss Slayer',
    'Defeat a boss quest.',
    'Special',
    Stat.bossesWon,
    1,
    100,
    Rarity.rare,
    _shield,
  ),
  AchievementDef(
    'record_breaker',
    'Record Breaker',
    'Set 10 personal records.',
    'Special',
    Stat.prs,
    10,
    75,
    Rarity.uncommon,
    _trophy,
  ),
];

// --- Titles (spec §13) ------------------------------------------------------------

enum TitleRule { registered, rank, workouts, attrLevel, gateOrBoss }

class TitleDef {
  const TitleDef(this.id, this.name, this.requirement, this.rule, {this.rank, this.attr, this.n = 0});
  final String id;
  final String name;
  final String requirement;
  final TitleRule rule;
  final String? rank;
  final Attr? attr;
  final int n;
}

const List<TitleDef> kTitles = [
  TitleDef('awakened', 'The Awakened', 'Register as a hunter', TitleRule.registered),
  TitleDef('e_beginner', 'E-Rank Beginner', 'Hold E-Rank', TitleRule.rank, rank: 'E'),
  TitleDef('novice', 'Training Novice', 'Log 10 workouts', TitleRule.workouts, n: 10),
  TitleDef('strength_seeker', 'Strength Seeker', 'Strength level 5', TitleRule.attrLevel, attr: Attr.strength, n: 5),
  TitleDef(
    'endurance_explorer',
    'Endurance Explorer',
    'Endurance level 5',
    TitleRule.attrLevel,
    attr: Attr.endurance,
    n: 5,
  ),
  TitleDef(
    'discipline_master',
    'Discipline Master',
    'Consistency level 10',
    TitleRule.attrLevel,
    attr: Attr.consistency,
    n: 10,
  ),
  TitleDef(
    'recovery_specialist',
    'Recovery Specialist',
    'Recovery Mastery level 8',
    TitleRule.attrLevel,
    attr: Attr.recovery,
    n: 8,
  ),
  TitleDef('dungeon_conqueror', 'Dungeon Conqueror', 'Clear a dungeon or defeat a boss', TitleRule.gateOrBoss),
  TitleDef('elite_hunter', 'Elite Hunter', 'Reach B-Rank', TitleRule.rank, rank: 'B'),
  TitleDef('monarch', 'Monarch of Discipline', 'Reach S-Rank', TitleRule.rank, rank: 'S'),
];

/// Profile frames: unlocked by rank, plus a holographic frame for any
/// legendary achievement. Purely cosmetic.
const List<(String, String, String)> kFrames = [
  ('plain', 'Plain', 'E'),
  ('verdant', 'Verdant', 'D'),
  ('azure', 'Azure', 'C'),
  ('violet', 'Violet', 'B'),
  ('gilded', 'Gilded', 'A'),
  ('crimson', 'Crimson', 'S'),
  ('holo', 'Holographic', 'legendary'),
];

// --- Skill tree (spec §9) ---------------------------------------------------------

enum SkillStat {
  strengthSessions,
  upperSessions,
  lowerSessions,
  coreSessions,
  walkSessions,
  runSessions,
  cardioSessions,
  totalKm,
  mobilitySessions,
  balanceSessions,
  plannedWorkouts,
  weeklyDone,
  workouts,
  comebackDone,
  cooldownSessions,
  recoveryQuests,
  checkIns,
}

class SkillDef {
  const SkillDef(
    this.id,
    this.tree,
    this.name,
    this.requirement,
    this.stat,
    this.threshold,
    this.reward, {
    this.attr,
    this.attrLevel = 0,
  });
  final String id;
  final String tree;
  final String name;
  final String requirement;
  final SkillStat stat;
  final num threshold;

  /// What learning it gives: training knowledge or new quest content.
  final String reward;

  /// Optional extra gate on an attribute level.
  final Attr? attr;
  final int attrLevel;
}

const List<String> kSkillTrees = ['Strength', 'Endurance', 'Mobility', 'Discipline', 'Recovery'];

const List<SkillDef> kSkills = [
  SkillDef(
    'basic_strength',
    'Strength',
    'Basic Strength',
    'Complete 3 strength sessions',
    SkillStat.strengthSessions,
    3,
    'Quests explain sets, reps and rest for strength work.',
  ),
  SkillDef(
    'upper_body',
    'Strength',
    'Upper Body Training',
    'Complete 10 upper-body sessions',
    SkillStat.upperSessions,
    10,
    'Unlocks upper-body focused Strength Quests.',
  ),
  SkillDef(
    'lower_body',
    'Strength',
    'Lower Body Training',
    'Complete 10 lower-body sessions',
    SkillStat.lowerSessions,
    10,
    'Unlocks lower-body focused Strength Quests.',
  ),
  SkillDef(
    'core_dev',
    'Strength',
    'Core Development',
    'Complete 8 sessions with core work',
    SkillStat.coreSessions,
    8,
    'Adds a core finisher to Main Quests.',
  ),
  SkillDef(
    'advanced_strength',
    'Strength',
    'Advanced Strength Training',
    '40 strength sessions and Strength level 10',
    SkillStat.strengthSessions,
    40,
    'Strength Quests may include intermediate lifts when your experience allows.',
    attr: Attr.strength,
    attrLevel: 10,
  ),
  SkillDef(
    'walking',
    'Endurance',
    'Walking Mastery',
    'Complete 5 walks',
    SkillStat.walkSessions,
    5,
    'Endurance Quests can use outdoor walks.',
  ),
  SkillDef(
    'running',
    'Endurance',
    'Running Fundamentals',
    'Complete 3 runs',
    SkillStat.runSessions,
    3,
    'Endurance Quests can include easy runs.',
  ),
  SkillDef(
    'cardio_dev',
    'Endurance',
    'Cardio Development',
    'Complete 10 cardio sessions',
    SkillStat.cardioSessions,
    10,
    'Endurance Quests add interval options.',
  ),
  SkillDef(
    'distance',
    'Endurance',
    'Distance Milestones',
    'Cover 25 km in total',
    SkillStat.totalKm,
    25,
    'Distance goals appear in weekly missions.',
  ),
  SkillDef(
    'endurance_mastery',
    'Endurance',
    'Endurance Mastery',
    'Endurance level 10',
    SkillStat.cardioSessions,
    10,
    'Longer Endurance Quests become available.',
    attr: Attr.endurance,
    attrLevel: 10,
  ),
  SkillDef(
    'flex_fundamentals',
    'Mobility',
    'Flexibility Fundamentals',
    'Complete 3 mobility sessions',
    SkillStat.mobilitySessions,
    3,
    'Mobility Quests explain how to stretch safely.',
  ),
  SkillDef(
    'joint_mobility',
    'Mobility',
    'Joint Mobility Education',
    'Complete 8 mobility sessions',
    SkillStat.mobilitySessions,
    8,
    'Joint-by-joint warm-ups join Main Quests.',
  ),
  SkillDef(
    'balance',
    'Mobility',
    'Balance Training',
    'Complete 5 sessions with single-leg work',
    SkillStat.balanceSessions,
    5,
    'Balance drills appear in Mobility Quests.',
  ),
  SkillDef(
    'advanced_mobility',
    'Mobility',
    'Advanced Mobility',
    '15 mobility sessions and Mobility level 8',
    SkillStat.mobilitySessions,
    15,
    'Longer, deeper Mobility Quests.',
    attr: Attr.mobility,
    attrLevel: 8,
  ),
  SkillDef(
    'consistency',
    'Discipline',
    'Consistency',
    'Complete 5 planned workouts',
    SkillStat.plannedWorkouts,
    5,
    'The System reminds you of your planned days.',
  ),
  SkillDef(
    'weekly_goal',
    'Discipline',
    'Weekly Goal Mastery',
    'Complete 2 weekly missions',
    SkillStat.weeklyDone,
    2,
    'Weekly missions suggest targets from your history.',
  ),
  SkillDef(
    'commitment',
    'Discipline',
    'Training Commitment',
    'Log 30 workouts',
    SkillStat.workouts,
    30,
    'Unlocks the long dungeons.',
  ),
  SkillDef(
    'comeback_mastery',
    'Discipline',
    'Comeback Mastery',
    'Finish a comeback plan',
    SkillStat.comebackDone,
    1,
    'Comeback plans adapt faster to you.',
  ),
  SkillDef(
    'cooldown',
    'Recovery',
    'Cooldown Mastery',
    'Finish 5 workouts with stretching',
    SkillStat.cooldownSessions,
    5,
    'Main Quests end with a short cooldown.',
  ),
  SkillDef(
    'mobility_recovery',
    'Recovery',
    'Mobility Recovery',
    'Complete 5 recovery quests',
    SkillStat.recoveryQuests,
    5,
    'Recovery Quests tailored to sore areas.',
  ),
  SkillDef(
    'recovery_awareness',
    'Recovery',
    'Recovery Awareness',
    'Do 7 readiness check-ins',
    SkillStat.checkIns,
    7,
    'Daily briefing explains your readiness trend.',
  ),
];

SkillDef? skillById(String id) {
  for (final s in kSkills) {
    if (s.id == id) return s;
  }
  return null;
}

/// Previous skill in the same tree (must be learned first).
SkillDef? prerequisiteOf(SkillDef s) {
  final tree = kSkills.where((k) => k.tree == s.tree).toList();
  final i = tree.indexOf(s);
  return i <= 0 ? null : tree[i - 1];
}

// --- Boss quests (spec §12) & rank trials (spec §4) ---------------------------------

/// A movement slot filled from the catalogue at start time, so bosses and
/// trials respect equipment and limitations.
enum Slot { push, pull, legs, hinge, core, cardio, stretch }

class SlotSpec {
  const SlotSpec(this.slot, this.sets, {this.reps, this.seconds});
  final Slot slot;
  final int sets;
  final int? reps;
  final int? seconds;
}

class BossDef {
  const BossDef(
    this.id,
    this.name,
    this.challenge,
    this.attr,
    this.beginner,
    this.advanced,
    this.xp, {
    this.questsNeeded = 3,
    this.title,
  });
  final String id;
  final String name;
  final String challenge;
  final Attr attr;
  final List<SlotSpec> beginner;
  final List<SlotSpec> advanced;
  final int xp;

  /// Quests completed before the gate to this boss opens.
  final int questsNeeded;
  final String? title;
}

const List<BossDef> kBossQuests = [
  BossDef(
    'iron_guardian',
    'The Iron Guardian',
    'Complete a personalised full-body workout.',
    Attr.strength,
    [
      SlotSpec(Slot.legs, 3, reps: 10),
      SlotSpec(Slot.push, 3, reps: 8),
      SlotSpec(Slot.pull, 3, reps: 8),
      SlotSpec(Slot.core, 2, seconds: 30),
    ],
    [
      SlotSpec(Slot.legs, 4, reps: 10),
      SlotSpec(Slot.push, 4, reps: 10),
      SlotSpec(Slot.pull, 4, reps: 10),
      SlotSpec(Slot.hinge, 3, reps: 10),
      SlotSpec(Slot.core, 3, seconds: 45),
    ],
    150,
    questsNeeded: 3,
  ),
  BossDef(
    'endurance_beast',
    'Endurance Beast',
    'Complete a sustained cardio milestone.',
    Attr.endurance,
    [SlotSpec(Slot.cardio, 1, seconds: 20 * 60)],
    [SlotSpec(Slot.cardio, 1, seconds: 40 * 60)],
    150,
    questsNeeded: 5,
  ),
  BossDef(
    'flexibility_master',
    'The Flexibility Master',
    'Complete a mobility progression challenge.',
    Attr.mobility,
    [
      SlotSpec(Slot.stretch, 2, seconds: 30),
      SlotSpec(Slot.stretch, 2, seconds: 30),
      SlotSpec(Slot.stretch, 2, seconds: 30),
    ],
    [
      SlotSpec(Slot.stretch, 3, seconds: 45),
      SlotSpec(Slot.stretch, 3, seconds: 45),
      SlotSpec(Slot.stretch, 3, seconds: 45),
      SlotSpec(Slot.stretch, 3, seconds: 45),
    ],
    120,
    questsNeeded: 5,
  ),
  BossDef(
    'warlord_of_volume',
    'Warlord of Volume',
    'A long, steady strength session.',
    Attr.strength,
    [
      SlotSpec(Slot.legs, 3, reps: 12),
      SlotSpec(Slot.push, 3, reps: 10),
      SlotSpec(Slot.pull, 3, reps: 10),
      SlotSpec(Slot.hinge, 3, reps: 10),
      SlotSpec(Slot.core, 3, seconds: 30),
    ],
    [
      SlotSpec(Slot.legs, 5, reps: 10),
      SlotSpec(Slot.push, 5, reps: 10),
      SlotSpec(Slot.pull, 5, reps: 10),
      SlotSpec(Slot.hinge, 4, reps: 10),
      SlotSpec(Slot.core, 4, seconds: 45),
    ],
    250,
    questsNeeded: 20,
    title: 'Warlord',
  ),
];

BossDef? bossById(String id) {
  for (final b in kBossQuests) {
    if (b.id == id) return b;
  }
  return null;
}

/// The trial to pass for promotion out of each rank.
const Map<String, List<SlotSpec>> kRankTrials = {
  'E': [SlotSpec(Slot.legs, 3, reps: 10), SlotSpec(Slot.push, 3, reps: 8), SlotSpec(Slot.core, 3, seconds: 30)],
  'D': [
    SlotSpec(Slot.legs, 3, reps: 12),
    SlotSpec(Slot.push, 3, reps: 10),
    SlotSpec(Slot.pull, 3, reps: 8),
    SlotSpec(Slot.cardio, 1, seconds: 10 * 60),
  ],
  'C': [
    SlotSpec(Slot.legs, 4, reps: 10),
    SlotSpec(Slot.push, 4, reps: 10),
    SlotSpec(Slot.pull, 4, reps: 10),
    SlotSpec(Slot.core, 3, seconds: 45),
    SlotSpec(Slot.stretch, 2, seconds: 30),
  ],
  'B': [
    SlotSpec(Slot.legs, 4, reps: 12),
    SlotSpec(Slot.hinge, 4, reps: 10),
    SlotSpec(Slot.push, 4, reps: 12),
    SlotSpec(Slot.pull, 4, reps: 10),
    SlotSpec(Slot.cardio, 1, seconds: 15 * 60),
  ],
  'A': [
    SlotSpec(Slot.legs, 5, reps: 10),
    SlotSpec(Slot.hinge, 4, reps: 10),
    SlotSpec(Slot.push, 5, reps: 10),
    SlotSpec(Slot.pull, 5, reps: 10),
    SlotSpec(Slot.core, 4, seconds: 60),
    SlotSpec(Slot.cardio, 1, seconds: 20 * 60),
  ],
};

const int kTrialXp = 100;

// --- Dungeons / gates (time-boxed events) -------------------------------------------

enum GateGoal { sessions, workingSets, cardioSessions, mobilitySessions, nutritionDays }

class GateDef {
  const GateDef(this.id, this.rank, this.name, this.story, this.days, this.goal, this.target, this.xp);
  final String id;
  final String rank;
  final String name;
  final String story;
  final int days;
  final GateGoal goal;
  final int target;
  final int xp;

  String get goalText => switch (goal) {
    GateGoal.sessions => 'Complete $target sessions in $days days',
    GateGoal.workingSets => 'Log $target working sets in $days days',
    GateGoal.cardioSessions => 'Complete $target cardio sessions in $days days',
    GateGoal.mobilitySessions => 'Do mobility work in $target sessions within $days days',
    GateGoal.nutritionDays => 'Log meals within your energy budget on $target of $days days',
  };
}

const List<GateDef> kGates = [
  GateDef(
    'gate_initiation',
    'E',
    'Iron Initiation',
    'Show up, learn the movements, build the habit.',
    14,
    GateGoal.sessions,
    6,
    200,
  ),
  GateDef('gate_hyper', 'D', 'Hypertrophy Block', 'Four weeks of accumulation.', 28, GateGoal.workingSets, 220, 400),
  GateDef(
    'gate_conditioning',
    'C',
    'Conditioning Dungeon',
    'Zone 2, intervals, rows, rides and runs.',
    21,
    GateGoal.cardioSessions,
    8,
    400,
  ),
  GateDef(
    'gate_mobility',
    'C',
    'Mobility Sanctum',
    'Every joint must move freely before you may leave.',
    28,
    GateGoal.mobilitySessions,
    10,
    350,
  ),
  GateDef(
    'gate_cut',
    'B',
    'Discipline of the Cut',
    'Log meals within budget. No crash diets: steady wins.',
    28,
    GateGoal.nutritionDays,
    21,
    500,
  ),
  GateDef(
    'gate_arc',
    'A',
    '12-Week Transformation Arc',
    'Twelve weeks, thirty-six sessions.',
    84,
    GateGoal.sessions,
    36,
    1000,
  ),
];

GateDef? gateById(String id) {
  for (final g in kGates) {
    if (g.id == id) return g;
  }
  return null;
}

// --- Discipline and bonus quest pools -------------------------------------------------

/// (check id, name, text, unit). Validated from logged data.
const List<(String, String, String, String)> kDisciplineQuests = [
  ('water', 'Hydration Discipline', 'Drink your daily water goal', 'ml'),
  ('protein', 'Protein Ration', 'Reach your protein target', 'g'),
  ('sleep', 'Mana Regeneration', 'Log 7+ hours of sleep', 'h'),
  ('weigh', 'Status Check', 'Log your bodyweight', ''),
  ('food', 'Provisions Log', 'Log at least 3 foods today', 'foods'),
  ('checkin', 'Self Assessment', 'Do your readiness check-in', ''),
];

/// (check id, name, text, target, unit).
const List<(String, String, String, int, String)> kBonusQuests = [
  ('pushReps', 'Hundred Palms', 'Do 50 push-up reps today (any variation)', 50, 'reps'),
  ('cardioMin', 'Second Wind', 'Do 20 minutes of cardio', 20, 'min'),
  ('steps', 'Wanderer', 'Walk 8,000 steps', 8000, 'steps'),
  ('effortSets', 'Honest Effort', 'Log RPE or RIR on 5 working sets', 5, 'sets'),
  ('coreSets', 'Braced Core', 'Log 6 working sets for abs or obliques', 6, 'sets'),
];

const List<String> kComebackReasons = ['Busy schedule', 'Illness', 'Injury', 'Travel', 'Low motivation', 'Other'];

// --- Health screening ---------------------------------------------------------------

const List<String> kScreeningQuestions = [
  'Has a doctor ever said you have a heart condition or high blood pressure?',
  'Do you feel pain in your chest at rest, during daily activities, or when you exercise?',
  'Do you lose balance because of dizziness, or have you lost consciousness in the last 12 months?',
  'Have you been diagnosed with another chronic medical condition?',
  'Are you currently taking prescribed medication for a chronic medical condition?',
  'Do you have a bone, joint or soft-tissue problem that could get worse with more physical activity?',
  'Has a doctor ever said you should only do medically supervised physical activity?',
  'Are you pregnant or have you given birth in the last 6 months?',
];

const List<String> kRedFlags = [
  'Chest pain, pressure or tightness',
  'Fainting or nearly fainting',
  'Severe or unusual shortness of breath',
  'Sudden weakness, numbness, confusion or trouble speaking',
  'New vision changes or a sudden severe headache',
  'Unexplained swelling, especially in one leg',
  'A racing or irregular heartbeat that does not settle',
];
