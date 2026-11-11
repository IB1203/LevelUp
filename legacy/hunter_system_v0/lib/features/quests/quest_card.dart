import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../workout/workout_screen.dart';
import 'quest_detail_screen.dart';

Color questColor(Quest q) {
  if (q.isRecovery) return Hx.vital;
  if (q.kind == QuestKind.comeback) return Hx.violet;
  if (q.kind == QuestKind.bonus) return Hx.gold;
  return Hx.mana;
}

String questKindLabel(Quest q) {
  switch (q.kind) {
    case QuestKind.daily:
      return q.isRecovery ? 'Recovery quest' : 'Daily quest';
    case QuestKind.comeback:
      return 'Comeback quest';
    case QuestKind.bonus:
      return 'Bonus quest';
  }
}

void openQuest(BuildContext context, Quest quest) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => QuestDetailScreen(questId: quest.id)),
  );
}

void startWorkout(BuildContext context, Quest quest) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => WorkoutScreen(questId: quest.id)),
  );
}

/// The main quest summary, used on Home and in the Quests tab.
class QuestCard extends StatelessWidget {
  const QuestCard({super.key, required this.quest, this.prominent = false});

  final Quest quest;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = questColor(quest);
    final pending = quest.status == QuestStatus.pending;

    return SystemPanel(
      accent: pending ? color : Hx.line,
      glow: prominent && pending,
      onTap: () => openQuest(context, quest),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  questKindLabel(quest),
                  style: text.labelMedium!.copyWith(color: color),
                ),
              ),
              if (quest.status == QuestStatus.completed)
                Tag('Complete  +${quest.xpEarned} XP', color: Hx.gold, icon: Icons.check)
              else if (quest.status == QuestStatus.missed)
                const Tag('Missed')
              else
                Tag('+${quest.xpReward} XP', color: Hx.gold),
            ],
          ),
          const SizedBox(height: 6),
          Text(quest.title, style: prominent ? text.headlineMedium : text.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Tag('${quest.minutes} min', icon: Icons.schedule),
              Tag('${quest.tasks.length} exercises', icon: Icons.list),
              Tag(quest.focus.label),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 14),
            if (quest.started) ...[
              XpBar(progress: quest.progress, color: color, height: 8),
              const SizedBox(height: 6),
              Text(
                '${quest.doneSets} of ${quest.totalSets} sets done',
                style: text.bodySmall!.copyWith(color: Hx.textDim),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => startWorkout(context, quest),
                    child: Text(quest.started ? 'Continue quest' : 'Start quest'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => openQuest(context, quest),
                  child: const Text('Details'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
