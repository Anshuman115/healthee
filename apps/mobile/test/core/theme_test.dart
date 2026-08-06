/// The token set, locked: the **scaffolding** to the approved design, the
/// **accent and verdicts** to `healthee-legacy/app/lib/ui/theme.dart`.
///
/// These tokens are transcriptions, and transcription is exactly the kind of work
/// that goes subtly wrong — a transposed digit, an alpha read off the wrong row —
/// which `flutter analyze` cannot see. So both source tables are restated here,
/// independently, and compared.
///
/// ## Two assertions changed on 2026-08-05 and the changes are the point
///
///   * **"the accent is a PAIR"** — it still is for the four per-theme roles, and
///     `unf` is a single legacy literal used in BOTH themes because legacy wrote
///     one. Asserting theme-variance on it would fail the port for being
///     faithful, so the test asserts the sameness.
///   * **`onAccent` is per-theme again, and the AA assertion is back.** It was
///     pinned here as a known failure at **2.14:1** on the dark green — under AA
///     and under the 3:1 large-text floor. Pinning a legibility defect keeps it
///     from drifting; it does not make the word on the button readable. The
///     accent hue is untouched (still legacy's `#4BBF93`) and only the ink on it
///     moved, to the dark page colour that was already in the palette.
///
/// The floor is asserted as a FLOOR, not pinned to a measurement: a pin fails
/// when contrast **improves**, which is the one direction nobody needs stopping.
/// What the exact-value pin was really protecting is that the tokens are what the
/// tables above say, and the token assertions do that directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const light = HealtheeColors.light();
  const dark = HealtheeColors.dark();

  group('light tokens match the brief verbatim', () {
    test('neutrals', () {
      expect(light.bg, const Color(0xFFF4F4F6));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.surface2, const Color(0xFFFAFAFB));
      expect(light.chrome, const Color(0xFFFFFFFF));
      expect(light.ink, const Color(0xFF121217));
      expect(light.ink2, const Color(0xFF56565F));
      expect(light.ink3, const Color(0xFF6D6D7C));
      expect(light.line, const Color.fromRGBO(18, 18, 23, 0.10));
      expect(light.line2, const Color.fromRGBO(18, 18, 23, 0.06));
    });

    test('accent and semantics are LEGACY’s HColors.light', () {
      expect(light.accent, const Color(0xFF1F6F54), reason: 'legacy green');
      expect(light.accent2, const Color(0xFF154D3A), reason: 'legacy greenDeep');
      expect(light.accentSoft, const Color(0xFFE2EBE3), reason: 'legacy greenSoft');
      expect(light.onAccent, const Color(0xFFFBF7EF), reason: 'legacy onGreen');
      // fav IS the accent, and cHrv, and cReady. Legacy shares them on purpose.
      expect(light.fav, light.accent);
      expect(light.favSoft, light.accentSoft);
      // Legacy's inline warn amber (today_screen.dart:19).
      expect(light.unf, const Color(0xFFE0A33E));
      expect(light.unfSoft, const Color.fromRGBO(224, 163, 62, 0.16));
      // alert IS cHeart. Legacy has no separate red.
      expect(light.alert, const Color(0xFFBF472E));
      expect(light.alertSoft, const Color.fromRGBO(191, 71, 46, 0.16));
      expect(light.hole, const Color.fromRGBO(18, 18, 23, 0.045));
    });
  });

  group('dark tokens match the brief verbatim', () {
    test('neutrals', () {
      expect(dark.bg, const Color(0xFF0A0A0E));
      expect(dark.surface, const Color(0xFF141419));
      expect(dark.surface2, const Color(0xFF1A1A21));
      expect(dark.chrome, const Color(0xFF141419));
      expect(dark.ink, const Color(0xFFF3F3F6));
      expect(dark.ink2, const Color(0xFFA2A2B0));
      expect(dark.ink3, const Color(0xFF8D8D99));
      expect(dark.line, const Color.fromRGBO(255, 255, 255, 0.10));
      expect(dark.line2, const Color.fromRGBO(255, 255, 255, 0.055));
    });

    test('accent and semantics are LEGACY’s HColors.dark', () {
      expect(dark.accent, const Color(0xFF4BBF93), reason: 'legacy green');
      expect(dark.accent2, const Color(0xFF2F8F6C), reason: 'legacy greenDeep');
      expect(dark.accentSoft, const Color(0xFF1E3329), reason: 'legacy greenSoft');
      // NOT legacy's onGreen — the one departure. See palette.dart: it is the
      // dark page colour, so no new hex entered the palette.
      expect(dark.onAccent, dark.bg, reason: 'the dark page colour, on the green');
      expect(dark.onAccent, isNot(const Color(0xFFFBF7EF)), reason: 'legacy onGreen fails AA here');
      expect(dark.fav, dark.accent);
      expect(dark.favSoft, dark.accentSoft);
      expect(dark.unf, const Color(0xFFE0A33E));
      expect(dark.unfSoft, const Color.fromRGBO(224, 163, 62, 0.16));
      expect(dark.alert, const Color(0xFFE07A5F));
      expect(dark.alertSoft, const Color.fromRGBO(224, 122, 95, 0.16));
      expect(dark.hole, const Color.fromRGBO(255, 255, 255, 0.05));
    });
  });

  group('the sleep-stage ramp, transcribed', () {
    // These eight are DERIVED rather than transcribed from legacy — the
    // accessibility repair in `lib/core/theme/sleep_stage_palette.dart` — but
    // they are pinned here for the same reason every other token is: a
    // transposed digit is invisible to the analyzer.
    //
    // The pin also closes the one hole the property tests cannot. Restoring
    // legacy's light-theme `deep` (`#B27F2C`) changes luminance by 0.005 and so
    // breaks neither the pair floor nor the depth ordering — legacy's light gold
    // was already on its rung. `test/theme/stage_contrast_test.dart` measures
    // that and names it; this is what fails when it comes back.
    const lightHues = InstrumentHues.light();
    const darkHues = InstrumentHues.dark();

    test('light — the four rungs and the grey', () {
      expect(lightHues.stageDeep, const Color(0xFFB4802E));
      expect(lightHues.stageLight, const Color(0xFF4C6E8B));
      expect(lightHues.stageRem, const Color(0xFF4F4875));
      expect(lightHues.stageAwake, const Color(0xFF631000));
      expect(lightHues.unstaged, const Color(0xFF7A7A7A));
    });

    test('dark — the four rungs and the grey', () {
      expect(darkHues.stageDeep, const Color(0xFFFFCC73));
      expect(darkHues.stageLight, const Color(0xFF87AECF));
      expect(darkHues.stageRem, const Color(0xFF867EB8));
      expect(darkHues.stageAwake, const Color(0xFFA8472E));
      expect(darkHues.unstaged, const Color(0xFF757575));
    });

    test('NO STAGE IS A METRIC HUE — the split, asserted from the token side', () {
      // The four metric hues legacy borrowed are unchanged and still in use, so
      // "the stage moved" and "the metric moved" are both possible edits and
      // only one of them is the repair. This says which.
      for (final (name, hues) in <(String, InstrumentHues)>[
        ('light', lightHues),
        ('dark', darkHues),
      ]) {
        final metrics = <Color>[hues.steps, hues.spo2, hues.sleep, hues.heart];
        for (final stage in <Color>[
          hues.stageDeep, hues.stageLight, hues.stageRem, hues.stageAwake,
        ]) {
          expect(metrics, isNot(contains(stage)), reason: name);
        }
      }
    });

    test('the awake stage is NOT the alert colour — the split that mattered', () {
      // `cHeart` is the illness flag. Moving it to fix a chart would have
      // repainted a verdict.
      expect(lightHues.stageAwake, isNot(light.alert));
      expect(darkHues.stageAwake, isNot(dark.alert));
      expect(lightHues.heart, light.alert, reason: 'and alert itself did not move');
      expect(darkHues.heart, dark.alert);
    });
  });

  group('the structural decisions, pinned', () {
    test('the accent is a PAIR, and legacy’s two single-value tokens are named', () {
      // Legacy authors green and cHeart per theme, so these must differ.
      expect(light.accent, isNot(dark.accent));
      expect(light.accent2, isNot(dark.accent2));
      expect(light.fav, isNot(dark.fav));
      expect(light.alert, isNot(dark.alert));
      // Legacy wrote TWO colours as one value for both themes. The warn amber is
      // ported that way — this asserts the port, not the design: if it gained a
      // per-theme partner, that would be a change the owner did not ask for, and
      // this test is where it surfaces.
      expect(light.unf, dark.unf, reason: 'legacy’s inline warn amber');
      // `onGreen` is the other one, and it is deliberately NOT ported that way,
      // because legacy's two greens need different ink. The asymmetry is the fix.
      expect(light.onAccent, isNot(dark.onAccent), reason: 'legibility, not design');
    });

    test('fav and unf are distinct in both themes — the ladder needs the pair', () {
      // Brief §5.1's recovery signal ladder has a favourable and an unfavourable
      // side. Collapsing them (or mapping `unf` onto something else) makes the
      // app's signature chart undrawable.
      expect(light.fav, isNot(light.unf));
      expect(dark.fav, isNot(dark.unf));
    });

    test('alert is not the accent, but it IS legacy’s heart hue', () {
      expect(light.alert, isNot(light.accent));
      expect(dark.alert, isNot(dark.accent));
      // The collision the port makes deliberately. See palette.dart: legacy's
      // `improving ? c.green : c.cHeart` puts a metric hue on both sides of a
      // verdict, so alert == cHeart and fav == cHrv == cReady == the accent.
      expect(light.alert, const InstrumentHues.light().heart);
      expect(dark.alert, const InstrumentHues.dark().heart);
      expect(light.fav, const InstrumentHues.light().hrv);
      expect(light.fav, const InstrumentHues.light().readiness);
    });

    test('hole is a near-invisible FILL, not a hue', () {
      // It is a shape, not a colour. If someone "fixes" it to something visible,
      // the withheld card starts reading as a warning.
      expect(light.hole.a, lessThan(0.10));
      expect(dark.hole.a, lessThan(0.10));
    });

    test('text on the accent clears WCAG AA in BOTH themes', () {
      // This was pinned at `closeTo(2.14)` for the dark theme — a measured
      // failure, recorded so it could not drift. It has been fixed instead.
      // Light keeps legacy's off-white at 5.68:1; dark takes the page colour at
      // 8.63:1.
      for (final (name, colors) in [('light', light), ('dark', dark)]) {
        expect(
          _contrast(colors.accent, colors.onAccent),
          greaterThanOrEqualTo(4.5),
          reason: '$name: the label inside a filled accent button',
        );
      }
    });

    test('MUTATION — reinstating legacy’s onGreen on the dark green fails', () {
      // The assertion above passes for any sufficiently dark ink, including one
      // chosen by accident. This one names the exact value that was wrong and
      // proves the gate would catch it coming back — a regression here is a
      // one-character edit in palette.dart.
      const legacyOnGreen = Color(0xFFFBF7EF);
      expect(_contrast(dark.accent, legacyOnGreen), lessThan(3));
      expect(_contrast(light.accent, legacyOnGreen), greaterThanOrEqualTo(4.5));
    });

    test('onAccent is Material’s onError too, and clears AA there as well', () {
      // app_theme.dart wires `onError: colors.onAccent`. The off-white measured
      // 2.76:1 on the dark alert — the same failure one token over, and it went
      // unnoticed because nothing asserted it.
      for (final (name, colors) in [('light', light), ('dark', dark)]) {
        expect(
          _contrast(colors.alert, colors.onAccent),
          greaterThanOrEqualTo(4.5),
          reason: '$name: text on an error surface',
        );
      }
    });

    test('body and label ink clear AA against their own surface', () {
      for (final (name, colors) in [('light', light), ('dark', dark)]) {
        expect(
          _contrast(colors.ink, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name: primary ink on a card',
        );
        expect(
          _contrast(colors.ink2, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name: secondary ink carries the withheld remedy',
        );
      }
    });
  });

  group('the assembled themes', () {
    test('carry the extension, so context.colors never throws', () {
      expect(AppTheme.light.extension<HealtheeColors>(), light);
      expect(AppTheme.dark.extension<HealtheeColors>(), dark);
    });

    test('wire ColorScheme.error to alert rather than inventing a second red', () {
      // Reserving alert for the illness flag is a rule about OUR cards. Material
      // still needs an error colour, and leaving it at the M3 default would put
      // a red nobody chose into form validation.
      expect(AppTheme.light.colorScheme.error, light.alert);
      expect(AppTheme.dark.colorScheme.error, dark.alert);
    });

    test('use chrome for the app bar, not the page background', () {
      // In light mode the frame is white against a grey page; collapsing them
      // loses the design's separation between frame and canvas.
      expect(AppTheme.light.appBarTheme.backgroundColor, light.chrome);
      expect(AppTheme.light.scaffoldBackgroundColor, light.bg);
      expect(AppTheme.dark.appBarTheme.backgroundColor, dark.chrome);
    });

    test('set Manrope with tabular figures on every text style', () {
      final text = AppTheme.light.textTheme;
      for (final style in [
        text.displayLarge,
        text.headlineMedium,
        text.titleMedium,
        text.bodyMedium,
        text.labelSmall,
      ]) {
        expect(style!.fontFamily, 'Manrope');
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: 'brief §7: non-tabular numerals in a metric column is a defect',
        );
      }
    });
  });

  test('HealtheeColors.lerp moves every role, so a theme swap cannot half-animate', () {
    // At t=1 every role must have arrived at the other theme's value. A role
    // missing from `lerp` would keep its old colour here and stand out.
    expect(light.lerp(dark, 1), dark);
  });
}
