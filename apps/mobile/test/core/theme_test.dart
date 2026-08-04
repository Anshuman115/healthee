/// The token set, locked to `docs/APP_DESIGN_BRIEF.md` §2.
///
/// These tokens were transcribed from an approved design. Transcription is
/// exactly the kind of work that goes subtly wrong — a transposed digit, an alpha
/// read off the wrong row — and `flutter analyze` cannot see a wrong-but-valid
/// colour. So the brief's table is restated here, independently, and compared.
///
/// It also pins the three judgement calls that are NOT pure transcription, each
/// of which has a paragraph of reasoning in the source and would otherwise be one
/// careless edit from being undone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
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

    test('accent and semantics', () {
      expect(light.accent, const Color(0xFF5145E5));
      expect(light.accent2, const Color(0xFF3F34C9));
      expect(light.accentSoft, const Color.fromRGBO(81, 69, 229, 0.09));
      expect(light.fav, const Color(0xFF1A7F57));
      expect(light.favSoft, const Color.fromRGBO(26, 127, 87, 0.10));
      expect(light.unf, const Color(0xFFA4680B));
      expect(light.unfSoft, const Color.fromRGBO(164, 104, 11, 0.10));
      expect(light.alert, const Color(0xFFB8352A));
      expect(light.alertSoft, const Color.fromRGBO(184, 53, 42, 0.08));
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

    test('accent and semantics', () {
      expect(dark.accent, const Color(0xFF8F87FF));
      expect(dark.accent2, const Color(0xFFA9A2FF));
      expect(dark.accentSoft, const Color.fromRGBO(143, 135, 255, 0.14));
      expect(dark.fav, const Color(0xFF4FC691));
      expect(dark.favSoft, const Color.fromRGBO(79, 198, 145, 0.14));
      expect(dark.unf, const Color(0xFFDFA550));
      expect(dark.unfSoft, const Color.fromRGBO(223, 165, 80, 0.14));
      expect(dark.alert, const Color(0xFFFF7466));
      expect(dark.alertSoft, const Color.fromRGBO(255, 116, 102, 0.12));
      expect(dark.hole, const Color.fromRGBO(255, 255, 255, 0.05));
    });
  });

  group('the structural decisions, pinned', () {
    test('the accent is a PAIR — no theme-invariant brand colour', () {
      // The previous palette (landing v5) held brand colour constant across
      // themes. This design does not, and a `BrandPalette` reappearing would
      // quietly force one theme to wear the other's accent.
      expect(light.accent, isNot(dark.accent));
      expect(light.accent2, isNot(dark.accent2));
      expect(light.fav, isNot(dark.fav));
      expect(light.unf, isNot(dark.unf));
      expect(light.alert, isNot(dark.alert));
    });

    test('fav and unf are distinct in both themes — the ladder needs the pair', () {
      // Brief §5.1's recovery signal ladder has a favourable and an unfavourable
      // side. Collapsing them (or mapping `unf` onto something else) makes the
      // app's signature chart undrawable.
      expect(light.fav, isNot(light.unf));
      expect(dark.fav, isNot(dark.unf));
    });

    test('alert is the only red, and is not reused as the accent', () {
      expect(light.alert, isNot(light.accent));
      expect(dark.alert, isNot(dark.accent));
    });

    test('hole is a near-invisible FILL, not a hue', () {
      // It is a shape, not a colour. If someone "fixes" it to something visible,
      // the withheld card starts reading as a warning.
      expect(light.hole.a, lessThan(0.10));
      expect(dark.hole.a, lessThan(0.10));
    });

    test('text on the accent clears WCAG AA in BOTH themes', () {
      // The one place this implementation departs from `Healthee.html`, which
      // hardcodes #fff on the accent. Against the dark accent that measures
      // 2.97:1 — below even the 3:1 large-text floor. This test is the reason
      // the departure exists, so it must fail if onAccent is reverted to white.
      expect(_contrast(light.accent, light.onAccent), greaterThanOrEqualTo(4.5));
      expect(_contrast(dark.accent, dark.onAccent), greaterThanOrEqualTo(4.5));
      expect(_contrast(dark.accent, const Color(0xFFFFFFFF)), lessThan(3.0));
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

    test('set Instrument Sans with tabular figures on every text style', () {
      final text = AppTheme.light.textTheme;
      for (final style in [
        text.displayLarge,
        text.headlineMedium,
        text.titleMedium,
        text.bodyMedium,
        text.labelSmall,
      ]) {
        expect(style!.fontFamily, 'Instrument Sans');
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
