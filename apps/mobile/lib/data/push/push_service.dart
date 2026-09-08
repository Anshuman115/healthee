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
/// the run is a loop over pages, and the loop is bounded by [PushService.maxPages]
/// rather than by "until nothing is pending", because a loop whose exit depends
/// on a write it does not verify is a loop that can spin forever on a bug in the
/// marker. It stops early on a short page, which is the normal exit.
///
/// ## The outer drain, and why it is safe where an unbounded inner loop is not
///
/// The page bound is correct and stays. What it left behind was a backlog that
/// nothing drained: hitting the cap sent 80,000 samples and then waited for the
/// owner to press a button again, once per cap, forever. So [PushService.drain]
/// repeats [PushService.run] — but only while the round it just finished can be
/// **proved** to have moved the backlog:
///
///   * `rowsSent > 0` — the server acknowledged something this round; and
///   * the pending count **strictly fell** across the round.
///
/// The second is the check the inner loop cannot make and the whole reason this
/// loop is allowed to exist. The inner loop's feared bug is a broken marker:
/// pages send, `markPushed` writes nothing, the same page resends forever. Under
/// that bug `rowsSent` keeps growing — so `rowsSent > 0` alone would spin too —
/// while the pending count does not move. Reading it before and after is what
/// turns "I did some work" into "the queue is smaller than it was", which is the
/// only progress that can terminate this loop.
///
/// It is still bounded by [PushService.maxDrainRounds] as a backstop, because a
/// loop that terminates only by argument is a loop one wrong `<` away from not
/// terminating at all. Any [PushFailed], [PushInterrupted] or [PushSkipped] stops
/// it on the spot: those are not slow progress, they are the transport or the
/// token, and retrying them in a tight loop is how a phone burns a battery
/// telling itself the same bad news.
library;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/push/push_client.dart';
import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/push_reader.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/device_lease.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_service.g.dart';

/// Sends everything the local tier is holding back.
class PushService {
  /// [store] supplies both the pending rows and the bookkeeping.
  ///
  /// The three bounds default to the shipping values and are constructor
  /// parameters only so a test can reach them. A guard that cannot be exercised
  /// at a realistic cost is a guard nobody has run: hitting [maxPages] honestly
  /// takes 80,000 rows, and a suite that will not pay that price ships an
  /// unexercised loop exit.
  const PushService({
    required this.store,
    required this.client,
    required this.credentials,
    this.pageLimit = kPushSampleLimit,
    this.maxPages = 20,
    this.maxDrainRounds = 12,
  });

  /// The local tier — read from and stamped by this service.
  final LocalStore store;

  /// The ingest call.
  final PushClient client;

  /// Where the API bearer token lives. Read per run, never cached.
  final Credentials credentials;

  /// How many samples one request carries. [kPushSampleLimit] in the app.
  final int pageLimit;

  /// A backlog can be big; a runaway loop must not be. Twenty pages of
  /// [kPushSampleLimit] is 80,000 samples in ONE run.
  final int maxPages;

  /// How many times [drain] may repeat [run]. Twelve rounds of [maxPages] is
  /// close to a million samples — far beyond what the 60-day horizon can hold,
  /// so reaching it means something is wrong rather than that somebody was busy.
  final int maxDrainRounds;

  /// Sends every pending row, oldest first, and records what happened.
  ///
  /// Never throws. A push failure is background work failing, and Standards §1
  /// requires those to reach a health surface rather than an exception nobody
  /// catches: the outcome is returned, stamped into [SyncMeta] for the data
  /// health card to read, and logged through the one logging path.
  Future<PushOutcome> run({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final lease = DeviceLease(store, resource: 'push_lease');
    if (!await lease.acquire()) {
      return const PushSkipped('Another upload is already running');
    }
    try {
      final outcome = await _attempt(at);
      await _stamp(at, outcome);
      return outcome;
    } finally {
      await lease.release();
    }
  }

  /// Repeats [run] until the backlog is gone, it stops shrinking, or it faults.
  ///
  /// The termination argument is in this file's library docstring; the code
  /// below is that argument and nothing more. Two things are worth reading here.
  ///
  /// Every round stamps, because a drain over a large backlog takes real time
  /// and a health surface that only becomes true at the end is stale for all of
  /// it — and a phone killed mid-drain would otherwise leave the previous run's
  /// stamp standing over a backlog that has since moved. The aggregate is
  /// stamped again at the end, so the sentence the owner reads counts the whole
  /// drain rather than its last round.
  ///
  /// A stall — a round that reports progress the pending count does not confirm
  /// — is returned as [PushInterrupted] and therefore **as a fault**. It is the
  /// marker bug the inner loop's bound was written against, and the one push
  /// state where "it goes out on the next sync" would be false.
  Future<PushOutcome> drain({DateTime? now}) async {
    final at = now ?? DateTime.now();
    var total = 0;
    var pending = await pendingCount();
    for (var round = 0; round < maxDrainRounds; round++) {
      final outcome = await run(now: at);
      total += outcome.rowsSent;
      if (outcome is! PushPaused) {
        // Sent (the backlog is gone), failed, interrupted or skipped. Each is
        // the whole answer for this drain; only the row count is aggregated.
        return _finish(at, _aggregate(outcome, total));
      }
      final remaining = await pendingCount();
      if (outcome.rowsSent <= 0 || remaining >= pending) {
        return _finish(at, _stalled(total, remaining));
      }
      pending = remaining;
    }
    return _finish(
      at,
      PushPaused(
        rows: total,
        reason:
            'the backlog is still large; the rest goes out on the next sync',
      ),
    );
  }

  /// How many rows are still waiting. For the sync-health surface.
  Future<int> pendingCount() => store.pushReader.pendingCount();

  Future<PushOutcome> _attempt(DateTime at) async {
    final String? token;
    try {
      token = await credentials.apiToken();
    } on PlatformException catch (error, stackTrace) {
      // The keystore itself refused. This method's contract is that it never
      // throws, and that contract stopped being a nicety when the push became
      // unattended: an exception raised inside a foreground transition has no
      // caller to catch it and no screen to land on. Standards §1 — background
      // work reports to its health surface.
      AppLog.failure('push', 'reading the API token', error, stackTrace);
      return PushFailed(
        "this phone's secure storage could not be read (${error.code})",
      );
    } on MissingPluginException catch (error, stackTrace) {
      // A separate type, and deliberately not folded into the one above: this
      // is a BUILD fault (the keystore plugin is not registered), not a device
      // one, and the two need different sentences or whoever reads the log
      // starts looking at the phone's security settings.
      AppLog.failure('push', 'reading the API token', error, stackTrace);
      return const PushFailed(
        'this build has no secure storage, so there is no token to send with',
      );
    }
    if (token == null || token.isEmpty) {
      // Not a fault and not coloured as one. Everything stays pending, so
      // signing in later sends the whole backlog rather than starting from then.
      return const PushSkipped(
        'Not signed in to your server yet — your strap data is being kept here '
        'until you are.',
      );
    }

    var sent = 0;
    for (var page = 0; page < maxPages; page++) {
      final batch = await store.pushReader.pending(sampleLimit: pageLimit);
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
        AppLog.failure(
          'push',
          'sending ${batch.rowCount} rows',
          error,
          stackTrace,
        );
        final reason = _reasonFor(error);
        // Nothing is marked, so nothing is lost. `sent` decides whether this run
        // moved anything at all, which is the difference the owner can see.
        return sent == 0
            ? PushFailed(reason)
            : PushInterrupted(rows: sent, reason: reason);
      }
      await store.pushReader.markPushed(batch, at);
      sent += batch.rowCount;
      if (batch.samples.length < pageLimit) {
        // A short page is the last page: sleep, workouts and counters are never
        // paged, so only samples can fill one.
        return PushSent(sent);
      }
    }
    // The page cap, reached with every page accepted. This is the design
    // working, not a fault — [drain] takes it from here.
    return PushPaused(
      rows: sent,
      reason: 'there is still more waiting; it goes out on the next sync',
    );
  }

  /// One drain's whole story, told with the row count of the whole drain.
  ///
  /// The [PushFailed] branch is the interesting one: rows that landed in an
  /// earlier round and then a transport that died is the [PushInterrupted]
  /// shape, and reporting it as "nothing landed" would understate a drain that
  /// moved most of a backlog.
  static PushOutcome _aggregate(PushOutcome last, int total) => switch (last) {
    PushSent() => PushSent(total),
    PushPaused(:final reason) => PushPaused(rows: total, reason: reason),
    PushInterrupted(:final reason) => PushInterrupted(
      rows: total,
      reason: reason,
    ),
    PushFailed(:final reason) =>
      total == 0
          ? PushFailed(reason)
          : PushInterrupted(rows: total, reason: reason),
    // Skipped can only mean the token went away mid-drain. Still not a fault,
    // and still the whole answer for why the rest is not going anywhere.
    PushSkipped() => last,
  };

  /// A round claimed progress the pending count did not confirm.
  ///
  /// Reported as a fault, because it is the one push state where "it goes out on
  /// the next sync" would be a promise nothing can keep: the next sync would
  /// take the same page and stall in the same place.
  static PushOutcome _stalled(int total, int remaining) => PushInterrupted(
    rows: total,
    reason:
        'sending is not reducing the backlog — $remaining measurements are '
        'still waiting',
  );

  /// Stamps the whole drain over its last round, and hands the outcome back.
  Future<PushOutcome> _finish(DateTime at, PushOutcome outcome) async {
    await _stamp(at, outcome);
    return outcome;
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
  ///
  /// A failure reason is written **only for a fault**. [PushPaused] leaves it
  /// null deliberately: the card keys its loud sentence on this field, and a
  /// deliberate pause with a reason in that slot is exactly how a working design
  /// got reported as a failure.
  Future<void> _stamp(DateTime at, PushOutcome outcome) async {
    await store.pushReader.stampAttempt(
      at: at,
      outcomeId: outcome.id,
      complete: outcome.isComplete,
      failureReason: switch (outcome) {
        PushFailed(:final reason) => reason,
        PushInterrupted(:final reason) => reason,
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
