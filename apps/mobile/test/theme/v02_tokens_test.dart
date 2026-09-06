/// **Every v02 token, transcribed independently and compared.** Replaces
/// `legacy_hues_test.dart`, which locked legacy's ten per-metric hues.
///
/// The values below were read from `design/mobile-preview/tokens.css` and
/// `richer.css` a second time, by hand, and written out here. That is the whole
/// method: a transcription checked against a transcription. `flutter analyze`
/// cannot see a transposed digit, and a palette that is merely *self-consistent*
/// is a palette that can be wrong everywhere at once.
///
/// **`richer.css` wins where both files define a name** — it is the last
/// stylesheet `index.html` links — so the canvas, background, ink, line, rule and
/// accent below are richer's, and the surface, on-accent, verdicts, overlay and
/// shadow are tokens.css's, which richer never overrides.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/appearance_variant.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/palette.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';

void main() {
  const light = HealtheeColors.light();
  const dark = HealtheeColors.dark();
  const lightHues = InstrumentHues.light();
  const darkHues = InstrumentHues.dark();

  group('scaffolding — light', () {
    test('the neutrals are richer.css’s, and surface is tokens.css’s', () {
      expect(light.canvas, const Color(0xFFE7EDE9), reason: '--canvas');
      expect(light.bg, const Color(0xFFF3F6F4), reason: '--background');
      expect(light.surface, const Color(0xFFFFFFFF), reason: '--surface');
      expect(light.surface2, const Color(0xFFF0F1F7), reason: '--surface-soft');
      expect(light.ink, const Color(0xFF171C19), reason: '--ink');
      expect(light.ink2, const Color(0xFF4C554F), reason: '--muted');
      expect(light.ink3, const Color(0xFF5E6560), reason: '--subtle');
      expect(light.line, const Color(0xFFD6DDD8), reason: '--line');
      expect(light.rule, const Color(0xFFB0BAB3), reason: '--rule');
    });

    test('accent and verdicts', () {
      expect(light.accent, const Color(0xFF00612F), reason: '--fitness');
      expect(light.accent2, const Color(0xFF004F23), reason: '--accent-hover');
      expect(light.accentSoft, const Color(0xFFD9F3DF));
      expect(light.onAccent, const Color(0xFFFBFBFE), reason: '--on-accent');
      expect(light.fav, const Color(0xFF065F3D), reason: '--positive');
      expect(light.favSoft, const Color(0xFFDDF1E5));
      expect(light.unf, const Color(0xFF6F4A12), reason: '--caution');
      expect(light.unfSoft, const Color(0xFFFFF0D8));
      expect(light.alert, const Color(0xFFA52A24), reason: '--danger');
      expect(light.alertSoft, const Color(0xFFFEE9E6));
    });

    test('the bio hero’s own surface', () {
      expect(light.bioBackground, const Color(0xFFD5ECD9));
      expect(light.bioInk, const Color(0xFF0E2516));
      expect(light.bioGlow, const Color(0xFF5AC480));
      expect(light.bioLine, const Color(0xFF328B54));
    });
  });

  group('scaffolding — dark, the default appearance for this direction', () {
    test('the neutrals', () {
      expect(dark.canvas, const Color(0xFF050806));
      expect(dark.bg, const Color(0xFF0D100E));
      expect(dark.surface, const Color(0xFF181C19));
      expect(dark.surface2, const Color(0xFF212522));
      expect(dark.ink, const Color(0xFFF0F3F0));
      expect(dark.ink2, const Color(0xFFB2BAB4));
      expect(dark.ink3, const Color(0xFF98A19B));
      expect(dark.line, const Color(0xFF2C322E));
      expect(dark.rule, const Color(0xFF505752));
    });

    test('accent and verdicts', () {
      expect(dark.accent, const Color(0xFF6ADD92));
      expect(dark.accent2, const Color(0xFF9AEAB2));
      expect(dark.accentSoft, const Color(0xFF172F1F));
      expect(dark.onAccent, const Color(0xFF08120C));
      expect(dark.fav, const Color(0xFF78C89E));
      expect(dark.favSoft, const Color(0xFF13271C));
      expect(dark.unf, const Color(0xFFE8BC78));
      expect(dark.unfSoft, const Color(0xFF2D220F));
      expect(dark.alert, const Color(0xFFF69C90));
      expect(dark.alertSoft, const Color(0xFF351C19));
    });

    test('the bio hero’s own surface', () {
      expect(dark.bioBackground, const Color(0xFF132419));
      expect(dark.bioInk, const Color(0xFFEEF8F0));
      expect(dark.bioGlow, const Color(0xFF2D8C53));
      expect(dark.bioLine, const Color(0xFF57AE74));
    });
  });

  group('the six families', () {
    test('light', () {
      expect(lightHues.fitness, const Color(0xFF00612F));
      expect(lightHues.fitnessSoft, const Color(0xFFD9F3DF));
      expect(lightHues.sleep, const Color(0xFF6B35B5));
      expect(lightHues.sleepSoft, const Color(0xFFF0EBFE));
      expect(lightHues.heart, const Color(0xFFA51D2B));
      expect(lightHues.heartSoft, const Color(0xFFFFE7E5));
      expect(lightHues.movement, const Color(0xFF774000));
      expect(lightHues.movementSoft, const Color(0xFFFFEAD3));
      expect(lightHues.oxygen, const Color(0xFF005A8D));
      expect(lightHues.oxygenSoft, const Color(0xFFDFF2FD));
      expect(lightHues.stress, const Color(0xFF874400));
      expect(lightHues.stressSoft, const Color(0xFFFFE9D6));
    });

    test('dark', () {
      expect(darkHues.fitness, const Color(0xFF6ADD92));
      expect(darkHues.fitnessSoft, const Color(0xFF172F1F));
      expect(darkHues.sleep, const Color(0xFFC5A8FF));
      expect(darkHues.sleepSoft, const Color(0xFF2B2539));
      expect(darkHues.heart, const Color(0xFFFF9390));
      expect(darkHues.heartSoft, const Color(0xFF3A2120));
      expect(darkHues.movement, const Color(0xFFFABA59));
      expect(darkHues.movementSoft, const Color(0xFF372813));
      expect(darkHues.oxygen, const Color(0xFF6EC6F7));
      expect(darkHues.oxygenSoft, const Color(0xFF172C38));
      expect(darkHues.stress, const Color(0xFFFCAD6A));
      expect(darkHues.stressSoft, const Color(0xFF362416));
    });

    test('SIX DISTINCT HUES, and six distinct fills, in both themes', () {
      for (final (name, hues) in [('light', lightHues), ('dark', darkHues)]) {
        final families = <Color>{
          for (final tone in kToneFamilies) tone.family(hues),
        };
        final softs = <Color>{
          for (final tone in kToneFamilies) tone.familySoft(hues),
        };
        expect(families.length, kToneFamilies.length, reason: name);
        expect(softs.length, kToneFamilies.length, reason: name);
      }
    });
  });

  group('the collisions legacy made on purpose are GONE', () {
    // Legacy's `improving ? c.green : c.cHeart` put a metric hue on both sides
    // of a verdict: green was HRV *and* "improving", red-orange was heart *and*
    // "degrading". v02 gives judgement its own three pairs, so identity and
    // judgement can no longer be confused — and a reader who "restores" the
    // sharing would be undoing a decision rather than fixing a duplication.
    test('fav is --positive, not the fitness family', () {
      expect(light.fav, isNot(lightHues.fitness));
      expect(dark.fav, isNot(darkHues.fitness));
    });

    test('alert is --danger, not the heart family', () {
      expect(light.alert, isNot(lightHues.heart));
      expect(dark.alert, isNot(darkHues.heart));
    });

    test('the accent IS the fitness family — that one v02 keeps', () {
      // `richer.css`: `--accent: var(--fitness)`. Asserted so a future palette
      // edit that moves one and not the other is caught.
      expect(light.accent, lightHues.fitness);
      expect(light.accentSoft, lightHues.fitnessSoft);
      expect(dark.accent, darkHues.fitness);
      expect(dark.accentSoft, darkHues.fitnessSoft);
    });
  });

  group('the derived roles keep their relation to what they came from', () {
    test('v02 has ONE hairline, so line2 is line — by transcription', () {
      // Recorded rather than asserted-away: if a later design splits the pair
      // again this test is where the intent is written down.
      expect(light.line2, light.line);
      expect(dark.line2, dark.line);
    });

    test('grid is line, quieter; reference is ink3, quieter', () {
      for (final (name, colors) in [('light', light), ('dark', dark)]) {
        expect(colors.grid.r, closeTo(colors.line.r, 1 / 255), reason: name);
        expect(colors.grid.g, closeTo(colors.line.g, 1 / 255), reason: name);
        expect(colors.grid.b, closeTo(colors.line.b, 1 / 255), reason: name);
        expect(colors.grid.a, lessThan(colors.line.a), reason: name);
        expect(colors.reference.r, closeTo(colors.ink3.r, 1 / 255));
        expect(colors.reference.g, closeTo(colors.ink3.g, 1 / 255));
        expect(colors.reference.b, closeTo(colors.ink3.b, 1 / 255));
        expect(colors.reference.a, lessThan(1));
      }
    });

    test('hole is a near-invisible FILL, not a hue', () {
      expect(light.hole.a, lessThan(0.10));
      expect(dark.hole.a, lessThan(0.10));
    });

    test('overlay and shadow are translucent — they sit ON something', () {
      for (final colors in [light, dark]) {
        expect(colors.overlay.a, lessThan(1));
        expect(colors.shadow.a, lessThan(1));
      }
    });
  });

  group('EVERY role resolves, in both themes', () {
    test('lerp reaches every role, so none was forgotten in a constructor', () {
      // The catch-all. A role added to the class but omitted from `lerp` keeps
      // its starting value at t=1, so the two sides cannot compare equal — and
      // a role omitted from a named constructor would not compile.
      expect(light.lerp(dark, 1), dark);
      expect(light.lerp(dark, 0), light);
      expect(lightHues.lerp(darkHues, 1), darkHues);
      expect(darkHues.lerp(lightHues, 1), lightHues);
    });

    test('the assembled themes carry both extensions', () {
      expect(AppTheme.light.extension<HealtheeColors>(), light);
      expect(AppTheme.light.extension<InstrumentHues>(), lightHues);
      expect(AppTheme.dark.extension<HealtheeColors>(), dark);
      expect(AppTheme.dark.extension<InstrumentHues>(), darkHues);
    });
  });

  test('the owner’s first accent IS the theme accent, in both themes', () {
    // `appearanceColors` leaves the palette alone at index 0, so a first entry
    // disagreeing with the theme would render one green before the owner opened
    // the picker and another after. The other six are the owner's own.
    expect(AppearancePalette.accents.length, AppearanceVariant.accentNames.length);
    expect(AppearancePalette.accents.first.first, light.accent);
    expect(AppearancePalette.accents.first.last, dark.accent);
  });
}
