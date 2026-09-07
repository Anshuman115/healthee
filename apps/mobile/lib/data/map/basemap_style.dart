/// What this deployment's basemap is, and who it must be credited to.
///
/// Served by `GET /api/map` rather than compiled into the build, because the
/// tile provider is server configuration: an operator who repoints the server's
/// `MAP_TILE_URL` changes who is owed the credit line, and a string baked into
/// the app could not follow. The zoom range travels with it for the same reason
/// — the app must never ask for a tile the server has already said it will not
/// serve, and the bound belongs with the thing it bounds.
library;

import 'package:healthee/data/map/basemap_view.dart';
import 'package:meta/meta.dart';

/// The basemap contract, as `GET /api/map` sends it.
@immutable
class BasemapStyle {
  /// Builds a style.
  const BasemapStyle({
    required this.attribution,
    required this.minZoom,
    required this.maxZoom,
    required this.tilePath,
  });

  /// Parses the server's payload.
  ///
  /// A missing or mistyped key is a `FormatException`, never a default filled
  /// in. A half-understood style is not a style: the one field this object
  /// exists to carry is the attribution, and a guessed credit line is worse than
  /// none. The caller turns the throw into "no basemap" — an `Exception` rather
  /// than a cast `TypeError` because that is a state a caller may handle, and
  /// the analyzer is right that an `Error` is not.
  factory BasemapStyle.fromJson(Map<String, Object?> json) {
    final Object? attribution = json['attribution'];
    final Object? minZoom = json['min_zoom'];
    final Object? maxZoom = json['max_zoom'];
    final Object? tilePath = json['tile_path'];
    if (attribution is! String ||
        tilePath is! String ||
        minZoom is! num ||
        maxZoom is! num) {
      throw const FormatException('The basemap style is not the shape we read');
    }
    return BasemapStyle(
      attribution: attribution,
      minZoom: minZoom.toInt(),
      maxZoom: maxZoom.toInt(),
      tilePath: tilePath,
    );
  }

  /// The credit line, drawn on screen wherever the basemap is.
  final String attribution;

  /// The shallowest zoom the server will serve.
  final int minZoom;

  /// The deepest zoom the server will serve.
  final int maxZoom;

  /// The tile route, with `{z}`, `{x}` and `{y}` still in it.
  final String tilePath;

  /// [tilePath] with [ref] substituted in.
  String pathFor(MapTileRef ref) => tilePath
      .replaceFirst('{z}', '${ref.z}')
      .replaceFirst('{x}', '${ref.x}')
      .replaceFirst('{y}', '${ref.y}');
}
