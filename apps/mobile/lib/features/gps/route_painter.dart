/// The ground, the basemap, and the recorded track on top of both.
///
/// ```css
/// .map-land       { fill: var(--map-land) }
/// .route-underlay { stroke: var(--surface); stroke-width: 8; fill: none }
/// .route-line     { stroke: var(--accent); stroke-width: 4; fill: none }
/// .route-start    { fill: var(--surface); stroke: var(--accent) }
/// ```
///
/// ## The order is the honesty
///
/// The plain ground is painted FIRST and always, then whatever tiles arrived
/// over it, then the track. So a missing tile is a square of plain ground, a
/// missing basemap is a box of plain ground, and in every case the track is
/// drawn — [drawsTrack] depends on the fixes and on nothing else. A basemap is
/// context; the track is the measurement, and a failure in the decoration may
/// never take the measurement off the screen.
///
/// ## Nothing here moves a fix
///
/// The track is projected into the same Web Mercator the tiles are cut in
/// ([BasemapView.plot]) and drawn where it lands. No snapping to a road, no
/// smoothing, no correction toward anything the basemap shows. A fix the phone
/// put in a hedge is drawn in the hedge.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/data/map/basemap_view.dart';

/// Paints one route drawing.
class RoutePainter extends CustomPainter {
  /// [points] is the (already thinned) track, [tiles] whatever basemap has
  /// arrived so far — often nothing, which is a normal state.
  const RoutePainter({
    required this.view,
    required this.points,
    required this.tiles,
    required this.land,
    required this.track,
    required this.underlay,
  });

  /// `.route-line { stroke-width: 4 }`.
  static const double lineWidth = 4;

  /// `.route-underlay { stroke-width: 8 }`.
  static const double underlayWidth = 8;

  /// `<circle class="route-start" r="6">`.
  static const double markerRadius = 6;

  /// The projection this drawing is in — the tiles' own.
  final BasemapView view;

  /// The fixes to draw, oldest first.
  final List<RoutePoint> points;

  /// The basemap tiles that have arrived, keyed by their place in the grid.
  final Map<MapTileRef, ui.Image> tiles;

  /// The ground under everything, `--map-land`.
  final Color land;

  /// The track's own colour — the only identity colour on the drawing.
  final Color track;

  /// The track's underlay, so it reads over a busy basemap.
  final Color underlay;

  /// Whether the track is drawn.
  ///
  /// Two fixes are the fewest that make a line; one is a dot nobody can read a
  /// route off. **It does not consult [tiles]**, and that is the guarantee this
  /// getter exists to make askable: the day a basemap is unreachable is the day
  /// the owner most needs to see the track they recorded, and a fallback that
  /// silently withheld it would look exactly like a screen that had not loaded.
  bool get drawsTrack => points.length >= 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    _paintBasemap(canvas);
    if (!drawsTrack) {
      return;
    }
    _paintTrack(canvas);
  }

  /// Whatever tiles arrived, each in its own place. Missing ones stay ground.
  void _paintBasemap(Canvas canvas) {
    final Paint paint = Paint()..filterQuality = FilterQuality.medium;
    for (final MapTileRef ref in view.tiles()) {
      final ui.Image? image = tiles[ref];
      if (image == null) {
        continue;
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        view.rectFor(ref),
        paint,
      );
    }
  }

  void _paintTrack(Canvas canvas) {
    final List<Offset> plotted = <Offset>[
      for (final RoutePoint point in points)
        view.plot(point.latitude, point.longitude),
    ];
    final Path path = Path()..moveTo(plotted.first.dx, plotted.first.dy);
    for (final Offset point in plotted.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas
      ..drawPath(path, _stroke(underlay, underlayWidth))
      ..drawPath(path, _stroke(track, lineWidth))
      // `.route-start` — a ring, so a track that ends where it began still
      // shows both ends.
      ..drawCircle(plotted.first, markerRadius, Paint()..color = underlay)
      ..drawCircle(plotted.first, markerRadius, _stroke(track, 3))
      // `.data-dot` — the finish, filled.
      ..drawCircle(plotted.last, markerRadius, Paint()..color = track);
  }

  Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.points != points ||
      old.tiles != tiles ||
      old.view != view ||
      old.land != land ||
      old.track != track ||
      old.underlay != underlay;
}
