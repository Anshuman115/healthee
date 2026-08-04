/// Fetches and parses `GET /api/today` — the whole boundary, end to end.
///
/// The pipeline this file completes: dio (one client, authenticated) → JSON →
/// [TodaySnapshot.fromJson] → typed model with [Reading] fields → a provider a
/// screen watches. Nothing above this line sees a `Map<String, Object?>` again,
/// which is Standards §3's "typed models at the data boundary" in one function.
///
/// ## Errors propagate; they are not converted to empty
///
/// A failed request throws, and Riverpod turns that into `AsyncError` for
/// [AsyncView] to render with a retry. Returning an empty [TodaySnapshot] on
/// failure would be the exact banned pattern — "returning empty-string/empty-map
/// to mean 'something failed'" (Standards §1) — and would show the owner a page
/// of withheld cards implying their data is missing when it is merely unreached.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/provider_logger.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_repository.g.dart';

/// Reads the Today payload.
class TodayRepository {
  /// Wraps the app's one dio client.
  const TodayRepository(this._dio);

  final Dio _dio;

  /// Fetches and parses today's snapshot.
  ///
  /// Throws on a transport failure or a body that is not the shape the contract
  /// pins. There is deliberately **no** `try`/`catch` here: a parse failure is a
  /// wire-contract break, and catching it would only let us re-throw it after
  /// logging. [ProviderLogger] already logs every provider failure through the
  /// one logging path, so the log entry happens either way and the error still
  /// reaches the UI as a retryable `AsyncError`.
  Future<TodaySnapshot> fetch() async {
    final response = await _dio.get<Map<String, Object?>>('/api/today');
    final body = response.data;
    if (body == null) {
      // An empty body is not an empty snapshot. Saying so out loud keeps "no
      // data" and "the request failed" distinguishable (Standards §1).
      throw const FormatException('GET /api/today returned an empty body');
    }
    return TodaySnapshot.fromJson(body);
  }
}

/// The app's [TodayRepository].
@riverpod
TodayRepository todayRepository(Ref ref) => TodayRepository(ref.watch(apiClientProvider));

/// Today's snapshot. Watch this from the Today screen.
@riverpod
Future<TodaySnapshot> todaySnapshot(Ref ref) => ref.watch(todayRepositoryProvider).fetch();
