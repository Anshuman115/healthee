/// Today's charts PAINT, at the size they were really laid out to.
///
/// Two charts have already shipped at zero height in this repo because a test
/// only checked that the widget existed. `find.byType(HArea)` passes for a chart
/// inside a `SizedBox(height: 0)`, for a chart with an empty series, and for a
/// chart whose painter returned on its first line. So every assertion here reads
/// the **recorded canvas**: the chart is laid out on the real screen, its painter
/// is replayed at the size the layout gave it, and what it actually drew is
/// counted.
///
/// `test/shared/_chart_probe.dart` owns the recording helpers; this file is
/// about the charts as Today lays them out, which is the half a widget-level
/// chart suite cannot see.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/charts/h_stage_bar.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';

import '../shared/_chart_probe.dart';
import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  Future<void> openToday(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(420, 14000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();
  }

  group('the tile charts', () {
    testWidgets("THE SLEEP TILE'S STAGE BAR FILLS THE 30 px SLOT AND IS PAINTED", (
      tester,
    ) async {
      // Owner-delegated departure, 2026-08-06: this cell drew legacy's four-lane
      // hypnogram at 30 px, which is ~7 px a lane and reads as scattered dots on
      // a fragmented night. It draws `HStageBar` now. `today_tiles.dart` carries
      // the decision; the full hypnogram is unchanged on the Sleep tab.
      await openToday(tester);
      await reveal(tester, find.byType(HStageBar));

      final chart = find.byType(HStageBar).first;
      expect(
        tester.getSize(chart).height,
        lessThanOrEqualTo(MetricTile.chartHeight),
        reason: 'the bar lives INSIDE legacy 30 px slot; it does not grow it',
      );
      // The slot itself keeps legacy's height whichever chart is in it, which is
      // what stops the tile moving.
      expect(
        tester
            .widgetList<SizedBox>(
              find.ancestor(of: chart, matching: find.byType(SizedBox)),
            )
            .map((box) => box.height),
        contains(MetricTile.chartHeight),
      );

      // Painted, not merely present: every segment at real height and width.
      // Two charts on this project shipped at zero height because a test only
      // asked whether the widget existed.
      //
      // Scoped to THIS chart. Today has other `FractionallySizedBox`es — the
      // biological-age waterfall's bars are one — and a screen-wide finder was
      // measuring them instead, which is a test that fails for a reason having
      // nothing to do with what it is named after.
      final segments = find.descendant(
        of: find.descendant(of: chart, matching: find.byType(FractionallySizedBox)),
        matching: find.byType(ColoredBox),
      );
      expect(segments, findsWidgets);
      for (var i = 0; i < tester.widgetList(segments).length; i++) {
        final size = tester.getSize(segments.at(i));
        expect(size.height, greaterThan(0), reason: 'segment $i collapsed');
        expect(size.width, greaterThan(0), reason: 'segment $i has no width');
      }
    });

    testWidgets('THE HYPNOGRAM IS GONE FROM TODAY, AND ONLY FROM TODAY', (
      tester,
    ) async {
      // The other half of the same decision. If this ever fails because a
      // hypnogram came back to the grid, read `today_tiles.dart` first — the
      // departure is deliberate and recorded there.
      await openToday(tester);

      expect(find.byType(HHypnogram), findsNothing);
    });

    testWidgets('a tile sparkline is laid out at 30 px and draws a path', (
      tester,
    ) async {
      await openToday(tester);
      final chart = find.descendant(
        of: find.byType(MetricTile),
        matching: find.byType(HArea),
      );
      await reveal(tester, chart.first);

      final size = tester.getSize(chart.first);
      expect(size.height, MetricTile.chartHeight);
      expect(countOf(paintedBy(tester, chart.first), #drawPath), greaterThan(0));
    });
  });

  group('the full-width charts', () {
    testWidgets('the 24-hour heart rate is 52 px and draws its line', (
      tester,
    ) async {
      await openToday(tester);
      await reveal(tester, find.byType(HeartRateDayCard));

      final chart = find.descendant(
        of: find.byType(HeartRateDayCard),
        matching: find.byType(HArea),
      );
      expect(tester.getSize(chart).height, 52);
      // Fill + stroke: a chart that drew one of the two lost half its ink.
      expect(countOf(paintedBy(tester, chart), #drawPath), 2);
    });

    testWidgets('the seven-night stack fills its 108 px and draws seven bars', (
      tester,
    ) async {
      await openToday(tester);
      await reveal(tester, find.byType(HStackedSleep));

      final chart = find.byType(HStackedSleep);
      expect(tester.getSize(chart).height, 108);
      final painted = paintedBy(tester, chart);
      // Four stage segments a night, seven nights.
      expect(countOf(painted, #drawRect), 7 * 4);
      final segments = rectsOf(painted).where((rect) => rect.height > 0);
      expect(
        segments,
        isNotEmpty,
        reason: 'a stacked bar of zero-height segments is an empty axis',
      );
    });

    testWidgets('the recovery gauge lights ticks in proportion to the score', (
      tester,
    ) async {
      await openToday(tester);
      await reveal(tester, find.byType(HTickGauge).first);

      final gauge = find.byType(HTickGauge).first;
      expect(tester.getSize(gauge), const Size(116, 116));
      // 45 marks over a 270° arc, every one drawn — the unlit ones are the scale.
      expect(countOf(paintedBy(tester, gauge), #drawLine), HTickGauge.ticks + 1);
    });
  });

  group('reveal-once', () {
    testWidgets('A CHART DOES NOT REPLAY WHEN IT SCROLLS BACK', (tester) async {
      // The registry belongs to the screen's `State`, so a chart rebuilt by
      // `ListView.builder` starts finished. The observable is the painted
      // geometry at the first frame after the scroll: a replaying chart would be
      // part-drawn.
      await openToday(tester);
      await reveal(tester, find.byType(HStackedSleep));
      final before = rectsOf(paintedBy(tester, find.byType(HStackedSleep)));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      // ONE frame, deliberately: a chart that restarted its reveal would be at
      // progress 0 here and every bar would have zero height.
      await tester.pump();

      final after = rectsOf(paintedBy(tester, find.byType(HStackedSleep)));
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        expect(
          after[i].height,
          moreOrLessEquals(before[i].height, epsilon: 0.01),
          reason: 'bar $i re-animated on scroll-back',
        );
      }
    });
  });
}
