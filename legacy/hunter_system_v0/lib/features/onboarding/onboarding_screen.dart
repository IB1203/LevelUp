import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';

/// First launch: the System boots, asks a few questions, and awakens the
/// player. Nothing here creates an online account; everything stays on the
/// device.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _bootLines = [
    'Initializing Hunter System…',
    'Scanning for a candidate…',
    'Evaluating potential…',
    'System activated.',
  ];

  // Step 0 is the boot sequence, steps 1–5 are questions, step 6 is the reveal.
  int _step = 0;
  int _bootShown = 0;
  Timer? _bootTimer;

  final _name = TextEditingController();
  ExperienceLevel? _experience;
  FitnessGoal? _goal;
  Set<Equipment> _equipment = {};
  int _minutes = 15;
  Set<Limitation> _limitations = {};

  @override
  void initState() {
    super.initState();
    _bootTimer = Timer.periodic(const Duration(milliseconds: 850), (t) {
      if (!mounted) return;
      setState(() => _bootShown++);
      if (_bootShown >= _bootLines.length) t.cancel();
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _name.dispose();
    super.dispose();
  }

  bool get _canContinue {
    switch (_step) {
      case 1:
        return _name.text.trim().isNotEmpty;
      case 2:
        return _experience != null;
      case 3:
        return _goal != null;
      default:
        return true;
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      _bootTimer?.cancel();
      setState(() {
        _bootShown = _bootLines.length;
        _step = 1;
      });
      return;
    }
    if (_step < 6) {
      setState(() => _step++);
      return;
    }
    ref.read(appProvider.notifier).createPlayer(
          Player(
            name: _name.text.trim(),
            experience: _experience!,
            goal: _goal!,
            equipment: _equipment,
            minutes: _minutes,
            limitations: _limitations,
          ),
        );
  }

  String get _buttonLabel {
    if (_step == 0) return _bootShown >= _bootLines.length ? 'Begin' : 'Skip intro';
    if (_step == 6) return 'Accept first quest';
    return 'Continue';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step >= 1 && _step <= 6) ...[
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _step > 1 ? () => setState(() => _step--) : null,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: XpBar(progress: (_step / 5).clamp(0.0, 1.0), height: 6)),
                    const SizedBox(width: 12),
                    Text(
                      _step <= 5 ? '$_step of 5' : 'Ready',
                      style: text.labelMedium!.copyWith(color: Hx.textDim),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Expanded(child: SingleChildScrollView(child: _content(text))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _canContinue ? _next : null,
                child: Text(_buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(TextTheme text) {
    switch (_step) {
      case 0:
        return _boot(text);
      case 1:
        return _question(
          text,
          'What should the System call you?',
          'This is your hunter name. You can change it later.',
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            style: text.titleLarge,
            decoration: const InputDecoration(hintText: 'Hunter name', counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canContinue) _next();
            },
          ),
        );
      case 2:
        return _question(
          text,
          'How much training experience do you have?',
          'This sets how hard your first quests are. When unsure, pick the lower one.',
          Column(
            children: [
              for (final e in ExperienceLevel.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SystemPanel(
                    accent: _experience == e ? Hx.mana : Hx.line,
                    glow: _experience == e,
                    onTap: () => setState(() => _experience = e),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.label, style: text.titleMedium),
                              const SizedBox(height: 2),
                              Text(e.hint, style: text.bodyMedium!.copyWith(color: Hx.textDim)),
                            ],
                          ),
                        ),
                        if (_experience == e) const Icon(Icons.check, color: Hx.mana),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      case 3:
        return _question(
          text,
          'What are you training for?',
          'Your goal decides which kinds of quests come up most often.',
          SingleChoice<FitnessGoal>(
            options: FitnessGoal.values,
            selected: _goal,
            label: (g) => g.label,
            onChanged: (g) => setState(() => _goal = g),
          ),
        );
      case 4:
        return _question(
          text,
          'What do you have to train with?',
          'Bodyweight is always included. Select anything else you can use.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MultiChoice<Equipment>(
                options: Equipment.values,
                selected: _equipment,
                label: (e) => e.label,
                onChanged: (s) => setState(() => _equipment = s),
              ),
              const SizedBox(height: 28),
              Text('How long should a daily quest take?', style: text.titleMedium),
              const SizedBox(height: 10),
              SingleChoice<int>(
                options: GameRules.questDurations,
                selected: _minutes,
                label: (m) => m == 45 ? '45+ min' : '$m min',
                onChanged: (m) => setState(() => _minutes = m),
              ),
            ],
          ),
        );
      case 5:
        return _question(
          text,
          'Any areas to go easy on?',
          'Exercises that load these areas are kept out of your quests. '
              'Leave it empty if nothing applies.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MultiChoice<Limitation>(
                options: Limitation.values,
                selected: _limitations,
                label: (l) => l.label,
                onChanged: (s) => setState(() => _limitations = s),
              ),
              const SizedBox(height: 20),
              Text(
                'This is a training filter, not medical advice. If you have an '
                'injury or a health condition, check with a doctor before '
                'starting a new routine.',
                style: text.bodySmall!.copyWith(color: Hx.textDim, height: 1.4),
              ),
            ],
          ),
        );
      default:
        return _reveal(text);
    }
  }

  Widget _boot(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _bootLines.length; i++)
            AnimatedOpacity(
              opacity: i < _bootShown ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _bootLines[i],
                  style: i == _bootLines.length - 1
                      ? text.headlineMedium!.copyWith(color: Hx.mana)
                      : text.titleLarge!.copyWith(color: Hx.textDim),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _question(TextTheme text, String title, String help, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineMedium),
        const SizedBox(height: 8),
        Text(help, style: text.bodyLarge!.copyWith(color: Hx.textDim, height: 1.4)),
        const SizedBox(height: 24),
        body,
      ],
    );
  }

  Widget _reveal(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SystemPanel(
        accent: Hx.mana,
        glow: true,
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            const SystemLine('Player awakened', center: true),
            const SizedBox(height: 24),
            const RankEmblem(letter: 'E', size: 112),
            const SizedBox(height: 20),
            Text(_name.text.trim(), style: text.displaySmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Rank E, level 1', style: text.titleMedium!.copyWith(color: Hx.textDim)),
            const SizedBox(height: 24),
            Text(
              'Every hunter starts here. Your first quest is ready, sized for '
              '$_minutes minutes and built around what you told the System.',
              textAlign: TextAlign.center,
              style: text.bodyLarge!.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
