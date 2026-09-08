/// The Sleep tab's three reads: the page, the regularity block, the AI analysis.
///
/// Legacy watched three providers over one stale-while-revalidate memory cache
/// (`data/providers.dart`). The shape is kept — three independent reads, so a slow
/// LLM call cannot hold the measured half of the screen — and the mechanism is
/// this repo's: `LocalStore` for the durable half, and Riverpod's own `AsyncValue`
/// for loading and error, which is what `AsyncView` renders.
///
/// ## Why the insight is NOT cached to disk
///
/// `/api/sleep/insight` is premium and cached **per day on the server**, so a
/// second call the same day costs no generation. A second copy on the phone would
/// only make a lapsed subscription able to keep reading yesterday's paid card, and
/// `routers/insights.py` says in as many words that the gate exists to stop
/// exactly that.
///
/// ## 402 is not a failure
///
/// The insight and `tonight` are the only paid things on this screen. A 402 means
/// *not included in your plan*, which is an answer; a timeout means *we could not
/// ask*, which is our fault. They are told apart at the boundary here and rendered
/// as different sentences, because a locked card that says "unavailable right now"
/// invites a retry that can never work.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_insight.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sleep_repository.g.dart';

/// The cache key the Sleep page is filed under. The endpoint's own name.
const String kSleepPayload = 'sleep';

/// The cache key the regularity block is filed under.
const String kSleepConsistencyPayload = 'sleep_consistency';

/// The LLM surfaces are slow on a cold cache — the server generates, validates
/// and may retry. Legacy allowed 60 s for the same call and measured 30–40 s.
const Duration kInsightTimeout = Duration(seconds: 60);

/// Reads the Sleep tab's payloads, network-first with the local tier behind them.
class SleepRepository {
  /// [dio] is the app's one client; [store] is the local 60-day tier.
  const SleepRepository(this._dio, this._store, {this.credentials});

  /// The account that owns every request and cached response.
  final Credentials? credentials;

  final Dio _dio;
  final LocalStore _store;

  /// `GET /api/sleep`, cache as the fallback.
  ///
  /// Throws only when BOTH fail. An empty [SleepPage] would be the banned
  /// "empty map means failure" (Standards §1) and would draw "No sleep recorded
  /// yet" over a network problem.
  Future<SleepPage> page({DateTime? now}) => _load(
    path: '/api/sleep',
    metric: kSleepPayload,
    parse: SleepPage.fromJson,
    dayOf: (page) => page.latest?.date,
    now: now,
  );

  /// `GET /api/sleep/consistency`, cache as the fallback.
  Future<SleepConsistency> consistency({DateTime? now}) => _load(
    path: '/api/sleep/consistency',
    metric: kSleepConsistencyPayload,
    parse: SleepConsistency.fromJson,
    dayOf: (_) => null,
    now: now,
    timeout: kInsightTimeout,
  );

  /// `GET /api/sleep/insight`. Never cached — see the library docstring.
  Future<SleepInsight> insight() async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/sleep/insight',
        options: Options(
          receiveTimeout: kInsightTimeout,
          sendTimeout: kInsightTimeout,
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const FormatException(
          'GET /api/sleep/insight returned an empty body',
        );
      }
      return SleepInsight.fromJson(body);
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode == _paymentRequired) {
        // An answer, not a failure. Logged at info because nothing is broken.
        AppLog.info('sleep', 'sleep insight is not included in this plan');
        return const SleepInsight.locked();
      }
      AppLog.failure('sleep', 'fetching /api/sleep/insight', error, stackTrace);
      rethrow;
    }
  }

  static const int _paymentRequired = 402;

  Future<T> _load<T extends Object>({
    required String path,
    required String metric,
    required T Function(Map<String, Object?> json) parse,
    required String? Function(T parsed) dayOf,
    DateTime? now,
    Duration? timeout,
  }) async {
    final at = now ?? DateTime.now();
    final session = await CacheSession.capture(credentials);
    try {
      final response = await _dio.get<Map<String, Object?>>(
        path,
        options: session.options(timeout: timeout),
      );
      final body = response.data;
      if (body == null) {
        throw FormatException('GET $path returned an empty body');
      }
      // Parsed BEFORE it is stored, so a body we cannot read never becomes the
      // thing the app falls back to.
      await session.ensureCurrent();
      final parsed = parse(body);
      await _store.write(
        scope: session.scope,
        metric: metric,
        day: dayOf(parsed) ?? _isoDay(at),
        payload: jsonEncode(body),
        fetchedAt: at,
      );
      return parsed;
    } on DioException catch (error, stackTrace) {
      AppLog.failure('sleep', 'fetching $path', error, stackTrace);
      await session.ensureCurrent();
      final cached = await _cached(metric, parse, session);
      if (cached == null) {
        rethrow;
      }
      return cached;
    }
  }

  Future<T?> _cached<T extends Object>(
    String metric,
    T Function(Map<String, Object?> json) parse,
    CacheSession session,
  ) async {
    final row = await _store.readLatest(metric, scope: session.scope);
    await session.ensureCurrent();
    if (row == null) {
      return null;
    }
    final decoded = jsonDecode(row.payload);
    if (decoded is! Map<String, Object?>) {
      AppLog.info(
        'sleep',
        'cached $metric payload for ${row.day} is not an object',
      );
      return null;
    }
    return parse(decoded);
  }

  static String _isoDay(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}

/// The app's [SleepRepository].
@riverpod
SleepRepository sleepRepository(Ref ref) => SleepRepository(
  ref.watch(apiClientProvider),
  ref.watch(localStoreProvider),
  credentials: ref.watch(credentialsProvider),
);

/// The nights and naps. Watch this from the Sleep screen.
@riverpod
Future<SleepPage> sleepPage(Ref ref) =>
    ref.watch(sleepRepositoryProvider).page();

/// Bedtime/wake regularity, the odd nights, and tonight's lever.
@riverpod
Future<SleepConsistency> sleepConsistency(Ref ref) =>
    ref.watch(sleepRepositoryProvider).consistency();

/// The grounded AI analysis of recent sleep.
@riverpod
Future<SleepInsight> sleepInsight(Ref ref) =>
    ref.watch(sleepRepositoryProvider).insight();
