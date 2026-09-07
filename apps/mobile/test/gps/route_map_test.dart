/// The route drawing: the track, the basemap under it, and what it refuses.
///
/// Split out of `route_screens_test.dart` when that file passed the 400-line
/// gate. What is here is one subject — the picture on the two screens that show
/// a track — and three claims about it that would each fail silently:
///
///   * the drawing shows the **owner's** track and, under it, a REAL basemap or
///     nothing. The prototype paints park, water and road shapes from fixture
///     path data, and under a real recording those would be a river and two
///     roads that were not there, at the top of a screen about where somebody
///     went. Real tiles are the opposite decision for the same reason;
///   * a missing basemap **never blanks the route**. Offline is the day the
///     owner most needs to see what they recorded, and a fallback that withheld
///     the track would look exactly like a screen that had not loaded;
///   * the caption says which of the two pictures this is, because "on a map"
///     and "not on a map" are different claims about the same line.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/data/map/basemap_source.dart';
import 'package:healthee/data/map/basemap_style.dart';
import 'package:healthee/data/map/basemap_view.dart';
import 'package:healthee/features/gps/route_map.dart';
import 'package:healthee/features/gps/route_painter.dart';

import '../shared/instruments/_instrument_probe.dart';

/// The style a server that HAS a basemap sends.
const BasemapStyle kStyle = BasemapStyle(
  attribution: '© OpenStreetMap contributors',
  minZoom: 1,
  maxZoom: 17,
  tilePath: '/api/map/tiles/{z}/{x}/{y}',
);

/// A tile source that answers every request the same way.
class _FixedTiles implements BasemapTiles {
  _FixedTiles(this.image);

  final ui.Image? image;
  final List<MapTileRef> asked = <MapTileRef>[];

  @override
  Future<ui.Image?> tile(BasemapStyle style, MapTileRef ref) async {
    asked.add(ref);
    return image;
  }
}

/// A 256-square of one colour — a stand-in for a raster tile.
ui.Image _tileImage() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 256, 256),
    Paint()..color = const Color(0xFF3C6E47),
  );
  return recorder.endRecording().toImageSync(256, 256);
}

/// `RouteMap` under a style and a tile source, at a phone's width.
Widget _mapHost(
  List<RoutePoint> points, {
  BasemapStyle? style,
  BasemapTiles? tiles,
}) => ProviderScope(
  overrides: [
    basemapStyleProvider.overrideWith((ref) async => style),
    if (tiles != null) basemapTilesProvider.overrideWithValue(tiles),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SizedBox(width: 340, child: RouteMap(points: points)),
    ),
  ),
);

/// A short track that climbs and turns, so the fit has a span on both axes.
List<RoutePoint> _track({int fixes = 12}) {
  final DateTime start = DateTime.utc(2026, 7, 31, 7);
  return <RoutePoint>[
    for (var i = 0; i < fixes; i++)
      RoutePoint(
        at: start.add(Duration(seconds: i * 30)),
        latitude: 52.0 + i * 0.001,
        longitude: 13.0 + (i.isEven ? i : fixes - i) * 0.0005,
      ),
  ];
}

void main() {
  group('THE MAP DRAWS THE TRACK AND NOTHING IT DID NOT MEASURE', () {
    testWidgets('a track with two or more fixes is drawn', (tester) async {
      await tester.pumpWidget(_mapHost(_track()));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text(RouteMap.plainCaption), findsOneWidget);
    });

    testWidgets('A SINGLE FIX DRAWS NOTHING AT ALL', (tester) async {
      // One point is a dot nobody can read a route off. A box with a dot in it
      // would be a picture of a journey that was never recorded.
      await tester.pumpWidget(_mapHost(_track(fixes: 1)));
      await tester.pumpAndSettle();

      expect(find.text(RouteMap.plainCaption), findsNothing);
      expect(find.text(RouteMap.mappedCaption), findsNothing);
    });
  });

  group('THE BASEMAP IS CONTEXT; THE TRACK IS THE MEASUREMENT', () {
    testWidgets('tiles are drawn UNDER the track, and credited on screen', (
      tester,
    ) async {
      final _FixedTiles tiles = _FixedTiles(_tileImage());

      await tester.pumpWidget(
        _mapHost(_track(), style: kStyle, tiles: tiles),
      );
      await tester.pumpAndSettle();

      expect(tiles.asked, isNotEmpty, reason: 'tiles were requested');
      final painted = paintedAt(tester, find.byKey(RouteMap.canvasKey));
      final int images = painted
          .where((call) => call.invocation.memberName == #drawImageRect)
          .length;
      final stroked = pathsOf(
        painted,
      ).where((drawn) => drawn.style == PaintingStyle.stroke);
      expect(images, greaterThan(0), reason: 'the basemap is painted');
      expect(stroked, isNotEmpty, reason: 'the track is painted over it');
      // Attribution is mandatory and ON SCREEN — not in a settings page, and
      // never absent while a tile is drawn.
      expect(find.text(kStyle.attribution), findsOneWidget);
      expect(find.text(RouteMap.mappedCaption), findsOneWidget);
    });

    testWidgets('A CACHE MISS FALLS BACK TO THE PLAIN GROUND, NOT TO NOTHING', (
      tester,
    ) async {
      // Offline, or a tile the server could not fill. The route is what the
      // owner recorded; the basemap is decoration, and decoration that fails
      // may not take the measurement off the screen.
      final _FixedTiles nothing = _FixedTiles(null);

      await tester.pumpWidget(
        _mapHost(_track(), style: kStyle, tiles: nothing),
      );
      await tester.pumpAndSettle();

      final painted = paintedAt(tester, find.byKey(RouteMap.canvasKey));
      expect(
        painted.where((call) => call.invocation.memberName == #drawImageRect),
        isEmpty,
      );
      expect(
        pathsOf(painted).where((drawn) => drawn.style == PaintingStyle.stroke),
        isNotEmpty,
        reason: 'the track is drawn on the plain ground',
      );
      expect(find.text(RouteMap.plainCaption), findsOneWidget);
      expect(
        find.text(kStyle.attribution),
        findsNothing,
        reason: 'nothing was drawn, so there is nobody to credit',
      );
    });

    testWidgets('NO STYLE AT ALL STILL DRAWS THE TRACK', (tester) async {
      // A deployment with no basemap configured, or a server we cannot reach.
      final _FixedTiles tiles = _FixedTiles(_tileImage());

      await tester.pumpWidget(_mapHost(_track(), tiles: tiles));
      await tester.pumpAndSettle();

      expect(tiles.asked, isEmpty, reason: 'no style, nothing to ask for');
      expect(
        pathsOf(
          paintedAt(tester, find.byKey(RouteMap.canvasKey)),
        ).where((drawn) => drawn.style == PaintingStyle.stroke),
        isNotEmpty,
      );
      expect(find.text(RouteMap.plainCaption), findsOneWidget);
    });

    testWidgets('A GROWING TRACK DOES NOT RE-FETCH WHAT IT ALREADY HAS', (
      tester,
    ) async {
      // Every accepted fix grows the bounding box, so the recorder produces a
      // NEW view about once a second. A tile reference carries its own zoom and
      // is therefore still correct after the view pans — clearing on every view
      // would blank the basemap between fixes and re-ask for the same squares
      // for as long as the owner keeps running.
      final _FixedTiles tiles = _FixedTiles(_tileImage());
      await tester.pumpWidget(
        _mapHost(_track(fixes: 8), style: kStyle, tiles: tiles),
      );
      await tester.pumpAndSettle();
      expect(tiles.asked, isNotEmpty);

      await tester.pumpWidget(
        _mapHost(_track(fixes: 9), style: kStyle, tiles: tiles),
      );
      await tester.pumpAndSettle();

      expect(
        tiles.asked.toSet().length,
        tiles.asked.length,
        reason: 'no square was fetched twice',
      );
      expect(
        find.text(kStyle.attribution),
        findsOneWidget,
        reason: 'the basemap did not blank between one fix and the next',
      );
    });

    test('THE TRACK IS DRAWN WHATEVER THE TILES DID', () {
      // The guard `paint` actually consults. Requiring a tile here is the
      // mutation `test/mutations.sh` proves is caught.
      final view = BasemapView.fit(_track(), const Size(340, 240))!;
      final painter = RoutePainter(
        view: view,
        points: _track(),
        tiles: const <MapTileRef, ui.Image>{},
        land: const Color(0xFFE7F2E7),
        track: const Color(0xFFBF472E),
        underlay: const Color(0xFFFFFFFF),
      );

      expect(painter.drawsTrack, isTrue);
    });

    test('the two captions make different claims about the same line', () {
      // With a basemap the picture has scale and streets, so the caption names
      // the instrument instead: these are phone fixes, drawn where they fell.
      expect(RouteMap.plainCaption.toLowerCase(), contains('no basemap'));
      expect(RouteMap.plainCaption.toLowerCase(), contains('no scale'));
      expect(RouteMap.mappedCaption.toLowerCase(), contains('phone gps'));
      expect(RouteMap.mappedCaption.toLowerCase(), contains('where it fell'));
    });
  });

  group('THE DRAWING IS THINNED; THE TRACK IS NOT', () {
    test('a long track is sampled down and keeps BOTH ENDS', () {
      // The start ring and the finish dot mark the first and last fixes, so a
      // thinning that dropped either would move a marker onto a fix that is not
      // where the owner started or stopped. The saved track is untouched.
      final List<RoutePoint> long = _track(fixes: 9001);

      final List<RoutePoint> drawn = RouteMap.displayPoints(long);

      expect(drawn, hasLength(RouteMap.maxDrawnPoints));
      expect(drawn.first.at, long.first.at);
      expect(drawn.last.at, long.last.at);
      expect(long, hasLength(9001), reason: 'the input is not mutated');
    });

    test('a short track is drawn whole', () {
      final List<RoutePoint> short = _track(fixes: 12);

      expect(RouteMap.displayPoints(short), same(short));
    });
  });

}
