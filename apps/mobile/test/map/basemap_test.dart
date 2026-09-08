/// The projection, the tile grid, and the contract the server sends.
///
/// The geometry here is the difference between a map and a picture that looks
/// like one. A track fitted in any projection but the tiles' own sits *beside*
/// the roads it ran on, and nothing in a screenshot says so — the line is still
/// the right shape, just in the wrong place. So the arithmetic is pinned against
/// values that can be derived by hand from the Web Mercator definition rather
/// than read back off a canvas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/data/map/basemap_style.dart';
import 'package:healthee/data/map/basemap_view.dart';

const Size _box = Size(340, 240);

RoutePoint _at(double latitude, double longitude) => RoutePoint(
  at: DateTime.utc(2026, 7, 31, 7),
  latitude: latitude,
  longitude: longitude,
);

/// A short track that spans both axes.
List<RoutePoint> _track() => <RoutePoint>[
  for (var i = 0; i < 12; i++)
    _at(52.0 + i * 0.001, 13.0 + (i.isEven ? i : 12 - i) * 0.0005),
];

void main() {
  group('Web Mercator, because the tiles are', () {
    test('the origin of the grid is the north-west corner of the world', () {
      // Zoom 0 is one 256-pixel tile holding the whole world: longitude 0 sits
      // at its centre, and the equator with it.
      const view = BasemapView(
        zoom: 0,
        scale: 1,
        originX: 0,
        originY: 0,
        size: Size(256, 256),
      );

      expect(view.plot(0, -180).dx, closeTo(0, 0.001));
      expect(view.plot(0, 180).dx, closeTo(256, 0.001));
      expect(view.plot(0, 0), const Offset(128, 128));
    });

    test('LATITUDE IS NOT LINEAR, WHICH IS THE WHOLE POINT', () {
      // Equirectangular would put 60 degrees north two thirds of the way from
      // the equator to the pole. Mercator puts it much further, and the tiles
      // are cut on Mercator — a linear fit is off by tens of metres at our
      // latitudes and by kilometres at the scale of a country.
      const view = BasemapView(
        zoom: 0,
        scale: 1,
        originX: 0,
        originY: 0,
        size: Size(256, 256),
      );

      final double sixty = view.plot(60, 0).dy;
      // 0.5 - ln(tan(60) + sec(60)) / 2pi = 0.29039 of the way down the world.
      expect(sixty, closeTo(74.342, 0.01), reason: 'ln(tan+sec) at 60 degrees');
      expect(
        sixty,
        isNot(closeTo(128 - 128 * 60 / 90, 1)),
        reason: 'a linear latitude would land at 42.7',
      );
    });

    test('A KNOWN PLACE LANDS ON ITS KNOWN TILE', () {
      // The slippy-map formula everybody's tile server is indexed by:
      //   x = (lng + 180) / 360 * 2^z
      //   y = (1 - ln(tan(lat) + sec(lat)) / pi) / 2 * 2^z
      // Berlin (52.0 N, 13.0 E) at zoom 14 is tile 8783/5411. If this drifts,
      // every track in the app is drawn beside the streets it ran on.
      final view = BasemapView.fit(
        <RoutePoint>[_at(52, 13), _at(52, 13)],
        _box,
        maxZoom: 14,
      )!;
      final Offset centre = view.plot(52, 13);
      final MapTileRef under = view
          .tiles()
          .firstWhere((ref) => view.rectFor(ref).contains(centre));

      expect(under.z, 14);
      expect(under.x, 8783);
      expect(under.y, 5411);
    });

    test('the poles are clamped to the grid the basemap is cut at', () {
      const view = BasemapView(
        zoom: 0,
        scale: 1,
        originX: 0,
        originY: 0,
        size: Size(256, 256),
      );

      // Mercator y is unbounded at 90 degrees; every XYZ basemap stops at
      // 85.0511, and so does this, rather than producing an infinity that
      // propagates into a blank canvas.
      expect(view.plot(90, 0).dy, closeTo(0, 0.01));
      expect(view.plot(-90, 0).dy, closeTo(256, 0.01));
      expect(view.plot(89.9, 0).dy.isFinite, isTrue);
    });
  });

  group('fitting a track into a box', () {
    test('the track is centred and inset, with one scale on both axes', () {
      final view = BasemapView.fit(_track(), _box)!;

      final List<Offset> plotted = <Offset>[
        for (final point in _track()) view.plot(point.latitude, point.longitude),
      ];
      for (final Offset point in plotted) {
        expect(point.dx, inInclusiveRange(-0.5, _box.width + 0.5));
        expect(point.dy, inInclusiveRange(-0.5, _box.height + 0.5));
      }
      // Centred: the margins on opposite sides match.
      final double left = plotted.map((p) => p.dx).reduce(math.min);
      final double right = plotted.map((p) => p.dx).reduce(math.max);
      expect(left, closeTo(_box.width - right, 0.01));
    });

    test('AN EMPTY TRACK OR A BOX WITH NO AREA FITS NOTHING', () {
      expect(BasemapView.fit(const <RoutePoint>[], _box), isNull);
      expect(BasemapView.fit(_track(), Size.zero), isNull);
    });

    test('a track that never moved is drawn at the deepest zoom offered', () {
      final view = BasemapView.fit(
        <RoutePoint>[_at(52, 13), _at(52, 13)],
        _box,
        maxZoom: 15,
      )!;

      expect(view.zoom, 15, reason: 'one place, seen as closely as we may');
      expect(view.plot(52, 13).dx, closeTo(_box.width / 2, 0.01));
    });

    test('THE ZOOM STAYS INSIDE THE RANGE THE SERVER SERVES', () {
      // Asking for a tile the server has already refused is a round trip that
      // can only 404 — and it is the request the server was told not to forward.
      final deep = BasemapView.fit(_track(), _box, minZoom: 2, maxZoom: 9)!;
      final shallow = BasemapView.fit(
        <RoutePoint>[_at(-40, -70), _at(60, 100)],
        _box,
        minZoom: 6,
        maxZoom: 17,
      )!;

      expect(deep.zoom, inInclusiveRange(2, 9));
      expect(shallow.zoom, inInclusiveRange(6, 17));
      for (final MapTileRef ref in <MapTileRef>[
        ...deep.tiles(),
        ...shallow.tiles(),
      ]) {
        expect(ref.x, inInclusiveRange(0, (1 << ref.z) - 1));
        expect(ref.y, inInclusiveRange(0, (1 << ref.z) - 1));
      }
    });

    test('THE TILE COUNT IS BOUNDED', () {
      // Standards section 1: unbounded data is windowed. A tall box at a deep
      // zoom would otherwise ask our server — and its provider — for hundreds
      // of squares to fill one screen.
      for (final Size box in <Size>[
        _box,
        const Size(340, 3000),
        const Size(3000, 240),
      ]) {
        final view = BasemapView.fit(_track(), box)!;
        expect(view.tiles().length, lessThanOrEqualTo(BasemapView.maxTiles));
      }
    });

    test('every drawn tile covers part of the box', () {
      final view = BasemapView.fit(_track(), _box)!;
      final Rect canvas = Offset.zero & _box;

      for (final MapTileRef ref in view.tiles()) {
        expect(view.rectFor(ref).overlaps(canvas), isTrue);
      }
    });

    test('the tiles tile: neighbours abut exactly', () {
      final view = BasemapView.fit(_track(), _box)!;
      final List<MapTileRef> tiles = view.tiles();
      final MapTileRef first = tiles.first;

      final Rect a = view.rectFor(first);
      final Rect b = view.rectFor(MapTileRef(first.z, first.x + 1, first.y));
      expect(b.left, closeTo(a.right, 0.001));
      expect(a.width, closeTo(a.height, 0.001), reason: 'tiles are square');
    });
  });

  group('the style the server sends', () {
    test('a tile path is expanded once per placeholder', () {
      const style = BasemapStyle(
        attribution: '© OpenStreetMap contributors',
        minZoom: 1,
        maxZoom: 17,
        tilePath: '/api/map/tiles/{z}/{x}/{y}',
      );

      expect(
        style.pathFor(const MapTileRef(14, 8752, 5371)),
        '/api/map/tiles/14/8752/5371',
      );
    });

    test('A PAYLOAD WE CANNOT READ IS REFUSED, NOT PATCHED UP', () {
      // The one field this object exists to carry is the credit line. A default
      // filled in here would put the wrong project's name under somebody's map.
      expect(
        () => BasemapStyle.fromJson(const <String, Object?>{
          'min_zoom': 1,
          'max_zoom': 17,
          'tile_path': '/api/map/tiles/{z}/{x}/{y}',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BasemapStyle.fromJson(const <String, Object?>{
          'attribution': 'somebody',
          'min_zoom': 'one',
          'max_zoom': 17,
          'tile_path': '/api/map/tiles/{z}/{x}/{y}',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('the contract snapshot parses', () {
      // The shape `packages/contracts/snapshots/map.json` pins.
      final style = BasemapStyle.fromJson(const <String, Object?>{
        'attribution': '© OpenStreetMap contributors',
        'min_zoom': 1,
        'max_zoom': 17,
        'tile_path': '/api/map/tiles/{z}/{x}/{y}',
      });

      expect(style.attribution, '© OpenStreetMap contributors');
      expect(style.minZoom, 1);
      expect(style.maxZoom, 17);
    });
  });
}
