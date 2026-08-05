/// The identity tags are NOT judgement colours, and this is what enforces it.
///
/// `palette.dart` argues that a per-metric hue family can exist here without
/// becoming a verdict, on two conditions. Both are checked below, because an
/// argument in a docstring is a comment and a comment does not fail a build.
///
///   1. **A tag never varies with a value.** `MetricHues.tagFor` takes a metric
///      id and nothing else, so the type system already forbids the value-driven
///      version; what a test can add is that the same id always answers the same
///      way, which is what makes the constancy visible to the owner.
///   2. **A tag is never mistakable for `fav`, `unf` or `alert`.** That is a
///      claim about colour, so it is measured in colour: OKLCH hue angle, the
///      space the palette was designed in. A future edit that sets `heart` to the
///      product's red fails here rather than in review.
///
/// And one thing the sleep hypnogram needs and the previous single-hue palette
/// did not give it: the three staged bands must be **distinguishable from each
/// other**, which is what makes a picture of a night a reading.
///
/// The OKLCH conversion is implemented here rather than imported. It is test
/// scaffolding — the app never needs it at runtime — and a copy of a documented
/// standard transform is cheaper than a dependency or a lib/ file with one user.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The three judgement colours, per theme — the ones a tag must never resemble.
Map<String, Color> judgements(HealtheeColors colors) => <String, Color>{
  'fav': colors.fav,
  'unf': colors.unf,
  'alert': colors.alert,
};

/// The tags, per theme.
Map<String, Color> tags(MetricHues hues) => <String, Color>{
  'rest': hues.rest,
  'heart': hues.heart,
  'body': hues.body,
  'move': hues.move,
  'energy': hues.energy,
};

/// The smallest angle between two hues, in degrees.
double hueGap(Color a, Color b) {
  final difference = (oklchHue(a) - oklchHue(b)).abs() % 360;
  return math.min(difference, 360 - difference);
}

/// The OKLCH lightness of [color], 0–1.
double oklchLightness(Color color) {
  final (l, m, s) = _cones(color);
  return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
}

/// The OKLCH hue angle of [color], in degrees.
double oklchHue(Color color) {
  final (l, m, s) = _cones(color);
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bAxis = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  return (math.atan2(bAxis, a) * 180 / math.pi) % 360;
}

/// The cube-rooted LMS cone responses [oklchHue] and [oklchLightness] share.
(double, double, double) _cones(Color color) {
  double linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  final r = linear(color.r);
  final g = linear(color.g);
  final b = linear(color.b);
  return (
    math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3).toDouble(),
    math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3).toDouble(),
    math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3).toDouble(),
  );
}

void main() {
  const themes = <String, (HealtheeColors, MetricHues)>{
    'light': (HealtheeColors.light(), MetricHues.light()),
    'dark': (HealtheeColors.dark(), MetricHues.dark()),
  };

  /// **Two floors, because the two claims are different sizes.**
  ///
  /// A tag landing on a verdict is a correctness failure — the screen would be
  /// asserting something about the owner's body that nobody computed — so that
  /// floor stays where the three-tag set put it. `palette.dart` records the
  /// closest measured approach as 42.7°.
  ///
  /// Two tags being hard to tell apart is a legibility failure, and it is bounded
  /// by the wheel: five hues inside the 145° the verdicts leave free cannot be
  /// further apart than 36°, and 34.6° is what the chosen five measure. Holding
  /// this at 40 would not make the screen better, it would make five tags
  /// impossible — so it is set to what the geometry actually allows and a sixth
  /// tag (29°) fails here rather than in review.
  const double verdictClearance = 40;
  const double tagSeparation = 34;

  group('a tag is never mistakable for a judgement', () {
    for (final entry in themes.entries) {
      final (colors, hues) = entry.value;

      test('${entry.key}: NO TAG IS A JUDGEMENT COLOUR', () {
        for (final tag in tags(hues).entries) {
          for (final judgement in judgements(colors).entries) {
            expect(
              tag.value,
              isNot(judgement.value),
              reason:
                  '${tag.key} is exactly ${judgement.key}. A colour that means '
                  '"worse than your normal" cannot also mean "this card is '
                  'about your heart".',
            );
          }
        }
      });

      test('${entry.key}: every tag sits $verdictClearance° clear of every verdict', () {
        for (final tag in tags(hues).entries) {
          for (final judgement in judgements(colors).entries) {
            final gap = hueGap(tag.value, judgement.value);
            expect(
              gap,
              greaterThanOrEqualTo(verdictClearance),
              reason:
                  '${tag.key} is only ${gap.toStringAsFixed(1)}° from '
                  '${judgement.key} in OKLCH. At the 6 px a dot occupies that '
                  'reads as the verdict.',
            );
          }
        }
      });

      test('${entry.key}: the five tags are $tagSeparation° clear of each other', () {
        final named = tags(hues).entries.toList();
        for (var i = 0; i < named.length; i++) {
          for (var j = i + 1; j < named.length; j++) {
            final gap = hueGap(named[i].value, named[j].value);
            expect(
              gap,
              greaterThanOrEqualTo(tagSeparation),
              reason:
                  '${named[i].key} and ${named[j].key} are '
                  '${gap.toStringAsFixed(1)}° apart — two identities the eye '
                  'cannot separate are one identity.',
            );
          }
        }
      });

      test('${entry.key}: NO TAG IS LIGHTER THAN ANOTHER, so none reads as ranked', () {
        // Lightness is the axis the eye reads as "more". Hue is the axis that
        // carries identity. If the five tags drifted apart in lightness, the
        // brightest would look like the important one — a rank nobody computed,
        // drawn in the one language this palette reserves for claims.
        final lightnesses = tags(hues).values.map(oklchLightness).toList();
        final spread =
            lightnesses.reduce(math.max) - lightnesses.reduce(math.min);
        expect(
          spread,
          lessThan(0.01),
          reason:
              'the tags span ${spread.toStringAsFixed(3)} in OKLCH lightness; '
              'they are authored at one L (0.540 light, 0.685 dark) precisely '
              'so no metric family looks more important than another',
        );
      });
    }
  });

  group('a tag is a constant of the metric', () {
    const hues = MetricHues.light();

    test('the same id always answers the same colour', () {
      for (final metric in <String>['rhr_daily', 'steps_total', 'hrv', 'spo2']) {
        expect(hues.tagFor(metric), hues.tagFor(metric));
      }
    });

    test('the server id and the strap id for one metric agree', () {
      // Two vocabularies reach this screen. A metric that is the heart tag on
      // the server's card and the rest tag on the strap's row would be one
      // metric in two colours, which is the identity claim broken.
      expect(hues.tagFor('rhr_daily'), hues.tagFor('resting_hr'));
      expect(hues.tagFor('steps_total'), hues.tagFor('steps'));
      expect(hues.tagFor('spo2_overnight'), hues.tagFor('spo2'));
    });

    test('an unlisted metric gets the default rather than a distinct hue', () {
      // A new metric should look like it belongs, not like an error.
      expect(hues.tagFor('a_metric_nobody_listed'), hues.rest);
    });

    test('EVERY FAMILY IS ITS OWN COLOUR', () {
      // Five fields that resolved to four colours would be four families with a
      // spare name — and the metric that wears the duplicate would silently
      // rejoin a family it was split out of.
      expect(
        <Color>{hues.rest, hues.heart, hues.body, hues.move, hues.energy},
        hasLength(5),
      );
    });

    test('the movement metrics are one family and the calories another', () {
      // The split that made the palette grow: `body` used to carry breathing,
      // blood oxygen, steps, distance and every calorie, which made the tag mean
      // only "not sleep and not heart".
      for (final metric in <String>[
        'steps_total',
        'distance_m_daily',
        'mvpa_min',
        'cardio_load',
      ]) {
        expect(hues.tagFor(metric), hues.move, reason: '$metric is movement');
      }
      for (final metric in <String>[
        'active_calories',
        'total_calories',
        'basal_calories',
      ]) {
        expect(hues.tagFor(metric), hues.energy, reason: '$metric is energy');
      }
      for (final metric in <String>[
        'respiratory_rate',
        'spo2_overnight',
        'temperature_c',
      ]) {
        expect(hues.tagFor(metric), hues.body, reason: '$metric is body');
      }
    });

    test('READINESS IS NOT THE GENERIC ACCENT', () {
      // The gauge wears `rest`. While `rest` WAS `accent` it was drawn in the
      // same colour as every link and button on the screen, which is the
      // opposite of an instrument having an identity.
      const light = HealtheeColors.light();
      const dark = HealtheeColors.dark();
      expect(const MetricHues.light().rest, isNot(light.accent));
      expect(const MetricHues.dark().rest, isNot(dark.accent));
      expect(
        hueGap(const MetricHues.light().rest, light.accent),
        greaterThan(20),
        reason: 'a tag three degrees off the accent is the accent',
      );
    });
  });

  group('a hypnogram of one hue would be unreadable', () {
    for (final entry in themes.entries) {
      final (colors, hues) = entry.value;

      test('${entry.key}: THE THREE STAGED BANDS ARE ALL DIFFERENT', () {
        final staged = <String, Color>{
          for (final stage in <String>['deep', 'light', 'rem'])
            stage: sleepStageColor(colors, hues, stage),
        };
        expect(
          staged.values.toSet(),
          hasLength(3),
          reason:
              'the previous palette drew all four stages as one accent at three '
              'alphas; three tints of indigo in a 28 px chart cannot be told '
              'apart, which makes the picture of the night decoration',
        );
      });

      test('${entry.key}: awake is not a fourth stage colour', () {
        // The absence of sleep, drawn as structure rather than as a tag.
        expect(sleepStageColor(colors, hues, 'awake'), colors.line);
      });

      test('${entry.key}: core and light are the same stage, so one colour', () {
        expect(
          sleepStageColor(colors, hues, 'core'),
          sleepStageColor(colors, hues, 'light'),
        );
      });

      test('${entry.key}: an unrecognised code is visibly not a staged span', () {
        expect(sleepStageColor(colors, hues, 'any'), colors.line2);
      });
    }
  });
}
