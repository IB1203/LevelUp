import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../quests/quest_card.dart';
import '../quests/quest_sheets.dart';
import 'workout_summary_screen.dart';

/// Guides the player through a quest one set at a time. Progress is saved
/// after every set, so leaving this screen never loses work.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.questId});

  final String questId;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int _index = 0;
  int _count = 0; // reps entered for the current set
  int _elapsed = 0; // seconds run on the current timed set
  bool _running = false;
  bool _resting = false;
  int _restLeft = 0;
  bool _lastWasBest = false;
  Timer? _ticker;

  Quest? get _quest => ref.read(appProvider).findQuest(widget.questId);

  @override
  void initState() {
    super.initState();
    final q = _quest;
    if (q != null) _loadTask(q, _firstOpen(q));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _firstOpen(Quest q) {
    final i = q.tasks.indexWhere((t) => !t.finished);
    return i < 0 ? 0 : i;
  }

  void _loadTask(Quest q, int index) {
    _index = index;
    _count = q.tasks[index].target;
    _elapsed = 0;
    _running = false;
  }

  void _buzz() {
    if (ref.read(appProvider).player?.haptics ?? false) {
      HapticFeedback.mediumImpact();
    }
  }

  void _tick() {
    if (!mounted) return;
    final q = _quest;
    if (q == null || q.status != QuestStatus.pending) return;
    if (_resting) {
      if (_restLeft <= 1) {
        _buzz();
        _endRest();
      } else {
        setState(() => _restLeft--);
      }
    } else if (_running) {
      final task = q.tasks[_index];
      setState(() => _elapsed++);
      if (_elapsed >= task.target) {
        _buzz();
        _completeSet();
      }
    }
  }

  void _endRest() {
    final q = _quest;
    if (q == null) return;
    setState(() {
      _resting = false;
      _lastWasBest = false;
      _loadTask(q, _firstOpen(q));
    });
  }

  void _completeSet() {
    final q = _quest;
    if (q == null) return;
    final task = q.tasks[_index];
    final amount = task.tracking == Tracking.reps
        ? _count
        : (_elapsed > 0 ? _elapsed : task.target);
    final best = ref.read(appProvider.notifier).logSet(q, _index, amount);
    _buzz();

    if (q.allTasksFinished) {
      _finish();
      return;
    }
    setState(() {
      _running = false;
      _lastWasBest = best;
      _resting = true;
      _restLeft = task.restSeconds;
    });
  }

  void _skip() {
    final q = _quest;
    if (q == null) return;
    ref.read(appProvider.notifier).skipTask(q, _index);
    if (q.allTasksFinished) {
      _finish();
    } else {
      setState(() => _loadTask(q, _firstOpen(q)));
    }
  }

  Future<void> _replace() async {
    final q = _quest;
    final player = ref.read(appProvider).player;
    if (q == null || player == null) return;
    setState(() => _running = false);
    final id = await showSwapSheet(context, player: player, quest: q, taskIndex: _index);
    if (id == null || !mounted) return;
    ref.read(appProvider.notifier).swapTask(q, _index, id);
    setState(() => _loadTask(q, _index));
  }

  void _finish() {
    final q = _quest;
    if (q == null) return;
    final result = ref.read(appProvider.notifier).finishQuest(q);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quest closed. No sets were logged, so no XP was paid.')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => WorkoutSummaryScreen(result: result)),
    );
  }

  Future<void> _confirmFinishEarly() async {
    final q = _quest;
    if (q == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish quest early?'),
        content: Text(
          q.doneSets == 0
              ? 'No sets are logged yet, so the quest will close without XP. '
                  'To come back later instead, just leave this screen.'
              : 'You will be paid for the ${q.doneSets} of ${q.totalSets} sets '
                  'you have done. The quest cannot be reopened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish early'),
          ),
        ],
      ),
    );
    if (ok == true) _finish();
  }

  void _showHowTo(Exercise e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.name, style: text.headlineSmall),
                Text(e.muscles, style: text.bodyMedium!.copyWith(color: Hx.textDim)),
                const SizedBox(height: 16),
                for (var i = 0; i < e.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text('${i + 1}', style: text.titleMedium!.copyWith(color: Hx.mana)),
                        ),
                        Expanded(
                          child: Text(e.steps[i], style: text.bodyLarge!.copyWith(height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                SystemPanel(
                  padding: const EdgeInsets.all(12),
                  child: Text(e.cue, style: text.bodyMedium!.copyWith(height: 1.4)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final quest = state.findQuest(widget.questId);
    final text = Theme.of(context).textTheme;

    if (quest == null || quest.status != QuestStatus.pending || quest.allTasksFinished) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This quest is closed.')),
      );
    }

    final index = _index.clamp(0, quest.tasks.length - 1);
    final task = quest.tasks[index];
    final exercise = ExerciseCatalog.byId(task.exerciseId);
    final color = questColor(quest);

    return Scaffold(
      appBar: AppBar(
        title: Text(quest.title),
        actions: [
          TextButton(onPressed: _confirmFinishEarly, child: const Text('Finish early')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              XpBar(progress: quest.progress, color: color, height: 8),
              const SizedBox(height: 6),
              Text(
                '${quest.doneSets} of ${quest.totalSets} sets done',
                style: text.bodySmall!.copyWith(color: Hx.textDim),
              ),
              Expanded(
                child: _resting
                    ? _rest(text, quest)
                    : _work(text, task, exercise, index, quest.tasks.length),
              ),
              if (_resting)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() => _restLeft += 15),
                      child: const Text('+15 sec'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(onPressed: _endRest, child: const Text('Skip rest')),
                    ),
                  ],
                )
              else ...[
                FilledButton(onPressed: _completeSet, child: const Text('Complete set')),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => _showHowTo(exercise), child: const Text('How to')),
                    TextButton(
                      onPressed: task.setsDone == 0 ? _replace : null,
                      child: const Text('Replace'),
                    ),
                    TextButton(onPressed: _skip, child: const Text('Skip exercise')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _work(TextTheme text, QuestTask task, Exercise e, int index, int total) {
    final timed = task.tracking == Tracking.seconds;
    final remaining = (task.target - _elapsed).clamp(0, task.target);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            'Exercise ${index + 1} of $total',
            style: text.labelMedium!.copyWith(color: Hx.textDim),
          ),
          const SizedBox(height: 6),
          Text(e.name, style: text.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Tag('Set ${task.setsDone + 1} of ${task.sets}', color: Hx.mana),
              if (e.perSide) const Tag('Each side'),
              Tag(e.equipmentLabel),
            ],
          ),
          const SizedBox(height: 28),
          if (timed) ...[
            Semantics(
              liveRegion: false,
              label: '$remaining seconds left',
              child: ExcludeSemantics(
                child: Text(
                  formatClock(remaining),
                  style: text.displaySmall!.copyWith(fontSize: 88, color: Hx.mana),
                ),
              ),
            ),
            Text(
              'Target ${formatSeconds(task.target)}',
              style: text.titleSmall!.copyWith(color: Hx.textDim),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _running = !_running),
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running
                  ? 'Pause timer'
                  : _elapsed > 0
                      ? 'Resume timer'
                      : 'Start timer'),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'One rep fewer',
                  iconSize: 30,
                  onPressed: _count > 0 ? () => setState(() => _count--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    '$_count',
                    textAlign: TextAlign.center,
                    style: text.displaySmall!.copyWith(fontSize: 96, color: Hx.mana),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'One rep more',
                  iconSize: 30,
                  onPressed: () => setState(() => _count++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(
              'Target ${task.target} reps. Adjust to what you actually did.',
              style: text.titleSmall!.copyWith(color: Hx.textDim),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }

  Widget _rest(TextTheme text, Quest quest) {
    final nextIndex = _firstOpen(quest);
    final next = quest.tasks[nextIndex];
    final nextExercise = ExerciseCatalog.byId(next.exerciseId);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          if (_lastWasBest) ...[
            const SystemLine('New personal best', color: Hx.gold, center: true),
            const SizedBox(height: 18),
          ],
          Text('Rest', style: text.headlineMedium!.copyWith(color: Hx.vital)),
          ExcludeSemantics(
            child: Text(
              formatClock(_restLeft),
              style: text.displaySmall!.copyWith(fontSize: 96, color: Hx.vital),
            ),
          ),
          const SizedBox(height: 24),
          SystemPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Up next', style: text.labelMedium!.copyWith(color: Hx.textDim)),
                      Text(nextExercise.name, style: text.titleLarge),
                      Text(
                        'Set ${next.setsDone + 1} of ${next.sets}, '
                        '${next.tracking == Tracking.reps ? '${next.target} reps' : formatSeconds(next.target)}',
                        style: text.bodyMedium!.copyWith(color: Hx.textDim),
                      ),
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
