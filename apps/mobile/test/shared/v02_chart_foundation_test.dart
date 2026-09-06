/// The chart foundation: where the ticks land, where the words may go, and the
/// one interpolation that cannot draw a value nobody measured.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';
import 'package:healthee/shared/charts/v02/chart_curve.dart';
import 'package:healthee/shared/charts/v02/chart_ticks.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';

void main() {
  group('tick placement', () {
    /// Real ranges from this app's own metrics, not tidy ones.
    const ranges = <String, List<double>>{
      'a heart-rate day': <double>[52, 79],
      'a temperature delta': <double>[0.5, 3.2],
      'a fortnight of steps': <double>[4200, 13800],
      'overnight blood oxygen': <double>[96.5, 99.1],
      'a stress index': <double>[0, 100],
      'a VO2max fortnight': <double>[38, 41],
      'HRV in milliseconds': <double>[31, 74],
    };

    ranges.forEach((name, range) {
      test('$name lands on round values', () {
        final ticks = ChartTicks.nice(range);
        expect(ticks.values.length, greaterThanOrEqualTo(3));
        for (final value in ticks.values) {
          final multiples = value / ticks.step;
          expect(
            (multiples - multiples.roundToDouble()).abs(),
            lessThan(1e-6),
            reason: '$value is not a whole number of ${ticks.step} steps',
          );
        }
        // The step is one of the five the library allows, and nothing else.
        final exponent = (math.log(ticks.step) / math.ln10).floor();
        final normalized = ticks.step / math.pow(10, exponent);
        expect(
          <double>[1, 2, 2.5, 5, 10].any((m) => (m - normalized).abs() < 1e-9),
          isTrue,
          reason: 'step ${ticks.step} normalizes to $normalized',
        );
        // And it contains the data rather than clipping it.
        expect(ticks.low, lessThanOrEqualTo(range.first));
        expect(ticks.high, greaterThanOrEqualTo(range.last));
      });
    });

    test('the heart-rate day is 50 · 60 · 70 · 80, not 52 · 65.5 · 79', () {
      final ticks = ChartTicks.nice(const <double>[52, 61, 79, 58]);
      expect(ticks.values, <double>[50, 60, 70, 80]);
      expect(ticks.values.map(ticks.label), <String>['50', '60', '70', '80']);
    });

    test('a step axis abbreviates its thousands so the gutter fits', () {
      final ticks = ChartTicks.nice(const <double>[4200, 13800]);
      expect(ticks.label(ticks.high), endsWith('k'));
      expect(ticks.label(10000), '10.0k');
    });

    test('a counted metric is pinned to zero; a measured one is not', () {
      expect(ChartTicks.nice(const <double>[4200, 13800], zeroBased: true).low, 0);
      expect(ChartTicks.nice(const <double>[52, 79]).low, greaterThan(0));
    });

    test('a reference outside the data widens the axis rather than clipping', () {
      final ticks = ChartTicks.nice(
        const <double>[60, 75],
        include: const <double>[41],
      );
      expect(ticks.low, lessThanOrEqualTo(41));
    });

    test('a flat series gets a readable axis that does not claim zero', () {
      final ticks = ChartTicks.nice(const <double>[68, 68, 68]);
      expect(ticks.span, greaterThan(0));
      expect(ticks.low, lessThan(68));
      expect(ticks.high, greaterThan(68));
      expect(ticks.low, greaterThan(0));
    });

    test('no data yields the unit axis, which nothing is meant to draw', () {
      expect(ChartTicks.nice(const <double>[]).values, <double>[0, 1]);
    });

    test('a tick sits where the axis says, in the plot it was given', () {
      const ticks = ChartTicks(
        low: 50,
        high: 80,
        step: 10,
        values: <double>[50, 60, 70, 80],
        decimals: 0,
      );
      const plot = Rect.fromLTRB(0, 0, 100, 90);
      expect(ticks.y(50, plot), 90);
      expect(ticks.y(80, plot), 0);
      expect(ticks.y(65, plot), 45);
    });
  });

  group('the plot and its gutters', () {
    const size = Size(328, 190);

    for (final entry in <String, ChartMetrics>{
      'series': ChartMetrics.series,
      'framed': ChartMetrics.framed,
      'bare': ChartMetrics.bare,
    }.entries) {
      test('${entry.key}: words and data do not share pixels', () {
        final box = entry.value.box(size);
        expect(box.plot.overlaps(box.values), isFalse);
        expect(box.plot.overlaps(box.captions), isFalse);
        expect(box.plot.overlaps(box.bubble), isFalse);
        expect(box.isDrawable, isTrue);
      });
    }

    test('the plot stops clear of the gutter, by padRight', () {
      final box = ChartMetrics.series.box(size);
      expect(box.values.left - box.plot.right, ChartMetrics.series.padRight);
    });

    test('a collapsed slot is not drawable, so nothing paints one pixel tall', () {
      expect(ChartMetrics.series.box(const Size(328, 20)).isDrawable, isFalse);
    });

    test('the finger and the trace agree about which sample is where', () {
      final box = ChartMetrics.series.box(size);
      for (var i = 0; i < 24; i++) {
        expect(box.indexAt(box.x(i, 24), 24), i);
      }
    });

    test('a lane is the same box, moved', () {
      final box = ChartMetrics.framed.box(size);
      final lane = box.shift(40);
      expect(lane.plot.top, box.plot.top + 40);
      expect(lane.plot.width, box.plot.width);
    });
  });

  group('monotone interpolation', () {
    /// The property that matters: **the drawn curve never leaves the range of
    /// the samples it was drawn from.** A spline that overshoots draws a night's
    /// minimum lower than any minimum recorded — a number the sensor never
    /// produced, on a chart whose subject is how low the reading went.
    test('never exceeds the input range, over generated series', () {
      final random = math.Random(20260906);
      for (var trial = 0; trial < 80; trial++) {
        final count = 3 + random.nextInt(12);
        final ys = <double>[
          for (var i = 0; i < count; i++) random.nextDouble() * 200,
        ];
        final points = <Offset>[
          for (var i = 0; i < count; i++) Offset(i * 17.0, ys[i]),
        ];
        final low = ys.reduce(math.min);
        final high = ys.reduce(math.max);
        final worst = _extremesOf(monotonePath(points));
        expect(
          worst.$1,
          greaterThanOrEqualTo(low - 1e-3),
          reason: 'trial $trial dipped below every sample: $ys',
        );
        expect(
          worst.$2,
          lessThanOrEqualTo(high + 1e-3),
          reason: 'trial $trial rose above every sample: $ys',
        );
      }
    });

    /// Why it is not the ported Catmull-Rom. Not an opinion: the same generator,
    /// the same series, and one of the two draws values nobody measured.
    test('the ported Catmull-Rom does overshoot on the same series', () {
      final random = math.Random(20260906);
      var overshoots = 0;
      for (var trial = 0; trial < 80; trial++) {
        final count = 3 + random.nextInt(12);
        final ys = <double>[
          for (var i = 0; i < count; i++) random.nextDouble() * 200,
        ];
        final points = <Offset>[
          for (var i = 0; i < count; i++) Offset(i * 17.0, ys[i]),
        ];
        final worst = _extremesOf(smoothPath(points));
        if (worst.$1 < ys.reduce(math.min) - 0.5 ||
            worst.$2 > ys.reduce(math.max) + 0.5) {
          overshoots++;
        }
      }
      expect(overshoots, greaterThan(0));
    });

    test('a local minimum is drawn at the minimum, not below it', () {
      final path = monotonePath(const <Offset>[
        Offset(0, 90),
        Offset(50, 90),
        Offset(100, 10),
        Offset(150, 90),
        Offset(200, 90),
      ]);
      expect(_extremesOf(path).$1, greaterThanOrEqualTo(10 - 1e-3));
    });

    test('two points are a straight line, whatever curve was asked for', () {
      const points = <Offset>[Offset(0, 0), Offset(10, 10)];
      expect(
        monotonePath(points).getBounds(),
        straightPath(points).getBounds(),
      );
    });

    test('a discrete series is joined straight, and says so in its bounds', () {
      const points = <Offset>[Offset(0, 50), Offset(50, 10), Offset(100, 50)];
      final bounds = straightPath(points).getBounds();
      expect(bounds.top, 10);
      expect(bounds.bottom, 50);
    });
  });

  group('holes and withholding', () {
    test('a null breaks a series into runs; it is never bridged', () {
      expect(
        seriesRuns(const <double?>[1, 2, null, 4, 5, null, 7]),
        <List<int>>[
          <int>[0, 1],
          <int>[3, 4],
          <int>[6, 6],
        ],
      );
    });

    test('an all-null series has no runs at all', () {
      expect(seriesRuns(const <double?>[null, null]), isEmpty);
    });

    test('one reading is not a line', () {
      expect(canDrawSeries(const <double?>[68, null, null]), isFalse);
      expect(canDrawSeries(const <double?>[68, null, 70]), isTrue);
      expect(canDrawSeries(const <double?>[]), isFalse);
    });

    test('one column IS a value, so the column rule differs on purpose', () {
      expect(canDrawColumns(const <double?>[9000, null, null]), isTrue);
      expect(canDrawColumns(const <double?>[null, null]), isFalse);
    });

    test('an empty slot is still a slot', () {
      const empty = ChartVoid(height: 190);
      expect(empty.height, 190);
    });
  });
}

/// The highest and lowest y the path actually reaches, sampled along the curve.
///
/// Sampled rather than read from `getBounds`, which is documented as
/// conservative: it would pass a curve that overshoots if the control points
/// happened not to.
(double, double) _extremesOf(Path path) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += 1.5) {
      final position = metric.getTangentForOffset(d)!.position;
      low = math.min(low, position.dy);
      high = math.max(high, position.dy);
    }
  }
  return (low, high);
}
