/// What is still waiting to reach the server, and how it stops waiting.
///
/// The other end of `strap_writer.dart`: that file decides when a row becomes
/// pending, this one reads the pending rows out and marks them settled. They are
/// separate accessors because they have separate reasons to change — one follows
/// the BLE protocol, the other follows the ingest contract.
///
/// ## Resumability, and the one ordering rule
///
/// Rows are paged **oldest first** and marked only after the server has accepted
/// them. Three properties fall out of that and they are the whole design:
///
///   * a push that dies mid-way leaves every unacknowledged row pending, so the
///     next one resends exactly what did not land — nothing is lost;
///   * a resend is an upsert on the server, keyed by the measurement's own
///     identity (`(metric, ts)`, the session start, the workout start, the day),
///     so a row sent twice is stored once — nothing is double-counted;
///   * a backfilled row that is OLDER than everything already sent is pending by
///     construction, because the marker is on the row rather than on a cursor.
///
/// The last one is not hypothetical: the one-shot stress and nap passes exist
/// precisely to write old rows, and a high-water cursor would have skipped every
/// one of them permanently.
library;

import 'package:drift/drift.dart';
import 'package:healthee/data/push/push_batch.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/strap_writer.dart';
import 'package:healthee/data/store/tables.dart';

part 'push_reader.g.dart';

/// How many samples one request carries.
///
/// Bounded because a phone that has been offline for a fortnight holds tens of
/// thousands of rows, and one 40 MB body is a request that times out forever
/// while a hundred small ones finish. Standards §1 budgets a normal day's ingest
/// at under 5 s end to end; this is the page size that keeps a backlog made of
/// normal days.
const int kPushSampleLimit = 4000;

/// Reads unsent measurements and records what the server accepted.
@DriftAccessor(
  tables: [StrapSamples, SleepSessions, StoredWorkouts, DeviceTotals, SyncMeta],
)
class PushReader extends DatabaseAccessor<LocalStore> with _$PushReaderMixin {
  /// Built by drift as `store.pushReader`.
  PushReader(super.db);

  /// The next page of unsent rows, oldest first.
  ///
  /// Sleep, workouts and the daily counters are not paged: there are at most a
  /// few dozen of each inside the 60-day horizon, and splitting them would buy
  /// round-trips rather than save bytes. Only samples need a limit, and they are
  /// ordered by timestamp so a partial backlog always closes from the oldest
  /// end — a gap in the middle of the server's history is harder to notice than
  /// a history that simply has not caught up yet.
  Future<PushBatch> pending({int sampleLimit = kPushSampleLimit}) async {
    final samples = select(strapSamples)
      ..where((row) => row.pushedAtMs.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.tsMs)])
      ..limit(sampleLimit);
    final nights = select(sleepSessions)
      ..where((row) => row.pushedAtMs.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.startMs)]);
    final workouts = select(storedWorkouts)
      ..where((row) => row.pushedAtMs.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.startMs)]);
    final totals = select(deviceTotals)
      ..where((row) => row.pushedAtMs.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.day)]);

    return PushBatch(
      samples: await samples.get(),
      nights: await nights.get(),
      workouts: await workouts.get(),
      totals: await totals.get(),
    );
  }

  /// How many rows are still waiting, across every kind.
  ///
  /// For the sync-health surface. A push that keeps failing must be visible as a
  /// growing number rather than as a screen that looks fine.
  Future<int> pendingCount() async {
    final counts = await Future.wait<int>([
      _countPending(strapSamples, strapSamples.pushedAtMs),
      _countPending(sleepSessions, sleepSessions.pushedAtMs),
      _countPending(storedWorkouts, storedWorkouts.pushedAtMs),
      _countPending(deviceTotals, deviceTotals.pushedAtMs),
    ]);
    return counts.reduce((a, b) => a + b);
  }

  /// Records that the server accepted every row of [batch], at [at].
  ///
  /// **Called only after a 2xx.** Marking optimistically would turn a failed
  /// push into permanent data loss with no error anywhere: the rows would look
  /// sent, nothing would ever retry them, and the server would be missing days
  /// it never heard about. That is the #121 shape — a measurement with no
  /// durable home — and it is worth one extra round-trip's worth of caution.
  ///
  /// One transaction, so a page is settled all at once. A half-marked page is
  /// not wrong (the unmarked half simply resends) but it is a state nobody can
  /// reason about, and the transaction is free.
  Future<void> markPushed(PushBatch batch, DateTime at) {
    final stamp = Value(at.millisecondsSinceEpoch);
    return transaction(() async {
      for (final sample in batch.samples) {
        await (update(strapSamples)..where(
          (row) => row.metric.equals(sample.metric) & row.tsMs.equals(sample.tsMs),
        )).write(StrapSamplesCompanion(pushedAtMs: stamp));
      }
      for (final night in batch.nights) {
        await (update(sleepSessions)
              ..where((row) => row.startMs.equals(night.startMs)))
            .write(SleepSessionsCompanion(pushedAtMs: stamp));
      }
      for (final workout in batch.workouts) {
        await (update(storedWorkouts)
              ..where((row) => row.startMs.equals(workout.startMs)))
            .write(StoredWorkoutsCompanion(pushedAtMs: stamp));
      }
      for (final total in batch.totals) {
        // Guarded on `read_at_ms`: the counter grows all day, so a row rewritten
        // by a sync that overlapped this push is a NEWER reading than the one
        // the server accepted. Marking it here would send the 09:00 figure and
        // then never send the 21:00 one.
        await (update(deviceTotals)..where(
          (row) => row.day.equals(total.day) & row.readAtMs.equals(total.readAtMs),
        )).write(DeviceTotalsCompanion(pushedAtMs: stamp));
      }
    });
  }

  /// Records one push attempt, the way `StrapWriter.stampAttempt` records a pull.
  ///
  /// [complete] gates the one key a screen may read as "the server has
  /// everything", so a partial run cannot make the app look caught up.
  /// [failureReason] is CLEARED on success rather than left behind — a stale
  /// failure sentence sitting under a healthy push is a lie with a timestamp.
  Future<void> stampAttempt({
    required DateTime at,
    required String outcomeId,
    required bool complete,
    String? failureReason,
  }) async {
    await _setMeta(SyncKeys.lastPushAttemptMs, '${at.millisecondsSinceEpoch}');
    await _setMeta(SyncKeys.lastPushOutcome, outcomeId);
    await _setMeta(SyncKeys.lastPushFailure, failureReason ?? '');
    if (complete) {
      await _setMeta(SyncKeys.lastCompletePushMs, '${at.millisecondsSinceEpoch}');
    }
  }

  /// What the last push attempt did, for the data-health card.
  Future<PushStamp> lastAttempt() async {
    final failure = await _meta(SyncKeys.lastPushFailure);
    return PushStamp(
      lastCompletePush: _instant(await _meta(SyncKeys.lastCompletePushMs)),
      lastAttempt: _instant(await _meta(SyncKeys.lastPushAttemptMs)),
      outcomeId: await _meta(SyncKeys.lastPushOutcome),
      // Empty string is how "cleared" is stored; it is not a reason.
      failureReason: (failure == null || failure.isEmpty) ? null : failure,
      pendingRows: await pendingCount(),
      // Written by the prune, not by any push — but it is the same question
      // this type exists to answer, asked about rows that will never be sent
      // because they no longer exist. `horizon_prune.dart` owns the encoding.
      loss: await db.horizonPrune.loss(),
    );
  }

  Future<void> _setMeta(String name, String value) {
    return into(syncMeta).insertOnConflictUpdate(
      SyncMetaRow(name: name, value: value),
    );
  }

  Future<String?> _meta(String name) async {
    final query = select(syncMeta)..where((row) => row.name.equals(name));
    return (await query.getSingleOrNull())?.value;
  }

  static DateTime? _instant(String? ms) {
    final value = int.tryParse(ms ?? '');
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<int> _countPending<T extends HasResultSet, D>(
    ResultSetImplementation<T, D> table,
    GeneratedColumn<int> marker,
  ) async {
    final total = countAll(filter: marker.isNull());
    final query = selectOnly(table)..addColumns([total]);
    return (await query.getSingle()).read(total) ?? 0;
  }
}
