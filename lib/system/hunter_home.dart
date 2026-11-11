import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/entrance.dart';
import '../widgets/ui_kit.dart';
import 'hunter_catalog.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'system_screen.dart';
import 'system_sheets.dart';
import 'system_widgets.dart';

/// The home tab: the hunter's dashboard and today's quest board.
class HunterHome extends StatelessWidget {
  const HunterHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hunter,
      builder: (context, _) {
        final s = hunter.status;
        return RiseScope(
          id: 'hunter-home',
          child: SafeArea(
            bottom: false,
            child: ListView(
              key: const PageStorageKey('hunter-home'),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
              children: riseAll([
                _topBar(context, s),
                const SizedBox(height: 20),
                if (!s.registered) ..._unregistered(context) else ..._registered(context, s),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(t.longDate(DateTime.now())),
              const SizedBox(height: 4),
              Text(
                s.registered ? 'Hi, ${s.player!.name}' : 'Hunter System',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(28, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.4),
              ),
            ],
          ),
        ),
        if (s.registered)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => showInboxSheet(context),
                icon: Icon(PhosphorIconsRegular.bell, color: gc.text),
              ),
              if (s.unreadNotes > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Sx.alert, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${s.unreadNotes > 99 ? '99+' : s.unreadNotes}',
                      style: AppTheme.f(10.5, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  List<Widget> _unregistered(BuildContext context) {
    final gc = context.gc;
    return [
      SystemWindow(
        title: 'Notice',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: RankEmblem(letter: '?', size: 80)),
            const SizedBox(height: 14),
            Text(
              'You have acquired the qualifications to be a Player.',
              textAlign: TextAlign.center,
              style: Sx.disp(19, color: gc.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Register to start at E-Rank, Level 1. Your existing workout log stays as it is.',
              textAlign: TextAlign.center,
              style: AppTheme.s(13.5, color: gc.textSecondary),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Register as a hunter', onTap: () => fit.pushRoute('register')),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _trainingHub(context),
    ];
  }

  List<Widget> _registered(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final board = s.todayQuests;
    final done = board.where((q) => q.done).length;
    return [
      if (s.comebackDue) ...[
        SystemWindow(
          title: 'System message',
          accent: Sx.vital,
          onTap: () => showComebackSheet(context),
          child: Text(
            'Welcome back, Hunter. ${s.daysAway} days away. Your journey has not ended: tap for a comeback plan.',
            style: AppTheme.s(14, color: gc.text),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (s.weeklyProposal case final p?) ...[
        SystemWindow(
          title: 'Weekly target review',
          accent: Sx.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.to > p.from
                    ? 'You beat your target two weeks running. Raise it from ${p.from} to ${p.to} training days?'
                    : 'The last two weeks were lighter than planned. Lower the target from ${p.from} to ${p.to} days for now?',
                style: AppTheme.s(14, color: gc.text),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => hunter.answerWeeklyProposal(false), child: const Text('Keep it')),
                  TextButton(onPressed: () => hunter.answerWeeklyProposal(true), child: const Text('Approve')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (s.promotionReady) ...[
        SystemWindow(
          title: 'Rank promotion available',
          accent: Sx.gold,
          onTap: () => SystemScreen.open(3),
          child: Text(
            'You have fulfilled your promotion requirements for ${s.nextRank!.letter}-Rank. Tap to begin.',
            style: AppTheme.s(14, color: gc.text),
          ),
        ),
        const SizedBox(height: 12),
      ],
      _statusWindow(context, s),
      const SizedBox(height: 14),
      Row(
        children: [
          const Expanded(child: SectionLabel('Daily quests')),
          Text(
            '$done/${board.length} complete',
            style: AppTheme.s(12.5, color: done == board.length ? Sx.vital : gc.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (s.readiness.low)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Readiness is low today: the System lowered quest difficulty.',
            style: AppTheme.s(12.5, color: Sx.gold),
          ),
        )
      else if (!s.readiness.logged)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => showCheckInSheet(context),
            child: Text(
              'Do a 10-second check-in so quests match how you feel today ›',
              style: AppTheme.s(12.5, color: Sx.mana),
            ),
          ),
        ),
      for (final q in board) ...[QuestCard(q), const SizedBox(height: 8)],
      const SizedBox(height: 6),
      for (final m in s.weekly) ...[WeeklyCard(m), const SizedBox(height: 8)],
      const SizedBox(height: 6),
      _grid(context, s),
      const SizedBox(height: 14),
      _trainingHub(context),
    ];
  }

  Widget _statusWindow(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    return SystemWindow(
      title: 'Status',
      onTap: () => SystemScreen.open(0),
      trailing: Text('OPEN ›', style: Sx.disp(12, color: Sx.mana, spacing: 1.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FramedEmblem(letter: s.rank.letter, frame: s.frame, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.player!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Sx.disp(19, color: gc.text),
                    ),
                    Text(
                      [if (s.currentTitle != null) '«${s.currentTitle!.name}»', '${s.rank.letter}-Rank'].join(' · '),
                      style: AppTheme.s(12.5, color: s.currentTitle != null ? Sx.gold : gc.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SystemBar(value: s.levelRatio, height: 6),
                    const SizedBox(height: 4),
                    Text(
                      '${s.into}/${s.need} XP to Lv ${s.level + 1} · ${s.totalXp} total',
                      style: AppTheme.s(11.5, color: gc.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('LV', style: Sx.disp(11, color: gc.textSecondary)),
                  Text('${s.level}', style: Sx.disp(34, color: Sx.mana, spacing: 0)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final a in Attr.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => showAttributeSheet(context, a),
                    child: Column(
                      children: [
                        Text(a.short, style: Sx.disp(12, color: gc.textSecondary, spacing: 1.2)),
                        Text('${s.attrs[a]!.level}', style: Sx.disp(20, color: Sx.violet, spacing: 0)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SystemBar(value: s.attrs[a]!.ratio, height: 3, color: Sx.violet),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _mini(context, 'Workouts', '${s.workouts}')),
              Expanded(child: _mini(context, 'Quests', '${s.questsDone}')),
              Expanded(child: _mini(context, 'Streak', '${s.streak}d')),
              Expanded(child: _mini(context, 'SP', '${s.skillPoints}', color: s.skillPoints > 0 ? Sx.gold : null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(BuildContext context, String k, String v, {Color? color}) => Column(
    children: [
      Text(v, style: Sx.disp(17, color: color ?? context.gc.text)),
      Text(k.toUpperCase(), style: Sx.disp(10.5, color: context.gc.textTertiary, spacing: 1.2)),
    ],
  );

  Widget _grid(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final items = [
      (PhosphorIconsRegular.user, 'Status', 0),
      (PhosphorIconsRegular.flag, 'Quests', 1),
      (PhosphorIconsRegular.shieldChevron, 'Bosses', 2),
      (PhosphorIconsRegular.medal, 'Rank', 3),
      (PhosphorIconsRegular.treeStructure, 'Skills', 4),
      (PhosphorIconsRegular.trophy, 'Awards', 5),
      (PhosphorIconsRegular.chartBar, 'Records', 6),
      (PhosphorIconsRegular.clockCounterClockwise, 'Timeline', 7),
      (PhosphorIconsRegular.heartbeat, 'Vitals', 8),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.3,
      children: [
        for (final (icon, label, tab) in items)
          SystemWindow(
            glow: false,
            padding: const EdgeInsets.all(6),
            onTap: () => SystemScreen.open(tab),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Sx.mana, size: 22),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: Sx.disp(12.5, color: gc.text, spacing: 1.2)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _trainingHub(BuildContext context) {
    final gc = context.gc;
    return SystemWindow(
      title: 'Training hub',
      accent: Sx.violet,
      onTap: () => fit.pushRoute('training'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Routines, weekly plan, body map, 466 exercises, nutrition and body stats. '
              'Every workout you log here feeds the System.',
              style: AppTheme.s(13.5, color: gc.textSecondary),
            ),
          ),
          const Icon(PhosphorIconsBold.caretRight, color: Sx.violet),
        ],
      ),
    );
  }
}

/// Kept for screens that expect a category colour without importing the board.
Color categoryColor(QuestCategory c) => switch (c) {
  QuestCategory.bonus => Sx.violet,
  QuestCategory.recovery || QuestCategory.mobility => Sx.vital,
  QuestCategory.discipline => Sx.gold,
  _ => Sx.mana,
};

String rankTitle(String letter) => rankByLetter(letter).title;
