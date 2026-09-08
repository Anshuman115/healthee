/// **Contrast floors for every text pair the v02 palette makes, both themes.**
///
/// ## Floors, never pins
///
/// Every assertion is `greaterThanOrEqualTo`. A pin fails when contrast
/// *improves*, which is the one direction nobody needs stopping — and this
/// project has the receipt: `onAccent` was once pinned to an exact 2.14:1, so the
/// pin recorded a legibility defect and then objected to it being fixed.
///
/// ## Which floor, and why
///
/// **4.5:1** for anything with words in it — WCAG 2.1 SC 1.4.3, normal text. It
/// is applied to the label colours as well as the body ones, because this app's
/// labels *are* the reading: a unit under a number is not decoration.
///
/// **3:1** for a family drawn as a mark rather than as words — SC 1.4.11,
/// non-text contrast. A line, a dot, an icon tile's glyph.
///
/// The gridline is deliberately **excluded**. It is structure at the edge of
/// perception and is asserted in `chart_ink_test.dart` as *the quietest ink on
/// the chart*; holding it to a text floor would be asking the background to
/// compete with the data drawn on it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/palette.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// SC 1.4.3 — normal text.
const double kTextFloor = 4.5;

/// SC 1.4.11 — a graphical object.
const double kMarkFloor = 3.0;

void main() {
  const themes = <String, (HealtheeColors, InstrumentHues)>{
    'light': (HealtheeColors.light(), InstrumentHues.light()),
    'dark': (HealtheeColors.dark(), InstrumentHues.dark()),
  };

  for (final entry in themes.entries) {
    final name = entry.key;
    final (colors, hues) = entry.value;

    group('$name — the three inks', () {
      test('every ink clears AA on the card AND on the page', () {
        // Both grounds, because a card that moved onto the page (or a page
        // section that gained a surface) must not degrade silently.
        for (final (role, ink) in <(String, Color)>[
          ('ink', colors.ink),
          ('ink2', colors.ink2),
          ('ink3', colors.ink3),
        ]) {
          expect(
            contrast(ink, colors.surface),
            greaterThanOrEqualTo(kTextFloor),
            reason: '$name $role on a card',
          );
          expect(
            contrast(ink, colors.bg),
            greaterThanOrEqualTo(kTextFloor),
            reason: '$name $role on the page',
          );
          expect(
            contrast(ink, colors.surface2),
            greaterThanOrEqualTo(kTextFloor),
            reason: '$name $role on a recessed block',
          );
        }
      });
    });

    group('$name — judgement and the accent', () {
      test('text ON the accent, and on the error surface Material shares it', () {
        expect(
          contrast(colors.accent, colors.onAccent),
          greaterThanOrEqualTo(kTextFloor),
          reason: '$name: the label inside a filled accent button',
        );
        expect(
          contrast(colors.alert, colors.onAccent),
          greaterThanOrEqualTo(kTextFloor),
          reason: '$name: app_theme wires onError to onAccent',
        );
      });

      test('each verdict reads as words on its own soft fill', () {
        for (final (role, ink, fill) in <(String, Color, Color)>[
          ('fav', colors.fav, colors.favSoft),
          ('unf', colors.unf, colors.unfSoft),
          ('alert', colors.alert, colors.alertSoft),
          ('accent', colors.accent, colors.accentSoft),
        ]) {
          expect(
            contrast(ink, fill),
            greaterThanOrEqualTo(kTextFloor),
            reason: '$name: a $role chip',
          );
          expect(
            contrast(ink, colors.surface),
            greaterThanOrEqualTo(kTextFloor),
            reason: '$name: $role as a word on a card',
          );
        }
      });

      test('the three verdicts are distinguishable from each other', () {
        // Not a contrast floor — a distinctness one. `fav` and `unf` are the
        // two sides of the recovery ladder and collapsing them makes the app's
        // signature chart undrawable.
        expect(colors.fav, isNot(colors.unf));
        expect(colors.unf, isNot(colors.alert));
        expect(colors.fav, isNot(colors.alert));
      });
    });

    group('$name — the six families', () {
      test('a family is READABLE on its own soft ground', () {
        // The summary tile writes its label in `--family` on `--family-soft`,
        // so this pair carries words and takes the text floor.
        for (final tone in kToneFamilies) {
          expect(
            contrast(tone.family(hues), tone.familySoft(hues)),
            greaterThanOrEqualTo(kTextFloor),
            reason: '$name: a ${tone.name} tile’s label',
          );
        }
      });

      test('a family is VISIBLE as a mark on the card and on the page', () {
        for (final tone in kToneFamilies) {
          expect(
            contrast(tone.family(hues), colors.surface),
            greaterThanOrEqualTo(kMarkFloor),
            reason: '$name: a ${tone.name} line on a panel',
          );
          expect(
            contrast(tone.family(hues), colors.bg),
            greaterThanOrEqualTo(kMarkFloor),
            reason: '$name: a ${tone.name} line on the page',
          );
        }
      });
    });

    group('$name — the bio hero, which has its own surface', () {
      test('its ink clears AA on its own background, not the page’s', () {
        expect(
          contrast(colors.bioInk, colors.bioBackground),
          greaterThanOrEqualTo(kTextFloor),
          reason: '$name: the 88px figure and everything under it',
        );
      });

      test('the faded label at 80% still clears AA', () {
        // `.model-label { opacity: .8 }` — the quietest text in the card, and
        // the one that names the instrument, so it has to be readable.
        final faded = Color.alphaBlend(
          colors.bioInk.withValues(alpha: 0.8),
          colors.bioBackground,
        );
        expect(
          contrast(faded, colors.bioBackground),
          greaterThanOrEqualTo(kTextFloor),
          reason: '$name: which instrument produced the figure',
        );
      });
    });
  }

  group('MUTATION — the guard can see a failure', () {
    test('the ratio itself is right at both extremes', () {
      // A helper that always returned a large number would pass every test in
      // this file. These two are arithmetic, not design.
      expect(
        contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contrast(const Color(0xFF808080), const Color(0xFF808080)),
        closeTo(1, 0.001),
      );
    });

    test('using the light on-accent on the dark accent is caught', () {
      // The exact regression the palette carries a per-theme `onAccent` to
      // prevent: one value for both greens. On the dark green it is 1.66:1.
      expect(
        contrast(DarkPalette.accent, LightPalette.onAccent),
        lessThan(kMarkFloor),
      );
      expect(
        contrast(LightPalette.accent, LightPalette.onAccent),
        greaterThanOrEqualTo(kTextFloor),
      );
    });

    test('writing a family in its own soft fill is caught', () {
      // The mutation `color: familySoft` where the label should be `family` —
      // a one-word slip that renders an invisible label rather than a wrong one.
      for (final entry in themes.entries) {
        final (_, hues) = entry.value;
        for (final tone in kToneFamilies) {
          expect(
            contrast(tone.familySoft(hues), tone.familySoft(hues)),
            lessThan(kTextFloor),
            reason: '${entry.key} ${tone.name}',
          );
        }
      }
    });

    test('the ink floor would catch an ink drawn on the wrong ground', () {
      // Dark ink on the dark page is the classic theme-crossing bug. It must
      // fail the same floor the tests above apply.
      expect(contrast(LightPalette.ink, DarkPalette.bg), lessThan(kTextFloor));
      expect(contrast(DarkPalette.ink, LightPalette.bg), lessThan(kTextFloor));
    });
  });
}
