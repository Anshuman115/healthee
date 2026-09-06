/// How a series is joined up — and the one interpolation that cannot lie.
///
/// ## The bug that decides this file
///
/// A spline is fitted, not measured. `smoothPath` (the ported Catmull-Rom every
/// pre-v02 chart uses) overshoots: given three points where the middle one is
/// the lowest, its cubic dips **below** the middle point before coming back up.
/// On a chart of nightly blood-oxygen *minimums* that draws a minimum lower than
/// any minimum ever recorded — a number the sensor never produced, in a plot
/// whose entire subject is how low the reading went. The same overshoot on a
/// steps chart draws negative steps.
///
/// **Monotone cubic interpolation (Fritsch–Carlson, 1980) provably cannot do
/// that.** It is a Hermite cubic whose tangents are limited so that each segment
/// is monotone between its own endpoints; a monotone segment attains its extrema
/// at its endpoints, so the drawn curve stays inside `[min(sample), max(sample)]`
/// everywhere. That is not a tuning choice, it is the theorem, and
/// `v02_chart_curve_test.dart` holds it as a property test over generated
/// series rather than over three hand-picked ones.
///
/// ## When a curve is wrong even when it does not overshoot
///
/// [SeriesCurve.straight] exists because smoothing is a claim about what
/// happened *between* two samples, and for some series there is no between:
///
///   * **an extremum** — a nightly minimum, a daily peak. The value is already a
///     summary of a window; a curve through summaries implies a path through
///     values that were summarised away.
///   * **a total** — steps in a day, TRIMP in a day. Tuesday's total does not
///     ease into Wednesday's.
///
/// Continuous physiological signals sampled densely — a heart rate every five
/// minutes, an overnight stress trace — are the case a curve is *for*, and they
/// get [SeriesCurve.monotone].
///
/// ## A null is a hole, never a shortcut
///
/// [seriesRuns] splits on nulls, and every caller draws each run as its own
/// path. Joining across a gap draws a straight line through hours the strap was
/// off the wrist, which is the fabricated-data failure this app has shipped
/// before (`HArea([0, 0])`, an invented 56-bpm fallback).
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How the points of a series are joined.
enum SeriesCurve {
  /// Monotone cubic. For a densely sampled continuous signal. Never overshoots
  /// the samples it was given — see the library docstring.
  monotone,

  /// Straight segments. For a discrete or extremum series, where there is
  /// nothing between two samples to describe.
  straight,
}

/// The runs of consecutive measured samples in [values].
///
/// Each run is `[firstIndex, lastIndex]` inclusive. A `null` ends a run, so two
/// readings either side of a gap are never joined. A run of one index is a lone
/// sample: real, and drawn as a dot rather than as a line, because one reading
/// is not a trend.
List<List<int>> seriesRuns(List<double?> values) {
  final runs = <List<int>>[];
  var start = -1;
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    final measured = value != null && value.isFinite;
    if (measured && start < 0) {
      start = i;
    } else if (!measured && start >= 0) {
      runs.add(<int>[start, i - 1]);
      start = -1;
    }
  }
  if (start >= 0) {
    runs.add(<int>[start, values.length - 1]);
  }
  return runs;
}

/// Joins [points] with [curve].
Path curvePath(List<Offset> points, SeriesCurve curve) => switch (curve) {
  SeriesCurve.monotone => monotonePath(points),
  SeriesCurve.straight => straightPath(points),
};

/// Straight segments through [points].
Path straightPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) {
    return path;
  }
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  return path;
}

/// Fritsch–Carlson monotone cubic through [points], as cubic béziers.
///
/// [points] must be ordered by x, which every series here is (it is time).
///
/// The three steps are the paper's, and each one is load-bearing:
///
///   1. **Secants.** `slope[i]` is the straight-line gradient of segment i.
///   2. **Tangents.** The interior tangent is the average of its two secants,
///      **except at a turning point** — where the two secants have opposite
///      signs, the tangent is flat. This is what stops a curve carrying on
///      downward past a local minimum and drawing a value below every sample.
///   3. **The limiter.** Where `(m[i]/slope[i])² + (m[i+1]/slope[i])² > 9`, both
///      tangents are scaled back onto that circle. Nine is the monotonicity
///      region's radius, and it is also exactly the condition that keeps each
///      bézier's control points inside the segment's own y-range — so the
///      conservative bounds of the path are inside the data's range too, not
///      only the curve.
Path monotonePath(List<Offset> points) {
  final n = points.length;
  if (n < 3) {
    return straightPath(points);
  }
  final dx = List<double>.filled(n - 1, 0);
  final slope = List<double>.filled(n - 1, 0);
  for (var i = 0; i < n - 1; i++) {
    dx[i] = points[i + 1].dx - points[i].dx;
    slope[i] = dx[i] == 0 ? 0 : (points[i + 1].dy - points[i].dy) / dx[i];
  }
  final tangent = List<double>.filled(n, 0);
  tangent[0] = slope[0];
  tangent[n - 1] = slope[n - 2];
  for (var i = 1; i < n - 1; i++) {
    tangent[i] = slope[i - 1] * slope[i] <= 0
        ? 0
        : (slope[i - 1] + slope[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    if (slope[i] == 0) {
      tangent[i] = 0;
      tangent[i + 1] = 0;
      continue;
    }
    final a = tangent[i] / slope[i];
    final b = tangent[i + 1] / slope[i];
    final radius = a * a + b * b;
    if (radius > 9) {
      final scale = 3 / math.sqrt(radius);
      tangent[i] = scale * a * slope[i];
      tangent[i + 1] = scale * b * slope[i];
    }
  }
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < n - 1; i++) {
    final third = dx[i] / 3;
    path.cubicTo(
      points[i].dx + third,
      points[i].dy + tangent[i] * third,
      points[i + 1].dx - third,
      points[i + 1].dy - tangent[i + 1] * third,
      points[i + 1].dx,
      points[i + 1].dy,
    );
  }
  return path;
}
