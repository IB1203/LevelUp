import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../library/exercise_detail_screen.dart';
import 'quest_card.dart';
import 'quest_sheets.dart';

class QuestDetailScreen extends ConsumerStatefulWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  @override
  ConsumerState<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends ConsumerState<QuestDetailScreen> {
  late String _id = widget.questId;

  Future<void> _change(Quest quest) async {
    final request = await showQuestRequestSheet(
      context,
      title: 'Change today\'s quest',
      help: 'Short on time, or want something different? The System will '
          'rebuild the quest. Safety adjustments from your check-in still apply.',
      initialMinutes: ref.read(appProvider).player?.minutes ?? 15,
      action: 'Rebuild quest',
    );
    if (request == null || !mounted) return;
    final controller = ref.read(appProvider.notifier);
    if (controller.regenerateDaily(minutes: request.minutes, focus: request.focus)) {
      setState(() => _id = ref.read(appProvider).dailyQuest!.id);
    }
  }

  Future<void> _swap(Quest quest, int index) async {
    final player = ref.read(appProvider).player!;
    final id = await showSwapSheet(context, player: player, quest: quest, taskIndex: index);
    if (id == null || !mounted) return;
    ref.read(appProvider.notifier).swapTask(quest, index, id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final quest = state.findQuest(_id);
    final text = Theme.of(context).textTheme;

    if (quest == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This quest is no longer available.')),
      );
    }

    final color = questColor(quest);
    final pending = quest.status == QuestStatus.pending;
    final canChange = pending && !quest.started && quest.kind != QuestKind.bonus;

    return Scaffold(
      appBar: AppBar(title: Text(questKindLabel(quest))),
      bottomNavigationBar: pending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: () => startWorkout(context, quest),
                  child: Text(quest.started ? 'Continue quest' : 'Start quest'),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(quest.title, style: text.displaySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Tag('${quest.minutes} min', icon: Icons.schedule),
              Tag(quest.focus.label, color: color),
              Tag(quest.difficultyLabel),
              if (quest.status == QuestStatus.completed)
                Tag('Earned ${quest.xpEarned} XP', color: Hx.gold, icon: Icons.check)
              else if (quest.status == QuestStatus.missed)
                const Tag('Missed')
              else
                Tag('Reward ${quest.xpReward} XP', color: Hx.gold),
            ],
          ),
          if (quest.safetyNote != null) ...[
            const SizedBox(height: 16),
            SystemPanel(
              accent: Hx.alert,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.health_and_safety_outlined, color: Hx.alert),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(quest.safetyNote!, style: text.bodyMedium!.copyWith(height: 1.45)),
                  ),
                ],
              ),
            ),
          ],
          if (quest.reason.isNotEmpty) ...[
            const SizedBox(height: 16),
            SystemPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SystemLine('Why this quest'),
                  const SizedBox(height: 8),
                  Text(quest.reason, style: text.bodyMedium!.copyWith(height: 1.45)),
                  if (canChange) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => _change(quest),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Change time or focus'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SectionHeading('Objectives',
              trailing: Text('${quest.doneSets}/${quest.totalSets} sets',
                  style: text.labelMedium!.copyWith(color: Hx.textDim))),
          for (var i = 0; i < quest.tasks.length; i++)
            _TaskRow(
              task: quest.tasks[i],
              onInfo: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseDetailScreen(exerciseId: quest.tasks[i].exerciseId),
                ),
              ),
              onSwap: pending && quest.tasks[i].setsDone == 0 && !quest.tasks[i].skipped
                  ? () => _swap(quest, i)
                  : null,
            ),
          if (pending)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'XP is paid for the work you actually do. Stopping early still '
                'earns its share, and replacing an exercise costs nothing.',
                style: text.bodySmall!.copyWith(color: Hx.textDim, height: 1.4),
              ),
            ),
          if (quest.personalBests.isNotEmpty) ...[
            const SectionHeading('Personal bests'),
            for (final id in quest.personalBests)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Hx.gold, size: 18),
                    const SizedBox(width: 8),
                    Text(ExerciseCatalog.byId(id).name, style: text.titleMedium),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onInfo, this.onSwap});

  final QuestTask task;
  final VoidCallback onInfo;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = ExerciseCatalog.byId(task.exerciseId);
    final done = task.setsDone >= task.sets;
    final IconData icon;
    final Color iconColor;
    if (task.skipped) {
      icon = Icons.remove_circle_outline;
      iconColor = Hx.textDim;
    } else if (done) {
      icon = Icons.check_circle;
      iconColor = Hx.vital;
    } else {
      icon = Icons.radio_button_unchecked;
      iconColor = Hx.line;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SystemPanel(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        onTap: onInfo,
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: text.titleMedium),
                    Text(
                      [
                        task.targetLabel + (e.perSide ? ' each side' : ''),
                        if (task.skipped) 'skipped',
                        if (!task.skipped && task.setsDone > 0 && !done)
                          '${task.setsDone} done',
                        if (task.swappedFrom != null)
                          'replaces ${ExerciseCatalog.byId(task.swappedFrom!).name.toLowerCase()}',
                      ].join(', '),
                      style: text.bodySmall!.copyWith(color: Hx.textDim),
                    ),
                  ],
                ),
              ),
            ),
            if (onSwap != null)
              IconButton(
                tooltip: 'Replace exercise',
                onPressed: onSwap,
                icon: const Icon(Icons.swap_horiz, color: Hx.mana),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
