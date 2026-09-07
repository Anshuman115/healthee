/// The **assembled** themes, and the structural decisions the palette encodes.
///
/// The token values themselves are transcribed and compared in
/// `test/theme/v02_tokens_test.dart`; restating them here as well would give the
/// palette two sources of truth and neither would be the one a reader trusts.
/// What is left is what that file cannot see: what `ThemeData` was actually built
/// with, and the handful of properties that are decisions rather than values.
///
/// Every contrast assertion is a FLOOR, never a pin. This file is where that
/// lesson was paid for: `onAccent` was once pinned to an exact 2.14:1, which
/// recorded a legibility defect faithfully and then objected to it being fixed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/palette.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';

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
  const lightHues = InstrumentHues.light();
  const darkHues = InstrumentHues.dark();

  group('the structural decisions, pinned', () {
    test('BOTH THEMES ARE AUTHORED — every role differs between them', () {
      // v02 writes a dark value for every token rather than deriving one, so
      // apart from the deliberate `line2 == line` collapse *within* a theme,
      // no role may come through identical across the two. A role omitted from
      // one named constructor is exactly what that would look like.
      final shared = <String>[
        if (light.accent == dark.accent) 'accent',
        if (light.unf == dark.unf) 'unf',
        if (light.alert == dark.alert) 'alert',
        if (light.onAccent == dark.onAccent) 'onAccent',
        if (light.bioInk == dark.bioInk) 'bioInk',
      ];
      expect(shared, isEmpty);
    });

    test('identity and judgement are separate token sets in v02', () {
      // Legacy shared them on purpose — `improving ? c.green : c.cHeart` — and
      // v02 does not. See palette.dart: a reader who "restores" the sharing is
      // undoing a decision, not fixing a duplication.
      expect(light.fav, isNot(lightHues.fitness));
      expect(dark.fav, isNot(darkHues.fitness));
      expect(light.alert, isNot(lightHues.heart));
      expect(dark.alert, isNot(darkHues.heart));
    });

    test('fav and unf are distinct — the recovery ladder needs the pair', () {
      expect(light.fav, isNot(light.unf));
      expect(dark.fav, isNot(dark.unf));
    });

    test('hole is a near-invisible FILL, not a hue', () {
      // It is a shape, not a colour. Made visible, a withheld card starts
      // reading as a warning about the owner rather than a refusal by us.
      expect(light.hole.a, lessThan(0.10));
      expect(dark.hole.a, lessThan(0.10));
    });

    test('text on the accent clears WCAG AA in BOTH themes', () {
      for (final (name, colors) in [('light', light), ('dark', dark)]) {
        expect(
          _contrast(colors.accent, colors.onAccent),
          greaterThanOrEqualTo(4.5),
          reason: '$name: the label inside a filled accent button',
        );
      }
    });

    test('MUTATION — one on-accent for both greens fails on the dark one', () {
      // The assertion above passes for any sufficiently contrasting ink,
      // including one chosen by accident. This names the exact regression the
      // per-theme pair exists to prevent: v02's light `--on-accent` measures
      // 1.66:1 on the dark accent. A one-line edit in palette.dart.
      expect(
        _contrast(DarkPalette.accent, LightPalette.onAccent),
        lessThan(3),
      );
      expect(
        _contrast(LightPalette.accent, LightPalette.onAccent),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onAccent is Material’s onError too, and clears AA there as well', () {
      // app_theme.dart wires `onError: colors.onAccent`. The same failure one
      // token over went unnoticed once because nothing asserted it.
      for (final (name, colors) in [('light', light), ('dark', dark)]) {
        expect(
          _contrast(colors.alert, colors.onAccent),
          greaterThanOrEqualTo(4.5),
          reason: '$name: text on an error surface',
        );
      }
    });
  });

  group('the assembled themes', () {
    test('carry both extensions, so context.colors/hues never throw', () {
      expect(AppTheme.light.extension<HealtheeColors>(), light);
      expect(AppTheme.light.extension<InstrumentHues>(), lightHues);
      expect(AppTheme.dark.extension<HealtheeColors>(), dark);
      expect(AppTheme.dark.extension<InstrumentHues>(), darkHues);
    });

    test('wire ColorScheme.error to alert rather than inventing a second red', () {
      // Reserving alert for the illness flag is a rule about OUR cards.
      // Material still needs an error colour, and leaving it at the M3 default
      // would put a red nobody chose into form validation.
      expect(AppTheme.light.colorScheme.error, light.alert);
      expect(AppTheme.dark.colorScheme.error, dark.alert);
    });

    test('use chrome for the app bar, not the page background', () {
      expect(AppTheme.light.appBarTheme.backgroundColor, light.chrome);
      expect(AppTheme.light.scaffoldBackgroundColor, light.bg);
      expect(AppTheme.dark.appBarTheme.backgroundColor, dark.chrome);
      expect(AppTheme.dark.scaffoldBackgroundColor, dark.bg);
    });

    test('the primary IS the fitness family — richer.css’s --accent', () {
      expect(AppTheme.light.colorScheme.primary, Tone.fitness.family(lightHues));
      expect(AppTheme.dark.colorScheme.primary, Tone.fitness.family(darkHues));
    });

    test('set Inter with tabular figures on every text style', () {
      final text = AppTheme.light.textTheme;
      for (final style in [
        text.displayLarge,
        text.headlineMedium,
        text.titleMedium,
        text.bodyMedium,
        text.labelSmall,
      ]) {
        expect(style!.fontFamily, 'Inter');
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: 'a non-tabular numeral in a metric column is a defect',
        );
      }
    });
  });

  test('lerp moves every role, so a theme swap cannot half-animate', () {
    // At t=1 every role must have arrived at the other theme's value. A role
    // missing from `lerp` would keep its old colour here and stand out.
    expect(light.lerp(dark, 1), dark);
    expect(lightHues.lerp(darkHues, 1), darkHues);
  });
}
