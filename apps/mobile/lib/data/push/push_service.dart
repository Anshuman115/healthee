/// The push, start to finish: pending rows → `/ingest/helio` → marked sent.
///
/// ```text
///   SQLite ──PushReader──▶ PushBatch ──PushClient──▶ server
///                              │
///                              └──(only on 2xx)──▶ pushed_at_ms stamped
/// ```
///
/// ## The order is the whole safety argument
///
/// Read, send, **then** mark. Every other order loses data:
///
///   * mark-then-send turns any failure into permanent loss — the rows look
///     sent, nothing retries them, and no error survives the app being closed;
///   * delete-then-send is the same thing with the evidence destroyed.
///
/// Marking last costs one thing — a push that dies *after* the server accepted a
/// page resends that page next time — and the server is an upsert keyed on each
/// measurement's own identity, so the cost is a duplicate request, never a
/// duplicate row. Trading a wasted request against a lost day is not a close
/// call.
///
/// ## Why it pages, and why the loop is bounded
///
/// A phone that has been away from the network for a fortnight is holding tens
/// of thousands of samples. One request for all of them is one request that
/// times out forever while a hundred small ones would have finished — the exact
/// failure the legacy client's 180-second timeout was raised to paper over. So
/// the run is a loop over pages, and the loop is bounded by [_maxPages] rather
/// than by "until nothing is pending", because a loop whose exit depends on a
/// write it does not verify is a loop that can spin forever on a bug in the
/// marker. It stops early on a short page, which is the normal exit.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/push/push_client.dart';
import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/push_reader.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_service.g.dart';

/// Sends everything the local tier is holding back.
class PushService {
  /// [store] supplies both the pending rows and the bookkeeping.
  const PushService({
    required this.store,
    required this.client,
    required this.credentials,
  });

  /// The local tier — read from and stamped by this service.
  final LocalStore store;

  /// The ingest call.
  final PushClient client;

  /// Where the API bearer token lives. Read per run, never cached.
  final Credentials credentials;

  /// A backlog can be big; a runaway loop must not be. Twenty pages of
  /// [kPushSampleLimit] is 80,000 samples — comfortably more than the 60-day
  /// horizon can hold, so hitting this bound means a bug, not a busy owner.
  static const int _maxPages = 20;

  /// Sends every pending row, oldest first, and records what happened.
  ///
  /// Never throws. A push failure is background work failing, and Standards §1
  /// requires those to reach a health surface rather than an exception nobody
  /// catches: the outcome is returned, stamped into [SyncMeta] for the data
  /// health card to read, and logged through the one logging path.
  Future<PushOutcome> run({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final outcome = await _attempt(at);
    await _stamp(at, outcome);
    return outcome;
  }

  /// How many rows are still waiting. For the sync-health surface.
  Future<int> pendingCount() => store.pushReader.pendingCount();

  Future<PushOutcome> _attempt(DateTime at) async {
    final token = await credentials.apiToken();
    if (token == null || token.isEmpty) {
      // Not a fault and not coloured as one. Everything stays pending, so
      // signing in later sends the whole backlog rather than starting from then.
      return const PushSkipped(
        'Not signed in to your server yet — your strap data is being kept here '
        'until you are.',
      );
    }

    var sent = 0;
    for (var page = 0; page < _maxPages; page++) {
      final batch = await store.pushReader.pending();
      if (batch.isEmpty) {
        return PushSent(sent);
      }
      try {
        final receipt = await client.send(batch);
        AppLog.info('push', 'page $page: ${batch.rowCount} rows → $receipt');
        if (receipt.samplesRejected > 0) {
          // The whitelist and our map have drifted. Said out loud because the
          // server drops these silently by design, and a silent drop that
          // nobody reports is a metric quietly missing from the owner's history.
          AppLog.info(
            'push',
            'the server did not recognise ${receipt.samplesRejected} samples — '
            'check kPushMetricNames against ingest ALLOWED_METRICS',
          );
        }
      } on DioException catch (error, stackTrace) {
        AppLog.failure('push', 'sending ${batch.rowCount} rows', error, stackTrace);
        final reason = _reasonFor(error);
        // Nothing is marked, so nothing is lost. `sent` decides whether this run
        // moved anything at all, which is the difference the owner can see.
        return sent == 0
            ? PushFailed(reason)
            : PushPartial(rows: sent, reason: reason);
      }
      await store.pushReader.markPushed(batch, at);
      sent += batch.rowCount;
      if (batch.samples.length < kPushSampleLimit) {
        // A short page is the last page: sleep, workouts and counters are never
        // paged, so only samples can fill one.
        return PushSent(sent);
      }
    }
    return PushPartial(
      rows: sent,
      reason: 'there is still more waiting; it goes out on the next sync',
    );
  }

  /// Turns a transport failure into a sentence, without inventing a remedy.
  ///
  /// The taxonomy is deliberately coarse. `sync_failure.dart` is rich because a
  /// BLE failure has an action the owner can take ("turn Bluetooth on"); a push
  /// failure usually does not, and offering one we made up would be worse than
  /// saying plainly that the server could not be reached.
  static String _reasonFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'the server did not accept this phone (HTTP $status) — the token '
          'may have been rotated';
    }
    if (status != null) {
      return 'the server answered HTTP $status';
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'it took too long to answer',
      DioExceptionType.connectionError => 'it could not be reached',
      _ => 'the request did not complete',
    };
  }

  /// Records the attempt where the data-health card can read it.
  ///
  /// Same two-timestamp discipline as `StrapWriter.stampAttempt`: only a
  /// complete run moves the "last complete push" key, so a run that sent four
  /// pages of six cannot make the app look caught up.
  Future<void> _stamp(DateTime at, PushOutcome outcome) async {
    await store.pushReader.stampAttempt(
      at: at,
      outcomeId: outcome.id,
      complete: outcome.isComplete,
      failureReason: switch (outcome) {
        PushFailed(:final reason) => reason,
        PushPartial(:final reason) => reason,
        _ => null,
      },
    );
    AppLog.info('push', outcome.summary);
  }
}

/// The app's [PushService].
@Riverpod(keepAlive: true)
PushService pushService(Ref ref) => PushService(
  store: ref.watch(localStoreProvider),
  client: ref.watch(pushClientProvider),
  credentials: ref.watch(credentialsProvider),
);
