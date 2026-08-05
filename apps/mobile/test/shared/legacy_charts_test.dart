/// `HArea`, `HBars` and the tick gauge — **what they PAINT**.
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
/// ## What "verbatim" is being defended here
///
/// The bars' 1.12 headroom and their 2 px gap above fourteen bars; the gauge's
/// 44 ticks over 270° from 135°. A "tidier" value in any of them is a different
/// instrument.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';

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

  group('HBars', () {
    testWidgets('DRAWS ONE BAR PER POINT, EACH WITH REAL HEIGHT', (tester) async {
      await tester.pumpWidget(
        chartHost(
          const HBars(
            <double>[10, 20, 30, 40],
            color: Colors.indigo,
            progress: 1,
            height: 40,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(HBars)), const Size(hostWidth, 40));
      final rects = rectsOf(paintedBy(tester, find.byType(HBars)));
      expect(rects.length, 4);
      for (final rect in rects) {
        expect(rect.height, greaterThan(0), reason: 'a bar of no height');
        expect(rect.width, greaterThan(0));
      }
      // Legacy's 1.12 headroom: the tallest bar never touches the top.
      final tallest = rects.map((r) => r.height).reduce((a, b) => a > b ? a : b);
      expect(tallest, closeTo(40 / 1.12, 0.01));
    });

    testWidgets('the gap tightens above fourteen bars, as legacy does', (
      tester,
    ) async {
      Future<double> gapFor(int count) async {
        await tester.pumpWidget(
          chartHost(
            HBars(
              <double>[for (var i = 0; i < count; i++) 10 + i.toDouble()],
              color: Colors.indigo,
              progress: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rects = rectsOf(paintedBy(tester, find.byType(HBars)))
          ..sort((a, b) => a.left.compareTo(b.left));
        return rects[1].left - rects[0].right;
      }

      expect(await gapFor(7), closeTo(4, 0.01));
      expect(await gapFor(20), closeTo(2, 0.01));
    });

    testWidgets('at progress 0 every bar has zero height, and none is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        chartHost(
          const HBars(<double>[10, 20, 30], color: Colors.indigo, progress: 0),
        ),
      );
      await tester.pumpAndSettle();
      final rects = rectsOf(paintedBy(tester, find.byType(HBars)));
      expect(rects.length, 3);
      expect(rects.every((rect) => rect.height == 0), isTrue);
    });
  });
  group('HTickGauge', () {
    test('legacy’s geometry, to the constant', () {
      expect(HTickGauge.ticks, 44);
      expect(HTickGauge.startAngle, 135);
      expect(HTickGauge.sweep, 270);
    });

    testWidgets('DRAWS 45 TICKS AT ITS REAL DIAMETER', (tester) async {
      await tester.pumpWidget(
        chartHost(
          const HTickGauge(value: 72, color: Colors.indigo, progress: 1, size: 116),
        ),
      );
      await tester.pumpAndSettle();

      // The gauge sizes ITSELF; the 300 px host would stretch a SizedBox, so
      // the assertion is on the painted box rather than on the widget's slot.
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(HTickGauge),
            matching: find.byType(CustomPaint),
          ).first,
        ),
        const Size(116, 116),
      );
      final painted = paintedBy(tester, find.byType(HTickGauge));
      // `i <= ticks` in legacy, so the sweep is closed: 45 marks, not 44.
      expect(countOf(painted, #drawLine), 45);
    });

    testWidgets('the lit count follows the value, and the track stays visible', (
      tester,
    ) async {
      const hues = InstrumentHues.light();
      for (final (value, lit) in <(double, int)>[(0, 1), (50, 23), (100, 45)]) {
        await tester.pumpWidget(
          chartHost(
            HTickGauge(value: value, color: hues.sleep, progress: 1, size: 116),
          ),
        );
        await tester.pumpAndSettle();
        final painted = paintedBy(tester, find.byType(HTickGauge));
        final onColour = painted.where((call) {
          final args = call.invocation.positionalArguments;
          return call.invocation.memberName == #drawLine &&
              args.last is Paint &&
              (args.last as Paint).color.toARGB32() == hues.sleep.toARGB32();
        }).length;
        expect(onColour, lit, reason: 'value $value');
      }
    });
  });
}
