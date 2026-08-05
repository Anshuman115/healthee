/// Legacy's ten hues, both themes — resolved, transcribed and measured.
///
/// This file replaces `metric_hues_test.dart`, which proved the five identity
/// tags could never be confused with a verdict. That property is gone **on
/// purpose**: legacy's `cHrv` and `cReady` ARE its green, and its `cHeart` IS its
/// "degrading" colour. So what is asserted now is the port itself —
///
///   * every hue **resolves** in both themes, from a real assembled `ThemeData`;
///   * every value is legacy's, restated independently from
///     `healthee-legacy/app/lib/ui/theme.dart`;
///   * the collisions legacy makes are **asserted rather than avoided**, so a
///     future "fix" that separates them fails here and has to be argued;
///   * every hue clears the large-text contrast floor on both surfaces, in both
///     themes — because these hues carry 27 px figures on a module.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/metric_hue.dart';
import 'package:healthee/core/theme/tokens.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Every hue by name, so a failure says which one.
Map<String, Color> _named(InstrumentHues hues) => <String, Color>{
  'cSleep': hues.sleep,
  'cHeart': hues.heart,
  'cHrv': hues.hrv,
  'cSteps': hues.steps,
  'cCal': hues.calories,
  'cResp': hues.respiratory,
  'cSpo2': hues.spo2,
  'cStress': hues.stress,
  'cReady': hues.readiness,
  'cRem': hues.rem,
};

void main() {
  const light = InstrumentHues.light();
  const dark = InstrumentHues.dark();

  group('the hue set is legacy’s HColors, transcribed', () {
    test('light — all ten, verbatim', () {
      expect(light.sleep, const Color(0xFF5B5483));
      expect(light.heart, const Color(0xFFBF472E));
      expect(light.hrv, const Color(0xFF1F6F54));
      expect(light.steps, const Color(0xFFB27F2C));
      expect(light.calories, const Color(0xFFCE6131));
      expect(light.respiratory, const Color(0xFF3C7A84));
      expect(light.spo2, const Color(0xFF587A97));
      expect(light.stress, const Color(0xFFA55F6D));
      expect(light.readiness, const Color(0xFF1F6F54));
      expect(light.rem, const Color(0xFF8A7FB8));
    });

    test('dark — all ten, verbatim', () {
      expect(dark.sleep, const Color(0xFF968EC9));
      expect(dark.heart, const Color(0xFFE07A5F));
      expect(dark.hrv, const Color(0xFF4BBF93));
      expect(dark.steps, const Color(0xFFD9A84E));
      expect(dark.calories, const Color(0xFFE8835A));
      expect(dark.respiratory, const Color(0xFF5FA9B4));
      expect(dark.spo2, const Color(0xFF7DA3C4));
      expect(dark.stress, const Color(0xFFC98A96));
      expect(dark.readiness, const Color(0xFF4BBF93));
      expect(dark.rem, const Color(0xFFB3A9E0));
    });

    test('EVERY HUE RESOLVES FROM AN ASSEMBLED THEME, in both themes', () {
      // The failure this catches: an extension registered in one theme and not
      // the other renders one mode in colours nobody chose, and `context.hues`
      // throws in the other. Both themes are asked, from the real ThemeData.
      for (final (name, theme, expected) in <(String, ThemeData, InstrumentHues)>[
        ('light', AppTheme.light, light),
        ('dark', AppTheme.dark, dark),
      ]) {
        final resolved = theme.extension<InstrumentHues>();
        expect(resolved, isNotNull, reason: '$name theme carries no hue set');
        expect(resolved, expected, reason: name);
        expect(_named(resolved!).length, 10, reason: '$name: ten hues, not nine');
      }
    });

    test('every hue is opaque — a hue is a colour, never a wash', () {
      for (final (name, hues) in <(String, InstrumentHues)>[
        ('light', light),
        ('dark', dark),
      ]) {
        for (final entry in _named(hues).entries) {
          expect(entry.value.a, 1.0, reason: '$name ${entry.key}');
        }
      }
    });

    test('the two themes are authored apart, hue by hue', () {
      // Every one of the ten differs between the themes in legacy. If a value
      // were copied across, this is where it shows.
      final lightNames = _named(light);
      final darkNames = _named(dark);
      for (final key in lightNames.keys) {
        expect(
          lightNames[key],
          isNot(darkNames[key]),
          reason: '$key is the same value in both themes',
        );
      }
    });
  });

  group('THE COLLISIONS LEGACY MAKES ON PURPOSE', () {
    test('cHrv and cReady ARE the green accent, and the fav verdict', () {
      // insights_screen.dart:171 — `improving ? c.green : c.cHeart`.
      // A future reader who separates these is undoing the owner's decision,
      // not fixing a defect. palette.dart carries the argument.
      const colors = HealtheeColors.light();
      const darkColors = HealtheeColors.dark();
      expect(light.hrv, colors.accent);
      expect(light.readiness, colors.accent);
      expect(light.hrv, colors.fav);
      expect(dark.hrv, darkColors.accent);
      expect(dark.readiness, darkColors.accent);
      expect(dark.hrv, darkColors.fav);
    });

    test('cHeart IS the alert colour — legacy has no separate red', () {
      expect(light.heart, const HealtheeColors.light().alert);
      expect(dark.heart, const HealtheeColors.dark().alert);
    });

    test('cRem is defined and drawn by nothing — legacy draws REM in cSleep', () {
      // Ported because the set is ported whole. Asserting it is distinct keeps
      // a later "it is unused, delete it" honest about what would be lost.
      expect(light.rem, isNot(light.sleep));
      expect(const InstrumentHues.light().sleepStage('rem'), light.sleep);
    });
  });

  group('contrast — these hues carry 27 px figures', () {
    // The floor is WCAG's **3:1 large-text** threshold, not 4.5:1, and the
    // reason is measured rather than chosen: legacy's `cSteps` on this theme's
    // page reaches 3.21:1 and cannot reach 4.5 without changing legacy's value.
    // 27 px at weight 600 is large text by WCAG's own definition (>= 18.66 px
    // bold), which is the size `HModuleValue` draws at.
    const floor = 3.0;

    test('every hue clears the large-text floor on both surfaces', () {
      for (final (name, hues, colors) in <(String, InstrumentHues, HealtheeColors)>[
        ('light', light, const HealtheeColors.light()),
        ('dark', dark, const HealtheeColors.dark()),
      ]) {
        for (final entry in _named(hues).entries) {
          expect(
            _contrast(entry.value, colors.surface),
            greaterThanOrEqualTo(floor),
            reason: '$name ${entry.key} on a card',
          );
          expect(
            _contrast(entry.value, colors.bg),
            greaterThanOrEqualTo(floor),
            reason: '$name ${entry.key} on the page',
          );
        }
      }
    });

    test('THE WORST CASE IS PINNED, so a hue cannot quietly get worse', () {
      // cSteps on the light page. If this number moves, a legacy value moved.
      expect(
        _contrast(light.steps, const HealtheeColors.light().bg),
        closeTo(3.21, 0.01),
      );
    });

    test('NO HUE CLEARS 4.5:1 EVERYWHERE — this is a known limit, not a target', () {
      // Stated as a test so nobody "raises the floor" in the other file and
      // believes the palette passes it. It does not, and legacy's values are
      // what ship.
      expect(
        _contrast(light.steps, const HealtheeColors.light().surface),
        lessThan(4.5),
      );
    });
  });

  group('the metric table is a transcription of legacy’s call sites', () {
    test('the six Today grid metrics wear the hues legacy gives them', () {
      // today_screen.dart:174 · 181 · 187 · 193 · 199 · 209.
      expect(hueFor(light, 'sleep_duration'), light.sleep);
      expect(hueFor(light, 'rhr_daily'), light.heart);
      expect(hueFor(light, 'hrv'), light.hrv);
      expect(hueFor(light, 'steps_total'), light.steps);
      expect(hueFor(light, 'active_calories'), light.calories);
      expect(hueFor(light, 'respiratory_rate'), light.respiratory);
    });

    test('legacy’s two odd ones are ported as legacy has them', () {
      // Stress wears cCal, not cStress (today_screen.dart:272), and skin
      // temperature is what actually wears cStress (sleep_screen.dart:352).
      // Both look like mistakes and both are legacy's.
      expect(hueFor(light, 'stress'), light.calories);
      expect(hueFor(light, 'skin_temp_c'), light.stress);
    });

    test('an unlisted metric gets legacy’s own fallback, the green', () {
      // today_screen.dart:905 — `_ => c.green`.
      expect(hueFor(light, 'a_metric_nobody_listed'), light.hrv);
      expect(hueFor(dark, 'a_metric_nobody_listed'), dark.hrv);
    });

    test('THE SAME ID ALWAYS ANSWERS THE SAME HUE', () {
      for (final metric in const <String>[
        'sleep_duration', 'rhr_daily', 'hrv', 'steps_total',
        'active_calories', 'respiratory_rate', 'stress', 'vo2max_estimate',
      ]) {
        expect(hueFor(light, metric), hueFor(light, metric), reason: metric);
      }
    });

    test('the server id and the strap id for one metric agree', () {
      expect(hueFor(light, 'rhr_daily'), hueFor(light, 'resting_hr'));
      expect(hueFor(light, 'steps_total'), hueFor(light, 'steps'));
      expect(hueFor(light, 'spo2_overnight'), hueFor(light, 'spo2'));
    });
  });
}
