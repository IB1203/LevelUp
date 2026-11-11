import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/engine.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../quests/quest_card.dart';
import '../quests/quest_sheets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Up late';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final player = state.player!;
    final text = Theme.of(context).textTheme;
    final today = todayKey();
    final daily = state.dailyQuest;
    final week = Engine.weekStats(state, today);
    final readiness = state.readiness;
    final extras = state.today.where((q) => q.kind == QuestKind.bonus).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text('${_greeting()}, ${player.name}', style: text.headlineSmall),
          const SizedBox(height: 14),
          _StatusWindow(player: player),
          const SizedBox(height: 18),
          _systemMessage(state, today),
          const SizedBox(height: 10),
          if (daily != null) QuestCard(quest: daily, prominent: true),
          for (final q in extras)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: QuestCard(quest: q),
            ),
          const SectionHeading('Last 7 days'),
          Row(
            children: [
              Expanded(child: _Figure(value: '${week.quests}', label: 'Quests')),
              const SizedBox(width: 10),
              Expanded(child: _Figure(value: '${week.minutes}', label: 'Active min')),
              const SizedBox(width: 10),
              Expanded(child: _Figure(value: '${week.xp}', label: 'XP earned')),
            ],
          ),
          const SectionHeading('Quick actions'),
          _Action(
            icon: Icons.monitor_heart_outlined,
            title: readiness == null ? 'Check in for today' : 'Update today\'s check-in',
            subtitle: readiness == null
                ? 'Tell the System how you feel so it can adjust your quest.'
                : 'Readiness: ${readiness.statusLabel.toLowerCase()}.',
            onTap: () => showReadinessSheet(context),
          ),
          _Action(
            icon: Icons.menu_book_outlined,
            title: 'Browse exercises',
            subtitle: 'Instructions and alternatives for every movement.',
            onTap: () => ref.read(tabProvider.notifier).go(2),
          ),
          _Action(
            icon: Icons.insights_outlined,
            title: 'See your progress',
            subtitle: '${player.achievements.length} of ${Engine.achievements.length} '
                'achievements unlocked.',
            onTap: () => ref.read(tabProvider.notifier).go(3),
          ),
        ],
      ),
    );
  }

  Widget _systemMessage(AppState state, String today) {
    final player = state.player!;
    final daily = state.dailyQuest;
    if (state.readiness?.pain ?? false) {
      return const SystemLine('Rest advised. Your streak is protected today', color: Hx.alert);
    }
    if (daily != null && daily.status == QuestStatus.completed) {
      return const SystemLine('Daily quest complete. Recover well', color: Hx.vital);
    }
    if (Engine.streakAtRisk(state, today)) {
      return SystemLine(
        'Your ${player.streak}-day streak is at risk. Today\'s quest saves it',
        color: Hx.violet,
      );
    }
    if (daily != null && daily.kind == QuestKind.comeback) {
      return const SystemLine('Welcome back, hunter. Nothing was lost', color: Hx.violet);
    }
    if (daily != null && daily.isRecovery) {
      return const SystemLine('Recovery is scheduled for today', color: Hx.vital);
    }
    if (daily != null && daily.started) {
      return const SystemLine('Quest in progress');
    }
    return const SystemLine('A daily quest has arrived');
  }
}

/// The player's status window: rank, level, XP and streak in one glance.
class _StatusWindow extends StatelessWidget {
  const _StatusWindow({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rank = player.rank;
    final next = GameRules.nextRank(player.level);
    final color = RankEmblem.colorFor(rank.letter);

    return SystemPanel(
      accent: color,
      glow: true,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              RankEmblem(letter: rank.letter, size: 92, variant: player.emblem),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level ${player.level}', style: text.displaySmall),
                    Text(
                      'Rank ${rank.letter}, ${rank.title.toLowerCase()}',
                      style: text.titleSmall!.copyWith(color: color),
                    ),
                    const SizedBox(height: 10),
                    XpBar(progress: player.levelProgress),
                    const SizedBox(height: 5),
                    Text(
                      '${player.xp} / ${player.xpToNext} XP to level ${player.level + 1}',
                      style: text.bodySmall!.copyWith(color: Hx.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              _mini(text, '${player.streak}', 'Day streak'),
              _mini(text, '${player.questsCompleted}', 'Quests done'),
              _mini(
                text,
                next == null ? 'Max' : 'Lv ${next.minLevel}',
                next == null ? 'Top rank' : 'Rank ${next.letter} at',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(TextTheme text, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.headlineSmall),
          Text(label, style: text.bodySmall!.copyWith(color: Hx.textDim)),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SystemPanel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(value, style: text.headlineMedium),
          Text(label, style: text.bodySmall!.copyWith(color: Hx.textDim)),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
            Icon(icon, color: Hx.mana),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(subtitle, style: text.bodySmall!.copyWith(color: Hx.textDim)),
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
