/// The three GPS screens on the v02 frame — and what each of them refuses.
///
/// They were the last legacy `Scaffold`/`AppBar` screens in the app. Porting the
/// frame is the visible half; the half worth a suite is what the port made
/// possible to get wrong:
///
///   * the schematic map draws the **owner's** track and nothing else. The
///     prototype paints park, water and road shapes from fixture path data, and
///     under a real recording those would be a river and two roads that were not
///     there, at the top of a screen about where somebody went;
///   * a summary field the server did not send leaves **no slot**, rather than a
///     dash that reads as a measurement that came back empty;
///   * a session VO₂max is either printed **with the instrument that produced
///     it** or withheld with its reason, which is the prototype's own notice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/gps/recorded_route.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/features/gps/gps_live_summary.dart';
import 'package:healthee/features/gps/route_detail_sections.dart';
import 'package:healthee/features/gps/route_map.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/reveal_once.dart';

/// A short track that climbs and turns, so the fit has a span on both axes.
List<RoutePoint> _track({int fixes = 12, bool elevations = true, int hr = 0}) {
  final DateTime start = DateTime.utc(2026, 7, 31, 7);
  return <RoutePoint>[
    for (var i = 0; i < fixes; i++)
      RoutePoint(
        at: start.add(Duration(seconds: i * 30)),
        latitude: 52.0 + i * 0.001,
        longitude: 13.0 + (i.isEven ? i : fixes - i) * 0.0005,
        elevationM: elevations ? 894 + (i % 5).toDouble() : null,
        hr: i < hr ? 140 : null,
      ),
  ];
}

RecordedRoute _route({
  List<RoutePoint>? points,
  double? distanceKm = 4.2,
  int? durationS = 1800,
  double? avgPaceMinKm = 7.1,
  double? vo2max,
  String? method,
  double? r2,
  double? gain = 21,
  double? loss = 18,
}) => RecordedRoute(
  id: 'track-1',
  start: DateTime.utc(2026, 7, 31, 7),
  points: points ?? _track(),
  distanceKm: distanceKm,
  durationS: durationS,
  avgPaceMinKm: avgPaceMinKm,
  elevationGainM: gain,
  elevationLossM: loss,
  vo2max: vo2max,
  vo2Method: method,
  r2: r2,
);

/// A window tall enough to build the whole page.
///
/// The sections live in a `ListView`, so anything below the fold is not built
/// at all and `findsNothing` would be true of a section that is present and
/// merely scrolled past — a green assertion about a widget nobody looked for.
/// `out_of_shell_navigation_test.dart` records the same trap.
void _tallViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(420, 3200)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The sections under a theme, in a scroll, the way the screen builds them.
Widget _host(RecordedRoute route) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: ListView(
          children: routeDetailSections(context, route, RevealRegistry()),
        ),
      ),
    ),
  ),
);

void main() {
  group('THE MAP DRAWS THE TRACK AND NOTHING IT DID NOT MEASURE', () {
    testWidgets('a track with two or more fixes is drawn', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: RouteMap(points: _track())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text(RouteMap.caption), findsOneWidget);
    });

    testWidgets('THE CAPTION SAYS THERE IS NO BASEMAP AND NO SCALE', (
      tester,
    ) async {
      // The drawing looks enough like a map to be read as one. It has neither
      // a basemap under it nor a scale on it, and saying so is the point of
      // drawing a schematic rather than tiles.
      expect(RouteMap.caption.toLowerCase(), contains('no basemap'));
      expect(RouteMap.caption.toLowerCase(), contains('no scale'));
    });

    testWidgets('A SINGLE FIX DRAWS NOTHING AT ALL', (tester) async {
      // One point is a dot nobody can read a route off. A box with a dot in it
      // would be a picture of a journey that was never recorded.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RouteMap(points: _track(fixes: 1)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(RouteMap.caption), findsNothing);
    });
  });

  group('the route detail, section by section', () {
    testWidgets('the three summary figures and the fix count', (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(_route()));
      await tester.pumpAndSettle();

      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Avg. pace'), findsOneWidget);
      expect(find.textContaining('Phone GPS · 12 fixes'), findsOneWidget);
    });

    testWidgets('A FIGURE THE SERVER DID NOT SEND LEAVES NO SLOT', (
      tester,
    ) async {
      // Not a dash. A dash in a row of three reads as a measurement that came
      // back empty, which is a different thing from one that was never sent.
      await tester.pumpWidget(_host(_route(avgPaceMinKm: null)));
      await tester.pumpAndSettle();

      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Avg. pace'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('the elevation profile is drawn, with gain and loss', (
      tester,
    ) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(_route()));
      await tester.pumpAndSettle();

      expect(find.text(kElevationHeading), findsOneWidget);
      // The edge captions are painted on the canvas rather than laid out as
      // `Text`, so the chart itself is what carries them and is what is asked.
      final V02LineChart chart = tester.widget<V02LineChart>(
        find.byType(V02LineChart),
      );
      expect(chart.captions, <String>['Start', 'Finish']);
      expect(chart.unit, 'm');
      expect(find.text('Elevation gain'), findsOneWidget);
      expect(find.text('Elevation loss'), findsOneWidget);
    });

    testWidgets('A TRACK WITH NO ALTITUDES GETS NO ELEVATION SECTION', (
      tester,
    ) async {
      // Rather than a flat line at zero, which is a reading of level ground
      // that no barometer took.
      await tester.pumpWidget(
        _host(_route(points: _track(elevations: false))),
      );
      await tester.pumpAndSettle();

      expect(find.text(kElevationHeading), findsNothing);
    });
  });

  group('THE SESSION VO₂MAX IS NAMED OR WITHHELD, NEVER BARE', () {
    testWidgets('no estimate keeps the prototype’s own stated refusal', (
      tester,
    ) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(_route(points: _track(hr: 1))));
      await tester.pumpAndSettle();

      expect(find.text(kNoFitnessTitle), findsOneWidget);
      expect(
        find.textContaining('one matched heart-rate point'),
        findsOneWidget,
        reason: 'the reason is about THIS track, not a general sentence',
      );
    });

    testWidgets('an estimate is printed WITH the method that produced it', (
      tester,
    ) async {
      // `derive/vo2max_tier.py` names its method on the wire precisely so a
      // screen never has to guess which tier a number came from. A bare number
      // is the shape the #108 failure shipped in.
      _tallViewport(tester);
      await tester.pumpWidget(
        _host(_route(vo2max: 43.04, method: 'gps_graded', r2: 0.91)),
      );
      await tester.pumpAndSettle();

      expect(find.text('43.0'), findsOneWidget);
      expect(find.textContaining('gps_graded'), findsOneWidget);
      expect(find.text(kNoFitnessTitle), findsNothing);
    });

    testWidgets('AN UNNAMED METHOD SAYS SO RATHER THAN GOING QUIET', (
      tester,
    ) async {
      _tallViewport(tester);
      _tallViewport(tester);
      await tester.pumpWidget(_host(_route(vo2max: 43.04)));
      await tester.pumpAndSettle();

      expect(find.textContaining('not named by the server'), findsOneWidget);
    });

    test('the fit note says what a fit is and is not', () {
      expect(fitNote(0.91), contains('0.91'));
      expect(fitNote(0.91), contains('does not establish'));
    });
  });

  group('the recorder’s own reading', () {
    test('the timer wears hours only once there are any', () {
      expect(elapsedLabel(const Duration(seconds: 0)), '00:00');
      expect(elapsedLabel(const Duration(minutes: 9, seconds: 30)), '09:30');
      expect(
        elapsedLabel(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('the two lines are about the app, never about the owner', () {
      expect(recordingHeadline(recording: true), 'Recording');
      expect(recordingHeadline(recording: false), 'Ready when you are');
      expect(recordingFootnote(recording: true), contains('approximate'));
    });
  });
}
