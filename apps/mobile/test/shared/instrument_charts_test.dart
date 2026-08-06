/// The three charts ported for the legacy Today: the gauge, the meter, the spark.
///
/// Painters are hard to assert pixel by pixel and mostly not worth it. What IS
/// worth asserting is the handful of behaviours that would be silently wrong:
///
///   * **The gauge's geometry is legacy's**, to the constant. A "tidier" 40 ticks
///     over 280° is a different instrument.
///   * **A meter with no value draws no fill.** A zero-width bar and a score of
///     zero look identical and mean opposite things, which is the whole reason
///     `HMeter.fraction` is nullable.
///   * **A sparkline of one point draws nothing.** One reading has no shape, and
///     a flat line through it asserts a trend nobody measured.
///
/// Each also has to survive `progress` at both ends, because `RevealOnce` hands
/// them 0 on the first frame and 1 on every frame after a scroll-back.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/charts/h_meter.dart';
import 'package:healthee/shared/charts/h_spark.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';

/// One chart in the light theme, sized so a painter has room.
Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: SizedBox(width: 200, child: child))),
);

void main() {
  group('the tick gauge', () {
    test("keeps legacy's geometry to the constant", () {
      // design_reference/project/hh/ui.jsx — ticks 44, startA 135, sweep 270.
      expect(HTickGauge.ticks, 44);
      expect(HTickGauge.startAngle, 135);
      expect(HTickGauge.sweep, 270);
    });

    testWidgets('draws its centre content and survives both ends of a reveal', (
      tester,
    ) async {
      for (final progress in <double>[0, 0.5, 1]) {
        await tester.pumpWidget(
          host(
            HTickGauge(
              value: 72,
              color: Colors.indigo,
              progress: progress,
              child: const Text('72'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('72'), findsOneWidget);
      }
    });

    testWidgets('a value past the top of the scale does not throw', (tester) async {
      // A server that sent 140 would otherwise light ticks that do not exist.
      await tester.pumpWidget(
        host(const HTickGauge(value: 140, color: Colors.indigo, progress: 1)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the meter', () {
    testWidgets('A MISSING SUB-SCORE DRAWS NO FILL AT ALL', (tester) async {
      await tester.pumpWidget(
        host(const HMeter(fraction: null, color: Colors.indigo, progress: 1)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(FractionallySizedBox),
        findsNothing,
        reason:
            'a zero-width bar and a score of zero look identical and mean '
            'opposite things',
      );
    });

    testWidgets('a real sub-score fills in proportion', (tester) async {
      await tester.pumpWidget(
        host(const HMeter(fraction: 0.8, color: Colors.indigo, progress: 1)),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.8, 1e-9));
    });

    testWidgets('the reveal scales the fill, not the track', (tester) async {
      await tester.pumpWidget(
        host(const HMeter(fraction: 0.8, color: Colors.indigo, progress: 0.5)),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.4, 1e-9));
    });
  });

  group('a reveal scales a colour, it does not overrule it', () {
    test('AN ALREADY-TRANSLUCENT TOKEN STAYS TRANSLUCENT AT FULL PROGRESS', () {
      // The bug `revealed` was extracted for: `withValues(alpha: progress)`
      // REPLACES the alpha, which turned the hypnogram's `awake` band — the 10%
      // hairline, chosen so the absence of sleep is the quietest thing on the
      // chart — into the loudest thing on it.
      const hairline = Color.fromRGBO(255, 255, 255, 0.10);
      expect(revealed(hairline, 1).a, closeTo(0.10, 0.005));
      expect(revealed(hairline, 0.5).a, closeTo(0.05, 0.005));
    });

    test('an opaque colour still fades in from nothing', () {
      expect(revealed(const Color(0xFF8F87FF), 0).a, 0);
      expect(revealed(const Color(0xFF8F87FF), 1).a, 1);
    });
  });

  group('the sparkline', () {
    testWidgets('ONE POINT IS NOT A TREND, AND DRAWS NONE', (tester) async {
      await tester.pumpWidget(
        host(const HSpark(<double>[55], color: Colors.indigo, progress: 1)),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(HSpark),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a flat series does not divide by zero', (tester) async {
      await tester.pumpWidget(
        host(
          const HSpark(<double>[55, 55, 55], color: Colors.indigo, progress: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives both ends of a reveal', (tester) async {
      for (final progress in <double>[0, 1]) {
        await tester.pumpWidget(
          host(
            HSpark(
              const <double>[52, 58, 54, 61, 55],
              color: Colors.indigo,
              progress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
