/// `.route-map` — the recorded track, on a real basemap when there is one.
///
/// `charts.js::H.charts.route` draws a 340x240 box: the land, then **park, water
/// and road shapes from hardcoded path data**, then the track, a start ring and
/// a finish dot, and a caption at (18, 224).
///
/// ## The prototype's scenery is still not drawn. A real basemap is.
///
/// Those four literal `<path>` strings describe no place at all. Under the
/// preview's sample track that is honest scenery; under a track the owner
/// actually ran it would be a river and two roads that were not there, printed
/// at the top of a screen whose whole subject is where they went. This file used
/// to argue from that to "no basemap either", and the owner has since asked for
/// a real one — which is the opposite decision for the same reason. A drawn
/// river that is not there is a lie; the streets someone actually ran on are
/// context.
///
/// **The tiles come from our own server, never from a provider.** A tile request
/// says where somebody is looking, so the phone asks Healthee and Healthee
/// fetches and caches — `apps/server/src/healthee/core/map_tiles.py` carries the
/// argument, and it is `derive/dem.py`'s, one layer up.
///
/// ## Offline is a normal state, and it never blanks the route
///
/// No style, no tiles, half the tiles: the ground is painted first and always,
/// and the track is drawn on whatever ground there is. [RoutePainter.drawsTrack]
/// is the guarantee, and it is asked directly by the suite. The caption says
/// which picture the owner is looking at, because "on a map" and "not on a map"
/// are different claims about the same line.
///
/// ## The drawing is thinned; the SAVED TRACK is not
///
/// A long run is tens of thousands of fixes and the box is a few hundred pixels
/// wide, so most of them are sub-pixel. [displayPoints] samples down to
/// [maxDrawnPoints] and **keeps both ends**, so the start ring and the finish dot
/// still mark the fixes they mark. Standards section 1: unbounded data is
/// windowed. The upload path is untouched and retains every valid fix — this is
/// a decision about what is drawn, never about what is kept.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/data/map/basemap_source.dart';
import 'package:healthee/data/map/basemap_style.dart';
import 'package:healthee/data/map/basemap_view.dart';
import 'package:healthee/features/gps/route_painter.dart';

/// The recorded track, on the basemap when one is available.
class RouteMap extends ConsumerStatefulWidget {
  /// [points] is the track, oldest first.
  const RouteMap({required this.points, super.key});

  /// `H.charts.route()` — the SVG's own `viewBox` height.
  static const double height = 240;

  /// Identifies the drawing's canvas for tests.
  static const Key canvasKey = ValueKey<String>('route-map-canvas');

  /// What the caption says when the track is drawn on a real basemap.
  ///
  /// It names the instrument rather than the picture: the line is phone GPS,
  /// which is metres-accurate at best, and a track drawn over street geometry
  /// invites being read to the width of a pavement. Nothing here snaps a fix to
  /// a road, and the caption is where that is said out loud.
  static const String mappedCaption =
      'Your recorded track · phone GPS, drawn where it fell';

  /// And when there is no basemap: the drawing carries no scale of its own.
  static const String plainCaption =
      'Your recorded track · no basemap, no scale';

  /// The most fixes this drawing plots. See the class docstring.
  static const int maxDrawnPoints = 2000;

  /// The track.
  final List<RoutePoint> points;

  /// [points] thinned to at most [maxDrawnPoints], both ends retained.
  ///
  /// Public because the guarantee — first and last survive — is what the start
  /// ring and the finish dot depend on, and that is worth asking directly rather
  /// than reading back off a canvas.
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
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<RouteMap> {
  /// The tiles that have arrived, keyed by their absolute place in the grid.
  ///
  /// Absolute is what makes them reusable: a [MapTileRef] carries its own zoom,
  /// so a tile stays correct as the view pans and rescales, and only a change of
  /// ZOOM makes one a picture at the wrong scale. That matters on the recorder,
  /// where every accepted fix grows the track's bounding box and so produces a
  /// new view about once a second — emptying this on every view would blank the
  /// basemap between fixes and re-fetch the same squares forever.
  Map<MapTileRef, ui.Image> _tiles = const <MapTileRef, ui.Image>{};

  /// The view whose tiles have already been asked for.
  BasemapView? _asked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Two points is the fewest that draw a line. One fix is a dot the owner
    // cannot read anything off, so the card shows nothing instead.
    if (widget.points.length < 2) {
      return const SizedBox.shrink();
    }
    final BasemapStyle? style = ref.watch(basemapStyleProvider).value;
    final List<RoutePoint> drawn = RouteMap.displayPoints(widget.points);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: RepaintBoundary(
        child: SizedBox(
          height: RouteMap.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final BasemapView? view = BasemapView.fit(
                drawn,
                Size(constraints.maxWidth, RouteMap.height),
                minZoom: style?.minZoom ?? 1,
                maxZoom: style?.maxZoom ?? 17,
              );
              if (view == null) {
                return const SizedBox.shrink();
              }
              if (style != null) {
                _request(style, view);
              }
              return _drawing(context, view, drawn, colors);
            },
          ),
        ),
      ),
    );
  }

  Widget _drawing(
    BuildContext context,
    BasemapView view,
    List<RoutePoint> drawn,
    HealtheeColors colors,
  ) {
    // "Mapped" is about THIS view, not about the cache: a tile held from a
    // previous zoom is not drawn, so it may not put a credit line on screen or
    // change the caption's claim about the picture the owner is looking at.
    final bool mapped = view.tiles().any(_tiles.containsKey);
    final String caption = mapped
        ? RouteMap.mappedCaption
        : RouteMap.plainCaption;
    final String? credit = mapped
        ? ref.watch(basemapStyleProvider).value?.attribution
        : null;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          image: true,
          label:
              'The shape of your recorded track, ${widget.points.length} '
              'fixes. $caption.',
          child: CustomPaint(
            key: RouteMap.canvasKey,
            painter: RoutePainter(
              view: view,
              points: drawn,
              tiles: _tiles,
              land: colors.mapLand,
              track: colors.accent,
              underlay: colors.surface,
            ),
          ),
        ),
        _label(context, caption, colors, Alignment.bottomLeft),
        // Mandatory, on screen, beside the map it credits — never in a settings
        // page, and never absent while a tile is drawn.
        if (credit != null)
          _label(context, credit, colors, Alignment.bottomRight),
      ],
    );
  }

  Widget _label(
    BuildContext context,
    String text,
    HealtheeColors colors,
    Alignment where,
  ) => Align(
    alignment: where,
    child: Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.ink2),
      ),
    ),
  );

  /// Asks for the tiles this view needs and does not already have.
  ///
  /// After the frame because it is called from `build`: a tile that resolves
  /// synchronously (already in the source's cache) would otherwise `setState`
  /// during a build. Tiles already held are never re-requested, so the rebuild
  /// per GPS fix on the recorder costs one bounding-box comparison.
  void _request(BasemapStyle style, BasemapView view) {
    if (_asked == view) {
      return;
    }
    _asked = view;
    // A tile from another zoom is the right place at the wrong scale and
    // nothing draws it, so dropping it is what keeps this map bounded.
    if (_tiles.keys.any((MapTileRef held) => held.z != view.zoom)) {
      _tiles = <MapTileRef, ui.Image>{
        for (final MapEntry<MapTileRef, ui.Image> held in _tiles.entries)
          if (held.key.z == view.zoom) held.key: held.value,
      };
    }
    final List<MapTileRef> missing = <MapTileRef>[
      for (final MapTileRef tile in view.tiles())
        if (!_tiles.containsKey(tile)) tile,
    ];
    if (missing.isEmpty) {
      return;
    }
    final BasemapTiles source = ref.read(basemapTilesProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final MapTileRef tile in missing) {
        final ui.Image? image = await source.tile(style, tile);
        if (!mounted || image == null || _tiles.containsKey(tile)) {
          continue;
        }
        setState(() {
          _tiles = <MapTileRef, ui.Image>{..._tiles, tile: image};
        });
      }
    });
  }
}
