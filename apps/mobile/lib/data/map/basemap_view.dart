/// Where a recorded coordinate lands in a drawing box, and which basemap tiles
/// cover that box.
///
/// ## Web Mercator, because the tiles are
///
/// The XYZ tile grid every raster basemap ships in is defined in Web Mercator
/// (EPSG:3857), so a track drawn in any other projection sits *beside* the roads
/// it ran on rather than on them — by tens of metres at our latitudes, growing
/// with the box. The drawing used to fit latitude and longitude with one linear
/// scale on both axes, which was honest while there was nothing underneath: no
/// basemap, no scale, nothing to be wrong relative to. With a basemap under it
/// the projection is no longer a stylistic choice, it is the difference between
/// a map and a picture that looks like one.
///
/// **This projects; it never corrects.** No point is moved onto a road, snapped
/// to a path, or smoothed. A fix that the phone put in a hedge is drawn in the
/// hedge, because that is where the measurement says the owner was.
///
/// ## The zoom is an integer; the scale is not
///
/// Tiles exist at integer zooms only, so [fit] takes the zoom whose tiles are at
/// least as detailed as the box needs ([_zoomFor] rounds up) and then draws them
/// at a fractional [scale] to fill the box exactly. Rounding up means tiles are
/// drawn smaller than their native size — sharp — and it keeps the track filling
/// the same box it filled before there was a basemap at all.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:meta/meta.dart';

/// One tile in the XYZ grid.
@immutable
class MapTileRef {
  /// A tile at [z], column [x], row [y].
  const MapTileRef(this.z, this.x, this.y);

  /// Zoom level.
  final int z;

  /// Column, 0 at 180 degrees west.
  final int x;

  /// Row, 0 at the north edge.
  final int y;

  @override
  bool operator ==(Object other) =>
      other is MapTileRef && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => '$z/$x/$y';
}

/// A fixed view of the world inside one drawing box.
@immutable
class BasemapView {
  /// Built by [fit]; the constructor is public only so tests can pin a view.
  const BasemapView({
    required this.zoom,
    required this.scale,
    required this.originX,
    required this.originY,
    required this.size,
  });

  /// A raster tile's own side, in pixels. Every XYZ basemap uses 256.
  static const double tileSize = 256;

  /// The inset the track keeps from the box edge, in canvas pixels.
  ///
  /// The prototype's own fixture track keeps it (its coordinates run 70→260 of
  /// 340 and 45→195 of 240), and it is also what stops a start ring being
  /// clipped in half by the box it sits at the edge of.
  static const double inset = 24;

  /// The most tiles one drawing may request.
  ///
  /// Standards section 1: unbounded data is windowed. A tall box at a deep zoom
  /// could otherwise ask for hundreds of tiles for one screen, which is both a
  /// slow screen and an unkind thing to do to the provider. [fit] steps the zoom
  /// back until the grid fits inside this.
  static const int maxTiles = 24;

  /// The tile zoom the basemap is drawn from.
  final int zoom;

  /// Canvas pixels per tile pixel at [zoom].
  final double scale;

  /// World-pixel x at [zoom] of the box's left edge.
  final double originX;

  /// World-pixel y at [zoom] of the box's top edge.
  final double originY;

  /// The box this view was fitted to.
  final Size size;

  /// The view that fits [points] into [box], or null when there is nothing to
  /// fit (no points, or a box with no area).
  ///
  /// [minZoom] and [maxZoom] come from the server's own `/api/map`, so a
  /// deployment that serves a narrower range is never asked for a tile outside
  /// it. With no style to read they still bound the drawing, because the
  /// geometry has to resolve whether or not a tile ever arrives.
  static BasemapView? fit(
    List<RoutePoint> points,
    Size box, {
    int minZoom = 1,
    int maxZoom = 17,
  }) {
    if (points.isEmpty || box.width <= 0 || box.height <= 0) {
      return null;
    }
    double minX = _worldX(points.first.longitude);
    double maxX = minX;
    double minY = _worldY(points.first.latitude);
    double maxY = minY;
    for (final RoutePoint point in points) {
      final double x = _worldX(point.longitude);
      final double y = _worldY(point.latitude);
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final double usableWidth = math.max(box.width - inset * 2, 1);
    final double usableHeight = math.max(box.height - inset * 2, 1);
    // World pixels the whole globe would need for this track to fill the box.
    // A track with no span on an axis puts no demand on it; one with no span at
    // all (a single place) is drawn at the closest zoom offered.
    final double spanX = maxX - minX;
    final double spanY = maxY - minY;
    final double world = switch ((spanX, spanY)) {
      (0, 0) => tileSize * math.pow(2, maxZoom).toDouble(),
      (0, final double y) => usableHeight / y,
      (final double x, 0) => usableWidth / x,
      (final double x, final double y) =>
        math.min(usableWidth / x, usableHeight / y),
    };
    var zoom = _zoomFor(world, minZoom, maxZoom);
    var view = _at(zoom, world, minX, minY, spanX, spanY, box);
    while (view.tiles().length > maxTiles && zoom > minZoom) {
      zoom -= 1;
      view = _at(zoom, world, minX, minY, spanX, spanY, box);
    }
    return view;
  }

  /// The view at one zoom, with the track's bounding box centred in [box].
  static BasemapView _at(
    int zoom,
    double world,
    double minX,
    double minY,
    double spanX,
    double spanY,
    Size box,
  ) {
    final double tiled = tileSize * math.pow(2, zoom).toDouble();
    final double scale = world / tiled;
    return BasemapView(
      zoom: zoom,
      scale: scale,
      originX: minX * tiled - (box.width - spanX * world) / 2 / scale,
      originY: minY * tiled - (box.height - spanY * world) / 2 / scale,
      size: box,
    );
  }

  /// The smallest zoom whose tiles are at least as detailed as [world] needs.
  static int _zoomFor(double world, int minZoom, int maxZoom) {
    final double exact = math.log(world / tileSize) / math.ln2;
    return exact.isFinite ? exact.ceil().clamp(minZoom, maxZoom) : maxZoom;
  }

  /// Where [latitude]/[longitude] lands in the box.
  Offset plot(double latitude, double longitude) {
    final double tiled = tileSize * math.pow(2, zoom).toDouble();
    return Offset(
      (_worldX(longitude) * tiled - originX) * scale,
      (_worldY(latitude) * tiled - originY) * scale,
    );
  }

  /// Every tile that covers the box, row by row.
  List<MapTileRef> tiles() {
    final int side = 1 << zoom;
    final double first = originX / tileSize;
    final double last = (originX + size.width / scale) / tileSize;
    final double top = originY / tileSize;
    final double bottom = (originY + size.height / scale) / tileSize;
    final int x0 = first.floor().clamp(0, side - 1);
    final int x1 = (last.ceil() - 1).clamp(0, side - 1);
    final int y0 = top.floor().clamp(0, side - 1);
    final int y1 = (bottom.ceil() - 1).clamp(0, side - 1);
    return <MapTileRef>[
      for (var y = y0; y <= y1; y++)
        for (var x = x0; x <= x1; x++) MapTileRef(zoom, x, y),
    ];
  }

  /// Where [ref] is drawn in the box.
  Rect rectFor(MapTileRef ref) {
    final double side = tileSize * scale;
    return Rect.fromLTWH(
      ref.x * tileSize * scale - originX * scale,
      ref.y * tileSize * scale - originY * scale,
      side,
      side,
    );
  }

  /// Value equality, so a painter that was handed the same view does not
  /// repaint. Two fits of the same track into the same box ARE the same view.
  @override
  bool operator ==(Object other) =>
      other is BasemapView &&
      other.zoom == zoom &&
      other.scale == scale &&
      other.originX == originX &&
      other.originY == originY &&
      other.size == size;

  @override
  int get hashCode => Object.hash(zoom, scale, originX, originY, size);

  /// Longitude to a fraction of the globe's width, 0 at 180 degrees west.
  static double _worldX(double longitude) => (longitude + 180) / 360;

  /// Latitude to a fraction of the globe's height, 0 at the north edge.
  ///
  /// The Mercator y is unbounded at the poles, so latitude is clamped to the
  /// grid's own edge (±85.0511) — the same limit every XYZ basemap is cut at.
  static double _worldY(double latitude) {
    final double clamped = latitude.clamp(-85.05112878, 85.05112878);
    final double radians = clamped * math.pi / 180;
    final double merc = math.log(
      math.tan(radians) + 1 / math.cos(radians),
    );
    return 0.5 - merc / (2 * math.pi);
  }
}
