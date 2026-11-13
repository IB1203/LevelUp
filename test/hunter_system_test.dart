import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/models/workout.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/services/progress_reminder.dart';
import 'package:level_up/services/train_reminder.dart';
import 'package:level_up/services/system_reminder.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:level_up/system/hunter_catalog.dart';
import 'package:level_up/system/hunter_engine.dart';
import 'package:level_up/system/hunter_models.dart';
import 'package:level_up/system/hunter_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _ago(int days, {int hour = 18}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - days, hour);
}

LoggedSession _strength(DateTime at, {int min = 30, int sets = 4, double kg = 60, String? routine}) => LoggedSession(
      at,
      min * 60,
      [LoggedExercise('EIeI8Vf', 'Barbell Bench Press', 'chest', [for (var i = 0; i < sets; i++) LoggedSet(8, kg)])],
      routineId: routine,
    );

LoggedSession _cardio(DateTime at, {int min = 25}) => LoggedSession(at, min * 60, [
      LoggedExercise('running', 'Treadmill Run', 'quads', [LoggedSet(0, 0, sec: min * 60, km: min / 6)]),
    ]);

LoggedSession _stretch(DateTime at, {int min = 15}) => LoggedSession(at, min * 60, [
      LoggedExercise('hamstring-stretch', 'Hamstring Stretch', 'hamstrings',
          [for (var i = 0; i < 4; i++) LoggedSet(0, 0, sec: 45)]),
    ]);

/// Registers a hunter whose account started [daysAgo] days ago.
void _register({int daysAgo = 3, int experience = 1, String classId = 'hypertrophy', List<String> limits = const []}) {
  hunter.register(
    name: 'Kael',
    experience: experience,
    classId: classId,
    minutes: 30,
    weeklyTarget: 3,
    limitations: limits,
    screening: List.filled(kScreeningQuestions.length, false),
  );
  final p = Map<String, dynamic>.from(fit.hunterData['player'] as Map);
  p['created'] = _ago(daysAgo, hour: 0).toIso8601String();
  fit.hunterData['player'] = p;
  hunter.invalidate();
}

int _xpOf(String prefix) =>
    hunter.status.ledger.where((t) => t.id.startsWith(prefix)).fold(0, (n, t) => n + t.xp);

/// Logs a session that completes [q] by doing every planned set.
LoggedSession _doQuest(Quest q, DateTime at, {double share = 1}) => LoggedSession(
      at,
      q.minutes * 60,
      [
        for (final o in q.objectives)
          LoggedExercise(o.exerciseId, o.name, 'chest', [
            for (var i = 0; i < (o.sets * share).ceil(); i++)
              o.seconds != null ? LoggedSet(0, 0, sec: o.seconds) : LoggedSet(o.reps ?? 10, 0),
          ]),
      ],
      routineId: 'quest:${q.id}',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    ProgressReminder.instance.enabled = false;
    TrainReminder.instance.enabled = false;
    SystemReminder.instance.enabled = false;
    fit.resetAllData();
    fit.onboarded = true;
    hunter.invalidate();
  });

  group('player progression', () {
    test('formula: 100 + 25 × (level − 1), with the spec table', () {
      expect([for (final l in [1, 2, 3, 4, 5, 10, 15, 20, 25, 30]) HunterRules.xpToNext(l)],
          [100, 125, 150, 175, 200, 325, 450, 575, 700, 825]);
      expect(HunterRules.attrXpToNext(1), 75);
      expect(HunterRules.attrXpToNext(3), 105);
    });

    test('excess XP carries forward and multiple level-ups work', () {
      expect(HunterRules.levelFor(99), (level: 1, into: 99, need: 100));
      expect(HunterRules.levelFor(130), (level: 2, into: 30, need: 125));
      expect(HunterRules.levelFor(100 + 125 + 150 + 5).level, 4);
      expect(HunterRules.levelFor(100 + 125 + 150 + 5).into, 5);
    });

    test('a new player starts at E-Rank, level 1, 0 XP, every attribute level 1', () {
      _register(daysAgo: 0);
      final s = hunter.status;
      expect(s.registered, isTrue);
      expect(s.rank.letter, 'E');
      expect(s.level, 1);
      expect(s.totalXp, 0);
      for (final a in Attr.values) {
        expect(s.attrs[a]!.level, 1, reason: a.name);
      }
      expect(s.todayQuests, isNotEmpty);
    });

    test('a valid workout pays by duration tier; history before registration does not', () {
      fit.sessions.add(_strength(_ago(10)));
      _register(daysAgo: 3);
      expect(hunter.status.totalXp, 0);
      fit.sessions.add(_strength(_ago(1), min: 30));
      hunter.invalidate();
      final s = hunter.status;
      expect(_xpOf('session:'), 70);
      expect(s.ledger.where((t) => t.id.startsWith('session:')).single.attrs[Attr.strength], 8);
    });

    test('short workouts still count; over an hour earns no more than 45–60 min', () {
      expect(HunterRules.workoutXp(4), 0);
      expect(HunterRules.workoutXp(7), 20);
      expect(HunterRules.workoutXp(55), 85);
      expect(HunterRules.workoutXp(150), 85);
    });

    test('daily XP limit: three long sessions on one day are capped', () {
      _register();
      for (var h = 8; h <= 18; h += 5) {
        fit.sessions.add(_strength(_ago(1, hour: h), min: 60));
      }
      hunter.invalidate();
      expect(_xpOf('session:'), HunterRules.dailyWorkoutXpCap);
      expect(hunter.status.ledger.any((t) => t.reason.contains('daily limit')), isTrue);
    });

    test('opening the app or reading status never pays XP', () {
      _register();
      final before = hunter.status.totalXp;
      for (var i = 0; i < 5; i++) {
        hunter.invalidate();
        hunter.status;
      }
      expect(hunter.status.totalXp, before);
    });
  });

  group('attributes', () {
    test('each activity feeds its own attribute', () {
      _register();
      fit.sessions
        ..add(_strength(_ago(2)))
        ..add(_cardio(_ago(1)))
        ..add(_stretch(_ago(0, hour: 9)));
      hunter.invalidate();
      final byRef = {for (final t in hunter.status.ledger) t.id: t};
      final str = byRef['session:${_ago(2).millisecondsSinceEpoch}']!;
      final end = byRef['session:${_ago(1).millisecondsSinceEpoch}']!;
      final mob = byRef['session:${_ago(0, hour: 9).millisecondsSinceEpoch}']!;
      expect(str.attrs[Attr.strength], greaterThan(0));
      expect(str.attrs[Attr.endurance], isNull);
      expect(end.attrs[Attr.endurance], 25);
      expect(mob.category, 'mobility');
      expect(mob.attrs[Attr.mobility], 12);
      expect(mob.attrs[Attr.recovery], greaterThan(0));
    });

    test('planned workouts give more Consistency than unplanned ones', () {
      _register();
      fit.sessions
        ..add(_strength(_ago(2), routine: 'r1'))
        ..add(_strength(_ago(1)));
      hunter.invalidate();
      final l = {for (final t in hunter.status.ledger) t.id: t};
      expect(l['session:${_ago(2).millisecondsSinceEpoch}']!.attrs[Attr.consistency], 10);
      expect(l['session:${_ago(1).millisecondsSinceEpoch}']!.attrs[Attr.consistency], 5);
    });

    test('a deload counts as a recovery session and feeds Recovery Mastery', () {
      _register();
      fit.sessions.add(LoggedSession(_ago(1), 20 * 60, [
        LoggedExercise('EIeI8Vf', 'Barbell Bench Press', 'chest', [LoggedSet(8, 40), LoggedSet(8, 40)]),
      ], deload: true));
      hunter.invalidate();
      final t = hunter.status.ledger.firstWhere((t) => t.id.startsWith('session:'));
      expect(t.category, 'recovery');
      expect(t.xp, inInclusiveRange(25, 35));
      expect(t.attrs[Attr.recovery], 20);
    });
  });

  group('quests', () {
    test('the daily board has every category and respects limitations', () {
      _register(limits: ['Shoulders']);
      final q = hunter.status.todayQuests;
      final cats = q.map((x) => x.category).toSet();
      expect(cats, containsAll([QuestCategory.main, QuestCategory.side, QuestCategory.recovery,
          QuestCategory.discipline, QuestCategory.bonus]));
      for (final quest in q) {
        for (final o in quest.objectives) {
          expect(fit.exerciseById(o.exerciseId)?.primary, isNot('shoulders'), reason: o.name);
        }
      }
    });

    test('difficulty comes from experience, not level', () {
      _register(experience: 0);
      expect(hunter.status.todayQuests.first.difficulty, 'E');
      fit.hunterData.remove('quests');
      hunter.updatePlayer(experience: 3);
      expect(hunter.status.todayQuests.first.difficulty, 'B');
    });

    test('completing a quest pays its reward plus the bonus, exactly once', () {
      _register();
      final main = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      final at = DateTime.now().subtract(const Duration(minutes: 1));
      fit.sessions.add(_doQuest(main, at));
      hunter.invalidate();
      expect(hunter.questById(main.id)!.status, QuestStatus.completed);
      expect(_xpOf('quest:${main.id}'), main.xp);
      expect(_xpOf('qbonus:${main.id}'), HunterRules.dailyQuestBonus);
      int paid() => _xpOf('session:') + _xpOf('quest:${main.id}') + _xpOf('qbonus:${main.id}');
      final before = paid();
      final workouts = hunter.status.workouts;
      // The same session again (e.g. a re-import) and an edit: no new reward.
      fit.sessions.add(_doQuest(main, at));
      fit.sessions.first.exercises.first.sets.add(LoggedSet(3, 0));
      hunter.invalidate();
      expect(paid(), before);
      expect(hunter.status.workouts, workouts);
    });

    test('a half-done quest pays in proportion, without the completion bonus', () {
      _register();
      final main = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      fit.sessions.add(_doQuest(main, DateTime.now().subtract(const Duration(minutes: 1)), share: 0.5));
      hunter.invalidate();
      final q = hunter.questById(main.id)!;
      expect(q.status, QuestStatus.partial);
      expect(_xpOf('quest:${main.id}'), lessThan(main.xp));
      expect(_xpOf('qbonus:${main.id}'), 0);
    });

    test('a skipped quest pays nothing; a missed one never removes XP', () {
      _register();
      fit.sessions.add(_strength(_ago(1)));
      hunter.invalidate();
      final before = hunter.status.totalXp;
      final side = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.side);
      hunter.skipQuest(side.id);
      expect(hunter.questById(side.id)!.status, QuestStatus.skipped);
      expect(hunter.status.totalXp, before);
      expect(_xpOf('quest:${side.id}'), 0);
    });

    test('shortening halves the sets and scales the reward', () {
      _register();
      final main = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      hunter.shortenQuest(main.id);
      final short = hunter.questById(main.id)!;
      expect(short.shortened, isTrue);
      expect(short.plannedSets, lessThan(main.plannedSets));
      expect(short.xp, lessThan(main.xp));
      expect(short.id, main.id);
    });

    test('replacing an exercise keeps the quest and its reward', () {
      _register();
      final q = hunter.status.todayQuests.firstWhere((q) => q.isWorkout && q.objectives.isNotEmpty);
      final alts = hunter.alternativesFor(q.id, 0);
      expect(alts, isNotEmpty);
      hunter.replaceExercise(q.id, 0, alts.first.id);
      final after = hunter.questById(q.id)!;
      expect(after.objectives.first.exerciseId, alts.first.id);
      expect(after.xp, q.xp);
    });

    test('rescheduling keeps the quest id and its reward rules', () {
      _register();
      final q = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.side);
      hunter.rescheduleQuest(q.id);
      final moved = hunter.questById(q.id)!;
      expect(moved.rescheduled, isTrue);
      expect(moved.day, dayKey(_ago(-1)));
      expect(moved.xp, q.xp);
      expect(hunter.status.todayQuests.any((x) => x.id == q.id), isFalse);
    });

    test('data quests complete from logged data only', () {
      _register();
      final d = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.discipline);
      expect(d.done, isFalse);
      switch (d.check) {
        case 'water':
          fit.addWater(d.target.toInt());
        case 'sleep':
          hunter.logSleep(8);
        case 'weigh':
          fit.addBodyweight(80);
        case 'checkin':
          hunter.logCheckIn(energy: 4, soreness: 2, stress: 2, pain: false);
        default:
          return; // protein/food need the food library; covered by the water/sleep paths.
      }
      hunter.invalidate();
      expect(hunter.questById(d.id)!.status, QuestStatus.completed);
    });

    test('weekly missions pay once when every objective is met', () {
      _register(daysAgo: 0);
      final ws = DateTime.now();
      for (var i = 0; i < 3; i++) {
        final day = DateTime(ws.year, ws.month, ws.day, 6 + i * 4);
        fit.sessions.add(LoggedSession(day, 40 * 60, [
          LoggedExercise('EIeI8Vf', 'Barbell Bench Press', 'chest', [LoggedSet(8, 60), LoggedSet(8, 60)]),
          LoggedExercise('running', 'Treadmill Run', 'quads', [LoggedSet(0, 0, sec: 600)]),
          LoggedExercise('hamstring-stretch', 'Hamstring Stretch', 'hamstrings', [LoggedSet(0, 0, sec: 45)]),
        ], routineId: 'r$i'));
      }
      hunter.invalidate();
      // Weekly target 3 needs 3 different days; here all are today, so mission A stays open.
      final s = hunter.status;
      final b = s.weekly.firstWhere((m) => m.id == 'mission_b');
      expect(b.done, isTrue);
      expect(s.ledger.where((t) => t.id.startsWith('weekly:') && t.id.endsWith('mission_b')).length, 1);
    });
  });

  group('path mechanics', () {
    test('skill tree order starts with the path\'s tree and contains each tree once', () {
      expect(skillTreesFor('hypertrophy').first, 'Strength');
      expect(skillTreesFor('mobility').first, 'Mobility');
      expect(skillTreesFor('fatloss').first, 'Discipline');
      expect(skillTreesFor('strength').first, 'Strength');
      expect(skillTreesFor('endurance').first, 'Endurance');
      for (final c in kHunterClasses) {
        final trees = skillTreesFor(c.id);
        expect(trees.toSet().length, trees.length, reason: c.id);
        expect(trees.contains(c.tree), isTrue, reason: c.id);
      }
    });

    test('each class maps to a matching program template', () {
      expect(hunterClassById('hypertrophy').program, 'ppl');
      expect(hunterClassById('strength').program, 'stronglifts');
      expect(hunterClassById('endurance').program, 'fullbody');
      expect(hunterClassById('fatloss').program, 'home');
      expect(hunterClassById('mobility').program, 'rr');
    });

    test('weekly mission names are class-shaped', () {
      for (final (id, expected) in const [
        ('hypertrophy', 'Volume Week'),
        ('strength', 'Heavy Week'),
        ('endurance', 'Ranger Week'),
        ('fatloss', 'Shadow Week'),
        ('mobility', 'Monk Week'),
      ]) {
        _register(daysAgo: 0, classId: id);
        hunter.invalidate();
        expect(
          hunter.status.weekly.firstWhere((m) => m.id == 'mission_a').name,
          expected,
          reason: id,
        );
      }
    });
  });

  group('rank progression', () {
    test('rank level bands and promotion requirements from the spec', () {
      expect([for (final r in kRanks) '${r.letter}${r.minLevel}-${r.maxLevel}'],
          ['E1-10', 'D11-20', 'C21-35', 'B36-50', 'A51-75', 'S76-100']);
      expect(rankByLetter('E').promoQuests, 15);
      expect(rankByLetter('D').promoWorkouts, 30);
      expect(rankByLetter('A').promoWeekly, 15);
    });

    test('high XP alone does not promote: the trial and milestones are required', () {
      _register();
      final ledger = Map<String, dynamic>.from((fit.hunterData['ledger'] as Map?) ?? {});
      ledger['test:xp'] = {'xp': 20000, 'c': 'test', 'r': 'test', 'at': DateTime.now().toIso8601String()};
      fit.hunterData['ledger'] = ledger;
      hunter.invalidate();
      final s = hunter.status;
      expect(s.level, greaterThan(10));
      expect(s.rank.letter, 'E');
      expect(s.promotionReady, isFalse);
      expect(hunter.promote(), isNull);
    });

    test('meeting every requirement allows promotion; history is kept and rank is never removed', () {
      _register();
      final l = <String, dynamic>{
        'test:xp': {'xp': 3000, 'c': 'test', 'r': 'test', 'at': DateTime.now().toIso8601String()},
        'trial:E': {'xp': 100, 'c': 'trial', 'r': 'trial', 'at': DateTime.now().toIso8601String()},
        for (var i = 0; i < 15; i++) 'quest:fake$i': {'xp': 1, 'c': 'quest', 'r': 'q', 'at': DateTime.now().toIso8601String()},
        for (var i = 0; i < 3; i++) 'weekly:w$i': {'xp': 1, 'c': 'weekly', 'r': 'w', 'at': DateTime.now().toIso8601String()},
      };
      fit.hunterData['ledger'] = {...((fit.hunterData['ledger'] as Map?) ?? {}), ...l};
      hunter.invalidate();
      expect(hunter.status.promotionReady, isTrue);
      final change = hunter.promote();
      expect(change?.to, 'D');
      expect(hunter.status.rank.letter, 'D');
      expect(hunter.status.rankHistory.single.from, 'E');
      expect(hunter.status.ledger.any((t) => t.id == 'rank:D'), isTrue);
      // A long break never demotes.
      fit.sessions.clear();
      hunter.invalidate();
      expect(hunter.status.rank.letter, 'D');
    });
  });

  group('achievements, skills, titles', () {
    test('achievements unlock from measured activity and pay once', () {
      _register();
      fit.sessions.add(_strength(_ago(1)));
      hunter.invalidate();
      var s = hunter.status;
      expect(s.achievements.firstWhere((a) => a.def.id == 'first_workout').unlocked, isTrue);
      expect(s.achievements.firstWhere((a) => a.def.id == 'first_awakening').unlocked, isTrue);
      final xp = _xpOf('ach:first_workout');
      fit.sessions.add(_strength(_ago(0, hour: 7)));
      hunter.invalidate();
      s = hunter.status;
      expect(_xpOf('ach:first_workout'), xp);
      expect(s.ledger.where((t) => t.id == 'ach:first_workout').length, 1);
    });

    test('assisted pull-ups do not unlock First Pull-up; a strict one does', () {
      _register();
      fit.sessions.add(LoggedSession(_ago(1), 600, [LoggedExercise('x', 'Assisted Pull-up', 'back', [LoggedSet(8, 0)])]));
      hunter.invalidate();
      expect(hunter.status.achievements.firstWhere((a) => a.def.id == 'first_pullup').unlocked, isFalse);
      fit.sessions.add(LoggedSession(_ago(0, hour: 7), 600, [LoggedExercise('lBDjFxJ', 'Pull-up', 'back', [LoggedSet(1, 0)])]));
      hunter.invalidate();
      expect(hunter.status.achievements.firstWhere((a) => a.def.id == 'first_pullup').unlocked, isTrue);
    });

    test('skills need the training and a skill point, and the previous skill', () {
      _register();
      for (var i = 0; i < 3; i++) {
        fit.sessions.add(_strength(_ago(3 - i)));
      }
      hunter.invalidate();
      var s = hunter.status;
      final basic = s.skills.firstWhere((k) => k.def.id == 'basic_strength');
      expect(basic.conditionMet, isTrue);
      expect(s.skills.firstWhere((k) => k.def.id == 'upper_body').prereqMet, isFalse);
      expect(s.skillPoints, s.level - 1);
      if (s.skillPoints > 0) {
        expect(hunter.learnSkill('basic_strength'), isTrue);
        s = hunter.status;
        expect(s.skills.firstWhere((k) => k.def.id == 'basic_strength').learned, isTrue);
      }
    });

    test('titles unlock and one can be equipped', () {
      _register();
      final s = hunter.status;
      expect(s.titles.firstWhere((t) => t.def.id == 'awakened').unlocked, isTrue);
      expect(s.titles.firstWhere((t) => t.def.id == 'elite_hunter').unlocked, isFalse);
      hunter.equipTitle('e_beginner');
      expect(hunter.status.currentTitle?.id, 'e_beginner');
      hunter.equipTitle('elite_hunter');
      expect(hunter.status.currentTitle?.id, isNot('elite_hunter'));
    });
  });

  group('records', () {
    test('records keep the previous value and compare like with like', () {
      fit.sessions
        ..add(_strength(_ago(5), kg: 60))
        ..add(_strength(_ago(3), kg: 70))
        ..add(LoggedSession(_ago(1), 600, [LoggedExercise('plank-hold', 'Plank', 'abdomen', [LoggedSet(0, 0, sec: 90)])]));
      _register(daysAgo: 10);
      final recs = hunter.status.records;
      final heavy = recs.firstWhere((r) => r.exerciseId == 'EIeI8Vf' && r.type == RecordType.maxWeight);
      expect(heavy.value, 70);
      expect(heavy.previous, 60);
      final atW = recs.firstWhere((r) => r.exerciseId == 'EIeI8Vf' && r.type == RecordType.repsAtWeight);
      expect(atW.atWeight, 70);
      expect(recs.any((r) => r.exerciseId == 'plank-hold' && r.type == RecordType.longestHold && r.value == 90), isTrue);
      expect(_xpOf('pr:'), HunterRules.prXp);
    });
  });

  group('recovery and comeback', () {
    test('a planned rest day pays Recovery XP and costs nothing', () {
      _register();
      fit.setDayOff(_ago(1), 'rest');
      hunter.invalidate();
      expect(_xpOf('rest:'), HunterRules.restDayXp);
    });

    test('7+ days away: comeback is offered and nothing is deleted', () {
      _register(daysAgo: 20);
      fit.sessions.add(_strength(_ago(12)));
      hunter.invalidate();
      final before = hunter.status.totalXp;
      final s = hunter.status;
      expect(s.comebackDue, isTrue);
      expect(s.daysAway, 12);
      expect(s.totalXp, before);
      hunter.acceptComeback('Busy schedule');
      final after = hunter.status;
      expect(after.comebackDue, isFalse);
      expect(after.comebackActive, isTrue);
      expect(after.player!.weeklyTarget, 2);
      expect(after.totalXp, greaterThanOrEqualTo(before));
    });

    test('low readiness lowers quest difficulty and turns the main quest into recovery', () {
      _register(experience: 2);
      fit.hunterData.remove('quests');
      hunter.logCheckIn(energy: 1, soreness: 5, stress: 5, pain: false, sleep: 4);
      final main = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      expect(main.name, 'Active Recovery');
      expect(main.difficulty, 'D');
    });
  });

  group('data integrity', () {
    test('everything survives a save and reload', () {
      _register();
      fit.sessions.add(_strength(_ago(1)));
      hunter.logSleep(8);
      hunter.invalidate();
      final s = hunter.status;
      final json = jsonDecode(jsonEncode(fit.toJson())) as Map<String, dynamic>;
      fit.hunterData
        ..clear()
        ..addAll((json['hunter'] as Map).cast<String, dynamic>());
      hunter.invalidate();
      final r = hunter.status;
      expect(r.totalXp, s.totalXp);
      expect(r.ledger.length, s.ledger.length);
      expect(r.player!.id, s.player!.id);
      expect(r.todayQuests.map((q) => q.id), s.todayQuests.map((q) => q.id));
    });

    test('deleting a workout keeps the XP it earned; re-adding it pays nothing', () {
      _register();
      final session = _strength(_ago(1));
      fit.sessions.add(session);
      hunter.invalidate();
      final earned = hunter.status.totalXp;
      fit.sessions.remove(session);
      hunter.invalidate();
      expect(hunter.status.totalXp, earned);
      fit.sessions.add(session);
      hunter.invalidate();
      expect(hunter.status.totalXp, earned);
    });

    test('level-up notifications fire once and are not replayed', () {
      _register();
      fit.sessions
        ..add(_strength(_ago(2), min: 50))
        ..add(_strength(_ago(1), min: 50));
      hunter.invalidate();
      final ups = hunter.pendingAlerts({'level'});
      expect(ups, isNotEmpty);
      hunter.markShown(ups.map((n) => n.id));
      hunter.invalidate();
      expect(hunter.pendingAlerts({'level'}), isEmpty);
    });

    test('reset wipes the System with the rest of the data', () {
      _register();
      fit.resetAllData();
      hunter.invalidate();
      expect(hunter.status.registered, isFalse);
    });
  });

  group('quests follow how the hunter feels', () {
    test('a low check-in after the board exists rebuilds the untouched quests', () {
      _register(experience: 2);
      final before = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      expect(before.name, isNot('Active Recovery'));
      hunter.logCheckIn(energy: 1, soreness: 5, stress: 5, pain: true, sleep: 4);
      final after = hunter.status.todayQuests;
      expect(after.firstWhere((q) => q.category == QuestCategory.main).name, 'Active Recovery');
      expect(after.firstWhere((q) => q.category == QuestCategory.side).name, 'Loosen Up');
      expect(after.map((q) => q.id).toSet().length, after.length, reason: 'no duplicated quests');
    });

    test('a quest already accepted is kept when the board is rebuilt', () {
      _register(experience: 2);
      final main = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      hunter.acceptQuest(main.id);
      hunter.logCheckIn(energy: 1, soreness: 5, stress: 5, pain: false, sleep: 4);
      final kept = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      expect(kept.name, main.name);
      expect(kept.status, QuestStatus.accepted);
    });

    test('a recovery day never offers extra training volume as a bonus', () {
      _register(experience: 2);
      hunter.logCheckIn(energy: 1, soreness: 5, stress: 5, pain: true, sleep: 4);
      for (final q in hunter.status.todayQuests.where((q) => q.category == QuestCategory.bonus)) {
        expect(q.check, 'steps');
      }
    });

    test('a shoulder limitation never gets the push-up bonus', () {
      _register(limits: ['Shoulders']);
      for (final q in hunter.status.todayQuests.where((q) => q.category == QuestCategory.bonus)) {
        expect(q.check, isNot('pushReps'));
      }
    });

    test('an attempt below the minimum leaves the quest open and unpaid', () {
      _register();
      final q = hunter.status.todayQuests.firstWhere((q) => q.category == QuestCategory.main);
      hunter.acceptQuest(q.id);
      final first = q.objectives.first;
      fit.sessions.add(LoggedSession(DateTime.now(), 300, [
        LoggedExercise(first.exerciseId, first.name, 'chest', [LoggedSet(first.reps ?? 10, 0)]),
      ], routineId: 'quest:${q.id}'));
      hunter.invalidate();
      final tried = hunter.status.todayQuests.firstWhere((x) => x.id == q.id);
      expect(tried.done, isFalse);
      expect(_xpOf('quest:${q.id}'), 0);
      fit.sessions.add(_doQuest(q, DateTime.now().add(const Duration(minutes: 1))));
      hunter.invalidate();
      expect(hunter.status.todayQuests.firstWhere((x) => x.id == q.id).status, QuestStatus.completed);
      expect(_xpOf('quest:${q.id}'), q.xp);
    });
  });

  group('weekly missions are paid once', () {
    test('changing the first day of the week does not pay past weeks again', () {
      _register(daysAgo: 40);
      for (var d = 1; d <= 35; d++) {
        fit.sessions.add(_strength(_ago(d)));
      }
      hunter.invalidate();
      final paid = _xpOf('weekly:');
      final total = hunter.status.totalXp;
      fit.weekStartDay = fit.weekStartDay == 1 ? 7 : 1;
      hunter.invalidate();
      expect(_xpOf('weekly:'), paid);
      expect(hunter.status.totalXp, total);
    });
  });

  group('records and comebacks', () {
    test('moving a logged workout to another time does not pay its record again', () {
      _register(daysAgo: 10);
      fit.sessions.add(_strength(_ago(3), kg: 60));
      fit.sessions.add(_strength(_ago(1, hour: 18), kg: 80));
      hunter.invalidate();
      final paid = _xpOf('pr:');
      expect(paid, greaterThan(0));
      final moved = fit.sessions.removeLast();
      fit.sessions.add(LoggedSession(_ago(1, hour: 20), moved.durationSec, moved.exercises));
      hunter.invalidate();
      expect(_xpOf('pr:'), paid);
    });

    test('sports never fill a strength slot in a quest', () {
      _register();
      const sports = {'dance', 'football', 'basketball', 'tennis', 'golf'};
      for (final q in hunter.status.todayQuests) {
        for (final o in q.objectives) {
          expect(sports.contains(o.exerciseId), isFalse, reason: '${q.name}: ${o.name}');
        }
      }
    });

    test('a finished comeback plan gives the weekly target back', () {
      _register(daysAgo: 40);
      fit.sessions.add(_strength(_ago(30)));
      hunter.invalidate();
      expect(hunter.status.comebackDue, isTrue);
      hunter.acceptComeback('Travel');
      expect(hunter.status.player!.weeklyTarget, 2);
      final plans = [
        for (final c in fit.hunterData['comebacks'] as List)
          {...(c as Map).cast<String, dynamic>(), 'start': dayKey(_ago(20)), 'until': dayKey(_ago(1))},
      ];
      fit.hunterData['comebacks'] = plans;
      hunter.invalidate();
      expect(hunter.status.player!.weeklyTarget, 3);
    });
  });
}
