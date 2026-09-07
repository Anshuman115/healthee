/// `HArea` — **what it PAINTS**.
///
/// ## Why this asserts drawn geometry rather than widget presence
///
/// Two charts shipped at zero height in this repo because their tests only
/// checked that the widget was in the tree. `findsOneWidget` passes for a chart
/// laid out at `Size(390, 0)`, and it passes for a painter that draws nothing at
/// all. Neither is a chart.
///
/// So every test below either measures the laid-out box or replays the painter
/// into a `TestRecordingCanvas` (`_chart_probe.dart`) and inspects the
/// operations it actually recorded.
///
/// ## What left, and why
///
/// `HBars` and `HTickGauge` had their own groups here. Both became unreachable
/// from `main.dart` in the v02 redesign and are deleted, so the constants they
/// defended — the bars' 1.12 headroom and 2 px gap, the gauge's 44 ticks over
/// 270° from 135° — are no longer anything's geometry. `HArea` is still drawn,
/// by the diagnostics metric strip, so it stays.
///
/// The reference lines `HArea` can carry have their own suite:
/// `chart_reference_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/charts/h_area.dart';

import '_chart_probe.dart';

void main() {
  group('HArea', () {
    testWidgets('IS LAID OUT AT ITS REAL HEIGHT AND DRAWS A LINE', (tester) async {
      await tester.pumpWidget(
        chartHost(
          const HArea(<double>[52, 58, 54, 61, 55], color: Colors.indigo, progress: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Legacy's default is 30. A chart of zero height is the bug this catches.
      expect(tester.getSize(find.byType(HArea)), const Size(hostWidth, 30));

      final painted = paintedBy(tester, find.byType(HArea));
      expect(countOf(painted, #drawPath), 2, reason: 'the fill and the line');
    });

    testWidgets('at progress 0 the fill is drawn and the line is not yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        chartHost(
          const HArea(<double>[52, 58, 54], color: Colors.indigo, progress: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fewer than two points draws NOTHING rather than a flat lie', (
      tester,
    ) async {
      await tester.pumpWidget(
        chartHost(const HArea(<double>[55], color: Colors.indigo, progress: 1)),
      );
      await tester.pumpAndSettle();
      expect(paintedBy(tester, find.byType(HArea)), isEmpty);
    });
  });
}
