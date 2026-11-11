import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/exercise_catalog.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import 'exercise_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  ExerciseCategory? _category;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final player = ref.watch(appProvider).player;
    final q = _query.trim().toLowerCase();

    final results = ExerciseCatalog.all.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_onlyMine && player != null) {
        if (!player.equipment.containsAll(e.equipment)) return false;
        if (e.stresses.intersection(player.limitations).isNotEmpty) return false;
      }
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.muscles.toLowerCase().contains(q) ||
          e.pattern.label.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name or muscle',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                FilterChip(
                  label: const Text('Suits me'),
                  selected: _onlyMine,
                  onSelected: (v) => setState(() => _onlyMine = v),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in ExerciseCategory.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No exercises match. Try a shorter search or clear the filters.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge!.copyWith(color: Hx.textDim),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    itemCount: results.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${results.length} exercises',
                            style: text.labelMedium!.copyWith(color: Hx.textDim),
                          ),
                        );
                      }
                      final e = results[i - 1];
                      final best = player?.records[e.id];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SystemPanel(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ExerciseDetailScreen(exerciseId: e.id),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name, style: text.titleMedium),
                                    Text(
                                      '${e.muscles}. ${e.difficultyLabel}, '
                                      '${e.equipmentLabel.toLowerCase()}.',
                                      style: text.bodySmall!.copyWith(color: Hx.textDim),
                                    ),
                                  ],
                                ),
                              ),
                              if (best != null) ...[
                                const SizedBox(width: 8),
                                Tag(
                                  e.tracking == Tracking.reps ? 'Best $best' : 'Best ${best}s',
                                  color: Hx.gold,
                                ),
                              ],
                              const Icon(Icons.chevron_right, color: Hx.textDim),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
