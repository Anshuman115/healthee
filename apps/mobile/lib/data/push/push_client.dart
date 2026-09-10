/// `POST /ingest/helio` — the one call that sends measurements to the server.
///
/// Thin on purpose: build the body, send it, read the receipt. What to send and
/// when to mark it sent are decided in `push_batch.dart` and `push_service.dart`
/// respectively, because those are different reasons to change.
///
/// ## The receipt is read, not assumed
///
/// The ingest endpoint answers with counts, including `samples_rejected` — rows
/// it coerce-dropped because their metric is not on its whitelist. A client that
/// ignored that would report "sent 4,000 measurements" for a push the server
/// mostly threw away, which is the kind of confident wrongness this product is
/// built against. [PushReceipt] carries it out so the service can log it and the
/// tests can assert on it.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/push/push_batch.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_client.g.dart';

/// The ingest path. One constant, because a typo here is a silent 404 loop.
const String kIngestPath = '/ingest/helio';

/// What the server says it did with a push.
///
/// The field names are `IngestSummary`'s, read off
/// `apps/server/src/healthee/ingest/service.py` rather than guessed.
@immutable
class PushReceipt {
  /// Built from the ingest response body.
  const PushReceipt({
    required this.samplesAccepted,
    required this.samplesRejected,
    required this.nights,
    required this.workouts,
    required this.dailyTotals,
    required this.daysDerived,
  });

  /// Parses the receipt. A missing counter reads as zero — the endpoint answered
  /// 2xx, so the push landed; an absent key is a shape question, not a failure.
  factory PushReceipt.fromJson(Map<String, Object?> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PushReceipt(
      samplesAccepted: count('samples_accepted'),
      samplesRejected: count('samples_rejected'),
      nights: count('sleep'),
      workouts: count('workouts'),
      dailyTotals: count('daily_totals'),
      daysDerived: count('days_derived'),
    );
  }

  /// Samples the server STORED — new or not.
  ///
  /// The server returns `len(rows)`: every whitelisted sample in the payload,
  /// including the ones its `ON CONFLICT` branch merely rewrote with the
  /// identical value. "Accepted" reads as "landed and was new"; it means "was
  /// not rejected" (write-path audit D4), and this app re-sends nothing already
  /// marked pushed, so on a healthy sync the two coincide — a retry after a
  /// dropped response is where they part.
  ///
  /// The receipt line says `stored` rather than `accepted` for that reason. Low
  /// consequence, and it is the sync surface: a whole session was once lost to
  /// misreading a counter of exactly this kind.
  final int samplesAccepted;

  /// Samples the server dropped because it does not know the metric.
  ///
  /// Non-zero means [kPushMetricNames] and the server's `ALLOWED_METRICS` have
  /// drifted apart. Worth a log line every time, because a coerce-drop is
  /// deliberately not a 422 and nothing else would say so.
  final int samplesRejected;

  /// Sleep records upserted.
  final int nights;

  /// Workout summaries upserted.
  final int workouts;

  /// Daily counters that reached `device_daily_total` — **the #121 number**.
  ///
  /// The one row on this receipt worth checking by eye: it is the authoritative
  /// step total, it cannot be re-read tomorrow, and 142 production days were
  /// lost because nothing was watching it.
  final int dailyTotals;

  /// How many owner-local days the push re-derived.
  final int daysDerived;

  @override
  String toString() =>
      'stored $samplesAccepted · rejected $samplesRejected · '
      '$nights sleep · $workouts workouts · $dailyTotals daily totals · '
      '$daysDerived days derived';
}

/// Sends one [PushBatch].
class PushClient {
  /// Wraps the app's one dio client.
  const PushClient(this._dio);

  final Dio _dio;

  /// The phone's IANA zone, or null when the platform will not say.
  ///
  /// ⛔ **The server had no other way to learn this**, and it decides the owner's
  /// day boundary — which day a sample lands on, when the nightly chain runs, and
  /// which dates `/api/today` will even accept. Every account provisioned from a
  /// Supabase sign-in kept the column default `UTC`; measured on real data, that
  /// filed **27.9% of samples** under the previous day and made `/api/today`
  /// refuse the phone's own date as "in the future" for five and a half hours
  /// every night.
  ///
  /// Sent on every push rather than once at sign-in, because people travel and a
  /// zone captured at sign-up is a fact that silently goes stale.
  ///
  /// Null on failure, and the push proceeds without it: this is a courtesy field
  /// on a request whose job is delivering measurements, and a platform channel
  /// that will not answer must not cost the owner their data. Bounded for the same
  /// reason `settings/app_version.dart` is — an unanswered channel has no other end.
  Future<String?> _localTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 2),
      );
      return zone.identifier.isEmpty ? null : zone.identifier;
    } on Object catch (error) {
      AppLog.info('push', 'the platform did not name its timezone: ${error.runtimeType}');
      return null;
    }
  }

  /// Posts [batch] and returns the server's receipt.
  ///
  /// Throws `DioException` on any non-2xx or transport failure, deliberately
  /// without catching: the caller must not mark these rows as sent, and the only
  /// way to make that impossible is to not return normally. Swallowing here and
  /// returning an empty receipt would be the banned "empty means failed" pattern
  /// (Standards §1) with data loss attached.
  Future<PushReceipt> send(PushBatch batch) async {
    final response = await _dio.post<Map<String, Object?>>(
      kIngestPath,
      data: <String, Object?>{
        ...batch.toJson(),
        // Added HERE and not in `PushBatch`, because the zone is a fact about the
        // phone at the moment of pushing rather than about the rows being pushed:
        // the same stored samples sent from a different country carry a different
        // one, and the batch is built from the local store.
        if (await _localTimezone() case final String zone) 'timezone': zone,
      },
      // Per-call, not on the client: every OTHER endpoint should still fail fast
      // at ten seconds, and a shared 180 s would make a dead network look like a
      // slow screen everywhere.
      options: Options(
        sendTimeout: Env.pushTimeout,
        receiveTimeout: Env.pushTimeout,
      ),
    );
    return PushReceipt.fromJson(response.data ?? const <String, Object?>{});
  }
}

/// The app's [PushClient].
@riverpod
PushClient pushClient(Ref ref) => PushClient(ref.watch(apiClientProvider));
