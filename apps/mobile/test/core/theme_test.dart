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
///   * **"the accent is a PAIR"** — it still is for the four per-theme roles, but
///     `unf` and `onAccent` are now single legacy literals used in BOTH themes,
///     because legacy wrote one of each. Asserting theme-variance on them would
///     fail the port for being faithful, so the test now asserts the sameness.
///   * **"text on the accent clears WCAG AA in BOTH themes"** — legacy's `onGreen`
///     measures **2.14:1** on the dark green. The previous palette fixed this by
///     making `onAccent` per-theme; the owner's instruction is that legacy's
///     values ship unchanged and an imperfection is reported rather than
///     repaired. The measurement is therefore **pinned as a known failure**, so
///     it cannot drift further and cannot be forgotten.
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
      expect(dark.onAccent, const Color(0xFFFBF7EF), reason: 'legacy onGreen');
      expect(dark.fav, dark.accent);
      expect(dark.favSoft, dark.accentSoft);
      expect(dark.unf, const Color(0xFFE0A33E));
      expect(dark.unfSoft, const Color.fromRGBO(224, 163, 62, 0.16));
      expect(dark.alert, const Color(0xFFE07A5F));
      expect(dark.alertSoft, const Color.fromRGBO(224, 122, 95, 0.16));
      expect(dark.hole, const Color.fromRGBO(255, 255, 255, 0.05));
    });
  });

  group('the structural decisions, pinned', () {
    test('the accent is a PAIR, and legacy’s two single-value tokens are named', () {
      // Legacy authors green and cHeart per theme, so these must differ.
      expect(light.accent, isNot(dark.accent));
      expect(light.accent2, isNot(dark.accent2));
      expect(light.fav, isNot(dark.fav));
      expect(light.alert, isNot(dark.alert));
      // Legacy wrote exactly TWO colours as one value for both themes, and both
      // are ported that way. This asserts the port, not the design: if either
      // gained a per-theme partner, that would be a change the owner did not ask
      // for, and this test is where it surfaces.
      expect(light.unf, dark.unf, reason: 'legacy’s inline warn amber');
      expect(light.onAccent, dark.onAccent, reason: 'legacy’s onGreen');
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

    test('LEGACY’S onGreen FAILS AA ON THE DARK ACCENT — pinned, not fixed', () {
      // Light is fine at 5.68:1. Dark is 2.14:1 — below WCAG AA (4.5:1) and
      // below the 3:1 large-text floor, because legacy puts ONE off-white on two
      // different greens.
      //
      // The previous palette solved this by making `onAccent` per-theme. The
      // owner's instruction for this port is that legacy's values ship and an
      // imperfection is REPORTED, not repaired. So the number is pinned here
      // instead: this fails the day the value drifts in either direction, and a
      // reviewer reading it sees the debt rather than inheriting it.
      expect(_contrast(light.accent, light.onAccent), greaterThanOrEqualTo(4.5));
      expect(_contrast(dark.accent, dark.onAccent), closeTo(2.14, 0.01));
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
