/// What reaches the SURFACE of the two rebuilt screens — and what must not.
///
/// Three claims, each of which a "does the screen render" test passes without
/// noticing:
///
///   * **No raw identifier.** `gps_graded`, `steps_total`, `mvpa_min` and
///     `hrv_sleep_avg` are wire ids. On a health screen they are log lines where
///     a name belongs, and `shared/format/metric_names.dart` exists to turn them
///     into words. The scan is over every `Text` the screen laid out, so an id
///     that leaks through a new panel fails here rather than looking fine.
///   * **No `[` citation marker.** The defect `grounded_surfaces_test.dart` was
///     written for — `…moderate movement [recovery_readiness]` — reaching a card
///     verbatim. That file drives Today's model prose; this one drives the two
///     screens it never sees.
///   * **The charts paint at the size they were really laid out to.** Two charts
///     have already shipped at zero height in this repo because a test only
///     checked that the widget existed. Every assertion below replays the
///     recorded canvas at the layout's own size.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/insights/insights_screen.dart';
import 'package:healthee/features/insights/widgets/trends_section.dart';
import 'package:healthee/shared/charts/v02/v02_bar_chart.dart';
import 'package:healthee/shared/charts/v02/v02_linked_chart.dart';
import 'package:healthee/shared/charts/v02/v02_sparkline.dart';
import 'package:healthee/shared/v02/instruments/vo2max_rail.dart';

import '../shared/_chart_probe.dart';
import '../shared/_v02_chart_probe.dart';
import '_today_host.dart';

/// A wire id: lower-case words joined by underscores, and at least two of them.
final RegExp _rawId = RegExp(r'\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b');

/// Every string the screen actually laid out.
List<String> _saidOn(WidgetTester tester) => <String>[
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (text.data case final String said) said,
];

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  /// Pumps [screen] on a viewport tall enough that every section lays out.
  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view
      ..physicalSize = const Size(390, 14000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(todayHost(store, home: screen));
    await tester.pumpAndSettle();
  }

  for (final screen in <String, Widget>{
    'Activity': const ActivityScreen(),
    'Insights': const InsightsScreen(),
  }.entries) {
    group(screen.key, () {
      testWidgets('NO RAW IDENTIFIER REACHES THE SCREEN', (tester) async {
        await open(tester, screen.value);

        final offenders = <String>[
          for (final said in _saidOn(tester))
            for (final match in _rawId.allMatches(said)) match.group(0)!,
        ];
        expect(
          offenders,
          isEmpty,
          reason:
              '${screen.key} rendered wire ids where names belong: $offenders',
        );
      });

      testWidgets('NO `[` CITATION MARKER REACHES THE SCREEN', (tester) async {
        await open(tester, screen.value);

        final offenders = <String>[
          for (final said in _saidOn(tester))
            if (said.contains('[')) said,
        ];
        expect(
          offenders,
          isEmpty,
          reason: '${screen.key} rendered a raw marker: $offenders',
        );
      });

      testWidgets('NO REFERENCE LABEL SITS ON A CARD FACE', (tester) async {
        // The owner, twice: *"that reference pill can we remove those from
        // cards please info sheets are for that"*. The references are kept —
        // `MetricDetail.references` puts each one in the ⓘ — and this is the
        // other half of that move.
        await open(tester, screen.value);

        final offenders = <String>[
          for (final said in _saidOn(tester))
            if (said.contains('Reference ') || said.contains('Reference:'))
              said,
        ];
        expect(offenders, isEmpty, reason: 'still on a face: $offenders');
      });
    });
  }

  group('Activity’s charts paint, at the size the layout gave them', () {
    testWidgets('THE INTENSITY BARS DRAW ONE COLUMN PER MEASURED DAY', (
      tester,
    ) async {
      await open(tester, const ActivityScreen());
      // The second bar chart on the screen: the first is the step week, which
      // this contract carries no `steps_total` sparkline for.
      final chart = find.byType(V02BarChart).at(1);
      await reveal(tester, chart);

      expect(paintSize(tester, chart).height, greaterThan(0));
      final columns = columnsOf(paintedAt(tester, chart));
      expect(columns, isNotEmpty, reason: 'the bars drew nothing at all');
      for (final column in columns) {
        expect(column.$1.height, greaterThan(0));
        expect(column.$1.width, greaterThan(0));
      }
    });

    testWidgets('A SERIES THE SERVER DID NOT SEND DRAWS NOTHING, AT FULL HEIGHT', (
      tester,
    ) async {
      // `sparklines` carries eleven ids and `steps_total` is not one of them, so
      // the step week has nothing to draw. It must keep its slot and draw no
      // bars: a chart that collapses makes every card below it jump when the
      // data lands, and a chart that invents a flat line is the fabricated
      // series `chart_void.dart` exists to refuse.
      await open(tester, const ActivityScreen());
      final chart = find.byType(V02BarChart).first;
      await reveal(tester, chart);

      expect(tester.getSize(chart).height, 150);
      expect(
        find.descendant(of: chart, matching: find.byType(CustomPaint)),
        findsNothing,
      );
    });

    testWidgets('THE VO₂MAX RAIL PAINTS AT ITS LAID-OUT SIZE', (tester) async {
      await open(tester, const ActivityScreen());
      final rail = find.byType(Vo2maxRail);
      await reveal(tester, rail);

      final paint = find.descendant(
        of: rail,
        matching: find.byType(CustomPaint),
      );
      final widget = tester.widget<CustomPaint>(paint.first);
      final canvas = TestRecordingCanvas();
      final size = tester.getSize(paint.first);
      expect(size.height, greaterThan(0));
      expect(size.width, greaterThan(0));
      widget.painter!.paint(canvas, size);
      expect(canvas.invocations, isNotEmpty, reason: 'the rail drew nothing');
    });
  });

  group('Insights’ charts paint, at the size the layout gave them', () {
    testWidgets('EVERY TREND SPARKLINE IS 30 px TALL AND DRAWS A PATH', (
      tester,
    ) async {
      await open(tester, const InsightsScreen());
      final chart = find.byType(V02Sparkline).first;
      await reveal(tester, chart);

      expect(tester.getSize(chart).height, TrendPanel.sparklineHeight);
      // Body + trace. A chart that drew one of the two lost half its ink.
      expect(countOf(paintedAt(tester, chart), #drawPath), greaterThan(0));
    });

    testWidgets('THE LINKED CHART DRAWS BOTH PANES, AT REAL HEIGHT', (
      tester,
    ) async {
      await open(tester, const InsightsScreen());
      final chart = find.byType(V02LinkedChart);
      await reveal(tester, chart);

      expect(paintSize(tester, chart).height, greaterThan(100));
      // Two panes, each an area and a trace, so at least four paths.
      expect(
        countOf(paintedAt(tester, chart), #drawPath),
        greaterThanOrEqualTo(4),
        reason: 'a linked chart with one live pane is a different chart',
      );
    });
  });
}
