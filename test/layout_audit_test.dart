import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/app/level_up_app.dart';
import 'package:level_up/l10n/l10n.dart';
import 'package:level_up/models/workout.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/services/progress_reminder.dart';
import 'package:level_up/services/system_reminder.dart';
import 'package:level_up/services/train_reminder.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:level_up/system/hunter_catalog.dart';
import 'package:level_up/system/hunter_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whole-app layout audit. Every primary destination is rendered on a small
/// phone and on a large phone, with normal and very large system text, then
/// scrolled through so lazily built children are laid out too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const routes = <String>[
    'home',
    'progress',
    'train',
    'exercises',
    'exercise-detail',
    'tools',
    'tools-detail',
    'settings',
    'preferences',
    'moments',
    'awards',
    'passes',
    'about',
    'routines',
    'ai-plan',
    'routine-edit',
    'measures',
    'places',
    'timeline',
    'compare',
    'notes',
    'note-edit',
    'history',
    'nutrition',
    'health',
    'system',
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    ProgressReminder.instance.enabled = false;
    TrainReminder.instance.enabled = false;
    SystemReminder.instance.enabled = false;
    fit.resetAllData();
    fit.pendingAwards.clear();
    hunter.invalidate();
    hunter.setSetting('freq', 'off');
    setAppLanguage('en');
  });

  Future<void> settle(WidgetTester tester, [int frames = 14]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  void fixture() {
    fit.onboarded = true;
    hunter.register(
      name: 'A Very Long Hunter Name',
      experience: 2,
      classId: 'strength',
      minutes: 45,
      weeklyTarget: 4,
      limitations: const ['Knees'],
      screening: List.filled(kScreeningQuestions.length, false),
    );
    final now = DateTime.now();
    for (var i = 0; i < 14; i++) {
      fit.sessions.add(LoggedSession(DateTime(now.year, now.month, now.day - i, 18), 3000, [
        LoggedExercise('EIeI8Vf', 'Barbell Bench Press With A Very Long Exercise Name', 'chest', [
          for (var k = 0; k < 4; k++) LoggedSet(10, 60.0 + i + k),
        ]),
        LoggedExercise('plank-hold', 'Plank', 'abdomen', [LoggedSet(0, 0, sec: 45)]),
      ]));
    }
    hunter.logCheckIn(energy: 2, soreness: 3, stress: 2, pain: false, sleep: 5.5);
    hunter.addInjury('hamstrings', 5, 'tight');
    hunter.invalidate();
    fit.activeExerciseId = 'EIeI8Vf';
    fit.activeToolId = 'rm';
  }

  Future<void> sweep(WidgetTester tester, String route, Size size, double scale) async {
    await tester.binding.setSurfaceSize(size);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    fixture();
    fit.route = route;
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester);
    final first = tester.takeException();
    expect(first, isNull, reason: '$route on ${size.width}x${size.height} @$scale');

    final scrollables = find.byType(Scrollable).evaluate().toList();
    for (final element in scrollables) {
      final target = find.byElementPredicate((candidate) => identical(candidate, element));
      if (!tester.any(target)) continue;
      for (var step = 0; step < 8; step++) {
        if (!tester.any(target)) break;
        await tester.drag(target, const Offset(0, -420), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull,
            reason: '$route scrolled on ${size.width}x${size.height} @$scale');
      }
    }
  }

  for (final route in routes) {
    testWidgets('$route on a 320x568 phone at 2x text', (tester) async {
      await sweep(tester, route, const Size(320, 568), 2.0);
    });
  }

  for (final route in routes) {
    testWidgets('$route on a 320x568 phone', (tester) async {
      await sweep(tester, route, const Size(320, 568), 1.0);
    });
  }

  for (final route in routes) {
    testWidgets('$route on a 360x800 phone', (tester) async {
      await sweep(tester, route, const Size(360, 800), 1.0);
    });
  }

  for (final route in routes) {
    testWidgets('$route on a 393x852 phone', (tester) async {
      await sweep(tester, route, const Size(393, 852), 1.0);
    });
  }

  for (final route in routes) {
    testWidgets('$route on a 430x932 phone', (tester) async {
      await sweep(tester, route, const Size(430, 932), 1.0);
    });
  }

  for (final route in routes) {
    testWidgets('$route on a 430x932 phone at 1.3x text', (tester) async {
      await sweep(tester, route, const Size(430, 932), 1.3);
    });
  }

  for (final route in routes) {
    testWidgets('$route in landscape at 1x text', (tester) async {
      await sweep(tester, route, const Size(640, 320), 1.0);
    });
  }
}
