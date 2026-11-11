import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../domain/quest_generator.dart';
import '../../state/app_controller.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final e = ExerciseCatalog.byId(exerciseId);
    final player = ref.watch(appProvider).player;
    final best = player?.records[e.id];
    final flagged = player == null
        ? <Limitation>{}
        : e.stresses.intersection(player.limitations);
    final alternatives =
        player == null ? <Exercise>[] : QuestGenerator.alternatives(player, e);

    return Scaffold(
      appBar: AppBar(title: Text(e.category.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(e.name, style: text.displaySmall),
          const SizedBox(height: 4),
          Text(e.muscles, style: text.bodyLarge!.copyWith(color: Hx.textDim)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Tag(e.difficultyLabel, color: Hx.mana),
              Tag(e.equipmentLabel),
              Tag(e.pattern.label),
              Tag('Trains ${e.attribute.label}', color: Hx.violet),
              if (e.impact == Impact.high) const Tag('High impact', color: Hx.alert),
            ],
          ),
          if (flagged.isNotEmpty) ...[
            const SizedBox(height: 16),
            SystemPanel(
              accent: Hx.alert,
              padding: const EdgeInsets.all(12),
              child: Text(
                'This loads your ${flagged.map((l) => l.label.toLowerCase()).join(' and ')}, '
                'which you asked the System to go easy on. It is left out of your quests.',
                style: text.bodyMedium!.copyWith(height: 1.4),
              ),
            ),
          ],
          if (best != null) ...[
            const SizedBox(height: 16),
            SystemPanel(
              accent: Hx.gold,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Hx.gold),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Your best set', style: text.titleMedium)),
                  Text(
                    e.tracking == Tracking.reps ? '$best reps' : formatSeconds(best),
                    style: text.titleLarge!.copyWith(color: Hx.gold),
                  ),
                ],
              ),
            ),
          ],
          const SectionHeading('How to do it'),
          for (var i = 0; i < e.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}', style: text.titleLarge!.copyWith(color: Hx.mana)),
                  ),
                  Expanded(child: Text(e.steps[i], style: text.bodyLarge!.copyWith(height: 1.45))),
                ],
              ),
            ),
          SystemPanel(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: Hx.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(e.cue, style: text.bodyMedium!.copyWith(height: 1.4))),
              ],
            ),
          ),
          if (alternatives.isNotEmpty) ...[
            const SectionHeading('Alternatives you can do'),
            for (final a in alternatives)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SystemPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExerciseDetailScreen(exerciseId: a.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: text.titleMedium),
                            Text(
                              '${a.difficultyLabel}, ${a.equipmentLabel.toLowerCase()}',
                              style: text.bodySmall!.copyWith(color: Hx.textDim),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Hx.textDim),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
