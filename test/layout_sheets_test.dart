import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/app/level_up_app.dart';
import 'package:level_up/l10n/l10n.dart';
import 'package:level_up/models/workout.dart';
import 'package:level_up/screens/start_sheet.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/services/progress_reminder.dart';
import 'package:level_up/services/system_reminder.dart';
import 'package:level_up/services/train_reminder.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:level_up/system/hunter_catalog.dart';
import 'package:level_up/system/hunter_engine.dart';
import 'package:level_up/system/hunter_home.dart';
import 'package:level_up/system/system_sheets.dart';
import 'package:level_up/theme/app_theme.dart';
import 'package:level_up/widgets/dialogs.dart';
import 'package:level_up/widgets/ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overlay surfaces are laid out in their own route, so they need their own
/// small-screen and large-text coverage: quest sheet, check-in, start sheet,
/// text dialogs and the generic AppSheet with the keyboard open.
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
    setAppLanguage('en');
  });

  Future<void> settle(WidgetTester tester, [int frames = 14]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  void registerHunter() {
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
    for (var i = 0; i < 5; i++) {
      fit.sessions.add(LoggedSession(DateTime(now.year, now.month, now.day - i, 18), 2700, [
        LoggedExercise('EIeI8Vf', 'Barbell Bench Press With A Very Long Exercise Name', 'chest', [
          for (var k = 0; k < 4; k++) LoggedSet(10, 60.0 + i + k),
        ]),
      ]));
    }
    hunter.logCheckIn(energy: 2, soreness: 3, stress: 2, pain: false, sleep: 5.5);
    hunter.addInjury('hamstrings', 5, 'tight');
    hunter.invalidate();
  }

  Future<BuildContext> pumpHome(WidgetTester tester, Size size, double scale) async {
    await tester.binding.setSurfaceSize(size);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    registerHunter();
    fit.resetRoute('home');
    await tester.pumpWidget(const LevelUpApp());
    await settle(tester);
    expect(find.byType(HunterHome), findsOneWidget);
    return tester.element(find.byType(HunterHome));
  }

  testWidgets('quest sheet holds its layout at 320x568 with 2x text', (tester) async {
    final context = await pumpHome(tester, const Size(320, 568), 2.0);
    final quest = hunter.status.todayQuests.first;
    showQuestSheet(context, quest.id);
    await settle(tester, 8);
    expect(find.text(quest.name), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'quest sheet at 2x text');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('check-in sheet holds its layout at 320x568 with 2x text', (tester) async {
    final context = await pumpHome(tester, const Size(320, 568), 2.0);
    showCheckInSheet(context);
    await settle(tester, 8);
    expect(tester.takeException(), isNull, reason: 'check-in sheet at 2x text');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('start sheet holds its layout at 320x568 with 2x text', (tester) async {
    final context = await pumpHome(tester, const Size(320, 568), 2.0);
    showStartSheet(context);
    await settle(tester, 8);
    expect(tester.takeException(), isNull, reason: 'start sheet at 2x text');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a text dialog stays usable with the keyboard open at 320x568 with 2x text',
      (tester) async {
    final context = await pumpHome(tester, const Size(320, 568), 2.0);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    final result = askText(context, title: 'Rename profile', initial: 'A very long initial value here');
    await settle(tester, 8);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'text dialog with keyboard at 2x text');
    await tester.tap(find.text(t.cancel).last, warnIfMissed: false);
    await settle(tester, 4);
    await result;
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AppSheet scrolls a long form above the keyboard at 320x568 with 2x text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          viewInsets: EdgeInsets.only(bottom: 260),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppSheet(
              children: [
                for (var i = 0; i < 12; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('Field label number $i with a long descriptive sentence',
                        style: const TextStyle(fontSize: 15)),
                  ),
                const TextField(decoration: InputDecoration(labelText: 'Note')),
              ],
            ),
          ),
        ),
      ),
    ));
    await settle(tester, 6);
    expect(tester.takeException(), isNull, reason: 'AppSheet with keyboard at 2x text');
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.takeException(), isNull, reason: 'AppSheet scrolled with keyboard at 2x text');
    await tester.pumpWidget(const SizedBox());
  });
}
