/// **The VO₂max rail and the route plot, measured.**
///
/// Two claims here are honesty claims rather than layout ones, and both are
/// mutation-tested:
///
///   * the shaded extent is **the supplied error magnitude, not a confidence
///     interval**, and the widget renders that sentence itself so no card can
///     show the band without it;
///   * the schematic ground carries **no family colour** — the recorded track is
///     the only thing on the plot that is a measurement, so it is the only thing
///     that gets the identity hue.
///
/// The rest is geometry: the extent is centred on the estimate, the reference
/// line sits at the reference value, the track keeps its aspect ratio, and the
/// elevation strip holds its height when there are no elevations to draw.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/shared/v02/instruments/route_plot.dart';
import 'package:healthee/shared/v02/instruments/vo2max_rail.dart';

import '../_chart_probe.dart';
import '_instrument_probe.dart';

Finder get _rail => find.byKey(Vo2maxRail.plotKey);
Finder get _route => find.byKey(RoutePlot.plotKey);

/// A 2:1 out-and-back, in lon/lat order.
const List<Offset> kTrack = <Offset>[
  Offset(0, 0),
  Offset(1, 0.5),
  Offset(2, 0),
  Offset(2, 1),
  Offset(0, 1),
];

void main() {
  group('the VO₂max rail', () {
    testWidgets('the extent is centred on the estimate and says what it is', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const Vo2maxRail(
            estimate: 43,
            medianForAge: 39.7,
            errorMagnitude: 2.95,
          ),
        ),
      );
      final painted = paintedAt(tester, _rail);
      final extents = rectsOf(painted);
      final dot = circlesOf(painted).single;

      expect(extents.length, 1);
      expect(extents.single.center.dx, closeTo(dot.at.dx, 0.5));
      // x = 5% + (v - 30) / 25 * 90% of 328: 45.95 - 40.05 spans 69.7 px.
      expect(extents.single.width, closeTo(69.7, 1));
      expect(dot.radius, 6);
      expect(dot.at.dx, closeTo(169.9, 1));

      final reference = linesOf(
        painted,
      ).where((line) => line.from.dx == line.to.dx).toList();
      expect(reference, isNotEmpty, reason: 'the median is drawn');
      for (final dash in reference) {
        expect(dash.from.dx, closeTo(130.9, 1));
      }
    });

    testWidgets('IT IS LABELLED AN ERROR MAGNITUDE, NOT A CONFIDENCE INTERVAL', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const Vo2maxRail(
            estimate: 43,
            medianForAge: 39.7,
            errorMagnitude: 2.95,
          ),
        ),
      );
      expect(find.textContaining('error magnitude'), findsOneWidget);
      expect(find.textContaining('not a confidence interval'), findsOneWidget);
      expect(find.textContaining('±2.95'), findsOneWidget);

      final note = tester.getRect(find.textContaining('error magnitude'));
      expect(note.height, greaterThan(0), reason: 'and it is on screen');
      expect(
        note.top,
        greaterThanOrEqualTo(tester.getRect(_rail).bottom),
        reason: 'the sentence sits under the extent it qualifies',
      );
    });

    testWidgets('NO ERROR MAGNITUDE DRAWS NO EXTENT, and keeps the height', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const Vo2maxRail(
            estimate: 43,
            medianForAge: 39.7,
            errorMagnitude: null,
          ),
        ),
      );
      expect(rectsOf(paintedAt(tester, _rail)), isEmpty);
      expect(circlesOf(paintedAt(tester, _rail)).length, 1);
      expect(tester.getSize(_rail).height, Vo2maxRail.railHeight);
      expect(find.textContaining('No error magnitude supplied'), findsOneWidget);
    });

    testWidgets('the window widens rather than clipping a high estimate', (
      tester,
    ) async {
      const rail = Vo2maxRail(
        estimate: 62,
        medianForAge: 39.7,
        errorMagnitude: 2.95,
      );
      expect(rail.window.high, greaterThanOrEqualTo(65));
      await tester.pumpWidget(instrumentHost(rail));
      final dot = circlesOf(paintedAt(tester, _rail)).single;
      expect(dot.at.dx, lessThan(tester.getSize(_rail).width));
      expect(dot.at.dx, greaterThan(0));
    });
  });

  group('the route plot', () {
    testWidgets('the track keeps its aspect ratio', (tester) async {
      await tester.pumpWidget(
        instrumentHost(const RoutePlot(points: kTrack)),
      );
      final stroked = pathsOf(
        paintedAt(tester, _route),
      ).where((drawn) => drawn.style == PaintingStyle.stroke).toList();

      expect(stroked, isNotEmpty);
      final bounds = stroked.first.path.getBounds();
      expect(
        bounds.width / bounds.height,
        closeTo(2, 0.02),
        reason: 'a stretched route is a different route',
      );
    });

    testWidgets('ONE FIX DRAWS NO TRACK, and no family colour appears', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const RoutePlot(points: <Offset>[Offset(0, 0)]),
        ),
      );
      expect(
        coloursOf(paintedAt(tester, _route)),
        isNot(contains(const InstrumentHues.dark().fitness.toARGB32())),
        reason: 'the schematic ground carries no identity colour',
      );
    });

    testWidgets('NO ELEVATIONS PAINTS NOTHING IN THE STRIP, and keeps it', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(const RoutePlot(points: kTrack)),
      );
      final painted = paintedAt(tester, _route);
      for (final rect in <Rect>[
        ...markRectsOf(painted),
        ...glyphRectsOf(painted),
      ]) {
        expect(
          rect.bottom,
          lessThanOrEqualTo(kRouteMapHeight + 0.5),
          reason: 'a flat line at the mean would be a fabricated profile',
        );
      }
      expect(
        tester.getSize(_route).height,
        kRouteMapHeight + kRouteElevationHeight,
      );
    });

    testWidgets('ELEVATIONS THAT DO NOT MATCH THE FIXES ARE NOT DRAWN', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const RoutePlot(points: kTrack, elevations: <double>[894, 900]),
        ),
      );
      for (final rect in markRectsOf(paintedAt(tester, _route))) {
        expect(rect.bottom, lessThanOrEqualTo(kRouteMapHeight + 0.5));
      }
    });

    testWidgets('elevations that match are drawn in the strip', (tester) async {
      await tester.pumpWidget(
        instrumentHost(
          const RoutePlot(
            points: kTrack,
            elevations: <double>[894, 896, 900, 898, 895],
          ),
        ),
      );
      final painted = paintedAt(tester, _route);
      expect(
        markRectsOf(painted).where(
          (rect) => rect.bottom > kRouteMapHeight,
        ),
        isNotEmpty,
      );
      expect(find.byType(RoutePlot), findsOneWidget);
      expect(
        glyphRectsOf(painted).where((rect) => rect.top > kRouteMapHeight).length,
        2,
        reason: 'the profile labels its own low and high',
      );
    });
  });
}
