/// Where the horizontal rules go, and what is written beside them.
///
/// ## The thing this replaces
///
/// The prototype draws its value axis as `[min, (min+max)/2, max]` — three rules
/// at whatever the data happened to reach. On a heart-rate day of 52–79 bpm that
/// prints **52 · 65.5 · 79**, three numbers nobody has ever thought in, and the
/// top and bottom rules sit exactly on the highest and lowest reading so the
/// trace touches the frame at both ends. Every chart in the app then carries a
/// different, arbitrary scale, and two charts of the same metric cannot be
/// compared by eye because neither axis is anchored to anything.
///
/// A considered axis picks a **round step** — 1, 2, 2.5, 5 or 10 times a power
/// of ten — and then extends the range outward to whole multiples of it. The
/// same heart-rate day becomes **50 · 60 · 70 · 80**: numbers a reader already
/// holds, air at both ends because the extension is what produces it, and an
/// axis that does not move when one sample does.
///
/// ## Why the padding is a consequence rather than a parameter
///
/// `ChartScale` (the pre-v02 scale, still used by the ported charts) pads the
/// data range by a fixed 18% so the curve does not touch its box. That padding
/// is invisible arithmetic: it makes the plot honest-looking without making the
/// axis readable, and its own docstring records the 2026-08-06 repair where a
/// symmetric version handed 49% of a plot to empty space. Here the air is
/// whatever rounding out to the next tick happens to cost — never more than one
/// step, usually much less, and always explicable by pointing at a label.
///
/// ## What it will not do
///
/// It will not invent a range for a series that has none. Empty data returns
/// [ChartTicks.unit] and the caller is expected not to have drawn anything at
/// all (`chart_void.dart`), because an axis around no measurement is a frame
/// around a claim we do not have.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A value axis: its bounds, its round step, and the ticks between them.
@immutable
class ChartTicks {
  /// Prefer [ChartTicks.nice]. Direct construction is for tests and for a
  /// caller that genuinely owns its own scale.
  const ChartTicks({
    required this.low,
    required this.high,
    required this.step,
    required this.values,
    required this.decimals,
  }) : assert(high > low, 'an axis with no span cannot place a value');

  /// The axis for [data], with round ticks and room for everything in
  /// [include].
  ///
  /// [include] is how a reference line stays honest: a resting-rate line below
  /// every sample widens the axis rather than clipping to the floor, which is
  /// the difference between "you did not go below your resting rate" being drawn
  /// and being true. It is the same contract `ChartScale.of` states at length.
  ///
  /// [target] is how many gaps to aim for, not a promise — the round step wins.
  /// [zeroBased] pins the floor at zero, which is correct for anything counted
  /// (steps, minutes, TRIMP) and wrong for anything measured (bpm, ms, °C),
  /// where a zero baseline throws away the whole readable range.
  factory ChartTicks.nice(
    Iterable<double> data, {
    Iterable<double> include = const <double>[],
    int target = 4,
    bool zeroBased = false,
  }) {
    final samples = <double>[
      for (final value in data)
        if (value.isFinite) value,
      for (final value in include)
        if (value.isFinite) value,
    ];
    if (samples.isEmpty) {
      return unit;
    }
    var lowest = samples.first;
    var highest = samples.first;
    for (final value in samples) {
      lowest = math.min(lowest, value);
      highest = math.max(highest, value);
    }
    if (zeroBased) {
      lowest = math.min(0, lowest);
      highest = math.max(0, highest);
    }
    if (highest == lowest) {
      // A flat series still deserves a readable axis, and it must not be one
      // that says the value is zero. Open a window around the reading itself.
      final pad = lowest.abs() < 1 ? 1.0 : lowest.abs() * 0.1;
      lowest -= zeroBased ? 0 : pad;
      highest += pad;
    }
    final step = _niceStep((highest - lowest) / math.max(1, target));
    final decimals = _decimalsFor(step);
    final floor = _round((lowest / step).floorToDouble() * step, decimals);
    var ceiling = _round((highest / step).ceilToDouble() * step, decimals);
    if (ceiling <= floor) {
      ceiling = _round(floor + step, decimals);
    }
    final count = ((ceiling - floor) / step).round();
    return ChartTicks(
      low: floor,
      high: ceiling,
      step: step,
      values: <double>[
        for (var i = 0; i <= count; i++) _round(floor + i * step, decimals),
      ],
      decimals: decimals,
    );
  }

  /// The axis for nothing. Never drawn — see the library docstring.
  static const ChartTicks unit = ChartTicks(
    low: 0,
    high: 1,
    step: 1,
    values: <double>[0, 1],
    decimals: 0,
  );

  /// The bottom of the plot, in the series' own units. A round multiple of
  /// [step].
  final double low;

  /// The top of the plot. A round multiple of [step].
  final double high;

  /// The distance between two rules. One of 1, 2, 2.5, 5 or 10 times a power of
  /// ten, and nothing else.
  final double step;

  /// Every tick from [low] to [high] inclusive.
  final List<double> values;

  /// How many decimal places [label] prints. Derived from [step], so an axis
  /// stepping by 2.5 shows `2.5` and one stepping by 10 shows `10`.
  final int decimals;

  /// The axis' span. Never zero — the constructor asserts it.
  double get span => high - low;

  /// Where [value] sits inside [plot], in canvas coordinates.
  double y(double value, Rect plot) =>
      plot.bottom - ((value - low) / span) * plot.height;

  /// Where [value] sits as a fraction of the axis, 0 at [low] and 1 at [high].
  double fraction(double value) => (value - low) / span;

  /// What is written beside a rule at [value].
  ///
  /// Thousands are abbreviated (`10000` → `10k`, `2500` → `2.5k`). Not
  /// decoration: a step-count axis writes five-digit numbers, and a gutter wide
  /// enough for `10000` is a gutter taken off the plot on every chart in the
  /// app. The abbreviation is exact — it never rounds a tick away — because the
  /// decimals come from the step, not from a guess.
  String label(double value) {
    if (high < 1000) {
      return value.toStringAsFixed(decimals);
    }
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(_decimalsFor(step / 1000))}k';
  }
}

/// The nearest round number at or above [rough]: 1, 2, 2.5, 5 or 10 × 10ⁿ.
///
/// 2.5 is in the set because without it a span of 24 over four gaps rounds to a
/// step of 10 and draws two ticks; with it the axis steps 2.5 and draws ten.
double _niceStep(double rough) {
  if (!rough.isFinite || rough <= 0) {
    return 1;
  }
  final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor())
      .toDouble();
  final normalized = rough / magnitude;
  final double multiple;
  if (normalized <= 1) {
    multiple = 1;
  } else if (normalized <= 2) {
    multiple = 2;
  } else if (normalized <= 2.5) {
    multiple = 2.5;
  } else if (normalized <= 5) {
    multiple = 5;
  } else {
    multiple = 10;
  }
  return multiple * magnitude;
}

/// How many decimals [step] needs to print exactly. 10 → 0, 2.5 → 1, 0.25 → 2.
int _decimalsFor(double step) {
  var decimals = 0;
  var scaled = step;
  while (decimals < 6 && (scaled - scaled.roundToDouble()).abs() > 1e-9) {
    scaled *= 10;
    decimals++;
  }
  return decimals;
}

/// Snaps [value] to [decimals] places.
///
/// Ticks are accumulated as `low + i * step`, and binary floating point turns
/// `0.1 + 0.2` into `0.30000000000000004`. A label reading `0.30000000000000004`
/// would be the loudest bug in the app, and an axis whose top tick is
/// `79.99999999999999` fails its own "lands on a round value" test.
double _round(double value, int decimals) {
  final factor = math.pow(10, decimals).toDouble();
  return (value * factor).roundToDouble() / factor;
}
