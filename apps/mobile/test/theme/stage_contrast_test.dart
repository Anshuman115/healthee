/// The sleep-stage ramp, measured. Every pair, both themes, against a floor.
///
/// The defect this file exists for: legacy borrows four near-isoluminant metric
/// hues for its four stages, so on the dark card `rem` and `awake` measured
/// **1.02:1 against each other** — the same colour to the eye, told apart by hue
/// alone, which is exactly what red-green colour deficiency removes. The owner
/// saw it on the installed build before any test did: *"only yellow is visible,
/// others are not."*
///
/// ## Why the floor is not 3:1
///
/// WCAG 2.1 SC 1.4.11 asks 3:1 of a graphical object, and adjacent hypnogram
/// bands are graphical objects. **Four colours cannot reach it pairwise.**
/// Contrast is `(Yhi + .05) / (Ylo + .05)`, so it multiplies along a ladder:
/// three steps of 3:1 need 27:1 end to end and sRGB's absolute maximum is 21:1.
/// Adding "and every stage clears 3:1 on its own card" narrows the usable
/// luminance band to a 6.1:1 span (dark) and 6.4:1 (light), i.e. **1.83:1 and
/// 1.85:1 per step at the theoretical best** — and that best spends both ends on
/// achromatic extremes, leaving no hue identity at all.
///
/// So the floor is `kStagePairFloor`, the measured achievable number, and the
/// ceiling is stated below as its own test so nobody reads 1.5 as an ambition
/// that was abandoned rather than a limit that was proved.
///
/// ## Why it is a floor and not a pin
///
/// `test/core/theme_test.dart` records what a pin costs: `onAccent` was pinned to
/// an exact ratio and the pin is the thing that fails when contrast *improves*.
/// Every assertion here is `greaterThanOrEqualTo`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/sleep_stage_palette.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// OKLab chroma — how much colour there is, independent of how light it is.
double _chroma(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r);
  final g = lin(c.g);
  final b = lin(c.b);
  double cbrt(double v) => math.pow(v.abs(), 1 / 3).toDouble() * (v < 0 ? -1 : 1);
  final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  final aa = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  return math.sqrt(aa * aa + bb * bb);
}

/// The four, by name, so a failure says which pair.
Map<String, Color> _stages(InstrumentHues hues) => <String, Color>{
  for (final stage in kSleepStages) stage: hues.sleepStage(stage),
};

/// The lowest contrast among every pair in [set]. The measurement this file is
/// built on, so mutations are run through the same code the assertions use.
double _worstPair(List<Color> set) {
  var lowest = double.infinity;
  for (var i = 0; i < set.length; i++) {
    for (var j = i + 1; j < set.length; j++) {
      lowest = math.min(lowest, _contrast(set[i], set[j]));
    }
  }
  return lowest;
}

/// Whether [set] is strictly darkening — the depth ordering, in `kSleepStages`
/// order.
bool _isDescending(List<Color> set) {
  for (var i = 1; i < set.length; i++) {
    if (set[i].computeLuminance() >= set[i - 1].computeLuminance()) {
      return false;
    }
  }
  return true;
}

/// Whether a mutated stage set would pass both properties this file asserts.
bool _slipsPast(List<Color> set) =>
    _worstPair(set) >= kStagePairFloor && _isDescending(set);

void main() {
  const themes = <String, (InstrumentHues, HealtheeColors)>{
    'light': (InstrumentHues.light(), HealtheeColors.light()),
    'dark': (InstrumentHues.dark(), HealtheeColors.dark()),
  };

  for (final entry in themes.entries) {
    final (hues, colors) = entry.value;
    final stages = _stages(hues);
    final names = stages.keys.toList();

    group('${entry.key} — the ramp', () {
      test('EVERY PAIR CLEARS THE FLOOR — this is the whole repair', () {
        // Six pairs, not three: the stacked bar puts deep beside light, the
        // hypnogram can put any lane above any other, and the legend sets all
        // four side by side. Asserting only the consecutive pairs would pass a
        // ramp that folded back on itself.
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            expect(
              _contrast(stages[names[i]]!, stages[names[j]]!),
              greaterThanOrEqualTo(kStagePairFloor),
              reason: '${names[i]} vs ${names[j]}',
            );
          }
        }
      });

      test('every stage clears 3:1 on the card it is drawn on', () {
        // SC 1.4.11 against the background. Every stage band in this app is
        // drawn inside a card, so `surface` is the binding one — but the page is
        // asserted too, because a chart that moved onto the page would otherwise
        // degrade silently.
        for (final stage in stages.entries) {
          expect(
            _contrast(stage.value, colors.surface),
            greaterThanOrEqualTo(kStageSurfaceFloor),
            reason: '${stage.key} on a card',
          );
          expect(
            _contrast(stage.value, colors.bg),
            greaterThanOrEqualTo(kStageSurfaceFloor),
            reason: '${stage.key} on the page',
          );
        }
      });

      test('THE RAMP IS ORDERED BY DEPTH — deep lightest, awake darkest', () {
        // Not decoration. A monotonic ramp is what lets lane position and
        // lightness say the same thing on the hypnogram, and it is what makes a
        // stacked bar read as one gradient rather than four blocks. `deep` is
        // brightest in BOTH themes; on the light card that also makes it the
        // closest to the paper, which is why its 3:1 is the tight one there.
        final ladder = <double>[
          for (final stage in kSleepStages)
            stages[stage]!.computeLuminance(),
        ];
        for (var i = 1; i < ladder.length; i++) {
          expect(
            ladder[i],
            lessThan(ladder[i - 1]),
            reason: '${kSleepStages[i]} is not darker than ${kSleepStages[i - 1]}',
          );
        }
      });

      test('MUTATION — collapsing two stages to one colour fails the floor', () {
        // Run the same sweep the first test runs, over a set with REM painted
        // in light sleep's colour. It must come back under the floor — which
        // proves the floor is what catches a collapse, rather than some other
        // assertion in this file happening to notice.
        expect(
          _worstPair(<Color>[
            hues.stageDeep, hues.stageLight, hues.stageLight, hues.stageAwake,
          ]),
          lessThan(kStagePairFloor),
        );
        expect(stages.values.toSet().length, kSleepStages.length);
      });

        test('MUTATION — ADOPTING v02’s OWN STAGE COLOURS IS UNDER THE FLOOR', () {
        // The live conflict, measured rather than argued. `richer.css` ships its
        // own four stage colours and they do not clear this gate: in both themes
        // light-vs-REM and light-vs-awake fall under the pair floor, and in the
        // light theme two of the four fall under the surface floor on a white
        // card. So the app draws the repaired ramp and the prototype's set is
        // recorded in `sleep_stage_palette.dart` as the rejected input.
        //
        // This is the "restore legacy" mutation's successor: same shape, current
        // temptation. Whether to adopt v02's set anyway is the owner's call, and
        // it costs these floors.
        final proposed = entry.key == 'light'
            ? V02StagePrototype.light
            : V02StagePrototype.dark;
        expect(_worstPair(proposed), lessThan(kStagePairFloor));
        expect(_isDescending(proposed), isFalse);
      });

      test('MUTATION — swapping ONE stage for v02’s, stage by stage', () {
        // Stronger than the wholesale substitution: each rung is put back on
        // v02's value alone, with the other three left repaired. Every one is
        // caught — three by the depth ordering and, in the dark theme, one by
        // the pair floor after the ordering happens to survive. `unguarded` is
        // the list of stages that slipped past BOTH properties, and it is empty.
        final proposed = entry.key == 'light'
            ? V02StagePrototype.light
            : V02StagePrototype.dark;
        final unguarded = <String>[
          for (var i = 0; i < kSleepStages.length; i++)
            if (_slipsPast(<Color>[
              for (var j = 0; j < kSleepStages.length; j++)
                j == i ? proposed[j] : stages[kSleepStages[j]]!,
            ]))
              kSleepStages[i],
        ];
        expect(
          unguarded,
          isEmpty,
          reason: 'a v02 stage value slipped past both properties',
        );
      });

      test('THE UNSTAGED GREY HAS NO CHROMA, and no stage is anywhere near it', () {
        // Luminance cannot separate a fifth value from a four-rung ladder — the
        // widest gap is 1.56:1, so the best any grey can do is ~1.25:1 from its
        // neighbours. Chroma is what does the work here, so it is chroma that is
        // asserted: exactly zero for the grey, and a real amount for all four.
        final grey = hues.unstaged;
        expect(grey.r, closeTo(grey.g, 0.001));
        expect(grey.g, closeTo(grey.b, 0.001));
        expect(_chroma(grey), lessThan(0.005));
        for (final stage in stages.entries) {
          expect(
            _chroma(stage.value),
            greaterThan(0.05),
            reason: '${stage.key} would be mistaken for “unrecognised”',
          );
          expect(stage.value, isNot(grey), reason: stage.key);
        }
      });

      test('the grey clears the card, and sits in a gap rather than on a rung', () {
        expect(
          _contrast(hues.unstaged, colors.surface),
          greaterThanOrEqualTo(kStageSurfaceFloor),
        );
        // "Not on a rung" is the honest claim: it is placed at the midpoint of a
        // gap, which is 1.25:1 from its neighbours, and that is all luminance
        // can offer. The word does the rest — `legendStages` adds an
        // "Unrecognised" key exactly when a grey band was drawn.
        for (final stage in stages.entries) {
          expect(
            _contrast(hues.unstaged, stage.value),
            greaterThan(1.15),
            reason: '${stage.key} sits on top of the unstaged grey',
          );
        }
      });
    });
  }

  test('THE CEILING IS PROVED, so 1.5 reads as a limit and not a surrender', () {
    // Four colours each 3:1 clear of the next need 27:1 end to end; sRGB offers
    // 21:1 at the absolute most (#000000 on #FFFFFF). If this ever fails,
    // physics changed and the floor should be revisited.
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    expect(_contrast(black, white), lessThan(3.0 * 3.0 * 3.0));
    expect(kStagePairFloor, lessThan(3.0));
  });

  test('the two themes reach the same floor — neither is the afterthought', () {
    double worst(InstrumentHues hues) {
      final values = _stages(hues).values.toList();
      var lowest = double.infinity;
      for (var i = 0; i < values.length; i++) {
        for (var j = i + 1; j < values.length; j++) {
          lowest = math.min(lowest, _contrast(values[i], values[j]));
        }
      }
      return lowest;
    }

    expect(worst(const InstrumentHues.light()), greaterThanOrEqualTo(kStagePairFloor));
    expect(worst(const InstrumentHues.dark()), greaterThanOrEqualTo(kStagePairFloor));
  });
}
