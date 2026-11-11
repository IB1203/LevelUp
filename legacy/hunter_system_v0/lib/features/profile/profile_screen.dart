import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, Player player) async {
    final controller = TextEditingController(text: player.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hunter name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save name'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(appProvider.notifier).updatePlayer((p) => p.name = name);
    }
  }

  /// Opens a sheet with [builder]'s picker and a Save button.
  Future<T?> _pick<T>(
    BuildContext context, {
    required String title,
    String? help,
    required T initial,
    required Widget Function(T value, ValueChanged<T> onChanged) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var value = initial;
        final text = Theme.of(context).textTheme;
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.headlineSmall),
                  if (help != null) ...[
                    const SizedBox(height: 4),
                    Text(help, style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.4)),
                  ],
                  const SizedBox(height: 16),
                  builder(value, (v) => setState(() => value = v)),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(value),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This erases your hunter, level, history and achievements from this '
          'device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my data'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Hx.alert),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all data'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(tabProvider.notifier).go(0);
      await ref.read(appProvider.notifier).resetEverything();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final player = state.player!;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(appProvider.notifier);
    final questStarted = state.dailyQuest?.started ?? false;

    void changed() {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(questStarted
              ? 'Saved. This applies from your next quest.'
              : 'Saved. Today\'s quest has been rebuilt.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          SystemPanel(
            child: Row(
              children: [
                RankEmblem(letter: player.rank.letter, size: 72, variant: player.emblem),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name, style: text.headlineMedium),
                      Text(
                        'Level ${player.level}, rank ${player.rank.letter}. '
                        'Best streak ${player.bestStreak} '
                        '${player.bestStreak == 1 ? 'day' : 'days'}.',
                        style: text.bodyMedium!.copyWith(color: Hx.textDim),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Change name',
                  onPressed: () => _rename(context, ref, player),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SectionHeading('Emblem style'),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Semantics(
                    button: true,
                    selected: player.emblem == i,
                    label: 'Emblem style ${i + 1}',
                    child: InkWell(
                      onTap: () => controller.updatePlayer((p) => p.emblem = i),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: ShapeDecoration(
                          shape: Hx.cut(
                            side: player.emblem == i ? Hx.mana : Colors.transparent,
                            corner: 8,
                          ),
                        ),
                        child: RankEmblem(letter: player.rank.letter, size: 52, variant: i),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SectionHeading('Training profile'),
          _Row(
            title: 'Experience',
            value: player.experience.label,
            onTap: () async {
              final v = await _pick<ExperienceLevel>(
                context,
                title: 'Training experience',
                help: 'Sets how demanding your quests are.',
                initial: player.experience,
                builder: (value, onChanged) => SingleChoice<ExperienceLevel>(
                  options: ExperienceLevel.values,
                  selected: value,
                  label: (e) => e.label,
                  onChanged: onChanged,
                ),
              );
              if (v != null) {
                controller.updatePlayer((p) => p.experience = v, affectsQuests: true);
                changed();
              }
            },
          ),
          _Row(
            title: 'Goal',
            value: player.goal.label,
            onTap: () async {
              final v = await _pick<FitnessGoal>(
                context,
                title: 'Training goal',
                initial: player.goal,
                builder: (value, onChanged) => SingleChoice<FitnessGoal>(
                  options: FitnessGoal.values,
                  selected: value,
                  label: (g) => g.label,
                  onChanged: onChanged,
                ),
              );
              if (v != null) {
                controller.updatePlayer((p) => p.goal = v, affectsQuests: true);
                changed();
              }
            },
          ),
          _Row(
            title: 'Quest length',
            value: '${player.minutes} min',
            onTap: () async {
              final v = await _pick<int>(
                context,
                title: 'Daily quest length',
                initial: player.minutes,
                builder: (value, onChanged) => SingleChoice<int>(
                  options: GameRules.questDurations,
                  selected: value,
                  label: (m) => m == 45 ? '45+ min' : '$m min',
                  onChanged: onChanged,
                ),
              );
              if (v != null) {
                controller.updatePlayer((p) => p.minutes = v, affectsQuests: true);
                changed();
              }
            },
          ),
          _Row(
            title: 'Equipment',
            value: player.equipment.isEmpty
                ? 'Bodyweight only'
                : player.equipment.map((e) => e.label).join(', '),
            onTap: () async {
              final v = await _pick<Set<Equipment>>(
                context,
                title: 'Equipment you can use',
                help: 'Travelling? Clear this to get bodyweight-only quests.',
                initial: {...player.equipment},
                builder: (value, onChanged) => MultiChoice<Equipment>(
                  options: Equipment.values,
                  selected: value,
                  label: (e) => e.label,
                  onChanged: onChanged,
                ),
              );
              if (v != null) {
                controller.updatePlayer((p) => p.equipment = v, affectsQuests: true);
                changed();
              }
            },
          ),
          _Row(
            title: 'Go easy on',
            value: player.limitations.isEmpty
                ? 'Nothing flagged'
                : player.limitations.map((e) => e.label).join(', '),
            onTap: () async {
              final v = await _pick<Set<Limitation>>(
                context,
                title: 'Areas to go easy on',
                help: 'Exercises that load these areas are kept out of your '
                    'quests. This is a training filter, not medical advice.',
                initial: {...player.limitations},
                builder: (value, onChanged) => MultiChoice<Limitation>(
                  options: Limitation.values,
                  selected: value,
                  label: (l) => l.label,
                  onChanged: onChanged,
                ),
              );
              if (v != null) {
                controller.updatePlayer((p) => p.limitations = v, affectsQuests: true);
                changed();
              }
            },
          ),
          const SectionHeading('Feel'),
          SystemPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Reward animations', style: text.titleMedium),
                  subtitle: Text(
                    'XP count-up and level-up effects.',
                    style: text.bodySmall!.copyWith(color: Hx.textDim),
                  ),
                  value: player.animations,
                  onChanged: (v) => controller.updatePlayer((p) => p.animations = v),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Vibration', style: text.titleMedium),
                  subtitle: Text(
                    'A short buzz when a set or rest ends.',
                    style: text.bodySmall!.copyWith(color: Hx.textDim),
                  ),
                  value: player.haptics,
                  onChanged: (v) => controller.updatePlayer((p) => p.haptics = v),
                ),
              ],
            ),
          ),
          const SectionHeading('About'),
          Text(
            'Hunter System keeps everything on this device. There is no account '
            'and nothing is uploaded.\n\n'
            'The app suggests general exercise. It cannot diagnose or treat '
            'anything. Stop if something hurts, and talk to a doctor before '
            'starting if you have a health condition.\n\n'
            'Typeface: Rajdhani by Indian Type Foundry, SIL Open Font License.',
            style: text.bodyMedium!.copyWith(color: Hx.textDim, height: 1.45),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Hx.alert,
              side: const BorderSide(color: Hx.alert),
            ),
            onPressed: () => _reset(context, ref),
            child: const Text('Delete all data'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SystemPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.labelMedium!.copyWith(color: Hx.textDim)),
                  Text(value, style: text.titleMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Hx.textDim),
          ],
        ),
      ),
    );
  }
}
