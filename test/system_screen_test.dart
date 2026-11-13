import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/app/level_up_app.dart';
import 'package:level_up/l10n/l10n.dart';
import 'package:level_up/models/workout.dart';
import 'package:level_up/screens/profile_screen.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/services/progress_reminder.dart';
import 'package:level_up/services/train_reminder.dart';
import 'package:level_up/services/system_reminder.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:level_up/system/hunter_catalog.dart';
import 'package:level_up/system/hunter_engine.dart';
import 'package:level_up/system/hunter_home.dart';
import 'package:level_up/system/registration_screen.dart';
import 'package:level_up/system/system_screen.dart';
import 'package:level_up/system/system_sheets.dart';
import 'package:level_up/widgets/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  Future<void> settle(WidgetTester tester, [int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapPrimary(WidgetTester tester) async {
    final b = find.byType(PrimaryButton).last;
    await tester.ensureVisible(b);
    await tester.pump();
    await tester.tap(b);
    await settle(tester, 6);
  }

  testWidgets('a new user registers through the Hunter System and lands on the hunter dashboard', (
    tester,
  ) async {
    setAppLanguage('en');
    await tester.binding.setSurfaceSize(const Size(360, 780));
    fit.onboarded = false;
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester, 40); // boot sequence types out
    expect(find.byType(HunterRegistrationScreen), findsOneWidget);
    expect(find.text('[SYSTEM INITIALIZATION]'), findsOneWidget);
    expect(find.text('Your journey starts now.'), findsOneWidget);

    await tapPrimary(tester); // begin assessment
    await tester.enterText(find.byType(TextField), 'Kael');
    await tester.pump();
    await tapPrimary(tester); // name
    await tapPrimary(tester); // experience + path
    await tapPrimary(tester); // ground, time, weekly target
    await tapPrimary(tester); // limitations
    await tapPrimary(tester); // safety
    expect(find.text('PLAYER AWAKENED'), findsOneWidget);
    await tapPrimary(tester); // enter
    await settle(tester);

    expect(fit.onboarded, isTrue);
    expect(hunter.registered, isTrue);
    expect(hunter.status.player!.name, 'Kael');
    expect(hunter.status.level, 1);
    expect(hunter.status.totalXp, 0);
    expect(find.byType(HunterHome), findsOneWidget);
    expect(find.text('DAILY QUESTS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('home, every System tab and the quest sheet render on a small phone', (tester) async {
    setAppLanguage('en');
    await tester.binding.setSurfaceSize(const Size(360, 740));
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
    for (var i = 0; i < 6; i++) {
      fit.sessions.add(
        LoggedSession(DateTime(now.year, now.month, now.day, 6 + i * 2), 1800, [
          LoggedExercise('EIeI8Vf', 'Barbell Bench Press', 'chest', [
            for (var k = 0; k < 4; k++) LoggedSet(8, 60.0 + i),
          ]),
          LoggedExercise('plank-hold', 'Plank', 'abdomen', [LoggedSet(0, 0, sec: 40 + i)]),
        ], routineId: 'r$i'),
      );
    }
    hunter.logCheckIn(energy: 4, soreness: 2, stress: 2, pain: false, sleep: 7.5);
    hunter.addInjury('hamstrings', 5, 'tight');
    hunter.invalidate();
    fit.resetRoute('home');
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester);

    expect(find.byType(HunterHome), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull, reason: 'home');

    for (var tab = 0; tab < SystemScreen.tabs.length; tab++) {
      SystemScreen.initialTab = tab;
      fit.resetRoute('home');
      fit.pushRoute('system');
      await settle(tester, 6);
      expect(find.byType(SystemScreen), findsOneWidget);
      for (var i = 0; i < 14; i++) {
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(tester.takeException(), isNull, reason: SystemScreen.tabs[tab]);
    }

    fit.goHome();
    await settle(tester, 4);
    final q = hunter.status.todayQuests.first;
    showQuestSheet(tester.element(find.byType(HunterHome)), q.id);
    await settle(tester, 6);
    expect(find.text(q.name), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'quest sheet');

    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the profile header holds its layout on a narrow screen with large text', (tester) async {
    setAppLanguage('en');
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    fit.onboarded = true;
    hunter.register(
      name: 'A Very Long Hunter Name',
      experience: 2,
      classId: 'strength',
      minutes: 45,
      weeklyTarget: 4,
      limitations: const [],
      screening: List.filled(kScreeningQuestions.length, false),
    );
    fit.setProfileHandle('a.very.long.handle.name');
    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      fit.sessions.add(
        LoggedSession(DateTime(now.year, now.month, now.day - i, 18), 2700, [
          LoggedExercise('EIeI8Vf', 'Barbell Bench Press', 'chest', [
            for (var k = 0; k < 4; k++) LoggedSet(8, 60.0 + i),
          ]),
        ]),
      );
    }
    hunter.invalidate();
    fit.goSettings();
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester, 20);

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'profile header at 2x text');
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tester.takeException(), isNull, reason: 'profile body at 2x text');

    // Same header with the Hunter System switched off (no rank, "This year" tile).
    fit.gamification = false;
    fit.resetRoute('home');
    fit.goSettings();
    await settle(tester, 12);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'profile without gamification');

    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the daily quest board holds its layout on a narrow screen with large text', (tester) async {
    setAppLanguage('en');
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    fit.onboarded = true;
    hunter.register(
      name: 'A Very Long Hunter Name',
      experience: 2,
      classId: 'strength',
      minutes: 45,
      weeklyTarget: 4,
      limitations: const [],
      screening: List.filled(kScreeningQuestions.length, false),
    );
    hunter.invalidate();
    SystemScreen.initialTab = 1;
    fit.resetRoute('home');
    fit.pushRoute('system');
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester, 14);

    expect(find.byType(SystemScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'quest board header at 2x text');
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tester.takeException(), isNull, reason: 'quest cards at 2x text');

    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Log it on a protein quest closes the sheet and opens Nutrition', (tester) async {
    setAppLanguage('en');
    await tester.binding.setSurfaceSize(const Size(400, 860));
    fit.onboarded = true;
    fit.setNutritionBeta(false); // even with Nutrition switched off
    hunter.register(
      name: 'Kael',
      experience: 1,
      classId: 'strength',
      minutes: 30,
      weeklyTarget: 3,
      limitations: const [],
      screening: List.filled(kScreeningQuestions.length, false),
    );
    hunter.status; // generates today's board
    final day = dayKey(DateTime.now());
    final id = 'q${day.replaceAll('-', '')}-discipline';
    fit.hunterData['quests'] = {
      ...(fit.hunterData['quests'] as Map),
      id: {
        'id': id,
        'day': day,
        'cat': 'discipline',
        'n': 'Protein Ration',
        'd': 'Reach your protein target',
        'diff': 'D',
        'obj': [],
        'xp': 15,
        'ax': {},
        'min': 0,
        'st': 'offered',
        'chk': 'protein',
        'tg': 126,
        'u': 'g',
      },
    };
    hunter.invalidate();
    fit.resetRoute('home');
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester);

    showQuestSheet(tester.element(find.byType(HunterHome)), id);
    await settle(tester, 6);
    expect(find.text('Protein Ration'), findsWidgets);
    final logIt = find.byType(PrimaryButton).last;
    await tester.ensureVisible(logIt);
    await tester.tap(logIt);
    await settle(tester, 8);

    expect(fit.route, 'nutrition');
    expect(fit.nutritionBeta, isTrue);
    expect(find.text('Reach your protein target'), findsNothing, reason: 'the quest sheet should be closed');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
