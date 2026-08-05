/// `sleepStage()` — the one mapping every sleep chart draws from.
///
/// Legacy states the rule in a comment and then relies on it in four places
/// (the hypnogram, the seven-night bars, the legend, the stage bar). A second
/// mapping anywhere would mean one night drawn in two colour schemes, which is
/// the kind of wrongness nobody files a bug for because each screen looks fine
/// on its own.
///
/// **Every assertion here is mutation-tested**: for each stage, the test proves
/// the mapping answers that hue AND that it answers none of the other three. An
/// assertion that only checks the expected value passes for a mapping that
/// returns the same colour for everything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';

void main() {
  const themes = <String, InstrumentHues>{
    'light': InstrumentHues.light(),
    'dark': InstrumentHues.dark(),
  };

  for (final theme in themes.entries) {
    final hues = theme.value;

    group('${theme.key} — legacy’s canonical four', () {
      /// `theme.dart:31` — deep=cSteps · core/light=cSpo2 · rem=cSleep ·
      /// awake=cHeart.
      final canonical = <String, Color>{
        'deep': hues.steps,
        'light': hues.spo2,
        'core': hues.spo2,
        'rem': hues.sleep,
        'awake': hues.heart,
      };

      test('each stage answers legacy’s hue', () {
        for (final entry in canonical.entries) {
          expect(
            hues.sleepStage(entry.key),
            entry.value,
            reason: '${entry.key} is not legacy’s colour',
          );
        }
      });

      test('MUTATION — no stage answers another stage’s hue', () {
        // The check that makes the one above mean something. Deep must be amber
        // and must NOT be the blue, the purple or the red; and so on round.
        final distinct = <String, Color>{
          'deep': hues.steps,
          'light': hues.spo2,
          'rem': hues.sleep,
          'awake': hues.heart,
        };
        for (final mine in distinct.entries) {
          for (final other in distinct.entries) {
            if (other.key == mine.key) {
              continue;
            }
            expect(
              hues.sleepStage(mine.key),
              isNot(other.value),
              reason: '${mine.key} draws in ${other.key}’s colour',
            );
          }
        }
      });

      test('THE FOUR ARE FOUR — a hypnogram of one hue is unreadable', () {
        final drawn = <Color>{
          for (final stage in const <String>['deep', 'light', 'rem', 'awake'])
            hues.sleepStage(stage),
        };
        expect(drawn.length, 4);
      });

      test('core and light are ONE stage under two vocabularies', () {
        // The server says `core`, the strap says `light`. Giving them different
        // colours would draw a distinction that does not exist.
        expect(hues.sleepStage('core'), hues.sleepStage('light'));
        expect(sleepStageLabel('core'), sleepStageLabel('light'));
      });

      test('AN UNRECOGNISED CODE FALLS BACK TO LIGHT SLEEP — legacy’s own rule', () {
        // theme.dart:36 and instrument_charts.dart:403 both default to cSpo2.
        //
        // This is ported and NOT repaired, and it is a reported finding: the
        // rebuild's previous mapping gave an unknown code a grey of its own, so
        // a span nothing measured was visibly not a staged span. Legacy paints
        // it as light sleep. Legacy is the specification.
        expect(hues.sleepStage('0x7f'), hues.spo2);
        expect(hues.sleepStage(''), hues.spo2);
        expect(hues.sleepStage('nap'), hues.sleepStage('light'));
      });

      test('the alias resolves to the same mapping', () {
        for (final stage in const <String>['deep', 'light', 'core', 'rem', 'awake']) {
          expect(sleepStageColor(hues, stage), hues.sleepStage(stage));
        }
      });
    });
  }

  test('the stacking order is legacy’s, deepest first', () {
    // instrument_charts.dart:335 stacks deep, core, rem, awake from the floor
    // up. A reordered list silently redraws every seven-night chart.
    expect(kSleepStages, const <String>['deep', 'light', 'rem', 'awake']);
  });

  test('MUTATION — the label table does not answer one word for everything', () {
    final labels = <String>{
      for (final stage in kSleepStages) sleepStageLabel(stage),
    };
    expect(labels.length, kSleepStages.length);
    expect(sleepStageLabel('0x7f'), 'Unrecognised');
  });

  test('the two themes agree on WHICH FIELD each stage takes', () {
    // The hexes differ by theme, and must; the mapping may not. This compares
    // the field a stage resolves to, not its value.
    const light = InstrumentHues.light();
    const dark = InstrumentHues.dark();
    String fieldOf(InstrumentHues hues, String stage) {
      final colour = hues.sleepStage(stage);
      if (colour == hues.steps) {
        return 'cSteps';
      }
      if (colour == hues.spo2) {
        return 'cSpo2';
      }
      if (colour == hues.sleep) {
        return 'cSleep';
      }
      if (colour == hues.heart) {
        return 'cHeart';
      }
      return 'unknown';
    }

    for (final stage in const <String>['deep', 'light', 'core', 'rem', 'awake']) {
      expect(fieldOf(dark, stage), fieldOf(light, stage), reason: stage);
      expect(fieldOf(light, stage), isNot('unknown'), reason: stage);
    }
  });
}
