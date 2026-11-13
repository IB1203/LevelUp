import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.session = null;
    fit.goHome();
  });

  test('the Train tab opens the training hub and keeps the bottom bar', () {
    fit.goTrain();
    expect(fit.route, 'training');
    expect(fit.showNav, isTrue);
    expect(fit.routeDepth, 0);
  });

  test('the five tabs are roots: back from any of them lands on Home', () {
    for (final go in [fit.goTrain, fit.goSystem, fit.goProgress, fit.goSettings]) {
      go();
      expect(fit.showNav, isTrue, reason: fit.route);
      expect(fit.handleBack(), isTrue);
      expect(fit.route, 'home');
    }
    expect(fit.handleBack(), isFalse, reason: 'Home is where the app closes');
  });

  test('the exercise library opens from the hub and goes back to it', () {
    fit.goTrain();
    fit.goExercises();
    expect(fit.route, 'exercises');
    expect(fit.showNav, isFalse);
    fit.handleBack();
    expect(fit.route, 'training');
  });

  test('an exercise opened from the library walks back through it to the hub', () {
    fit.goTrain();
    fit.goExercises();
    fit.openExercise(fit.allExercises.first.id);
    fit.handleBack();
    expect(fit.route, 'exercises');
    fit.handleBack();
    expect(fit.route, 'training');
  });

  test('building a workout from the hub closes back to the hub, not Home', () {
    fit.goTrain();
    fit.startWorkout();
    expect(fit.route, 'train');
    fit.closeTrain();
    expect(fit.route, 'training');
  });
}
