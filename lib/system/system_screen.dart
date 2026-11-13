import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/services.dart';

import '../models/exercise.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/ui_kit.dart';
import 'hunter_catalog.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'hunter_rules.dart';
import 'quest_board.dart';
import 'system_sheets.dart';
import 'system_widgets.dart';

/// The full System hub — signature Hunter experience.
class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  static const tabs = [
    'Status',
    'Quests',
    'Bosses',
    'Rank',
    'Skills',
    'Achievements',
    'Records',
    'Timeline',
    'Vitals',
  ];
  static int initialTab = 0;

  static void open(int tab) {
    initialTab = tab;
    fit.goSystem();
  }

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  late int _tab = SystemScreen.initialTab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hunter,
      builder: (context, _) {
        final s = hunter.status;
        final gc = context.gc;
        return RiseScope(
          id: 'system$_tab',
          once: false,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              key: PageStorageKey('system$_tab'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    // A root tab: a title, not a back arrow.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Hunter',
                            style: AppTheme.f(
                              28,
                              weight: FontWeight.w800,
                              color: gc.text,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.registered
                              ? '${s.rank.letter}-Rank ${s.rank.title} · Lv ${s.level}'
                              : 'Awaken to begin',
                          style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 0, 4),
                  sliver: SliverToBoxAdapter(child: _tabBar(context)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
                  sliver: SliverList.list(
                    children: riseAll(
                      !s.registered
                          ? [
                              SystemWindow(
                                title: 'Awaken',
                                accent: gc.accent,
                                glow: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: gc.accent.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(PhosphorIconsFill.sparkle, size: 20, color: gc.accent),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Register as a hunter',
                                                style: AppTheme.s(15, color: gc.text),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Your journey starts at E-Rank, Level 1.',
                                                style: AppTheme.s(12.5, color: gc.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    PrimaryButton(
                                      label: 'Register now',
                                      onTap: () => fit.pushRoute('register'),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : switch (_tab) {
                              0 => _status(context, s),
                              1 => _quests(context, s),
                              2 => _bosses(context, s),
                              3 => _rank(context, s),
                              4 => _skills(context, s),
                              5 => _awards(context, s),
                              6 => _records(context, s),
                              7 => _timeline(context, s),
                              _ => _vitals(context, s),
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabBar(BuildContext context) {
    final gc = context.gc;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < SystemScreen.tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = SystemScreen.initialTab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == _tab ? gc.ember : gc.bgRaised,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    SystemScreen.tabs[i],
                    style: AppTheme.f(
                      13.5,
                      weight: FontWeight.w700,
                      color: i == _tab ? gc.onEmber : gc.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _go(int tab) => setState(() => _tab = SystemScreen.initialTab = tab);

  Widget _label(BuildContext context, String text) =>
      Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: SectionLabel(text));

  // --- Status (spec §15) -----------------------------------------------------------

  List<Widget> _status(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    Widget row(String k, String v, {VoidCallback? onTap, Color? color, String? semanticsLabel}) => Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel ?? '$k $v',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(k, style: AppTheme.s(14, color: gc.textSecondary)),
              ),
              const SizedBox(width: 8),
              Text(v, style: Sx.disp(17, color: color ?? gc.text)),
              if (onTap != null) Icon(PhosphorIconsBold.caretRight, size: 18, color: gc.textTertiary),
            ],
          ),
        ),
      ),
    );
    return [
      SystemWindow(
        title: 'Player status',
        trailing: Text(s.player!.id, style: AppTheme.s(11, color: gc.textTertiary)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  container: true,
                  button: true,
                  label: 'Change title and frame',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showTitlesSheet(context),
                    child: FramedEmblem(letter: s.rank.letter, frame: s.frame, size: 70),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.player!.name, style: Sx.disp(21, color: gc.text)),
                      if (s.currentTitle != null)
                        Semantics(
                          container: true,
                          button: true,
                          label: 'Title: ${s.currentTitle!.name}. Change title and frame',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => showTitlesSheet(context),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '«${s.currentTitle!.name}»',
                                  style: AppTheme.s(13, color: context.sx.gold),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Text(
                        '${hunterClassById(s.player!.classId).name} · ${s.rank.letter}-Rank ${s.rank.title}',
                        style: AppTheme.s(12.5, color: gc.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('LEVEL', style: Sx.disp(11, color: gc.textSecondary)),
                    Text('${s.level}', style: Sx.disp(40, color: context.sx.mana, spacing: 0)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            SystemBar(
              value: s.levelRatio,
              semanticsLabel: 'Level ${s.level}, progress ${(s.levelRatio * 100).round()} percent',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Total XP ${s.totalXp}', style: AppTheme.s(12.5, color: gc.textSecondary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Next level at ${s.xpForNextLevel} XP (${(s.levelRatio * 100).round()}%)',
                    textAlign: TextAlign.end,
                    style: AppTheme.s(12.5, color: gc.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Player attributes',
        child: Column(
          children: [
            for (final a in Attr.values)
              Semantics(
                container: true,
                button: true,
                label: '${a.label} attribute, level ${s.attrs[a]!.level}',
                hint: 'Opens the progress breakdown',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: InkWell(
                    onTap: () => showAttributeSheet(context, a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(a.label.toUpperCase(), style: Sx.disp(15.5, color: gc.text)),
                              ),
                              Text(
                                'LV ${s.attrs[a]!.level.toString().padLeft(2, '0')}',
                                style: Sx.disp(16, color: context.sx.mana),
                              ),
                              Icon(PhosphorIconsBold.caretRight, size: 18, color: gc.textTertiary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SystemBar(value: s.attrs[a]!.ratio, height: 4, color: context.sx.violet),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Player records',
        child: Column(
          children: [
            row('Total workouts', '${s.workouts}', onTap: fit.goProgress),
            row('Total active minutes', '${s.activeMinutes}'),
            row('Completed quests', '${s.questsDone}', onTap: () => _go(1)),
            row('Weekly missions', '${s.weeklyDone}', onTap: () => _go(1)),
            row('Current streak', '${s.streak} days'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Unlocked',
        child: Column(
          children: [
            row('Achievements', '${s.achievementsUnlocked} / ${s.achievements.length}', onTap: () => _go(5)),
            row('Skills', '${s.skillsLearned} / ${s.skills.length}', onTap: () => _go(4)),
            row(
              'Skill points',
              '${s.skillPoints}',
              onTap: () => _go(4),
              color: s.skillPoints > 0 ? context.sx.gold : null,
            ),
            row('Titles', '${s.titlesUnlocked} / ${s.titles.length}', onTap: () => showTitlesSheet(context)),
            row('Personal records', '${s.records.length}', onTap: () => _go(6)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'XP transactions',
        trailing: Text('${s.ledger.length}', style: AppTheme.s(12, color: gc.textTertiary)),
        child: Column(
          children: [
            if (s.ledger.isEmpty)
              Text(
                'No XP yet. Complete a quest or log a workout.',
                style: AppTheme.s(13, color: gc.textTertiary),
              ),
            for (final t in s.ledger.take(30))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.reason, style: AppTheme.s(13.5, color: gc.text)),
                          Text(
                            '${t.category} · ${dayKey(t.at)}${t.attrs.isEmpty ? '' : ' · ${attrRewardText(t.attrs)}'}',
                            style: AppTheme.s(11.5, color: gc.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Text('+${t.xp}', style: Sx.disp(15, color: t.xp > 0 ? context.sx.gold : gc.textTertiary)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Each activity pays once and XP is never removed.',
              style: AppTheme.s(12, color: gc.textTertiary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => fit.pushRoute('register'),
              icon: const Icon(PhosphorIconsRegular.slidersHorizontal, size: 18),
              label: const Text('Edit assessment'),
            ),
            TextButton.icon(
              onPressed: () => showSystemSettingsSheet(context),
              icon: const Icon(PhosphorIconsRegular.bell, size: 18),
              label: const Text('Notifications'),
            ),
          ],
        ),
      ),
    ];
  }

  // --- Quests ---------------------------------------------------------------------

  List<Widget> _quests(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    return [
      QuestBoardHeader(
        quests: s.todayQuests,
        readiness: s.readiness,
        onCheckIn: () => showCheckInSheet(context),
      ),
      const SizedBox(height: 12),
      if (s.todayQuests.isEmpty)
        QuestEmptyState(onCheckIn: () => showCheckInSheet(context))
      else
        for (final q in s.todayQuests) ...[QuestCard(q), const SizedBox(height: 9)],
      const SizedBox(height: 14),
      HunterSectionHeader(title: 'Weekly missions', accent: context.sx.gold),
      const SizedBox(height: 8),
      for (final m in s.weekly) ...[WeeklyCard(m), const SizedBox(height: 9)],
      const SizedBox(height: 14),
      HunterSectionHeader(title: 'Dungeons', accent: context.sx.holo),
      const SizedBox(height: 4),
      Text(
        'Time-boxed events. Leaving or failing one costs nothing.',
        style: AppTheme.s(12.5, color: gc.textTertiary),
      ),
      const SizedBox(height: 8),
      for (final g in s.gates) ...[_gateCard(context, g), const SizedBox(height: 8)],
    ];
  }

  Widget _gateCard(BuildContext context, GateRun g) {
    final gc = context.gc;
    final color = switch (g.status) {
      GateStatus.cleared => context.sx.vital,
      GateStatus.active => context.sx.mana,
      GateStatus.failed => context.sx.gold,
      GateStatus.locked => gc.border,
      GateStatus.available => context.sx.rank(g.def.rank),
    };
    return Opacity(
      opacity: g.status == GateStatus.locked ? 0.55 : 1,
      child: SystemWindow(
        accent: color,
        glow: g.status == GateStatus.active,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SystemChip('${g.def.rank}-Rank', color: context.sx.rank(g.def.rank)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(g.def.name, style: Sx.disp(17, color: gc.text, spacing: 0.4)),
                ),
                Text('+${g.def.xp} XP', style: Sx.disp(13, color: context.sx.gold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${g.def.story} ${g.def.goalText}.', style: AppTheme.s(13, color: gc.textSecondary)),
            if (g.start != null) ...[
              const SizedBox(height: 8),
              SystemBar(value: (g.progress / g.def.target).clamp(0, 1).toDouble(), color: color),
              const SizedBox(height: 4),
              Text(switch (g.status) {
                GateStatus.cleared => 'CLEARED · ${g.progress}/${g.def.target}',
                GateStatus.failed => 'Closed at ${g.progress}/${g.def.target}. Re-enter when ready.',
                _ => '${g.progress}/${g.def.target} · ${g.daysLeft} days left',
              }, style: AppTheme.s(12.5, color: color)),
            ],
            Row(
              children: [
                if (g.status == GateStatus.locked)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Opens near ${g.def.rank}-Rank',
                      style: AppTheme.s(12, color: gc.textTertiary),
                    ),
                  )
                else if (g.status == GateStatus.active)
                  TextButton(
                    onPressed: () => hunter.abandonGate(g.def.id),
                    child: Text('Leave', style: TextStyle(color: gc.textSecondary)),
                  )
                else
                  TextButton(
                    onPressed: () => hunter.enterGate(g.def.id),
                    child: Text(g.status == GateStatus.available ? 'Enter dungeon' : 'Enter again'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Bosses (spec §12) -------------------------------------------------------------

  List<Widget> _bosses(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    return [
      Text(
        'Milestone challenges built from your equipment and limitations. They need earlier quests, a good readiness '
        'day and your acceptance. Retry as often as you like: nothing is lost.',
        style: AppTheme.s(13, color: gc.textSecondary),
      ),
      const SizedBox(height: 12),
      for (final b in s.bosses) ...[
        SystemWindow(
          accent: b.wonBeginner || b.wonAdvanced ? context.sx.vital : context.sx.alert,
          title: b.def.name,
          trailing: Text('+${b.def.xp} XP', style: Sx.disp(13, color: context.sx.gold)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(b.def.challenge, style: AppTheme.s(14, color: gc.text)),
              const SizedBox(height: 8),
              Text(
                [
                  '${s.questsDone}/${b.def.questsNeeded} quests completed',
                  if (s.readiness.low) 'readiness low: rest first',
                  if (b.def.title != null) 'title: ${b.def.title}',
                ].join(' · '),
                style: AppTheme.s(
                  12.5,
                  color: b.questsMet && !s.readiness.low ? gc.textTertiary : context.sx.gold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _bossButton(context, s, b, advanced: false)),
                  const SizedBox(width: 8),
                  Expanded(child: _bossButton(context, s, b, advanced: true)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _bossButton(BuildContext context, HunterStatus s, BossState b, {required bool advanced}) {
    final won = advanced ? b.wonAdvanced : b.wonBeginner;
    final open = hunter.bossUnlocked(b.def, s, advanced: advanced);
    final label = '${advanced ? 'Advanced' : 'Beginner'}${won ? ' ✓' : ''}';
    return Opacity(
      opacity: open ? 1 : 0.4,
      child: OutlinedButton(
        onPressed: !open
            ? null
            : () async {
                final ok = await _confirm(
                  context,
                  b.def.name,
                  '${advanced ? 'Advanced' : 'Beginner'} variant. Stop if anything hurts. Start the battle?',
                );
                if (ok && !hunter.startBoss(b.def.id, advanced: advanced) && context.mounted) {
                  ScaffoldMessenger.maybeOf(
                    context,
                  )?.showSnackBar(const SnackBar(content: Text('Finish your current workout first.')));
                }
              },
        child: Text(label),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
          ],
        ),
      ) ??
      false;

  // --- Rank (spec §4) ------------------------------------------------------------------

  List<Widget> _rank(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final next = s.nextRank;
    final trialReq = s.promotion.where((r) => r.label.contains('trial')).firstOrNull;
    final othersMet = s.promotion.where((r) => r != trialReq).every((r) => r.met);
    return [
      SystemWindow(
        accent: context.sx.rank(s.rank.letter),
        child: Row(
          children: [
            FramedEmblem(letter: s.rank.letter, frame: s.frame, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.rank.letter}-RANK ${s.rank.title.toUpperCase()}',
                    style: Sx.disp(20, color: gc.text),
                  ),
                  Text(
                    'Levels ${s.rank.minLevel}–${s.rank.maxLevel} · you are level ${s.level}',
                    style: AppTheme.s(13, color: gc.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (next != null)
        SystemWindow(
          title: 'Promotion to ${next.letter}-Rank',
          accent: s.promotionReady ? context.sx.gold : context.sx.mana,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in s.promotion)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        r.met ? PhosphorIconsFill.checkSquare : PhosphorIconsRegular.square,
                        color: r.met ? context.sx.vital : gc.textTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.label, style: AppTheme.s(14, color: gc.text)),
                      ),
                      Text(
                        '${r.have is double ? (r.have as double).toStringAsFixed(0) : r.have}/${r.need}',
                        style: AppTheme.s(12.5, color: gc.textSecondary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (s.promotionReady)
                PrimaryButton(
                  label: 'Begin rank promotion',
                  bg: context.sx.gold,
                  onTap: () => hunter.promote(),
                )
              else if (trialReq != null && !trialReq.met)
                Opacity(
                  opacity: othersMet || s.level >= s.rank.promoLevel ? 1 : 0.45,
                  child: PrimaryButton(
                    label: 'Start promotion trial',
                    onTap: () {
                      if (!(othersMet || s.level >= s.rank.promoLevel)) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(content: Text('The trial opens at level ${s.rank.promoLevel}.')),
                        );
                        return;
                      }
                      if (!hunter.startTrial()) {
                        ScaffoldMessenger.maybeOf(
                          context,
                        )?.showSnackBar(const SnackBar(content: Text('Finish your current workout first.')));
                      }
                    },
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Pass the trial by completing at least ${(HunterRules.trialPassCompletion * 100).round()}% of its sets. '
                'It adapts to your experience; retry any time.',
                style: AppTheme.s(12, color: gc.textTertiary),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Rank ladder',
        glow: false,
        child: Column(
          children: [
            for (final r in kRanks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    RankEmblem(letter: r.letter, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.title, style: Sx.disp(16, color: gc.text)),
                    ),
                    Text(
                      'Lv ${r.minLevel}–${r.maxLevel}',
                      style: AppTheme.s(
                        12.5,
                        color: rankIndex(r.letter) <= rankIndex(s.rank.letter)
                            ? context.sx.rank(r.letter)
                            : gc.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Promotion history',
        glow: false,
        child: s.rankHistory.isEmpty
            ? Text(
                'No promotions yet. Ranks are never taken away.',
                style: AppTheme.s(13, color: gc.textTertiary),
              )
            : Column(
                children: [
                  for (final r in s.rankHistory.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('${r.from} to ${r.to}', style: Sx.disp(16, color: context.sx.rank(r.to))),
                          const Spacer(),
                          Text(dayKey(r.at), style: AppTheme.s(12.5, color: gc.textSecondary)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 10),
      Text(
        'Rank is an RPG progression classification, not a medical or professional fitness assessment.',
        style: AppTheme.s(12, color: gc.textTertiary),
      ),
    ];
  }

  // --- Skills (spec §9) ------------------------------------------------------------------

  List<Widget> _skills(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    return [
      SystemWindow(
        accent: context.sx.gold,
        child: Row(
          children: [
            Text('${s.skillPoints}', style: Sx.disp(36, color: context.sx.gold, spacing: 0)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Skill points. Earn one per level and per rank promotion. Learn a skill once you have done the '
                'training it asks for.',
                style: AppTheme.s(13, color: gc.textSecondary),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final tree in skillTreesFor(s.player?.classId)) ...[
        _label(context, '$tree tree'),
        for (final k in s.skills.where((k) => k.def.tree == tree)) ...[
          SystemWindow(
            glow: k.learnable,
            accent: k.learned ? context.sx.vital : (k.learnable ? context.sx.gold : gc.border),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      k.learned
                          ? PhosphorIconsFill.sparkle
                          : (k.learnable
                                ? PhosphorIconsRegular.lockSimpleOpen
                                : PhosphorIconsRegular.lockSimple),
                      size: 18,
                      color: k.learned ? context.sx.vital : (k.learnable ? context.sx.gold : gc.textTertiary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(k.def.name, style: Sx.disp(16.5, color: gc.text)),
                    ),
                    if (k.learnable)
                      TextButton(
                        onPressed: s.skillPoints > 0 ? () => hunter.learnSkill(k.def.id) : null,
                        child: Text(s.skillPoints > 0 ? 'Learn (1 SP)' : 'Need SP'),
                      ),
                  ],
                ),
                Text(k.def.requirement, style: AppTheme.s(12.5, color: gc.textSecondary)),
                if (!k.learned) ...[
                  const SizedBox(height: 6),
                  SystemBar(value: (k.progress / k.def.threshold).clamp(0, 1).toDouble(), height: 4),
                  const SizedBox(height: 3),
                  Text(
                    '${k.progress >= k.def.threshold
                        ? k.def.threshold
                        : k.progress is double
                        ? (k.progress as double).toStringAsFixed(1)
                        : k.progress} / ${k.def.threshold}'
                    '${!k.attrMet ? ' · needs ${k.def.attr!.label} ${k.def.attrLevel}' : ''}'
                    '${!k.prereqMet ? ' · learn the previous skill first' : ''}',
                    style: AppTheme.s(11.5, color: gc.textTertiary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  k.def.reward,
                  style: AppTheme.s(12.5, color: k.learned ? context.sx.vital : gc.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  // --- Achievements (spec §10) --------------------------------------------------------------

  List<Widget> _awards(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final cats = <String>{for (final a in s.achievements) a.def.category};
    return [
      Text(
        '${s.achievementsUnlocked} of ${s.achievements.length} unlocked',
        style: AppTheme.s(13, color: gc.textSecondary),
      ),
      for (final c in cats) ...[
        _label(context, c),
        for (final a in s.achievements.where((a) => a.def.category == c)) ...[
          Opacity(
            opacity: a.unlocked ? 1 : 0.55,
            child: SystemWindow(
              glow: a.unlocked,
              accent: a.unlocked ? rarityColor(a.def.rarity.name, context.sx) : gc.border,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rarityColor(
                        a.def.rarity.name,
                        context.sx,
                      ).withValues(alpha: a.unlocked ? 0.18 : 0.06),
                      border: Border.all(
                        color: rarityColor(
                          a.def.rarity.name,
                          context.sx,
                        ).withValues(alpha: a.unlocked ? 1 : 0.3),
                      ),
                    ),
                    child: Icon(
                      badgeIcon(a.def.icon),
                      color: a.unlocked ? rarityColor(a.def.rarity.name, context.sx) : gc.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.def.name, style: Sx.disp(16, color: gc.text)),
                        Text(a.def.description, style: AppTheme.s(12.5, color: gc.textSecondary)),
                        Text(
                          a.unlocked
                              ? '${a.def.rarity.label} · unlocked ${dayKey(a.unlockedAt!)}'
                              : '${a.def.rarity.label} · ${a.progress is double ? (a.progress as double).toStringAsFixed(1) : a.progress}/${a.def.threshold}',
                          style: AppTheme.s(11.5, color: rarityColor(a.def.rarity.name, context.sx)),
                        ),
                      ],
                    ),
                  ),
                  Text('+${a.def.xp}', style: Sx.disp(14, color: context.sx.gold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ];
  }

  // --- Records (spec §11) ------------------------------------------------------------------

  List<Widget> _records(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final byEx = <String, List<HunterRecord>>{};
    for (final r in s.records) {
      (byEx[r.exerciseId] ??= []).add(r);
    }
    String v(HunterRecord r) => switch (r.type) {
      RecordType.longestHold => '${r.value.round()} s',
      RecordType.longestDistance => '${r.value.toStringAsFixed(2)} km',
      RecordType.maxWeight => '${fmt(r.value)} kg',
      RecordType.repsAtWeight => '${r.value.round()} reps @ ${fmt(r.atWeight ?? 0)} kg',
      RecordType.maxReps => '${r.value.round()} reps',
    };
    String prev(HunterRecord r) => r.previous == null
        ? 'first record'
        : 'previous ${switch (r.type) {
            RecordType.longestDistance => r.previous!.toStringAsFixed(2),
            RecordType.maxWeight => fmt(r.previous!),
            _ => r.previous!.round().toString(),
          }}';
    return [
      Text(
        'Only comparable sets are compared (reps at the same weight, holds with holds).',
        style: AppTheme.s(12.5, color: gc.textTertiary),
      ),
      const SizedBox(height: 10),
      if (byEx.isEmpty)
        Text('Log workouts to set your first records.', style: AppTheme.s(14, color: gc.textSecondary)),
      for (final e in byEx.entries) ...[
        SystemWindow(
          glow: false,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          onTap: () => fit.openExercise(e.key),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fit.exerciseById(e.key) == null
                    ? e.value.first.exerciseName
                    : exerciseName(fit.exerciseById(e.key)!),
                style: Sx.disp(16.5, color: gc.text),
              ),
              const SizedBox(height: 4),
              for (final r in e.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.type.label, style: AppTheme.s(13, color: gc.textSecondary)),
                      ),
                      Text(v(r), style: Sx.disp(15, color: context.sx.mana)),
                      const SizedBox(width: 8),
                      Text('${prev(r)} · ${dayKey(r.at)}', style: AppTheme.s(11, color: gc.textTertiary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  // --- Timeline (spec §17) ----------------------------------------------------------------

  List<Widget> _timeline(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final events = s.timeline.reversed.toList();
    final start = s.player!.created;
    Color c(String k) => switch (k) {
      'level' => context.sx.mana,
      'rank' => context.sx.gold,
      'achievement' => context.sx.violet,
      'record' => context.sx.vital,
      'boss' => context.sx.alert,
      _ => gc.textSecondary,
    };
    return [
      for (final e in events)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 70,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Day ${(DateTime(e.at.year, e.at.month, e.at.day).difference(DateTime(start.year, start.month, start.day)).inDays + 1).toString().padLeft(2, '0')}',
                    style: Sx.disp(14, color: gc.textSecondary),
                  ),
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: c(e.kind), shape: BoxShape.circle),
                  ),
                  Expanded(child: Container(width: 1.5, color: gc.border)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: AppTheme.s(14, color: gc.text, weight: FontWeight.w600),
                      ),
                      Text(
                        '${dayKey(e.at)}${e.xp > 0 ? ' · +${e.xp} XP' : ''}',
                        style: AppTheme.s(11.5, color: gc.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // --- Vitals --------------------------------------------------------------------------------

  List<Widget> _vitals(BuildContext context, HunterStatus s) {
    final gc = context.gc;
    final r = s.readiness;
    final rColor = !r.logged
        ? gc.textTertiary
        : (r.pain
              ? context.sx.alert
              : (r.score >= 75 ? context.sx.vital : (r.score >= 55 ? context.sx.mana : context.sx.gold)));
    return [
      SystemWindow(
        title: 'Readiness',
        accent: rColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(r.logged ? '${r.score}' : '--', style: Sx.disp(44, color: rColor, spacing: 0)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.verdict.toUpperCase(), style: Sx.disp(18, color: gc.text)),
                      Text(r.advice, style: AppTheme.s(13, color: gc.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: r.logged ? 'Update check-in' : 'Daily check-in',
              height: 44,
              onTap: () => showCheckInSheet(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Daily briefing',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (q, a) in [
              ('What should I train?', s.briefing.what),
              ('How hard should I push?', s.briefing.howHard),
              ('Am I recovering?', s.briefing.recovering),
              ('Is my plan working?', s.briefing.working),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.toUpperCase(), style: Sx.disp(12.5, color: context.sx.mana, spacing: 1.4)),
                    Text(a, style: AppTheme.s(14, color: gc.text)),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Load management',
        accent: s.loadSpike ? context.sx.gold : context.sx.mana,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: StatTile('This week', '${s.weekSets} sets')),
                Expanded(
                  child: StatTile(
                    '4-week avg',
                    '${s.avgWeekSets.toStringAsFixed(0)} sets',
                    color: gc.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.loadSpike
                  ? 'Volume is rising faster than your body adapts. Hold here or plan a deload week.'
                  : 'Volume is within a safe range of your recent average.',
              style: AppTheme.s(13, color: s.loadSpike ? context.sx.gold : gc.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Shadow army',
        accent: context.sx.violet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '30-day muscle balance. Shadows are undertrained areas to recruit.',
              style: AppTheme.s(12.5, color: gc.textTertiary),
            ),
            const SizedBox(height: 8),
            for (final m in s.muscles.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        muscleLabel(m.muscle),
                        style: AppTheme.s(13, color: m.injured ? context.sx.alert : gc.text),
                      ),
                    ),
                    Expanded(
                      child: SystemBar(
                        value: (m.ratio / 2).clamp(0, 1).toDouble(),
                        height: 6,
                        color: m.ratio < HunterRules.shadowBelowMedian
                            ? context.sx.violet
                            : (m.ratio >= HunterRules.soldierAtMedian ? context.sx.mana : context.sx.gold),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        m.sets.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                        style: AppTheme.s(12, color: gc.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Injury & pain log',
        accent: s.activeInjuries.isEmpty ? context.sx.vital : context.sx.alert,
        trailing: GestureDetector(
          onTap: () => showInjurySheet(context),
          child: Icon(PhosphorIconsBold.plus, color: context.sx.mana, size: 22),
        ),
        child: s.injuries.isEmpty
            ? Text(
                'Nothing logged. Quests avoid areas you log here.',
                style: AppTheme.s(13.5, color: gc.textSecondary),
              )
            : Column(
                children: [
                  for (final i in s.injuries.reversed)
                    Opacity(
                      opacity: i.resolved ? 0.5 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${muscleLabel(i.area)} · ${i.severity}/10',
                                  style: Sx.disp(16, color: i.severity >= 7 ? context.sx.alert : gc.text),
                                ),
                              ),
                              PopupMenuButton<String>(
                                iconColor: gc.textSecondary,
                                onSelected: (v) => v == 'delete'
                                    ? hunter.deleteInjury(i.id)
                                    : hunter.resolveInjury(i.id, resolved: !i.resolved),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(i.resolved ? 'Mark active' : 'Mark healed'),
                                  ),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ],
                          ),
                          if (i.note.isNotEmpty) Text(i.note, style: AppTheme.s(13, color: gc.textSecondary)),
                          if (!i.resolved) Text(i.guidance, style: AppTheme.s(12.5, color: gc.text)),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 14),
      SystemWindow(
        title: 'Safety',
        accent: context.sx.alert,
        glow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hunter.screeningFlagged)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Your safety check suggests talking to a clinician before hard training.',
                  style: AppTheme.s(13.5, color: context.sx.gold),
                ),
              ),
            Text(
              'Chest pain, fainting, severe breathlessness or sudden weakness mean stop and get urgent care.',
              style: AppTheme.s(13.5, color: gc.text),
            ),
            Row(
              children: [
                TextButton(onPressed: () => showRedFlagsSheet(context), child: const Text('Red flags')),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}
