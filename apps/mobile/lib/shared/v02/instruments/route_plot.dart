/// **The route plot** — a recorded GPS track on a schematic ground, with its
/// elevation under it.
///
/// ## There is no map, and the drawing says so
///
/// `README.md`: *"The route uses sample coordinates on a labelled schematic, not
/// real map tiles."* No tiles are fetched, nothing is geocoded, and the blocks,
/// water and roads under the track are **decoration drawn at fixed fractions of
/// the box** — they are not derived from the coordinates and they do not claim
/// to be anywhere. The plot labels itself so a reader cannot mistake the ground
/// for a place.
///
/// The one thing on it that IS a measurement is the track, and the track is the
/// only thing drawn in the family colour. That is the whole colour scheme: the
/// ground is neutral so the owner's own path is the only identity on the plot.
///
/// ## Aspect ratio is preserved, because a stretched route is a wrong route
///
/// The coordinates are fitted with a single scale on both axes. Fitting width
/// and height independently would make an out-and-back look like a loop and a
/// loop look like a circuit — the shape IS the data here.
///
/// ## Elevation
///
/// The strip under the schematic keeps its height whether or not elevations were
/// recorded. With them it draws the profile and labels its own low and high;
/// without them it draws **nothing** — no flat line at the mean, which would
/// assert a level walk nobody measured.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/v02/instruments/instrument_geometry.dart';

/// The schematic's height. `charts-detail.js` draws the map at 240.
const double kRouteMapHeight = 240;

/// The elevation strip's height, kept whether or not it has anything to draw.
const double kRouteElevationHeight = 56;

/// What the plot writes on itself so the ground cannot be mistaken for a map.
const String kSchematicNote = 'Schematic ground, not a map';

/// A recorded track, its schematic ground, and its elevation profile.
class RoutePlot extends StatelessWidget {
  /// Builds the plot.
  ///
  /// [points] are the recorded coordinates in any consistent frame; longitude
  /// east and latitude north is the usual one, and north is drawn up. Fewer than
  /// two points draws no track — one fix has no shape.
  ///
  /// [elevations] must be one per point or the profile is not drawn: a profile
  /// whose samples do not line up with the track is a different measurement.
  const RoutePlot({
    required this.points,
    this.elevations,
    this.progress = 1,
    super.key,
  });

  /// Identifies the plot for tests.
  static const Key plotKey = ValueKey<String>('route-plot');

  /// The recorded fixes, in order.
  final List<Offset> points;

  /// One elevation per fix, in metres. Null draws an empty strip.
  final List<double>? elevations;

  /// Reveal progress, 0-1. The track draws itself along its own length.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: kRouteMapHeight + kRouteElevationHeight,
      child: CustomPaint(
        key: plotKey,
        painter: _RoutePainter(
          points: points,
          elevations: elevations,
          progress: progress.clamp(0.0, 1.0),
          family: context.family,
          familySoft: context.familySoft,
          surface: colors.surface,
          ground: colors.surface2,
          block: colors.grid,
          water: colors.line,
          ink2: colors.ink2,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.points,
    required this.elevations,
    required this.progress,
    required this.family,
    required this.familySoft,
    required this.surface,
    required this.ground,
    required this.block,
    required this.water,
    required this.ink2,
  });

  final List<Offset> points;
  final List<double>? elevations;
  final double progress;
  final Color family;
  final Color familySoft;
  final Color surface;
  final Color ground;
  final Color block;
  final Color water;
  final Color ink2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final map = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - kRouteElevationHeight,
    );
    _paintGround(canvas, map);
    _paintTrack(canvas, map);
    paintLabel(
      canvas,
      chartLabel(kSchematicNote, TypeScale.tileMeta.copyWith(color: ink2)),
      Offset(10, map.bottom - 18),
    );
    _paintElevation(
      canvas,
      Rect.fromLTWH(0, map.bottom, size.width, kRouteElevationHeight),
    );
  }

  /// Blocks, water and roads at fixed fractions of the box. Decoration.
  void _paintGround(Canvas canvas, Rect map) {
    canvas.drawRect(map, Paint()..color = ground);
    final w = map.width;
    final h = map.height;
    final parks = Path()
      ..addPolygon(<Offset>[
        const Offset(0, 0),
        Offset(w * 0.44, 0),
        Offset(w * 0.38, h * 0.37),
        Offset(0, h * 0.54),
      ], true)
      ..addPolygon(<Offset>[
        Offset(w * 0.6, h * 0.6),
        Offset(w, h * 0.46),
        Offset(w, h),
        Offset(w * 0.53, h),
      ], true);
    canvas.drawPath(parks, Paint()..color = block);
    final river = Path()
      ..moveTo(w * 0.68, 0)
      ..cubicTo(w * 0.52, h * 0.38, w * 0.75, h * 0.58, w * 0.62, h)
      ..lineTo(w * 0.69, h)
      ..cubicTo(w * 0.82, h * 0.62, w * 0.6, h * 0.31, w * 0.76, 0)
      ..close();
    canvas.drawPath(river, Paint()..color = water);
    final roads = Paint()
      ..color = surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.054;
    for (final line in <List<Offset>>[
      <Offset>[Offset(0, h * 0.71), Offset(w, h * 0.08)],
      <Offset>[Offset(0, h * 0.92), Offset(w, h * 0.29)],
      <Offset>[Offset(w * 0.09, 0), Offset(w * 0.65, h)],
      <Offset>[Offset(w * 0.28, 0), Offset(w * 0.84, h)],
    ]) {
      canvas.drawLine(line[0], line[1], roads);
    }
  }

  void _paintTrack(Canvas canvas, Rect map) {
    if (points.length < 2) {
      return;
    }
    final area = map.deflate(24);
    final placed = _fit(points, area);
    final track = Path()..moveTo(placed.first.dx, placed.first.dy);
    for (final point in placed.skip(1)) {
      track.lineTo(point.dx, point.dy);
    }
    final drawn = progress >= 1 ? track : _upTo(track, progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..color = family
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(placed.first, 6, Paint()..color = surface);
    canvas.drawCircle(
      placed.first,
      6,
      Paint()
        ..color = family
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    if (progress >= 1) {
      canvas.drawCircle(placed.last, 6, Paint()..color = family);
    }
  }

  /// Fits [source] into [area] with ONE scale on both axes, north up.
  List<Offset> _fit(List<Offset> source, Rect area) {
    var minX = source.first.dx;
    var maxX = minX;
    var minY = source.first.dy;
    var maxY = minY;
    for (final point in source) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    final width = maxX - minX;
    final height = maxY - minY;
    final scale = math.min(
      width > 0 ? area.width / width : double.infinity,
      height > 0 ? area.height / height : double.infinity,
    );
    if (!scale.isFinite) {
      return <Offset>[for (final _ in source) area.center];
    }
    final dx = area.left + (area.width - width * scale) / 2;
    final dy = area.top + (area.height - height * scale) / 2;
    return <Offset>[
      for (final point in source)
        Offset(
          dx + (point.dx - minX) * scale,
          // North up: latitude grows as y shrinks.
          dy + (maxY - point.dy) * scale,
        ),
    ];
  }

  Path _upTo(Path path, double fraction) {
    final drawn = Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(
        metric.extractPath(0, metric.length * fraction),
        Offset.zero,
      );
    }
    return drawn;
  }

  /// The profile, or nothing at all. Never a flat line standing in for absence.
  void _paintElevation(Canvas canvas, Rect strip) {
    final series = elevations;
    if (series == null || series.length != points.length || series.length < 2) {
      return;
    }
    final low = series.reduce(math.min);
    final high = series.reduce(math.max);
    final plot = strip.deflate(10);
    final flat = high - low < 0.001;
    double y(double value) =>
        flat ? plot.center.dy : plot.bottom - (value - low) / (high - low) * plot.height;
    final placed = <Offset>[
      for (var i = 0; i < series.length; i++)
        Offset(
          plot.left + i / (series.length - 1) * plot.width,
          y(series[i]),
        ),
    ];
    final line = smoothPath(placed);
    final fill = Path.from(line)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(fill, Paint()..color = revealed(familySoft, progress));
    canvas.drawPath(
      progress >= 1 ? line : _upTo(line, progress),
      Paint()
        ..color = family
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final style = TypeScale.tileMeta.copyWith(color: ink2);
    paintLabel(
      canvas,
      chartLabel('${high.round()} m', style),
      Offset(strip.right - 4, plot.top - 2),
      anchor: LabelAnchor.end,
    );
    paintLabel(
      canvas,
      chartLabel('${low.round()} m', style),
      Offset(strip.right - 4, plot.bottom - 10),
      anchor: LabelAnchor.end,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.points != points ||
      old.elevations != elevations ||
      old.progress != progress ||
      old.family != family;
}
