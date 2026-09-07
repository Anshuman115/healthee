/// `.route-map` — the recorded track, drawn as a shape rather than as a place.
///
/// ```css
/// .route-map        { border-radius: var(--radius-md); overflow: clip }
/// .map-land         { fill: var(--map-land) }
/// .route-underlay   { stroke: var(--surface); stroke-width: 8; fill: none }
/// .route-line       { stroke: var(--accent); stroke-width: 4; fill: none;
///                     stroke-linecap: round }
/// .route-start      { fill: var(--surface); stroke: var(--accent);
///                     stroke-width: 3 }
/// ```
///
/// `charts.js::H.charts.route` draws a 340×240 box: the land, then **park, water
/// and road shapes from hardcoded path data**, then the track, a start ring and
/// a finish dot, and a caption at (18, 224).
///
/// ## The park, the water and the roads are not drawn here
///
/// They are fixture geometry — four literal `<path>` strings that describe no
/// place at all. Under the prototype's own sample track that is honest scenery
/// for a preview; under a track the owner actually ran it would be a river and
/// two roads that were not there, printed at the top of a screen whose whole
/// subject is where they went. This app draws the ground and the track, which is
/// every part of that picture that is a measurement.
///
/// **There is no basemap either, and that is the same decision.** The screen
/// before this one used `flutter_map` over OpenStreetMap tiles; the prototype
/// specifies a schematic, and a schematic is also the only version of this
/// drawing that needs no network to render a track already on the phone.
///
/// ## The drawing is thinned; the SAVED TRACK is not
///
/// A long run is tens of thousands of fixes and the box is 340 px wide, so most
/// of them are sub-pixel and none of them is legible. [displayPoints] samples
/// down to [maxDrawnPoints] and **keeps both ends**, so the start ring and the
/// finish dot still mark the fixes they mark. Standards section 1: unbounded
/// data is windowed. The upload path is untouched and retains every valid fix —
/// this is a decision about what is drawn, never about what is kept.
///
/// ## The shape is the owner's, normalised — so it carries no scale
///
/// Latitude and longitude are fitted to the box with **one** ratio for both axes
/// (`_fit`), so the track keeps its own proportions and cannot be stretched into
/// a different shape by a tall or wide window. What it does not carry is
/// distance: two tracks of very different lengths fill the same box. The
/// caption says so, because a picture with no scale that looks like a map is
/// read as one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/gps/route_point.dart';

/// The recorded track on the schematic ground, or nothing when there is none.
class RouteMap extends StatelessWidget {
  /// [points] is the track, oldest first.
  const RouteMap({required this.points, super.key});

  /// `H.charts.route()` — the SVG's own `viewBox` height.
  static const double height = 240;

  /// The inset the prototype's own fixture track keeps from the box edge: its
  /// coordinates run 70→260 of 340 and 45→195 of 240.
  static const double inset = 24;

  /// `.route-line { stroke-width: 4 }`.
  static const double lineWidth = 4;

  /// `.route-underlay { stroke-width: 8 }`.
  static const double underlayWidth = 8;

  /// `<circle class="route-start" r="6">`.
  static const double markerRadius = 6;

  /// What the caption says, and it is a disclaimer rather than a label: the
  /// drawing has no basemap and no scale, and it looks enough like a map that
  /// saying so is the honest thing to do.
  static const String caption = 'Your recorded track · no basemap, no scale';

  /// The most fixes this drawing plots. See the class docstring.
  static const int maxDrawnPoints = 2000;

  /// The track.
  final List<RoutePoint> points;

  /// [points] thinned to at most [maxDrawnPoints], both ends retained.
  ///
  /// Public because the guarantee — first and last survive — is what the start
  /// ring and the finish dot depend on, and that is worth asking directly
  /// rather than reading back off a canvas.
  static List<RoutePoint> displayPoints(List<RoutePoint> points) {
    if (points.length <= maxDrawnPoints) {
      return points;
    }
    final int last = points.length - 1;
    return <RoutePoint>[
      for (var i = 0; i < maxDrawnPoints; i++)
        points[(i * last / (maxDrawnPoints - 1)).round()],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Two points is the fewest that draw a line. One fix is a dot the owner
    // cannot read anything off, so the card says it has no track instead.
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size.fromHeight(height),
          painter: _RoutePainter(
            points: displayPoints(points),
            land: colors.mapLand,
            track: colors.accent,
            underlay: colors.surface,
          ),
          child: SizedBox(
            height: height,
            child: Semantics(
              image: true,
              label:
                  'The shape of your recorded track, ${points.length} fixes. '
                  '$caption.',
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Text(
                    caption,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ground, the track, the start ring and the finish dot.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.points,
    required this.land,
    required this.track,
    required this.underlay,
  });

  final List<RoutePoint> points;
  final Color land;
  final Color track;
  final Color underlay;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    final List<Offset> plotted = _fit(size);
    if (plotted.length < 2) {
      return;
    }
    final Path path = Path()..moveTo(plotted.first.dx, plotted.first.dy);
    for (final Offset point in plotted.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    // The underlay is the prototype's: a thicker stroke in the surface colour,
    // so the track reads over the ground rather than dissolving into it.
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = RouteMap.underlayWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = underlay,
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = RouteMap.lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = track,
      )
      // `.route-start` — a ring, so a track that ends where it began still
      // shows both ends.
      ..drawCircle(
        plotted.first,
        RouteMap.markerRadius,
        Paint()..color = underlay,
      )
      ..drawCircle(
        plotted.first,
        RouteMap.markerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = track,
      )
      // `.data-dot` — the finish, filled.
      ..drawCircle(plotted.last, RouteMap.markerRadius, Paint()..color = track);
  }

  /// The track's own coordinates, fitted into [size] with ONE ratio.
  ///
  /// Longitude runs left to right and latitude bottom to top, so the y axis is
  /// flipped. A degree of longitude is shorter than a degree of latitude away
  /// from the equator and this does **not** correct for that: the drawing
  /// carries no scale (see the class docstring), so a projection would be
  /// precision the picture does not claim.
  List<Offset> _fit(Size size) {
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final RoutePoint point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    final double spanLat = maxLat - minLat;
    final double spanLng = maxLng - minLng;
    final double usableWidth = size.width - RouteMap.inset * 2;
    final double usableHeight = size.height - RouteMap.inset * 2;
    // A track that never moved in one axis has no span there; it is centred
    // rather than divided by zero.
    final double scale = switch ((spanLng, spanLat)) {
      (0, 0) => 0,
      (0, final double lat) => usableHeight / lat,
      (final double lng, 0) => usableWidth / lng,
      (final double lng, final double lat) =>
        usableWidth / lng < usableHeight / lat
            ? usableWidth / lng
            : usableHeight / lat,
    };
    final double left = (size.width - spanLng * scale) / 2;
    final double top = (size.height - spanLat * scale) / 2;
    return <Offset>[
      for (final RoutePoint point in points)
        Offset(
          left + (point.longitude - minLng) * scale,
          // Flipped: a higher latitude is further up the box.
          top + (maxLat - point.latitude) * scale,
        ),
    ];
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.points != points ||
      old.land != land ||
      old.track != track ||
      old.underlay != underlay;
}
