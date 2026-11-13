// Renders the main screens to PNG files under build/shots so the look can be
// reviewed without a device. Not an assertion test: run it on demand with
//   SHOTS=1 PHOSPHOR=<path to the phosphoricons_flutter package> flutter test test/visual/shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:level_up/system/hunter_home.dart';
import 'package:level_up/system/hunter_models.dart';
import 'package:level_up/system/system_screen.dart';
import 'package:level_up/system/system_sheets.dart';
import 'package:level_up/widgets/profile_avatar.dart';
import 'package:level_up/widgets/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _on = Platform.environment['SHOTS'] == '1';
final _phosphor = Platform.environment['PHOSPHOR'] ?? '';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_on) return;
    await _font('Nunito', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'])
        'assets/fonts/Nunito-$w.ttf',
    ]);
    for (final (family, file) in [
      ('PhosphorRegular', 'Phosphor'),
      ('PhosphorBold', 'Phosphor-Bold'),
      ('PhosphorFill', 'Phosphor-Fill'),
      ('PhosphorLight', 'Phosphor-Light'),
      ('PhosphorThin', 'Phosphor-Thin'),
      ('PhosphorDuotone', 'Phosphor-Duotone'),
    ]) {
      await _font('packages/phosphoricons_flutter/$family', ['$_phosphor/lib/fonts/$file.ttf']);
    }
  });

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

  Future<void> warmImages(WidgetTester tester) async {
    final ctx = tester.element(find.byType(LevelUpApp));
    await tester.runAsync(() async {
      await precacheImage(kDefaultBanner, ctx);
      await precacheImage(ProfileAvatar.defaultPhoto, ctx);
    });
    await tester.pump();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    late ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/shots/$name.png')..createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('registration', skip: !_on, (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fit.onboarded = false;
    await tester.pumpWidget(RepaintBoundary(child: const LevelUpApp()));
    await warmImages(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot(tester, '00-registration-1');
    await tester.tap(find.byType(PrimaryButton).last);
    await shot(tester, '00-registration-2');
  });

  testWidgets('main screens', skip: !_on, (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fit.onboarded = true;
    hunter.register(
      name: 'Kael',
      experience: 1,
      classId: 'hypertrophy',
      minutes: 30,
      weeklyTarget: 3,
      limitations: const [],
      screening: List.filled(kScreeningQuestions.length, false),
    );
    final p = Map<String, dynamic>.from(fit.hunterData['player'] as Map);
    final n = DateTime.now();
    p['created'] = DateTime(n.year, n.month, n.day - 20).toIso8601String();
    fit.hunterData['player'] = p;
    for (final d in [1, 2, 4, 6, 8, 9, 12]) {
      fit.sessions.add(
        LoggedSession(DateTime(n.year, n.month, n.day - d, 18), 45 * 60, [
          LoggedExercise('EIeI8Vf', 'Barbell Bench Press', 'chest', [
            for (var i = 0; i < 4; i++) LoggedSet(8, 60.0 + d),
          ]),
        ]),
      );
    }
    hunter.invalidate();

    await tester.pumpWidget(RepaintBoundary(child: const LevelUpApp()));
    await warmImages(tester);
    await shot(tester, '01-home');
    fit.goTrain();
    await shot(tester, '02-train');
    fit.goSystem();
    await shot(tester, '03-hunter');
    for (final (i, tab) in [(1, 'quests'), (3, 'rank'), (4, 'skills'), (5, 'achievements')]) {
      fit.goHome();
      await tester.pump(const Duration(milliseconds: 600));
      SystemScreen.open(i);
      await shot(tester, '04-hunter-$tab');
    }
    fit.goProgress();
    await shot(tester, '05-progress');
    fit.goSettings();
    await shot(tester, '06-profile');
    fit.goTrain();
    fit.goExercises();
    await shot(tester, '07-library');
    fit.openExercise('EIeI8Vf');
    await shot(tester, '08-exercise');
    fit.goTrain();
    fit.startWorkout();
    await shot(tester, '09-build-workout');
    fit.closeTrain();
    fit.goPreferences();
    await shot(tester, '10-settings');
    for (final (name, go) in <(String, VoidCallback)>[
      ('13-nutrition', fit.goNutrition),
      ('14-health', () => fit.pushRoute('health')),
      ('15-routines', fit.goRoutines),
      ('16-history', () => fit.goHistory()),
      ('17-tools', fit.goTools),
      ('18-medals', fit.goAwards),
      ('19-measures', fit.goMeasures),
      ('20-about', fit.goAbout),
      ('21-timeline', fit.goTimeline),
    ]) {
      fit.goHome();
      await tester.pump(const Duration(milliseconds: 600));
      go();
      await shot(tester, name);
    }
    fit.goHome();
    await tester.pump(const Duration(milliseconds: 600));
    final ctx = tester.element(find.byType(HunterHome));
    final quest = hunter.status.todayQuests.first;
    showQuestSheet(ctx, quest.id);
    await shot(tester, '22-quest-sheet');
    Navigator.of(ctx, rootNavigator: true).pop();
    await tester.pump(const Duration(seconds: 1));
    showCheckInSheet(ctx);
    await shot(tester, '23-checkin-sheet');
    Navigator.of(ctx, rootNavigator: true).pop();
    await tester.pump(const Duration(seconds: 1));
    showAttributeSheet(ctx, Attr.strength);
    await shot(tester, '24-attribute-sheet');
    Navigator.of(ctx, rootNavigator: true).pop();
    await tester.pump(const Duration(seconds: 1));
    showInboxSheet(ctx);
    await shot(tester, '25-inbox-sheet');
    Navigator.of(ctx, rootNavigator: true).pop();
    await tester.pump(const Duration(seconds: 1));

    fit.setThemePref('light');
    fit.goHome();
    await shot(tester, '30-light-home');
    fit.goTrain();
    await shot(tester, '31-light-train');
    fit.goSystem();
    await shot(tester, '32-light-hunter');
    fit.goProgress();
    await shot(tester, '33-light-progress');
    fit.setThemePref('dark');

    fit.goHome();
    fit.startWorkout(['chest']);
    fit.trainContinue();
    await shot(tester, '11-review-picks');
    if (fit.sessionPicks.isEmpty) {
      fit.sessionPicks.addAll([
        'EIeI8Vf',
        for (final e in fit.allExercises.where((e) => e.primary == 'chest').skip(1).take(2)) e.id,
      ]);
    }
    fit.startSession();
    await tester.pump(const Duration(milliseconds: 300));
    fit.endCountdown();
    await shot(tester, '12-session');
    fit.discardSession();
    await tester.pump(const Duration(seconds: 2));
    fit.goHome();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
