import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/services.dart';

import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'hunter_catalog.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'system_widgets.dart';

/// Shows System pop-ups (level up, rank promotion, achievements, records,
/// quest completion, skills, bosses) once each. Waits while a workout is
/// on screen, follows the player's notification settings, and never
/// replays a pop-up on the next launch.
class SystemAlertsHost extends StatefulWidget {
  const SystemAlertsHost({super.key, required this.child});
  final Widget child;

  static const important = {'level', 'rank', 'achievement'};
  static const all = {
    'level',
    'rank',
    'achievement',
    'record',
    'questdone',
    'skillready',
    'skill',
    'trial',
    'boss',
    'gate',
    'weekly',
    'promo',
  };

  @override
  State<SystemAlertsHost> createState() => _SystemAlertsHostState();
}

class _SystemAlertsHostState extends State<SystemAlertsHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    hunter.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    hunter.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_showing || !mounted || !hunter.registered) return;
    if (fit.route == 'session' || fit.isSessionActive || fit.route == 'register') return;
    final level = hunter.alertLevel;
    final kinds = level == 'off'
        ? const <String>{}
        : (level == 'important' ? SystemAlertsHost.important : SystemAlertsHost.all);
    // Touch status first so any pending rewards are processed.
    hunter.status;
    final pending = hunter.pendingAlerts(SystemAlertsHost.all);
    if (pending.isEmpty) return;
    final show = pending.where((n) => kinds.contains(n.kind)).toList();
    // Everything pending is marked shown, so muted kinds never pile up.
    WidgetsBinding.instance.addPostFrameCallback((_) => hunter.markShown(pending.map((n) => n.id)));
    if (show.isEmpty) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showAll(show.take(6).toList()));
  }

  Future<void> _showAll(List<HunterNote> notes) async {
    for (final n in notes) {
      if (!mounted) break;
      if (hunter.soundOn) SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      final rank = n.kind == 'rank';
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'System',
        barrierColor: Colors.black.withValues(alpha: rank ? 0.85 : 0.7),
        transitionDuration: Duration(milliseconds: rank ? 650 : 380),
        pageBuilder: (context, _, _) => rank ? _RankPromotion(n) : _AlertWindow(n),
        transitionBuilder: (context, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(
              begin: rank ? 0.6 : 0.85,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
      );
    }
    _showing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

({String kicker, Color color}) _look(HunterNote n) => switch (n.kind) {
  'level' => (kicker: 'LEVEL UP!', color: Sx.mana),
  'achievement' => (kicker: 'ACHIEVEMENT UNLOCKED', color: Sx.violet),
  'record' => (kicker: 'PERSONAL RECORD ACHIEVED', color: Sx.vital),
  'questdone' => (kicker: 'QUEST COMPLETE', color: Sx.vital),
  'skillready' || 'skill' => (kicker: 'NEW SKILL UNLOCKED', color: Sx.violet),
  'trial' => (kicker: 'TRIAL PASSED', color: Sx.gold),
  'boss' => (kicker: 'BOSS DEFEATED', color: Sx.alert),
  'gate' => (kicker: 'DUNGEON CLEARED', color: Sx.vital),
  'weekly' => (kicker: 'WEEKLY MISSION COMPLETE', color: Sx.gold),
  'promo' => (kicker: 'RANK PROMOTION AVAILABLE', color: Sx.gold),
  _ => (kicker: n.title, color: Sx.mana),
};

class _AlertWindow extends StatelessWidget {
  const _AlertWindow(this.note);
  final HunterNote note;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final look = _look(note);
    final level = note.kind == 'level';
    final parts = note.body.split('→');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ParticleBurst(
                  color: look.color,
                  enabled: hunter.animationsOn && (level || note.kind == 'achievement'),
                ),
              ),
              SystemWindow(
                accent: look.color,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('[ SYSTEM NOTIFICATION ]', style: Sx.disp(12, color: gc.textSecondary, spacing: 3)),
                    const SizedBox(height: 10),
                    Text(
                      look.kicker,
                      textAlign: TextAlign.center,
                      style: Sx.disp(level ? 36 : 26, color: look.color, spacing: 2.5),
                    ),
                    const SizedBox(height: 8),
                    if (level && parts.length == 2)
                      _LevelCounter(from: int.tryParse(parts[0].trim()) ?? 1, to: int.tryParse(parts[1].trim()) ?? 2)
                    else
                      Text(
                        note.body,
                        textAlign: TextAlign.center,
                        style: Sx.disp(19, color: gc.text, spacing: 0.4),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      switch (note.kind) {
                        'level' => 'Your experience continues to grow.\nA skill point has been granted.',
                        'achievement' => 'New achievement added to your collection.',
                        'record' => 'New achievement detected. Your previous record has been surpassed.',
                        'skillready' => 'Spend a skill point in the Skills tab to learn it.',
                        'promo' => 'Open the Rank tab to begin your promotion.',
                        _ => '',
                      },
                      textAlign: TextAlign.center,
                      style: AppTheme.s(13.5, color: gc.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('CONFIRM', style: Sx.disp(15, color: look.color, spacing: 2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCounter extends StatelessWidget {
  const _LevelCounter({required this.from, required this.to});
  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final still = MediaQuery.of(context).disableAnimations || !hunter.animationsOn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$from', style: Sx.disp(30, color: gc.textSecondary, spacing: 0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(PhosphorIconsBold.arrowRight, color: gc.textSecondary),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: still ? to.toDouble() : from.toDouble(), end: to.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text('${v.round()}', style: Sx.disp(46, color: Sx.mana, spacing: 0)),
        ),
      ],
    );
  }
}

class _RankPromotion extends StatelessWidget {
  const _RankPromotion(this.note);
  final HunterNote note;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final to = note.id.startsWith('rank:') ? note.id.substring(5) : 'D';
    final history = hunter.rankHistory;
    final from = history.isEmpty ? 'E' : history.last.from;
    final color = Sx.rank(to);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ParticleBurst(color: color, enabled: hunter.animationsOn, count: 80),
              ),
              SystemWindow(
                accent: color,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('[ HUNTER RANK PROMOTION ]', style: Sx.disp(14, color: color, spacing: 3)),
                    const SizedBox(height: 10),
                    Text(
                      'Your training achievements have been evaluated.',
                      textAlign: TextAlign.center,
                      style: AppTheme.s(14, color: gc.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(opacity: 0.5, child: RankEmblem(letter: from, size: 56)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(PhosphorIconsBold.caretDoubleRight, color: color),
                        ),
                        RankEmblem(letter: to, size: 96),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('NEW RANK UNLOCKED!', style: Sx.disp(28, color: color, spacing: 2.5)),
                    Text(
                      '${rankByLetter(to).title} · Previous Rank: $from · New Rank: $to',
                      textAlign: TextAlign.center,
                      style: AppTheme.s(13.5, color: gc.text),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '+$kRankPromotionXp XP · +1 skill point · new profile frame',
                      textAlign: TextAlign.center,
                      style: Sx.disp(15, color: Sx.gold),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('CONFIRM', style: Sx.disp(16, color: color, spacing: 2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
