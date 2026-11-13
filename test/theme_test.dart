import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:level_up/l10n/l10n.dart';
import 'package:level_up/services/local_store.dart';
import 'package:level_up/state/fit_state.dart';
import 'package:level_up/system/system_widgets.dart';
import 'package:level_up/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('light theme belongs to the same family as dark', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Store.instance.init();
      fit.resetAllData();
      fit.onboarded = true;
      setAppLanguage('en');
    });

    double lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    double contrast(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    double warmth(Color c) => (c.r - c.b) * 255;

    test('light neutrals carry the cool System blue, not warm bone', () {
      for (final c in [GymColors.light.bg, GymColors.light.bgRaised2, GymColors.light.border]) {
        expect(warmth(c), lessThan(0), reason: 'neutral is not System blue: $c');
      }
    });

    test('every text colour on light is actually readable', () {
      final bg = GymColors.light.bg;
      expect(contrast(bg, GymColors.light.text), greaterThan(7), reason: 'principal, AAA');
      expect(contrast(bg, GymColors.light.textSecondary), greaterThan(4.5), reason: 'secundario, AA');

      expect(contrast(bg, GymColors.light.textTertiary), greaterThan(3), reason: 'terciario');
    });

    test('the light accent reads on the light background', () {

      expect(contrast(GymColors.light.bg, GymColors.light.accent), greaterThanOrEqualTo(4.5));
    });

    test('dark text stays readable too', () {
      final bg = GymColors.dark.bg;
      expect(contrast(bg, GymColors.dark.text), greaterThan(7));
      expect(contrast(bg, GymColors.dark.textSecondary), greaterThan(4.5));
    });

    test('action colour flips with the theme but keeps its contrast', () {
      expect(contrast(GymColors.dark.ember, GymColors.dark.onEmber), greaterThan(7));
      expect(contrast(GymColors.light.ember, GymColors.light.onEmber), greaterThan(7));
    });

    group('hunter accents keep WCAG AA in both themes', () {
      List<Color> accents(HunterPalette p) => [p.mana, p.violet, p.gold, p.vital, p.alert, p.muted, p.holo];

      test('light accents read on every light surface', () {
        for (final surface in [GymColors.light.bg, GymColors.light.bgRaised, GymColors.light.bgRaised2]) {
          for (final c in accents(HunterPalette.light)) {
            expect(contrast(surface, c), greaterThanOrEqualTo(4.5), reason: '$c on $surface');
          }
        }
      });

      test('dark accents are unchanged and still readable', () {
        for (final surface in [GymColors.dark.bg, GymColors.dark.bgRaised2]) {
          for (final c in accents(HunterPalette.dark)) {
            expect(contrast(surface, c), greaterThanOrEqualTo(4.5), reason: '$c on $surface');
          }
        }
      });

      test('rank letters pick a readable accent in each theme', () {
        for (final letter in ['E', 'D', 'C', 'B', 'A', 'S']) {
          expect(contrast(GymColors.light.bg, HunterPalette.light.rank(letter)), greaterThanOrEqualTo(4.5));
          expect(contrast(GymColors.dark.bg, HunterPalette.dark.rank(letter)), greaterThanOrEqualTo(4.5));
        }
      });
    });
  });
}
