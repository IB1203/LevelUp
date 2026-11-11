import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/engine.dart';
import '../../domain/exercise_catalog.dart';
import '../../state/app_controller.dart';

/// Shown once after a quest closes. This is the one place the app spends its
/// animation budget: the XP count and the level-up emblem.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.result});

  final QuestResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final player = ref.watch(appProvider).player;
    final animate = player?.animations ?? true;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = animate && !reduceMotion
        ? const Duration(milliseconds: 1100)
        : Duration.zero;
    final quest = result.quest;
    final total = quest.xpEarned + result.achievementXp;
    final full = quest.progress >= 0.999;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                children: [
                  SystemLine(full ? 'Quest complete' : 'Quest closed', center: true),
                  const SizedBox(height: 6),
                  Text(quest.title, style: text.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: total.toDouble()),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '+${value.round()} XP',
                        style: text.displaySmall!.copyWith(fontSize: 72, color: Hx.gold),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${quest.doneSets} of ${quest.totalSets} sets, '
                      'about ${(quest.minutes * quest.progress).round()} min',
                      style: text.titleSmall!.copyWith(color: Hx.textDim),
                    ),
                  ),
                  if (result.leveledUp) ...[
                    const SizedBox(height: 24),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: animate && !reduceMotion ? 0.6 : 1.0, end: 1.0),
                      duration: duration,
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: SystemPanel(
                        accent: RankEmblem.colorFor(result.rankAfter.letter),
                        glow: true,
                        child: Row(
                          children: [
                            RankEmblem(
                              letter: result.rankAfter.letter,
                              size: 76,
                              variant: player?.emblem ?? 0,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SystemLine(result.rankedUp ? 'Rank up' : 'Level up'),
                                  Text('Level ${result.levelAfter}', style: text.headlineMedium),
                                  Text(
                                    result.rankedUp
                                        ? 'You are now a ${result.rankAfter.letter}-rank hunter '
                                            '(${result.rankAfter.title.toLowerCase()}).'
                                        : 'Up from level ${result.levelBefore}.',
                                    style: text.bodyMedium!.copyWith(color: Hx.textDim),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SectionHeading('Reward breakdown'),
                  SystemPanel(
                    child: Column(
                      children: [
                        _line(text, 'Quest work', '+${result.baseXp} XP'),
                        if (result.streakBonusXp > 0)
                          _line(text, '${result.streak}-day streak bonus',
                              '+${result.streakBonusXp} XP'),
                        for (final a in result.achievements)
                          if (a.xp > 0) _line(text, a.title, '+${a.xp} XP'),
                        const Divider(height: 20),
                        _line(text, 'Active streak',
                            '${result.streak} ${result.streak == 1 ? 'day' : 'days'}'),
                      ],
                    ),
                  ),
                  if (result.achievements.isNotEmpty) ...[
                    const SectionHeading('Achievements unlocked'),
                    for (final a in result.achievements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SystemPanel(
                          accent: Hx.gold,
                          child: Row(
                            children: [
                              const Icon(Icons.military_tech, color: Hx.gold, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.title, style: text.titleMedium),
                                    Text(a.description,
                                        style: text.bodySmall!.copyWith(color: Hx.textDim)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (quest.personalBests.isNotEmpty) ...[
                    const SectionHeading('Personal bests'),
                    for (final id in quest.personalBests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, color: Hx.gold, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(ExerciseCatalog.byId(id).name, style: text.titleMedium),
                            ),
                            Text(
                              '${player?.records[id] ?? ''}',
                              style: text.titleMedium!.copyWith(color: Hx.gold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref.read(tabProvider.notifier).go(0);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Return to status'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(TextTheme text, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          Text(value, style: text.titleMedium),
        ],
      ),
    );
  }
}
