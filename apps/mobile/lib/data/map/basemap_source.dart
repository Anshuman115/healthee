/// How this app gets a basemap: from its own server, over its one HTTP client.
///
/// The phone never talks to a tile provider. `GET /api/map/tiles/{z}/{x}/{y}`
/// goes to the server the owner is signed into, which fetches upstream once and
/// caches — so the provider sees a square of the world asked for by a server,
/// not the neighbourhood one person runs in, at what times, from what IP. The
/// server's own `core/map_tiles.py` carries the argument in full.
///
/// ## Failure is a normal state here, and it is never an error card
///
/// Offline, a cache miss the server could not fill, a deployment with no basemap
/// configured: all of them resolve to "no tile", and the route is drawn on the
/// plain ground exactly as it was before there was a basemap at all. A basemap
/// is **context, never data** — the track is the measurement, and nothing about
/// the decoration may take it off the screen. Every failure is still logged
/// through the one logging path; what differs is that the honest handling of
/// this one is a quieter picture rather than a retry button.
///
/// ## The token never leaves the signed-in server
///
/// With `HELIO_TILES` set the basemap comes from a host that is NOT the one the
/// owner signed into, so both calls here suppress the stored session — no base
/// URL override and no `Authorization` header. `CacheSession.requestKey` present
/// with a null value is the session interceptor's own documented way to say
/// "this request has no session", and it is what stops a build-time host ever
/// receiving a runtime secret (`core/env.dart`).
library;

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/map/basemap_style.dart';
import 'package:healthee/data/map/basemap_view.dart';

/// `GET /api/map` — the style route, in one place.
const String kBasemapStylePath = '/api/map';

/// The deployment's basemap style, or null when it could not be read.
///
/// Null rather than an `AsyncError` the screen has to render: the caller's only
/// possible response is to draw no basemap, and a route screen must not grow an
/// error state for its wallpaper. `keepAlive` is deliberate — this is per-server
/// configuration that cannot change while the app runs, so re-asking on every
/// route screen would be a round trip for an answer already in hand. It rebuilds
/// when the account does, because a different server is a different basemap and
/// a different credit line.
final basemapStyleProvider = FutureProvider<BasemapStyle?>((ref) async {
  try {
    if (Env.hasSeparateTileHost) {
      final Response<Map<String, Object?>> response = await ref
          .watch(apiClientProvider)
          .get<Map<String, Object?>>(
            '${Env.tileBaseUrl}$kBasemapStylePath',
            options: basemapOptions(),
          );
      return BasemapStyle.fromJson(response.data!);
    }
    final AccountApi api = await ref.watch(accountApiProvider.future);
    return BasemapStyle.fromJson(await api.get(kBasemapStylePath));
  } on Exception catch (error, stack) {
    // Offline, a server with no basemap, or a key it renamed. Logged either way,
    // because "the map went quiet everywhere at once" is not something anyone
    // spots from a screenshot.
    AppLog.failure('map', 'reading the basemap style', error, stack);
    return null;
  }
});

/// Request options for a call to the map host.
///
/// Public so the tile source and the style provider cannot disagree about it:
/// the session is applied only when the tiles come from the signed-in server,
/// and suppressed the moment `HELIO_TILES` names somebody else's host.
Options basemapOptions({bool bytes = false}) => Options(
  responseType: bytes ? ResponseType.bytes : ResponseType.json,
  extra: Env.hasSeparateTileHost
      ? const <String, Object?>{CacheSession.requestKey: null}
      : const <String, Object?>{},
);

/// One decoded basemap tile, or null when there is none to be had.
abstract class BasemapTiles {
  /// The tile for [ref] under [style], or null. Never throws.
  Future<ui.Image?> tile(BasemapStyle style, MapTileRef ref);
}

/// The app's tile source: the one HTTP client, a bounded decoded-image cache.
class HttpBasemapTiles implements BasemapTiles {
  /// Fetches over [_dio] — the app's single client, so tiles share its
  /// connection pool, its timeouts and its logging like every other call.
  HttpBasemapTiles(this._dio);

  /// How many decoded tiles are held in memory.
  ///
  /// 32 x 256 x 256 x 4 bytes is ~8 MB, a couple of screens' worth, and bounded
  /// on purpose (standards section 1: unbounded data is windowed) — an hour of
  /// panning would otherwise hold every tile it ever drew. Oldest-inserted goes
  /// first; a `LinkedHashMap` keeps that order for free, and re-reading a tile
  /// is a disk read on our own server.
  static const int maxCachedTiles = 32;

  final Dio _dio;
  final LinkedHashMap<MapTileRef, ui.Image> _cache =
      LinkedHashMap<MapTileRef, ui.Image>();
  final Map<MapTileRef, Future<ui.Image?>> _inFlight =
      <MapTileRef, Future<ui.Image?>>{};

  @override
  Future<ui.Image?> tile(BasemapStyle style, MapTileRef ref) {
    final ui.Image? held = _cache[ref];
    if (held != null) {
      return Future<ui.Image?>.value(held);
    }
    // One request per tile even when two widgets ask at once — the recorder and
    // a saved route can be looking at the same square.
    return _inFlight[ref] ??= _load(
      style,
      ref,
    ).whenComplete(() => _inFlight.remove(ref));
  }

  Future<ui.Image?> _load(BasemapStyle style, MapTileRef ref) async {
    final String path = style.pathFor(ref);
    try {
      final Response<Uint8List> response = await _dio.get<Uint8List>(
        Env.hasSeparateTileHost ? '${Env.tileBaseUrl}$path' : path,
        options: basemapOptions(bytes: true),
      );
      final ui.Image image = await _decode(response.data!);
      _remember(ref, image);
      return image;
    } on Exception catch (error, stack) {
      // A 404 from a zoom the server does not serve, a 502 from an upstream it
      // could not reach, a decode failure, or no network at all. The route still
      // draws; this is the fallback, not a fault the owner has to act on.
      AppLog.failure('map', 'reading a basemap tile', error, stack);
      return null;
    }
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Holds [image], evicting the oldest once the cache is full.
  ///
  /// Evicted images are **dropped, not disposed**. A painter that is mid-frame
  /// may still hold the same handle, and drawing a disposed image throws — which
  /// would turn a memory bound into a crash on the one screen this feature is
  /// for. Dropping the reference lets the engine reclaim it once nothing draws
  /// it, which is the same outcome a frame later and cannot fail.
  void _remember(MapTileRef ref, ui.Image image) {
    _cache[ref] = image;
    while (_cache.length > maxCachedTiles) {
      _cache.remove(_cache.keys.first);
    }
  }
}

/// The app's tile source.
final basemapTilesProvider = Provider<BasemapTiles>(
  (ref) => HttpBasemapTiles(ref.watch(apiClientProvider)),
);
