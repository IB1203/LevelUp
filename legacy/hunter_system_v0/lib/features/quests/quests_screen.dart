import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/engine.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import 'quest_card.dart';
import 'quest_sheets.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  String _bonusExplanation(AppState s) {
    final daily = s.dailyQuest;
    if (s.readiness?.pain ?? false) {
      return 'Bonus quests are off while you are resting. They will be back.';
    }
    if (daily == null || daily.status == QuestStatus.pending) {
      return 'Finish today\'s main quest to unlock bonus quests.';
    }
    if (s.bonusQuestsToday >= GameRules.maxBonusQuestsPerDay) {
      return 'You have taken ${GameRules.maxBonusQuestsPerDay} bonus quests today. '
          'That is the daily limit: recovery is part of training.';
    }
    return 'Finish your current bonus quest before asking for another.';
  }

  Future<void> _requestBonus(BuildContext context, WidgetRef ref) async {
    final request = await showQuestRequestSheet(
      context,
      title: 'Request a bonus quest',
      help: 'Extra quests pay half XP, and you can take up to '
          '${GameRules.maxBonusQuestsPerDay} a day.',
      initialMinutes: 10,
      action: 'Generate quest',
    );
    if (request == null) return;
    final quest = ref
        .read(appProvider.notifier)
        .addBonusQuest(minutes: request.minutes, focus: request.focus);
    if (quest != null && context.mounted) openQuest(context, quest);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final text = Theme.of(context).textTheme;
    final today = todayKey();
    final readiness = state.readiness;
    final canBonus = Engine.canAddBonusQuest(state);

    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          for (final q in state.today)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuestCard(quest: q, prominent: q.kind != QuestKind.bonus),
            ),
          SystemPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => showReadinessSheet(context),
            child: Row(
              children: [
                const Icon(Icons.monitor_heart_outlined, color: Hx.vital),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        readiness == null
                            ? 'Check in for today'
                            : 'Readiness: ${readiness.statusLabel.toLowerCase()}',
                        style: text.titleMedium,
                      ),
                      Text(
                        readiness == null
                            ? 'Energy, soreness and sleep shape your quest.'
                            : 'Tap to update your check-in.',
                        style: text.bodySmall!.copyWith(color: Hx.textDim),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Hx.textDim),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (canBonus)
            OutlinedButton.icon(
              onPressed: () => _requestBonus(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Request a bonus quest'),
            )
          else
            Text(
              _bonusExplanation(state),
              style: text.bodySmall!.copyWith(color: Hx.textDim, height: 1.4),
            ),
          const SectionHeading('History'),
          if (state.history.isEmpty)
            Text(
              'Finished quests appear here from tomorrow. Complete today\'s '
              'quest to start your record.',
              style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.4),
            ),
          for (final q in state.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SystemPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => openQuest(context, q),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        friendlyDate(q.dateKey, today),
                        style: text.labelMedium!.copyWith(color: Hx.textDim),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.title, style: text.titleMedium),
                          Text(
                            '${questKindLabel(q)}, ${q.minutes} min',
                            style: text.bodySmall!.copyWith(color: Hx.textDim),
                          ),
                        ],
                      ),
                    ),
                    if (q.status == QuestStatus.completed)
                      Tag('+${q.xpEarned} XP', color: Hx.gold)
                    else
                      const Tag('Missed'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
