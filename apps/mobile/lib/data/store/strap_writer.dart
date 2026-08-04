/// Everything a sync writes, and the watermarks the next sync resumes from.
///
/// ## Resumability is a property of the STORE, not of the sync
///
/// The watermark this hands back is `MAX(ts_ms)` over the rows that are actually
/// on disk — not a cursor the sync engine remembered, and not a "we got to here"
/// note written at the end of a run. That choice is the whole resumability
/// design, and it is worth stating why:
///
/// A remembered cursor is a second claim about what we hold, and it can be
/// wrong in the direction that loses data. A pull that dies with three metrics
/// stored and six not would leave a cursor written for all nine (if written
/// optimistically) or for none (if written at the end), and either way the next
/// run asks the strap for the wrong window. Deriving the watermark from the rows
/// means a half-finished sync resumes exactly where its own data stopped, per
/// metric, with no bookkeeping to keep honest.
///
/// The two one-shot backfill flags are the exception and they are handled the
/// conservative way — see [markBackfillsRan].
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:healthee/ble/models/strap_sync_result.dart';
import 'package:healthee/ble/models/strap_sync_window.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/tables.dart';

part 'strap_writer.g.dart';

/// The names [SyncMeta] rows are filed under. Constants, because a mistyped
/// literal here reads back as "never done" and silently re-runs a wide pass.
abstract final class SyncKeys {
  /// Whether the one-time wide stress pass has ever completed.
  static const String stressBackfillDone = 'stress_backfill_done';

  /// Whether the one-time 14-day nap pass has ever completed.
  static const String napBackfillDone = 'nap_backfill_done';

  /// Epoch ms of the last sync that finished **completely**.
  static const String lastCompleteSyncMs = 'last_complete_sync_ms';

  /// Epoch ms of the last sync attempt, complete or not.
  static const String lastAttemptMs = 'last_attempt_ms';

  /// The last attempt's outcome id — see `SyncOutcome.id`.
  static const String lastOutcome = 'last_outcome';

  /// Strap battery percent as of the last connection.
  static const String batteryPercent = 'strap_battery_percent';

  /// Epoch ms of the last push that sent everything pending.
  static const String lastCompletePushMs = 'last_complete_push_ms';

  /// Epoch ms of the last push attempt, complete or not.
  static const String lastPushAttemptMs = 'last_push_attempt_ms';

  /// The last push attempt's outcome id — see `PushOutcome.id`.
  static const String lastPushOutcome = 'last_push_outcome';

  /// Why the last push failed, in the owner's words. Absent after a good push.
  static const String lastPushFailure = 'last_push_failure';

  /// How many measurements this phone has destroyed before the server saw them.
  ///
  /// Cumulative and **never cleared**. `horizon_prune.dart` writes it; nothing
  /// resets it, because nothing undoes what it counts.
  static const String droppedUnsentRows = 'dropped_unsent_rows';

  /// The newest calendar day among those measurements, `YYYY-MM-DD`.
  static const String droppedUnsentThroughDay = 'dropped_unsent_through_day';

  /// Epoch ms of the most recent prune that destroyed something.
  static const String droppedUnsentAtMs = 'dropped_unsent_at_ms';
}

/// "This row has not reached the server", as a SQL expression.
///
/// Named because `const Constant<int>(null)` reads like a mistake at four call
/// sites and like a decision at one.
const Constant<int> _pending = Constant<int>(null);

/// Writes raw strap data to the local tier and reports where to resume.
@DriftAccessor(
  tables: [StrapSamples, SleepSessions, StoredWorkouts, DeviceTotals, SyncMeta],
)
class StrapWriter extends DatabaseAccessor<LocalStore> with _$StrapWriterMixin {
  /// Built by drift as `store.strapWriter`.
  StrapWriter(super.db);

  /// Stores everything one sync pulled. Idempotent.
  ///
  /// Every table's primary key is the measurement's own identity — `(metric,
  /// ts)`, the session start, the workout start, the day — so a re-pulled window
  /// replaces rather than duplicates. The fetch plan re-pulls on purpose (two
  /// days of sleep so a late nap is picked up, one day of workout overlap), and
  /// a store that grew a copy each time would make the overlap a leak.
  ///
  /// One batch, so a sync is one transaction: a store holding half a night is
  /// worse than a store holding none of it, because nothing downstream can tell.
  ///
  /// ## What a re-write does to the push marker
  ///
  /// Every conflict clause below is spelled out rather than left to
  /// `insertAllOnConflictUpdate`, because the interesting column is the one that
  /// is NOT in it. A sample keeps `pushed_at_ms` — its value cannot change under
  /// its own key, so re-sending it would be work with no answer. A night, a
  /// workout and the daily counter all CLEAR it: those three genuinely change
  /// under the same key (a night gains stages, the counter grows all day), and a
  /// row the server holds an earlier version of is a row still waiting to be
  /// sent. See `tables.dart` for the full argument.
  Future<void> saveSync(StrapSyncResult result) {
    return batch((batch) {
      batch.insertAll(strapSamples, [
        for (final sample in result.samples)
          StrapSamplesCompanion.insert(
            metric: sample.metric,
            tsMs: sample.date.millisecondsSinceEpoch,
            day: isoDay(sample.date),
            value: sample.value,
          ),
      ], onConflict: DoUpdate<StrapSamples, StoredSample>.withExcluded(
        (_, incoming) => StrapSamplesCompanion.custom(
          day: incoming.day,
          value: incoming.value,
        ),
      ));
      batch.insertAll(sleepSessions, [
        for (final night in result.sleepSessions)
          SleepSessionsCompanion.insert(
            // `Value(...)` because a single INTEGER PRIMARY KEY is SQLite's
            // rowid alias, so drift makes it optional and would happily
            // auto-assign one. The strap's own session start IS the identity
            // here — an assigned id would make every re-pull a new night.
            startMs: Value(night.sessionStart.millisecondsSinceEpoch),
            day: isoDay(night.sessionStart),
            isNap: night.isNap,
            sleepStartMin: night.sleepStartMin,
            sleepEndMin: night.sleepEndMin,
            avgHr: night.avgHr,
            score: night.score,
            remMin: night.remMin,
            lightMin: night.lightMin,
            deepMin: night.deepMin,
            wakeMin: night.wakeMin,
            stagesJson: jsonEncode([
              for (final stage in night.stages)
                [
                  stage.start.millisecondsSinceEpoch,
                  stage.end.millisecondsSinceEpoch,
                  stage.type,
                ],
            ]),
          ),
      ], onConflict: DoUpdate<SleepSessions, StoredSleepSession>.withExcluded(
        (_, incoming) => SleepSessionsCompanion.custom(
          day: incoming.day,
          isNap: incoming.isNap,
          sleepStartMin: incoming.sleepStartMin,
          sleepEndMin: incoming.sleepEndMin,
          avgHr: incoming.avgHr,
          score: incoming.score,
          remMin: incoming.remMin,
          lightMin: incoming.lightMin,
          deepMin: incoming.deepMin,
          wakeMin: incoming.wakeMin,
          stagesJson: incoming.stagesJson,
          pushedAtMs: _pending,
        ),
      ));
      batch.insertAll(storedWorkouts, [
        for (final workout in result.workouts)
          StoredWorkoutsCompanion.insert(
            startMs: Value(workout.start.millisecondsSinceEpoch),
            day: isoDay(workout.start),
            sportType: workout.sportType,
            durationSec: workout.durationSec,
            calories: workout.calories,
            avgHr: workout.avgHr,
            maxHr: workout.maxHr,
            minHr: workout.minHr,
          ),
      ], onConflict: DoUpdate<StoredWorkouts, StoredWorkout>.withExcluded(
        (_, incoming) => StoredWorkoutsCompanion.custom(
          day: incoming.day,
          sportType: incoming.sportType,
          durationSec: incoming.durationSec,
          calories: incoming.calories,
          avgHr: incoming.avgHr,
          maxHr: incoming.maxHr,
          minHr: incoming.minHr,
          pushedAtMs: _pending,
        ),
      ));
      // #121, one layer up. The counter is "since midnight" and is therefore
      // NOT re-readable tomorrow — if it does not land here on the day it was
      // read, that day's real step count is gone the way the server's 142 days
      // went. `if` rather than a null-safe write because a strap that did not
      // answer must not overwrite a good earlier reading with a zero.
      if (result.dailyTotals case final totals?) {
        batch.insert(
          deviceTotals,
          DeviceTotalsCompanion.insert(
            day: isoDay(totals.readAt),
            steps: totals.steps,
            distanceM: totals.distanceM,
            calories: totals.calories,
            readAtMs: totals.readAt.millisecondsSinceEpoch,
          ),
          onConflict: DoUpdate((_) => DeviceTotalsCompanion.custom(
            steps: Constant(totals.steps),
            distanceM: Constant(totals.distanceM),
            calories: Constant(totals.calories),
            readAtMs: Constant(totals.readAt.millisecondsSinceEpoch),
            // The counter grew since the last push, so the server's copy is no
            // longer this row. Pending again.
            pushedAtMs: _pending,
          )),
        );
      }
    });
  }

  /// Where the next sync should resume from, read off the stored rows.
  ///
  /// A metric with no rows is absent from `lastSampleAt`, which `StrapSync`
  /// reads as "fetch from the 30-day backfill floor" — the right answer for a
  /// phone that has never held it.
  Future<StrapSyncWindow> resumeWindow() async {
    final newest = strapSamples.tsMs.max();
    final perMetric = selectOnly(strapSamples)
      ..addColumns([strapSamples.metric, newest])
      ..groupBy([strapSamples.metric]);

    final watermarks = <String, DateTime>{};
    for (final row in await perMetric.get()) {
      final ts = row.read(newest);
      if (ts != null) {
        watermarks[row.read(strapSamples.metric)!] =
            DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }

    return StrapSyncWindow(
      lastSampleAt: watermarks,
      lastSleepStart: await _newestInstant(sleepSessions.startMs, sleepSessions),
      lastWorkoutStart: await _newestInstant(
        storedWorkouts.startMs,
        storedWorkouts,
      ),
      stressBackfillDone: await _flag(SyncKeys.stressBackfillDone),
      napBackfillDone: await _flag(SyncKeys.napBackfillDone),
    );
  }

  /// Records that a wide one-shot pass ran to completion.
  ///
  /// Called ONLY after a sync that finished — deliberately conservative. A flag
  /// set for a pass that died mid-way would close a gap that is still open and
  /// nothing would ever revisit it; a flag left unset merely costs one extra
  /// wide fetch. `StrapSyncResult` reports these as **ran**, not as "should now
  /// be true", so this cannot mark a pass that never started.
  Future<void> markBackfillsRan(StrapSyncResult result) async {
    if (result.stressBackfillRan) {
      await _setMeta(SyncKeys.stressBackfillDone, 'true');
    }
    if (result.napBackfillRan) {
      await _setMeta(SyncKeys.napBackfillDone, 'true');
    }
  }

  /// Stamps an attempt: when it happened, its outcome id, and — only when the
  /// pull was complete — when the last complete sync was.
  ///
  /// The two timestamps are separate because a partial pull must never be able
  /// to move the one the screen shows as "up to date". That is the whole of
  /// "partial state must not be presented as complete", written where it is
  /// enforced rather than where it is rendered.
  Future<void> stampAttempt({
    required DateTime at,
    required String outcomeId,
    required bool complete,
  }) async {
    await _setMeta(SyncKeys.lastAttemptMs, '${at.millisecondsSinceEpoch}');
    await _setMeta(SyncKeys.lastOutcome, outcomeId);
    if (complete) {
      await _setMeta(
        SyncKeys.lastCompleteSyncMs,
        '${at.millisecondsSinceEpoch}',
      );
    }
  }

  /// Records the strap's battery, when the connection reported one.
  ///
  /// Null is not written. An unreadable battery characteristic must not clear a
  /// figure we had, and it certainly must not store a zero — "we could not ask"
  /// and "the strap is flat" would then look identical on the device card.
  Future<void> stampBattery(int? percent) async {
    if (percent != null) {
      await _setMeta(SyncKeys.batteryPercent, '$percent');
    }
  }

  /// When a sync last finished **completely**, or null if none ever has.
  ///
  /// Deliberately not "the last sync": a partial pull never writes this key, so
  /// a screen reading it cannot show a half-finished sync as an up-to-date one.
  Future<DateTime?> lastCompleteSync() async {
    final ms = int.tryParse(await meta(SyncKeys.lastCompleteSyncMs) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// One [SyncMeta] value, or null when it was never written.
  Future<String?> meta(String name) async {
    final query = select(syncMeta)..where((row) => row.name.equals(name));
    return (await query.getSingleOrNull())?.value;
  }

  Future<void> _setMeta(String name, String value) {
    return into(syncMeta).insertOnConflictUpdate(
      SyncMetaRow(name: name, value: value),
    );
  }

  Future<bool> _flag(String name) async => await meta(name) == 'true';

  Future<DateTime?> _newestInstant<T extends HasResultSet, D>(
    GeneratedColumn<int> column,
    ResultSetImplementation<T, D> table,
  ) async {
    final newest = column.max();
    final query = selectOnly(table)..addColumns([newest]);
    final ms = (await query.getSingleOrNull())?.read(newest);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
