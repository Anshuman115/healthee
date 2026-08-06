/// The y-scales: a reference inside the plot, a trace that has room, a fixed window.
///
/// Two owner reports, both about scale rather than about ink:
///
///   * *"the header says 60–75 bpm while the resting reference sits at 56"* —
///     the day was pressed into the top of its own range because the reference
///     had been padded by the same 18% as the data. A chart that spends half its
///     height on air draws a flat line out of a moving one.
///   * *"the y-scale crushes 93–98% onto the 92% line while one night at 85%
///     sets the floor"* — an auto-scale handed the whole plot to the worst night
///     of the fortnight, and rescaled itself every time a night changed.
///
/// Both are measured here, and measured through the PAINTER wherever a mutation
/// could bypass the arithmetic: a scale computed correctly and then not used is
/// the same picture as a scale computed wrong.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/charts/h_night_line.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../shared/_chart_probe.dart';
import '_vitals_probe.dart';

/// The heart-rate plot's height, as the card draws it.
const double _dayHeight = 52;

/// The share of its own plot a reading must own.
///
/// A display decision, written down rather than inlined. Below this the trace is
/// a flat line inside a mostly empty box, which is what the owner was looking at
/// — the symmetric padding this replaced gave the same day 51%.
const double _usableShare = 0.55;

/// One percentage point of SpO2, in pixels, at the blood-oxygen card's height.
///
/// A night mark is 2.6 px in radius, so two nights one point apart must move by
/// more than a mark's own diameter or they read as one smear. This is why that
/// card is taller than legacy's 52 px, where a point is 3.8 px.
const double _percentPixels = 4;

void main() {
  group('the heart-rate reference is inside the scale it is drawn in', () {
    testWidgets('THE PAINTED LINE SITS WHERE THE SHARED SCALE PUTS IT', (
      tester,
    ) async {
      const resting = 55.0;
      final series = <double>[for (final point in hours()) point.average];

      await tester.pumpWidget(
        chartHost(
          HeartRateDayCard(
            points: hours(),
            restingHeartRate: const Present<double>(resting),
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lines = <double>[
        for (final call in paintedBy(tester, find.byType(HArea)))
          if (call.invocation.memberName == #drawLine)
            (call.invocation.positionalArguments[0] as Offset).dy,
      ];
      expect(lines, hasLength(1), reason: 'one solid reference, no scrub');

      // The claim: the painter widened its own scale to hold the reference. A
      // painter that dropped `include:` still draws a line — one that lands
      // below every hour, on the floor, reading as "you never went below your
      // resting rate". That version is 51.4 here and passes any "is it drawn"
      // test ever written.
      expect(
        lines.single,
        closeTo(
          ChartScale.of(
            series,
            include: const <double>[resting],
          ).y(resting, _dayHeight),
          0.01,
        ),
      );
      expect(
        lines.single,
        lessThan(_dayHeight - ChartScale.inset),
        reason: 'the reference is clipping to the bottom edge',
      );
      expect(lines.single, greaterThan(ChartScale.inset));
    });
  });

  group('the trace gets a usable share of its own plot', () {
    /// The fraction of a [height]-tall plot that [series] occupies once
    /// [reference] has widened the scale — the arithmetic the painter uses.
    double shareOf(List<double> series, double reference, double height) {
      final scale = ChartScale.of(series, include: <double>[reference]);
      return scale.share(
        series.reduce(math.min),
        series.reduce(math.max),
        height,
      );
    }

    test('A REFERENCE BELOW THE DATA DOES NOT TAKE THE CHART OVER', () {
      // The owner's own shape: a quiet day of 60–75 over a resting rate of 56.
      const day = <double>[60, 66, 72, 75, 68, 63, 70];
      expect(
        shareOf(day, 56, _dayHeight),
        greaterThan(_usableShare),
        reason: 'the day is a flat line in an empty box',
      );
      expect(
        shareOf(
          <double>[for (final point in hours()) point.average],
          55,
          _dayHeight,
        ),
        greaterThan(_usableShare),
      );
    });

    test('and a chart with no reference is unchanged', () {
      // The whole extension has to be free for the dozen charts that use none.
      const day = <double>[60, 66, 72, 75, 68, 63, 70];
      final bare = ChartScale.of(day);
      expect(bare.low, ChartScale.of(day, include: const <double>[]).low);
      expect(bare.high, ChartScale.of(day, include: const <double>[]).high);
      expect(bare.low, closeTo(60 - 15 * ChartScale.padFraction, 0.001));
    });
  });

  group('blood oxygen is drawn on a FIXED window', () {
    /// Where each night's mark landed, in the card's real layout.
    Future<List<Offset>> nightsOf(
      WidgetTester tester,
      List<double> minima,
    ) async {
      await tester.pumpWidget(
        chartHost(
          BloodOxygenCard(
            minima: minima,
            reading: const Present<double>(96),
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return <Offset>[
        for (final call in paintedBy(tester, find.byType(HNightLine)))
          if (call.invocation.memberName == #drawCircle)
            call.invocation.positionalArguments[0] as Offset,
      ];
    }

    testWidgets('95% LANDS ON THE SAME PIXEL IN TWO DIFFERENT FORTNIGHTS', (
      tester,
    ) async {
      // The measurement argument for a fixed scale: the sensor's error is
      // unquantified and at least ±3.5% (#98), so a scale fitted to the
      // fortnight resolves noise — and draws a different picture of the same
      // body every night. Auto-scaled, these two land 20 px apart.
      final spread = await nightsOf(tester, const <double>[
        93,
        95,
        97,
        94,
        96,
        98,
        95,
      ]);
      final flat = await nightsOf(tester, const <double>[
        95,
        95,
        94,
        95,
        96,
        95,
        95,
      ]);

      expect(spread[1].dy, closeTo(flat[0].dy, 0.001));
    });

    testWidgets('ONE PERCENTAGE POINT IS BIGGER THAN A NIGHT MARK', (
      tester,
    ) async {
      final nights = await nightsOf(tester, const <double>[
        93,
        94,
        95,
        96,
        97,
        96,
        95,
      ]);

      expect(
        nights[0].dy - nights[1].dy,
        greaterThanOrEqualTo(_percentPixels),
        reason:
            'consecutive nights one point apart overlap into a smear — the '
            'plot is too short for the window it is drawn on',
      );
    });

    testWidgets('A NIGHT BELOW THE FLOOR WIDENS THE WINDOW, AND IS SAID', (
      tester,
    ) async {
      // Nothing is ever clipped: the low night is plotted, and the card states
      // that its scale is no longer the usual one. A fixed scale that silently
      // stopped being fixed would be worse than never fixing it.
      final nights = await nightsOf(tester, const <double>[
        85,
        95,
        97,
        94,
        96,
        95,
        96,
      ]);
      expect(nights, hasLength(7), reason: 'the low night is still drawn');
      expect(
        nights[0].dy,
        greaterThan(nights[1].dy),
        reason: 'and it is drawn below the rest, not clamped to them',
      );
      expect(
        textOf(tester, find.byType(BloodOxygenCard)).join(' · ').toLowerCase(),
        contains('widened'),
      );
    });

    testWidgets('AND AN ORDINARY FORTNIGHT SAYS NOTHING ABOUT ITS SCALE', (
      tester,
    ) async {
      await nightsOf(tester, const <double>[95, 94, 96, 93, 95, 94, 96]);
      expect(
        textOf(tester, find.byType(BloodOxygenCard)).join(' · ').toLowerCase(),
        isNot(contains('widened')),
      );
    });

    test('the window is the convention plus the sensor’s own error', () {
      // 92% minus the ≥±3.5% #98 records, rounded down: the convention line and
      // its caution margin are on every chart, every night.
      expect(
        BloodOxygenCard.scaleFloorPercent,
        lessThan(BloodOxygenCard.scaleCeilingPercent),
      );
      expect(
        BloodOxygenCard.scaleFloorPercent,
        lessThan(92),
        reason: 'a floor at or above the convention would clip the line itself',
      );
      expect(
        BloodOxygenCard.scaleCeilingPercent,
        100,
        reason: 'saturation cannot exceed 100%, so nothing above it is plot',
      );
    });
  });
}
