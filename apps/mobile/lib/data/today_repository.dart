/// Fetches, caches and parses `GET /api/today` — the whole boundary, end to end.
///
/// The pipeline this file completes: dio (one client, authenticated) → JSON →
/// the local tier → [TodaySnapshot.fromJson] → typed model with [Reading] fields
/// → a provider a screen watches. Nothing above this line sees a
/// `Map<String, Object?>` again, which is Standards §3's "typed models at the
/// data boundary" in one function.
///
/// ## The cache stores BYTES, and re-parses them on the way out
///
/// `local_store.dart` argues this at length and it is worth repeating where it
/// is used: the row holds the response body verbatim, and the same
/// `fromJson` the network path uses turns it back into a model. A cache that
/// shredded the payload into columns would be a second definition of every
/// metric on this screen, and a cache that parsed differently from the network
/// could show a number the server never sent.
///
/// ## Falling back is not the same as succeeding
///
/// [TodayRepository.load] tries the network and falls back to the cache, and the
/// difference is carried out in [TodayView.fromCache] rather than hidden. A
/// silent fallback would let a phone that has been offline for three days draw a
/// full screen of confident numbers about a Tuesday.
///
/// When the network fails AND there is nothing cached, the error propagates:
/// Riverpod turns it into `AsyncError` for [AsyncView] to render with a retry.
/// Returning an empty [TodaySnapshot] instead would be the banned pattern —
/// "returning empty-string/empty-map to mean 'something failed'" (Standards §1)
/// — and would show a page of withheld cards implying the owner's data is
/// missing when it is merely unreached.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/provider_logger.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_repository.g.dart';

/// The cache key this payload is filed under. The endpoint's own name.
const String kTodayPayload = 'today';

/// Reads the Today payload, from the server when it can and from disk when it
/// cannot.
class TodayRepository {
  /// [dio] is the app's one client; [store] is the local 60-day tier.
  const TodayRepository(this._dio, this._store, {this.credentials});

  /// The account that owns every request and cached response.
  final Credentials? credentials;

  final Dio _dio;
  final LocalStore _store;

  /// The Today payload, network-first, cache as the fallback.
  ///
  /// Throws only when BOTH fail — a transport error with nothing on disk. That
  /// is genuinely "we could not answer", which is different from "we have no
  /// data" and must stay different (Standards §1).
  Future<TodayView> load({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final session = await CacheSession.capture(credentials);
    try {
      return await _fetch(at, session);
    } on DioException catch (error, stackTrace) {
      // Named, logged, then either substituted or rethrown — never swallowed.
      AppLog.failure('today', 'fetching /api/today', error, stackTrace);
      await session.ensureCurrent();
      final cached = await _cached(session);
      if (cached == null) {
        rethrow;
      }
      return cached;
    }
  }

  /// Fetches from the server and writes the body to the local tier.
  ///
  /// The write is part of the fetch rather than a separate step a caller could
  /// forget: every successful read is what makes the next offline launch
  /// readable, and a cache that only some code paths fill is a cache that is
  /// empty on the day it matters.
  Future<TodayView> fetch({DateTime? now}) async {
    return _fetch(
      now ?? DateTime.now(),
      await CacheSession.capture(credentials),
    );
  }

  Future<TodayView> _fetch(DateTime at, CacheSession session) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/today',
      options: session.options(),
    );
    await session.ensureCurrent();
    final body = response.data;
    if (body == null) {
      // An empty body is not an empty snapshot. Saying so out loud keeps "no
      // data" and "the request failed" distinguishable (Standards §1).
      throw const FormatException('GET /api/today returned an empty body');
    }
    final snapshot = TodaySnapshot.fromJson(body);
    // Parsed BEFORE it is stored, so a body we cannot read never becomes the
    // thing the app falls back to. A cache full of unparseable JSON is worse
    // than an empty one: it looks like coverage.
    await _store.write(
      scope: session.scope,
      metric: kTodayPayload,
      day: snapshot.date,
      payload: jsonEncode(body),
      fetchedAt: at,
    );
    return TodayView(snapshot: snapshot, fetchedAt: at, fromCache: false);
  }

  /// The newest cached payload, or null when this phone holds none.
  ///
  /// A row we cannot parse is treated as absent and said out loud. It cannot be
  /// repaired here, and rendering half of it would be inventing the other half.
  Future<TodayView?> cached() async =>
      _cached(await CacheSession.capture(credentials));

  Future<TodayView?> _cached(CacheSession session) async {
    final row = await _store.readLatest(kTodayPayload, scope: session.scope);
    await session.ensureCurrent();
    if (row == null) {
      return null;
    }
    final decoded = jsonDecode(row.payload);
    if (decoded is! Map<String, Object?>) {
      AppLog.info('today', 'cached payload for ${row.day} is not an object');
      return null;
    }
    return TodayView(
      snapshot: TodaySnapshot.fromJson(decoded),
      fetchedAt: row.fetchedAt,
      fromCache: true,
    );
  }
}

/// The app's [TodayRepository].
@riverpod
TodayRepository todayRepository(Ref ref) => TodayRepository(
  ref.watch(apiClientProvider),
  ref.watch(localStoreProvider),
  credentials: ref.watch(credentialsProvider),
);

/// Today's snapshot, with its provenance. Watch this from the Today screen.
///
/// [ProviderLogger] logs every provider failure through the one logging path, so
/// there is deliberately no `try`/`catch` here: catching would only let us
/// re-throw after a log entry that already happens.
@riverpod
Future<TodayView> todaySnapshot(Ref ref) =>
    ref.watch(todayRepositoryProvider).load();
