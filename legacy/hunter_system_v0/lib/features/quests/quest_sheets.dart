import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../domain/quest_generator.dart';
import '../../state/app_controller.dart';

// ---------------------------------------------------------------------------
// Readiness check
// ---------------------------------------------------------------------------

Future<void> showReadinessSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ReadinessSheet(),
  );
}

class _ReadinessSheet extends ConsumerStatefulWidget {
  const _ReadinessSheet();

  @override
  ConsumerState<_ReadinessSheet> createState() => _ReadinessSheetState();
}

class _ReadinessSheetState extends ConsumerState<_ReadinessSheet> {
  int _energy = 2;
  int _soreness = 2;
  int _sleep = 2;
  bool _pain = false;

  @override
  void initState() {
    super.initState();
    final r = ref.read(appProvider).readiness;
    if (r != null) {
      _energy = r.energy;
      _soreness = r.soreness;
      _sleep = r.sleep;
      _pain = r.pain;
    }
  }

  Widget _scale(String title, int value, List<String> labels, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < 3; i++)
                  ButtonSegment(value: i + 1, label: Text(labels[i])),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final started = ref.watch(appProvider).dailyQuest?.started ?? false;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How are you today?', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              started
                  ? 'Today\'s quest is already under way, so it will stay as it is. '
                      'Your answers still shape any further quests today.'
                  : 'The System adjusts today\'s quest to your answers.',
              style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.4),
            ),
            const SizedBox(height: 20),
            _scale('Energy', _energy, const ['Drained', 'Okay', 'Strong'],
                (v) => setState(() => _energy = v)),
            _scale('Muscle soreness', _soreness, const ['Fresh', 'A little', 'Very sore'],
                (v) => setState(() => _soreness = v)),
            _scale('Last night\'s sleep', _sleep, const ['Poor', 'Fair', 'Good'],
                (v) => setState(() => _sleep = v)),
            SystemPanel(
              accent: _pain ? Hx.alert : Hx.line,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pain,
                onChanged: (v) => setState(() => _pain = v),
                title: Text('I\'m in pain, injured or unwell', style: text.titleMedium),
                subtitle: Text(
                  'Switches today to gentle movement and protects your streak.',
                  style: text.bodySmall!.copyWith(color: Hx.textDim),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(appProvider.notifier).submitReadiness(
                        energy: _energy,
                        soreness: _soreness,
                        sleep: _sleep,
                        pain: _pain,
                      );
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(started
                          ? 'Check-in saved.'
                          : 'Check-in saved. Today\'s quest has been adjusted.'),
                    ),
                  );
                },
                child: const Text('Save check-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Replace an exercise
// ---------------------------------------------------------------------------

/// Returns the id of the chosen replacement, or null if dismissed.
Future<String?> showSwapSheet(
  BuildContext context, {
  required Player player,
  required Quest quest,
  required int taskIndex,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SwapSheet(player: player, quest: quest, taskIndex: taskIndex),
  );
}

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.player, required this.quest, required this.taskIndex});

  final Player player;
  final Quest quest;
  final int taskIndex;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  static const _reasons = [
    'No equipment',
    'Too difficult',
    'Uncomfortable',
    'Pain or injury',
    'Just don\'t like it',
  ];
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final current = ExerciseCatalog.byId(widget.quest.tasks[widget.taskIndex].exerciseId);
    final inQuest = widget.quest.tasks.map((t) => t.exerciseId).toSet();
    var options = QuestGenerator.alternatives(widget.player, current, exclude: inQuest);
    if (_reason == 'Too difficult' || _reason == 'Pain or injury') {
      final easier = options.where((e) => e.difficulty <= current.difficulty).toList();
      if (easier.isNotEmpty) options = easier;
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Replace ${current.name}', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'A replacement keeps the quest\'s full reward.',
                style: text.bodyMedium!.copyWith(color: Hx.textDim),
              ),
              const SizedBox(height: 16),
              Text('What\'s the reason?', style: text.titleMedium),
              const SizedBox(height: 8),
              SingleChoice<String>(
                options: _reasons,
                selected: _reason,
                label: (r) => r,
                onChanged: (r) => setState(() => _reason = r),
              ),
              if (_reason == 'Pain or injury') ...[
                const SizedBox(height: 14),
                SystemPanel(
                  accent: Hx.alert,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'These options are easier on the body, but the System can\'t '
                    'assess an injury. If the pain is sharp or keeps returning, '
                    'stop and get it checked. You can also skip this exercise.',
                    style: text.bodyMedium!.copyWith(height: 1.4),
                  ),
                ),
              ],
              if (_reason != null) ...[
                const SizedBox(height: 18),
                Text('Choose a replacement', style: text.titleMedium),
                const SizedBox(height: 8),
                if (options.isEmpty)
                  Text(
                    'Nothing in the library matches this movement with your '
                    'equipment and limits. Skip the exercise instead: the rest '
                    'of the quest still counts.',
                    style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.4),
                  ),
                for (final e in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SystemPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => Navigator.of(context).pop(e.id),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.name, style: text.titleMedium),
                                Text(
                                  '${e.difficultyLabel}, ${e.equipmentLabel.toLowerCase()}',
                                  style: text.bodySmall!.copyWith(color: Hx.textDim),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.swap_horiz, color: Hx.mana),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request a quest
// ---------------------------------------------------------------------------

class QuestRequest {
  const QuestRequest(this.minutes, this.focus);
  final int minutes;
  final QuestFocus? focus;
}

Future<QuestRequest?> showQuestRequestSheet(
  BuildContext context, {
  required String title,
  required String help,
  required int initialMinutes,
  required String action,
}) {
  return showModalBottomSheet<QuestRequest>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RequestSheet(
      title: title,
      help: help,
      initialMinutes: initialMinutes,
      action: action,
    ),
  );
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({
    required this.title,
    required this.help,
    required this.initialMinutes,
    required this.action,
  });

  final String title;
  final String help;
  final int initialMinutes;
  final String action;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late int _minutes = widget.initialMinutes;
  QuestFocus? _focus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const focuses = [
      QuestFocus.fullBody,
      QuestFocus.upper,
      QuestFocus.lower,
      QuestFocus.cardio,
      QuestFocus.mobility,
      QuestFocus.recovery,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(widget.help, style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.4)),
            const SizedBox(height: 18),
            Text('Time available', style: text.titleMedium),
            const SizedBox(height: 8),
            SingleChoice<int>(
              options: GameRules.questDurations,
              selected: _minutes,
              label: (m) => m == 45 ? '45+ min' : '$m min',
              onChanged: (m) => setState(() => _minutes = m),
            ),
            const SizedBox(height: 18),
            Text('Focus', style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('System\'s choice'),
                  selected: _focus == null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _focus = null),
                ),
                for (final f in focuses)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _focus == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _focus = f),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(QuestRequest(_minutes, _focus)),
                child: Text(widget.action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
