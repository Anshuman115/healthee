/// The four vitals charts draw FOUR DIFFERENT THINGS — the owner's complaint.
///
/// Owner, 2026-08-06, on the installed build: *"can we change the heartrate,
/// stress, hrv, blood oxygen graphs to be more meaningful ones, this graphs all
/// look similar."* They were all `HArea(series, color: tint, height: 52)` — one
/// mark, one time base, no reference, four different questions.
///
/// That report is a claim about **painted marks**, so this suite asserts painted
/// marks. A widget-type check alone would pass for four charts that happened to
/// paint identically, and `findsOneWidget` passes for a chart that paints
/// nothing at all — `legacy_charts_test.dart` records both traps.
///
/// The second half is the rule the honesty contract puts on all four: a series
/// too short to be a trend **draws nothing, and the slot keeps its height**. The
/// slot matters as much as the silence — a card that collapses when the data
/// thins moves everything under it, which is how a reader learns to read
/// "missing" as "zero".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/today_series.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/hrv_trend_card.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/charts/h_deviation.dart';
import 'package:healthee/shared/charts/h_night_dots.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../shared/_chart_probe.dart';

/// The canvas operations a painter recorded, counted by name.
///
/// This is most of the "mark" in the owner's sense: `drawRRect` × 12 is a column
/// chart and `drawCircle` × 14 is a scatter of nights, whatever the widget is
/// called.
Map<Symbol, int> markOf(WidgetTester tester, Finder chart) {
  final counts = <Symbol, int>{};
  for (final call in paintedBy(tester, chart)) {
    final name = call.invocation.memberName;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return counts;
}

/// The lowest point any filled path reaches, or null when nothing was filled.
///
/// ## Why this is part of the mark and the op counts are not enough
///
/// The first version of this suite compared operation counts alone, and heart
/// rate and HRV came out **identical** — `drawPath` × 2, `drawLine` × 1,
/// `drawParagraph` × 1. That is not a flaw in the charts, it is the measurement
/// being too coarse: an area chart and a deviation chart both stroke a curve and
/// fill a region, and what differs is WHERE the region is anchored.
///
///   * [HArea] closes its fill to the **floor of the box**, so the ink means
///     "how big is this number" — right for a heart rate over a day.
///   * [HDeviation] closes its fill to the **baseline line**, so the ink means
///     "how far from your normal, and which side" — the only reading of an
///     overnight RMSSD that is worth anything.
///
/// So the anchor is asserted, and it is the half of the owner's complaint that
/// op counts cannot see.
double? fillFloorOf(WidgetTester tester, Finder chart) {
  double? lowest;
  for (final call in paintedBy(tester, chart)) {
    if (call.invocation.memberName != #drawPath) {
      continue;
    }
    final bottom = (call.invocation.positionalArguments[0] as Path)
        .getBounds()
        .bottom;
    if (lowest == null || bottom > lowest) {
      lowest = bottom;
    }
  }
  return lowest;
}

/// Twelve hours of an ordinary day.
List<HourPoint> hours() => <HourPoint>[
  for (var i = 0; i < 12; i++)
    HourPoint(
      hour: 6 + i,
      average: 62 + (i % 5) * 7,
      minimum: 58,
      maximum: 96,
      count: 60,
    ),
];

void main() {
  group('the four marks', () {
    /// Each card, laid out for real: its operation counts and its fill anchor.
    Future<(Map<Symbol, int>, double?)> markFor(
      WidgetTester tester,
      Widget card,
      Finder chart,
    ) async {
      await tester.pumpWidget(chartHost(card));
      await tester.pumpAndSettle();
      return (markOf(tester, chart), fillFloorOf(tester, chart));
    }

    testWidgets('EACH CHART PAINTS A DIFFERENT MARK FROM THE OTHER THREE', (
      tester,
    ) async {
      final heart = await markFor(
        tester,
        HeartRateDayCard(
          points: hours(),
          restingHeartRate: const Present<double>(55),
          reveals: RevealRegistry(),
        ),
        find.byType(HArea),
      );
      final arousal = await markFor(
        tester,
        StressCard(
          intraday: const <double>[30, 44, 38, 51, 33, 29, 47],
          daily: const <double>[],
          reveals: RevealRegistry(),
        ),
        find.byType(HBars),
      );
      final hrv = await markFor(
        tester,
        HrvTrendCard(
          series: const <double>[41, 47, 39, 52, 44, 48, 43],
          reading: const Present<double>(43),
          baseline: 45,
          reveals: RevealRegistry(),
        ),
        find.byType(HDeviation),
      );
      final oxygen = await markFor(
        tester,
        BloodOxygenCard(
          minima: const <double>[95, 94, 96, 93, 95, 94, 96],
          reading: const Present<double>(97),
          reveals: RevealRegistry(),
        ),
        find.byType(HNightDots),
      );

      const double slot = 52;

      // The claim, stated per chart rather than only as "they differ", so a
      // failure names WHICH chart stopped drawing what it is for.
      expect(
        heart.$1[#drawPath],
        2,
        reason: 'the day is an area: fill + stroke',
      );
      expect(
        heart.$2,
        slot,
        reason: 'the day fills to the FLOOR — its ink is the size of the number',
      );
      expect(
        arousal.$1[#drawRRect],
        7,
        reason: 'arousal is one column an hour, and nothing else',
      );
      expect(arousal.$1[#drawPath], isNull);
      expect(
        hrv.$1[#drawPath],
        2,
        reason: 'HRV is a region + a stroke',
      );
      expect(
        hrv.$2,
        lessThan(slot),
        reason: 'HRV fills to its BASELINE, not to the floor — that is the '
            'whole difference between "how much" and "how far from normal"',
      );
      expect(
        oxygen.$1[#drawCircle],
        7,
        reason: 'one unconnected dot a night — nights are not continuous',
      );
      expect(oxygen.$1[#drawPath], isNull);

      // And pairwise, which is the owner's sentence: no two of the four are the
      // same picture. Reverting any card to the shared `HArea` collapses two of
      // these onto one signature and fails here.
      final marks = <String, (Map<Symbol, int>, double?)>{
        'heart rate': heart,
        'arousal': arousal,
        'HRV': hrv,
        'blood oxygen': oxygen,
      };
      for (final a in marks.entries) {
        for (final b in marks.entries) {
          if (a.key == b.key) {
            continue;
          }
          expect(
            '${a.value.$1}|${a.value.$2}',
            isNot(equals('${b.value.$1}|${b.value.$2}')),
            reason: '${a.key} and ${b.key} paint the same thing',
          );
        }
      }
    });

    testWidgets('the four use four different chart widgets', (tester) async {
      // The cheap structural half of the same claim. It cannot replace the
      // painted assertion above — two widget types can paint identically — but
      // it fails earlier and more legibly when someone swaps one back.
      for (final (Widget card, Finder chart) in <(Widget, Finder)>[
        (
          HeartRateDayCard(
            points: hours(),
            restingHeartRate: const Present<double>(55),
            reveals: RevealRegistry(),
          ),
          find.byType(HArea),
        ),
        (
          StressCard(
            intraday: const <double>[30, 44, 38, 51],
            daily: const <double>[],
            reveals: RevealRegistry(),
          ),
          find.byType(HBars),
        ),
        (
          HrvTrendCard(
            series: const <double>[41, 47, 39, 52],
            reading: const Present<double>(43),
            baseline: 45,
            reveals: RevealRegistry(),
          ),
          find.byType(HDeviation),
        ),
        (
          BloodOxygenCard(
            minima: const <double>[95, 94, 96, 93],
            reading: const Present<double>(97),
            reveals: RevealRegistry(),
          ),
          find.byType(HNightDots),
        ),
      ]) {
        await tester.pumpWidget(chartHost(card));
        await tester.pumpAndSettle();
        expect(chart, findsOneWidget);
      }
    });
  });

  group('a series too short to be a trend', () {
    /// Every chart's slot height, so a collapse is visible as a number.
    const double slot = 52;

    testWidgets('DRAWS NOTHING, AND THE SLOT KEEPS ITS HEIGHT', (tester) async {
      // One point each. Painted geometry, not widget presence: this repo has
      // shipped `HArea([0, 0])` and an invented 56 bpm flat line, and both of
      // those would pass a `findsOneWidget`.
      for (final (String name, Widget chart, Finder finder)
          in <(String, Widget, Finder)>[
            (
              'heart rate',
              const HArea(
                <double>[64],
                color: Colors.indigo,
                progress: 1,
                height: slot,
              ),
              find.byType(HArea),
            ),
            (
              'arousal',
              const HBars(
                <double>[],
                color: Colors.indigo,
                progress: 1,
                height: slot,
              ),
              find.byType(HBars),
            ),
            (
              'HRV',
              const HDeviation(<double>[44], color: Colors.indigo, progress: 1),
              find.byType(HDeviation),
            ),
            (
              'blood oxygen',
              const HNightDots(<double>[93], color: Colors.indigo, progress: 1),
              find.byType(HNightDots),
            ),
          ]) {
        await tester.pumpWidget(chartHost(chart));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(finder),
          const Size(hostWidth, slot),
          reason: '$name collapsed its slot instead of drawing nothing in it',
        );
        expect(
          paintedBy(tester, finder),
          isEmpty,
          reason: '$name drew a line through a single measurement',
        );
      }
    });

    testWidgets('A REFERENCE ALONE IS NOT A CHART', (tester) async {
      // The trap this closes: a resting-HR line or a 92% convention would draw
      // perfectly well over an empty plot, and the card would look populated
      // while claiming nothing was measured.
      await tester.pumpWidget(
        chartHost(
          const HNightDots(
            <double>[93],
            color: Colors.indigo,
            progress: 1,
            reference: ChartReference.convention(value: 92, label: 'X'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(paintedBy(tester, find.byType(HNightDots)), isEmpty);
    });
  });

  group('a reference widens the plot instead of clipping to its edge', () {
    testWidgets('A RESTING LINE UNDER THE TRACE IS INSIDE THE BOX', (
      tester,
    ) async {
      // The failure this exists for: a reference outside the data's own range
      // drawn in the data's own scale lands on the bottom edge, where it reads
      // as "you never went below your resting rate" — a false claim made
      // entirely by layout. `ChartScale.of(include:)` is the fix.
      const resting = 44.0;
      const trace = <double>[62, 78, 95, 71, 66];
      final scale = ChartScale.of(trace, include: const <double>[resting]);
      final y = scale.y(resting, 52);

      expect(y, lessThan(52), reason: 'the line fell off the bottom');
      expect(y, greaterThan(0));
      expect(
        y,
        greaterThan(scale.y(trace.reduce((a, b) => a < b ? a : b), 52)),
        reason: 'a resting rate below every hour must sit below every hour',
      );
      // And with no references at all the scale is unchanged, which is what
      // makes this extension safe for every chart that does not use it.
      expect(ChartScale.of(trace).low, ChartScale.of(trace, include: const <double>[]).low);
    });
  });
}
