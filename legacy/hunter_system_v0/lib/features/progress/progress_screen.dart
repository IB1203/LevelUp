import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/engine.dart';
import '../../domain/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  static const _attributeHelp = {
    Attribute.strength: 'Strength sets',
    Attribute.endurance: 'Cardio sets',
    Attribute.agility: 'Mobility work',
    Attribute.vitality: 'Core work and walking',
    Attribute.recovery: 'Recovery quests',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final player = state.player!;
    final text = Theme.of(context).textTheme;
    final next = GameRules.nextRank(player.level);

    final bests = player.records.entries
        .map((e) => MapEntry(ExerciseCatalog.byId(e.key), e.value))
        .where((e) => e.key.category != ExerciseCategory.mobility)
        .toList()
      ..sort((a, b) => a.key.name.compareTo(b.key.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          SystemPanel(
            child: Column(
              children: [
                Center(child: StatRadar(values: player.attributes)),
                const SizedBox(height: 8),
                for (final a in Attribute.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(a.short, style: text.titleSmall!.copyWith(color: Hx.mana)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.label, style: text.titleMedium),
                              Text(
                                'From ${_attributeHelp[a]!.toLowerCase()}',
                                style: text.bodySmall!.copyWith(color: Hx.textDim),
                              ),
                            ],
                          ),
                        ),
                        Text('${player.attributes[a] ?? 0}', style: text.headlineSmall),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'One point per set logged. Points record the work you have '
                  'done; they are not a measurement of your body.',
                  style: text.bodySmall!.copyWith(color: Hx.textDim, height: 1.4),
                ),
              ],
            ),
          ),
          const SectionHeading('Hunter rank'),
          SystemPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final r in GameRules.ranks)
                      Opacity(
                        opacity: player.level >= r.minLevel ? 1 : 0.3,
                        child: Column(
                          children: [
                            RankEmblem(
                              letter: r.letter,
                              size: r.letter == player.rank.letter ? 50 : 38,
                              variant: player.emblem,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lv ${r.minLevel}',
                              style: text.bodySmall!.copyWith(color: Hx.textDim),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  next == null
                      ? 'You hold the highest rank.'
                      : 'Rank ${next.letter} (${next.title.toLowerCase()}) unlocks at level '
                          '${next.minLevel}: ${next.minLevel - player.level} '
                          '${next.minLevel - player.level == 1 ? 'level' : 'levels'} to go.',
                  style: text.bodyMedium!.copyWith(height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  '${player.totalXp} XP earned in total. Rank comes only from activity.',
                  style: text.bodySmall!.copyWith(color: Hx.textDim),
                ),
              ],
            ),
          ),
          SectionHeading(
            'Achievements',
            trailing: Text(
              '${player.achievements.length}/${Engine.achievements.length}',
              style: text.labelMedium!.copyWith(color: Hx.textDim),
            ),
          ),
          for (final a in Engine.achievements)
            Builder(builder: (context) {
              final date = player.achievements[a.id];
              final unlocked = date != null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SystemPanel(
                  accent: unlocked ? Hx.gold.withValues(alpha: 0.7) : Hx.line,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        unlocked ? Icons.military_tech : Icons.lock_outline,
                        color: unlocked ? Hx.gold : Hx.textDim,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: text.titleMedium!
                                  .copyWith(color: unlocked ? Hx.text : Hx.textDim),
                            ),
                            Text(
                              a.description,
                              style: text.bodySmall!.copyWith(color: Hx.textDim),
                            ),
                          ],
                        ),
                      ),
                      if (unlocked)
                        Text(
                          friendlyDate(date, todayKey()),
                          style: text.bodySmall!.copyWith(color: Hx.textDim),
                        )
                      else if (a.xp > 0)
                        Tag('+${a.xp} XP'),
                    ],
                  ),
                ),
              );
            }),
          const SectionHeading('Personal bests'),
          if (bests.isEmpty)
            Text(
              'Your best set for each exercise shows up here once you start logging.',
              style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.4),
            )
          else
            SystemPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final e in bests)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.key.name, style: text.titleMedium)),
                          Text(
                            e.key.tracking == Tracking.reps
                                ? '${e.value} reps'
                                : formatSeconds(e.value),
                            style: text.titleMedium!.copyWith(color: Hx.gold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SectionHeading('Recent XP'),
          if (state.xpLog.isEmpty)
            Text(
              'XP you earn is listed here.',
              style: text.bodyMedium!.copyWith(color: Hx.textDim),
            )
          else
            SystemPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final e in state.xpLog.take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 78,
                            child: Text(
                              friendlyDate(e.at.substring(0, 10), todayKey()),
                              style: text.bodySmall!.copyWith(color: Hx.textDim),
                            ),
                          ),
                          Expanded(child: Text(e.label, style: text.bodyLarge)),
                          Text('+${e.amount}', style: text.titleMedium!.copyWith(color: Hx.gold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
