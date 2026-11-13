import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'hunter_catalog.dart';
import 'hunter_engine.dart';
import 'hunter_models.dart';
import 'system_widgets.dart';

/// Hunter registration: the System's boot sequence, a fitness assessment
/// and a safety check. Replaces the generic onboarding for new users and
/// opens as a route for existing users who have not registered yet.
class HunterRegistrationScreen extends StatefulWidget {
  const HunterRegistrationScreen({super.key});

  @override
  State<HunterRegistrationScreen> createState() => _HunterRegistrationScreenState();
}

class _HunterRegistrationScreenState extends State<HunterRegistrationScreen> {
  static const _bootLines = [
    '[SYSTEM INITIALIZATION]',
    'Player detected.',
    'Fitness potential assessment initiated.',
    'Hunter System activated.',
    'Your journey starts now.',
  ];

  int _step = 0;
  int _shown = 0;
  Timer? _typer;

  late final _name = TextEditingController(
    text: hunter.player?.name ?? (fit.profile.name == 'InlitX' ? '' : fit.profile.name),
  );
  int _experience = hunter.player?.experience ?? 0;
  String _class = hunter.player?.classId ?? kHunterClasses.first.id;
  final Set<String> _places = {'home'};
  int _minutes = hunter.player?.minutes ?? 20;
  int _weekly = hunter.player?.weeklyTarget ?? 3;
  late final Set<String> _limits = {...?hunter.player?.limitations};
  late final List<bool> _screen = hunter.screeningAnswers;

  @override
  void initState() {
    super.initState();
    _typer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted || _shown >= _bootLines.length) {
        t.cancel();
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _shown++);
    });
  }

  @override
  void dispose() {
    _typer?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    setState(() => _step++);
  }

  void _back() => setState(() => _step = (_step - 1).clamp(0, 6));

  void _finish() {
    HapticFeedback.heavyImpact();
    hunter.register(
      name: _name.text,
      experience: _experience,
      classId: _class,
      minutes: _minutes,
      weeklyTarget: _weekly,
      limitations: _limits.toList(),
      screening: _screen,
    );
    if (!fit.onboarded) {
      String? first;
      for (final preset in kPlacePresets) {
        if (!_places.contains(preset)) continue;
        final gear = kPlacePresetGear[preset]!;
        final id = fit.addPlace(t.placePresetName(preset), equipment: {...gear, 'Bodyweight'});
        if (id.isNotEmpty) first ??= id;
      }
      if (first != null) fit.setActivePlace(first);
      fit.completeOnboarding();
    } else {
      fit.goHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final still = MediaQuery.of(context).disableAnimations;
    if (still && _shown < _bootLines.length) _shown = _bootLines.length;
    return Scaffold(
      backgroundColor: gc.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (_step > 0 && _step < 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: _back,
                      icon: Icon(PhosphorIconsBold.caretLeft, size: 20, color: gc.textSecondary),
                    ),
                    Expanded(child: SystemBar(value: _step / 5, height: 4)),
                    const SizedBox(width: 12),
                    Text('$_step / 5', style: Sx.disp(13, color: gc.textSecondary)),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 0 : 320),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: switch (_step) {
                      0 => _boot(gc),
                      1 => _nameStep(gc),
                      2 => _assessment(gc),
                      3 => _training(gc),
                      4 => _limitsStep(gc),
                      5 => _safety(gc),
                      _ => _reveal(gc),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String kicker, String title, [String? body]) {
    final gc = context.gc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(kicker, color: context.sx.mana),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppTheme.f(28, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.3),
        ),
        if (body != null) ...[const SizedBox(height: 8), Text(body, style: AppTheme.s(14.5, color: gc.textSecondary))],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _option(String title, String subtitle, bool selected, VoidCallback onTap) {
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SystemWindow(
        accent: selected ? context.sx.mana : gc.border,
        glow: selected,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: Sx.disp(16, color: gc.text)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTheme.s(13, color: gc.textSecondary)),
                  ],
                ],
              ),
            ),
            Icon(
              selected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
              color: selected ? context.sx.mana : gc.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _boot(GymColors gc) => [
    const SizedBox(height: 40),
    const Center(child: RankEmblem(letter: '?', size: 96)),
    const SizedBox(height: 32),
    SystemWindow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _shown; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _bootLines[i],
                style: Sx.disp(i == 0 ? 18 : 17, color: i == 0 ? context.sx.mana : gc.text, spacing: i == 0 ? 2 : 0.6),
              ),
            ),
          if (_shown < _bootLines.length) Text('▌', style: Sx.disp(17, color: context.sx.mana)),
        ],
      ),
    ),
    const SizedBox(height: 32),
    AnimatedOpacity(
      opacity: _shown >= _bootLines.length ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: PrimaryButton(label: 'Begin assessment', onTap: _shown >= _bootLines.length ? _next : () {}),
    ),
    const SizedBox(height: 14),
    Text(
      'Ranks, levels and attributes are game classifications of your training, not medical or professional '
      'fitness assessments.',
      textAlign: TextAlign.center,
      style: AppTheme.s(12, color: gc.textTertiary),
    ),
  ];

  List<Widget> _nameStep(GymColors gc) => [
    _title('REGISTRATION', 'Hunter name', 'How should the System address you?'),
    TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      maxLength: 24,
      style: Sx.disp(24, color: gc.text),
      decoration: const InputDecoration(hintText: 'Your hunter name'),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 20),
    PrimaryButton(label: 'Confirm', onTap: () => _name.text.trim().isEmpty ? null : _next()),
  ];

  List<Widget> _assessment(GymColors gc) => [
    _title(
      'ASSESSMENT',
      'Training experience',
      'Quest difficulty comes from this, never from your level. You can change it later.',
    ),
    for (var i = 0; i < kExperienceLevels.length; i++)
      _option(
        '${kExperienceLevels[i].$1} · ${kExperienceDifficulty[i]}-Rank quests',
        kExperienceLevels[i].$2,
        _experience == i,
        () => setState(() => _experience = i),
      ),
    const SizedBox(height: 18),
    Text('CHOOSE YOUR PATH', style: Sx.disp(14, color: gc.textSecondary, spacing: 1.8)),
    const SizedBox(height: 10),
    for (final c in kHunterClasses)
      _option('${c.name} — ${c.focus}', c.story, _class == c.id, () => setState(() => _class = c.id)),
    const SizedBox(height: 14),
    PrimaryButton(label: 'Continue', onTap: _next),
  ];

  List<Widget> _training(GymColors gc) => [
    _title('ASSESSMENT', 'Your training ground'),
    Text('WHERE DO YOU TRAIN?', style: Sx.disp(14, color: gc.textSecondary, spacing: 1.8)),
    const SizedBox(height: 10),
    if (fit.onboarded)
      Text('Equipment comes from your Places in the training hub.', style: AppTheme.s(13, color: gc.textTertiary))
    else
      for (final p in kPlacePresets)
        _option(
          t.placePresetName(p),
          (kPlacePresetGear[p] ?? const []).take(6).join(', '),
          _places.contains(p),
          () => setState(() => _places.contains(p) && _places.length > 1 ? _places.remove(p) : _places.add(p)),
        ),
    const SizedBox(height: 18),
    Text('TIME PER SESSION', style: Sx.disp(14, color: gc.textSecondary, spacing: 1.8)),
    const SizedBox(height: 10),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in kSessionMinutes)
          ChoiceChip(label: Text('$m min'), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = m)),
      ],
    ),
    const SizedBox(height: 18),
    Text('TRAINING DAYS PER WEEK', style: Sx.disp(14, color: gc.textSecondary, spacing: 1.8)),
    const SizedBox(height: 10),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var d = 1; d <= 6; d++)
          ChoiceChip(label: Text('$d'), selected: _weekly == d, onSelected: (_) => setState(() => _weekly = d)),
      ],
    ),
    const SizedBox(height: 6),
    Text('Pick what is realistic. Rest days are part of training.', style: AppTheme.s(12.5, color: gc.textTertiary)),
    const SizedBox(height: 22),
    PrimaryButton(label: 'Continue', onTap: _next),
  ];

  List<Widget> _limitsStep(GymColors gc) => [
    _title(
      'ASSESSMENT',
      'Physical limitations',
      'The System keeps load off these areas when it builds your quests. Select any that apply.',
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(label: const Text('None'), selected: _limits.isEmpty, onSelected: (_) => setState(_limits.clear)),
        for (final l in kLimitations.keys)
          FilterChip(
            label: Text(l),
            selected: _limits.contains(l),
            selectedColor: context.sx.gold.withValues(alpha: 0.25),
            onSelected: (on) => setState(() => on ? _limits.add(l) : _limits.remove(l)),
          ),
      ],
    ),
    const SizedBox(height: 22),
    PrimaryButton(label: 'Continue', onTap: _next),
  ];

  List<Widget> _safety(GymColors gc) => [
    _title(
      'SAFETY CHECK',
      'Before you enter',
      'A short readiness screen based on PAR-Q+. It is not a diagnosis and nothing leaves your phone.',
    ),
    for (var i = 0; i < kScreeningQuestions.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(kScreeningQuestions[i], style: AppTheme.s(13.5, color: gc.text)),
            ),
            const SizedBox(width: 8),
            SegToggle([
              SegOption('No', !_screen[i], () => setState(() => _screen[i] = false)),
              SegOption('Yes', _screen[i], () => setState(() => _screen[i] = true)),
            ]),
          ],
        ),
      ),
    if (_screen.any((a) => a))
      SystemWindow(
        accent: context.sx.gold,
        title: 'Clinician first',
        child: Text(
          'Please talk to a doctor or qualified clinician before starting or increasing training. '
          'The System will still work; keep effort light until you are cleared.',
          style: AppTheme.s(13, color: gc.text),
        ),
      ),
    const SizedBox(height: 18),
    PrimaryButton(label: 'Complete assessment', onTap: _next),
  ];

  List<Widget> _reveal(GymColors gc) {
    final cls = hunterClassById(_class);
    return [
      const SizedBox(height: 10),
      Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: ParticleBurst(color: context.sx.mana, enabled: hunter.animationsOn),
          ),
          const RankEmblem(letter: 'E', size: 120),
        ],
      ),
      const SizedBox(height: 12),
      Center(child: SectionLabel('Player awakened', color: context.sx.mana)),
      const SizedBox(height: 6),
      Text(
        _name.text.trim().isEmpty ? 'Hunter' : _name.text.trim(),
        textAlign: TextAlign.center,
        style: Sx.disp(32, color: gc.text),
      ),
      Text(
        '${cls.name} · E-Rank · Level 1 · 0 XP',
        textAlign: TextAlign.center,
        style: AppTheme.s(14, color: gc.textSecondary),
      ),
      const SizedBox(height: 18),
      SystemWindow(
        title: 'Player attributes',
        child: Column(
          children: [
            for (final a in Attr.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(a.label.toUpperCase(), style: Sx.disp(15, color: gc.text)),
                    ),
                    Text('LV 01', style: Sx.disp(15, color: context.sx.mana)),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      PrimaryButton(label: 'Enter the System', onTap: _finish),
    ];
  }
}
