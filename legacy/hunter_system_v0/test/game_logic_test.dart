import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hunter_system/core/game_rules.dart';
import 'package:hunter_system/domain/engine.dart';
import 'package:hunter_system/domain/exercise_catalog.dart';
import 'package:hunter_system/domain/models.dart';
import 'package:hunter_system/domain/quest_generator.dart';

Player newPlayer({
  ExperienceLevel experience = ExperienceLevel.beginner,
  FitnessGoal goal = FitnessGoal.generalFitness,
  Set<Equipment> equipment = const {},
  Set<Limitation> limitations = const {},
  int minutes = 15,
}) =>
    Player(
      name: 'Tester',
      experience: experience,
      goal: goal,
      equipment: {...equipment},
      minutes: minutes,
      limitations: {...limitations},
    );

String day(int n) => dateKey(DateTime.utc(2026, 1, 1).add(Duration(days: n)));

/// Completes every set of a quest and closes it.
QuestResult? completeAll(AppState s, Quest q) {
  for (var i = 0; i < q.tasks.length; i++) {
    while (!q.tasks[i].finished) {
      Engine.logSet(s, q, i, q.tasks[i].target);
    }
  }
  return Engine.finishQuest(s, q, at: '${q.dateKey}T10:00:00');
}

AppState freshState({Player? player}) {
  final s = AppState();
  Engine.startNewPlayer(s, player ?? newPlayer(), day(0));
  return s;
}

void main() {
  group('Game rules', () {
    test('XP needed grows with level', () {
      expect(GameRules.xpToNextLevel(1), 100);
      expect(GameRules.xpToNextLevel(2), greaterThan(GameRules.xpToNextLevel(1)));
    });

    test('rank follows level', () {
      expect(GameRules.rankForLevel(1).letter, 'E');
      expect(GameRules.rankForLevel(5).letter, 'D');
      expect(GameRules.rankForLevel(49).letter, 'A');
      expect(GameRules.rankForLevel(80).letter, 'S');
      expect(GameRules.nextRank(80), isNull);
    });

    test('streak bonus is capped', () {
      expect(GameRules.streakMultiplier(0), 1.0);
      expect(GameRules.streakMultiplier(500), lessThanOrEqualTo(1.2));
    });
  });

  group('Quest generator', () {
    test('never uses equipment the player lacks or loads a flagged area', () {
      for (final exp in ExperienceLevel.values) {
        for (final goal in FitnessGoal.values) {
          for (final minutes in GameRules.questDurations) {
            for (final limits in [
              <Limitation>{},
              {Limitation.knee},
              {Limitation.wrist, Limitation.shoulder},
              Limitation.values.toSet(),
            ]) {
              for (final gear in [<Equipment>{}, {Equipment.dumbbells}, Equipment.values.toSet()]) {
                final p = newPlayer(
                    experience: exp, goal: goal, minutes: minutes, limitations: limits, equipment: gear);
                for (var completed = 0; completed < 4; completed++) {
                  p.questsCompleted = completed;
                  final q = QuestGenerator.generate(player: p, date: day(completed));
                  expect(q.tasks.length, greaterThanOrEqualTo(3));
                  expect(q.xpReward, greaterThan(0));
                  for (final t in q.tasks) {
                    final e = ExerciseCatalog.byId(t.exerciseId);
                    expect(gear.containsAll(e.equipment), isTrue, reason: e.name);
                    expect(e.stresses.intersection(limits).isEmpty, isTrue, reason: e.name);
                  }
                }
              }
            }
          }
        }
      }
    });

    test('quest length tracks the requested duration', () {
      for (final exp in ExperienceLevel.values) {
        for (final minutes in GameRules.questDurations) {
          final p = newPlayer(experience: exp, minutes: minutes, equipment: Equipment.values.toSet());
          final q = QuestGenerator.generate(player: p, date: day(1));
          expect(q.minutes, lessThanOrEqualTo((minutes * 1.15).ceil()), reason: '$exp $minutes');
          expect(q.minutes, greaterThanOrEqualTo((minutes * 0.6).floor()), reason: '$exp $minutes');
        }
      }
    });

    test('beginners are not handed advanced exercises', () {
      final p = newPlayer(equipment: Equipment.values.toSet(), minutes: 45);
      final q = QuestGenerator.generate(player: p, date: day(2));
      for (final t in q.tasks) {
        expect(ExerciseCatalog.byId(t.exerciseId).difficulty, 1);
      }
    });

    test('reported pain forces a gentle recovery quest with safety guidance', () {
      final p = newPlayer(experience: ExperienceLevel.advanced, minutes: 45);
      final r = Readiness(dateKey: day(1), energy: 3, soreness: 1, sleep: 3, pain: true);
      final q = QuestGenerator.generate(
          player: p, date: day(1), readiness: r, focus: QuestFocus.upper);
      expect(q.isRecovery, isTrue);
      expect(q.safetyNote, isNotNull);
      expect(q.minutes, lessThanOrEqualTo(12));
    });

    test('low readiness schedules recovery', () {
      final r = Readiness(dateKey: day(1), energy: 1, soreness: 3, sleep: 1, pain: false);
      final q = QuestGenerator.generate(player: newPlayer(), date: day(1), readiness: r);
      expect(q.isRecovery, isTrue);
      expect(q.reason, isNotEmpty);
    });

    test('three training days in a row schedule recovery', () {
      final s = freshState();
      for (var d = 0; d < 3; d++) {
        Engine.rollover(s, day(d));
        expect(s.dailyQuest!.isRecovery, isFalse);
        completeAll(s, s.dailyQuest!);
      }
      Engine.rollover(s, day(3));
      expect(s.dailyQuest!.isRecovery, isTrue);
    });

    test('alternatives keep the movement pattern and respect limitations', () {
      final p = newPlayer(limitations: {Limitation.wrist});
      final alts = QuestGenerator.alternatives(p, ExerciseCatalog.byId('push_up'));
      expect(alts, isNotEmpty);
      for (final e in alts) {
        expect(e.pattern, MovementPattern.horizontalPush);
        expect(e.stresses.contains(Limitation.wrist), isFalse);
      }
    });

    test('every exercise id is unique', () {
      final ids = ExerciseCatalog.all.map((e) => e.id).toSet();
      expect(ids.length, ExerciseCatalog.all.length);
    });
  });

  group('Rewards', () {
    test('completing a quest pays XP once only', () {
      final s = freshState();
      final q = s.dailyQuest!;
      final result = completeAll(s, q)!;
      final xp = s.player!.totalXp;
      expect(result.baseXp, q.xpReward);
      expect(xp, greaterThanOrEqualTo(q.xpReward));
      expect(Engine.finishQuest(s, q, at: '${day(0)}T11:00:00'), isNull);
      expect(s.player!.totalXp, xp);
    });

    test('partial work earns proportional XP', () {
      final s = freshState();
      final q = s.dailyQuest!;
      Engine.logSet(s, q, 0, q.tasks[0].target);
      final result = Engine.finishQuest(s, q, at: '${day(0)}T10:00:00')!;
      expect(result.baseXp, lessThan(q.xpReward));
      expect(result.baseXp, greaterThan(0));
    });

    test('an untouched quest is missed, not completed, and costs nothing', () {
      final s = freshState();
      final q = s.dailyQuest!;
      expect(Engine.finishQuest(s, q, at: '${day(0)}T10:00:00'), isNull);
      expect(q.status, QuestStatus.missed);
      expect(s.player!.totalXp, 0);
    });

    test('excess XP carries into the next level', () {
      final s = freshState();
      final p = s.player!;
      p.xp = p.xpToNext - 1;
      completeAll(s, s.dailyQuest!);
      expect(p.level, greaterThanOrEqualTo(2));
      expect(p.xp, lessThan(p.xpToNext));
      expect(p.xp, greaterThan(0));
    });

    test('first quest unlocks the first achievement', () {
      final s = freshState();
      final result = completeAll(s, s.dailyQuest!)!;
      expect(result.achievements.map((a) => a.id).toList(), contains('first_quest'));
      expect(s.player!.achievements.containsKey('first_quest'), isTrue);
    });

    test('swapping an exercise keeps the quest fully completable', () {
      final s = freshState();
      final q = s.dailyQuest!;
      final index = q.tasks.indexWhere((t) => QuestGenerator.alternatives(
              s.player!, ExerciseCatalog.byId(t.exerciseId))
          .isNotEmpty);
      final alt = QuestGenerator.alternatives(
              s.player!, ExerciseCatalog.byId(q.tasks[index].exerciseId))
          .first;
      Engine.swapTask(s, q, index, alt.id);
      expect(q.tasks[index].exerciseId, alt.id);
      expect(q.tasks[index].swappedFrom, isNotNull);
      final result = completeAll(s, q)!;
      expect(result.baseXp, q.xpReward);
    });

    test('beating a previous best is recognised; the first entry is not', () {
      final s = freshState();
      final q = s.dailyQuest!;
      final i = q.tasks.indexWhere((t) =>
          t.sets >= 2 &&
          ExerciseCatalog.byId(t.exerciseId).category != ExerciseCategory.mobility);
      expect(Engine.logSet(s, q, i, 8), isFalse);
      expect(Engine.logSet(s, q, i, 11), isTrue);
      expect(q.personalBests, isNotEmpty);
    });

    test('bonus quests are capped per day and pay less', () {
      final s = freshState();
      expect(Engine.canAddBonusQuest(s), isFalse);
      completeAll(s, s.dailyQuest!);
      for (var i = 0; i < GameRules.maxBonusQuestsPerDay; i++) {
        final b = Engine.addBonusQuest(s, day(0), minutes: 10)!;
        expect(b.kind, QuestKind.bonus);
        completeAll(s, b);
      }
      expect(Engine.addBonusQuest(s, day(0), minutes: 10), isNull);
    });
  });

  group('Streaks and comebacks', () {
    test('consecutive days build a streak', () {
      final s = freshState();
      for (var d = 0; d < 3; d++) {
        Engine.rollover(s, day(d));
        completeAll(s, s.dailyQuest!);
      }
      expect(s.player!.streak, 3);
    });

    test('two quests on one day count once', () {
      final s = freshState();
      completeAll(s, s.dailyQuest!);
      completeAll(s, Engine.addBonusQuest(s, day(0), minutes: 10)!);
      expect(s.player!.streak, 1);
    });

    test('missing one day puts the streak at risk; a comeback quest saves it', () {
      final s = freshState();
      completeAll(s, s.dailyQuest!);
      Engine.rollover(s, day(1));
      completeAll(s, s.dailyQuest!);
      Engine.rollover(s, day(3)); // day 2 missed
      expect(Engine.streakAtRisk(s, day(3)), isTrue);
      expect(s.dailyQuest!.kind, QuestKind.comeback);
      expect(s.player!.streak, 2);
      completeAll(s, s.dailyQuest!);
      expect(s.player!.streak, 3);
      expect(s.player!.comebacks, 1);
    });

    test('a long break resets the streak but never removes XP or levels', () {
      final s = freshState();
      completeAll(s, s.dailyQuest!);
      final xp = s.player!.totalXp;
      final level = s.player!.level;
      Engine.rollover(s, day(10));
      expect(s.player!.streak, 0);
      expect(s.player!.totalXp, xp);
      expect(s.player!.level, level);
      expect(s.dailyQuest!.kind, QuestKind.comeback);
      expect(s.history.length, 1);
    });

    test('reporting pain protects the streak for that day', () {
      final s = freshState();
      completeAll(s, s.dailyQuest!);
      Engine.rollover(s, day(1));
      Engine.submitReadiness(
          s, Readiness(dateKey: day(1), energy: 1, soreness: 3, sleep: 1, pain: true));
      expect(s.dailyQuest!.isRecovery, isTrue);
      Engine.rollover(s, day(2)); // nothing done on day 1
      Engine.rollover(s, day(3));
      expect(s.player!.streak, 1);
      completeAll(s, s.dailyQuest!);
      expect(s.player!.streak, 2);
    });

    test('work left unfinished overnight is still credited', () {
      final s = freshState();
      final q = s.dailyQuest!;
      Engine.logSet(s, q, 0, q.tasks[0].target);
      Engine.rollover(s, day(1));
      expect(s.history.first.status, QuestStatus.completed);
      expect(s.player!.totalXp, greaterThan(0));
      expect(s.dailyQuest!.dateKey, day(1));
    });
  });

  group('Persistence', () {
    test('state survives a JSON round trip', () {
      final s = freshState(
          player: newPlayer(equipment: {Equipment.bands}, limitations: {Limitation.knee}));
      completeAll(s, s.dailyQuest!);
      Engine.rollover(s, day(1));
      Engine.submitReadiness(
          s, Readiness(dateKey: day(1), energy: 2, soreness: 2, sleep: 2, pain: false));
      final copy = AppState.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(copy.toJson()), jsonEncode(s.toJson()));
      expect(copy.player!.equipment.contains(Equipment.bands), isTrue);
      expect(copy.player!.limitations.contains(Limitation.knee), isTrue);
      expect(copy.history.length, 1);
    });
  });
}
