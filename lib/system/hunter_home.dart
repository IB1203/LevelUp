import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/entrance.dart';
import '../widgets/today_workout_card.dart';
import '../widgets/ui_kit.dart';
import 'hunter_catalog.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'quest_board.dart';
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
                    decoration: BoxDecoration(
                      color: context.sx.alert,
                      borderRadius: BorderRadius.circular(10),
                    ),
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
      if (TodayWorkoutCard.visible) ...[
        const SizedBox(height: 14),
        const SectionLabel("Today's mission"),
        const SizedBox(height: 8),
        const TodayWorkoutCard(),
      ],
    ];
  }

  List<Widget> _registered(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final board = s.todayQuests;
    final path = hunterClassById(hunter.player?.classId);
    return [
      if (s.comebackDue) ...[
        SystemWindow(
          title: 'System message',
          accent: context.sx.vital,
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
          accent: context.sx.gold,
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
                  TextButton(
                    onPressed: () => hunter.answerWeeklyProposal(false),
                    child: const Text('Keep it'),
                  ),
                  TextButton(
                    onPressed: () => hunter.answerWeeklyProposal(true),
                    child: const Text('Approve'),
                  ),
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
          accent: context.sx.gold,
          onTap: () => SystemScreen.open(3),
          child: Text(
            'You have fulfilled your promotion requirements for ${s.nextRank!.letter}-Rank. Tap to begin.',
            style: AppTheme.s(14, color: gc.text),
          ),
        ),
        const SizedBox(height: 12),
      ],
      _statusWindow(context, s),
      if (TodayWorkoutCard.visible) ...[
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: SectionLabel("Today's mission")),
            Text('${path.name} path', style: AppTheme.s(12.5, color: gc.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        const TodayWorkoutCard(),
      ],
      const SizedBox(height: 18),
      QuestBoardHeader(quests: board, readiness: s.readiness, onCheckIn: () => showCheckInSheet(context)),
      const SizedBox(height: 10),
      if (board.isEmpty)
        QuestEmptyState(onCheckIn: () => showCheckInSheet(context))
      else
        for (final q in board) ...[QuestCard(q), const SizedBox(height: 9)],
      if (s.weekly.isNotEmpty) ...[
        const SizedBox(height: 10),
        HunterSectionHeader(
          title: 'Weekly quests',
          accent: context.sx.gold,
          actionLabel: 'All quests',
          onAction: () => SystemScreen.open(1),
        ),
        const SizedBox(height: 6),
        for (final m in s.weekly) ...[WeeklyCard(m), const SizedBox(height: 9)],
      ],
    ];
  }

  Widget _statusWindow(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    return SystemWindow(
      title: 'Status',
      onTap: () => SystemScreen.open(0),
      trailing: Text('OPEN ›', style: Sx.disp(12, color: context.sx.mana, spacing: 1.4)),
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
                      [
                        if (s.currentTitle != null) '«${s.currentTitle!.name}»',
                        '${s.rank.letter}-Rank',
                      ].join(' · '),
                      style: AppTheme.s(
                        12.5,
                        color: s.currentTitle != null ? context.sx.gold : gc.textSecondary,
                      ),
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
                  Text('${s.level}', style: Sx.disp(34, color: context.sx.mana, spacing: 0)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final a in Attr.values)
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    label: '${a.label} attribute, level ${s.attrs[a]!.level}',
                    hint: 'Opens the progress breakdown',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showAttributeSheet(context, a),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.short, style: Sx.disp(12, color: gc.textSecondary, spacing: 1.2)),
                            Text(
                              '${s.attrs[a]!.level}',
                              style: Sx.disp(20, color: context.sx.violet, spacing: 0),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: SystemBar(value: s.attrs[a]!.ratio, height: 3, color: context.sx.violet),
                            ),
                          ],
                        ),
                      ),
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
              Expanded(
                child: _mini(
                  context,
                  'SP',
                  '${s.skillPoints}',
                  color: s.skillPoints > 0 ? context.sx.gold : null,
                ),
              ),
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
}
