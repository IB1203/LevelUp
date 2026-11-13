import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/system/registration_screen.dart';
import 'package:level_up/widgets/ui_kit.dart';
import 'package:level_up/app/level_up_app.dart';
import 'package:level_up/l10n/l10n.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = false;
    setAppLanguage('en');
  });

  testWidgets('a new user gets the Hunter registration, and Back steps return', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LevelUpApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(HunterRegistrationScreen), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(find.text('Hunter name'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
    fit.onboarded = true;
    fit.persistNow();
  });
}
