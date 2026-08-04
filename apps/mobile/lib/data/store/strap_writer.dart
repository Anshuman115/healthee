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
}

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
  Future<void> saveSync(StrapSyncResult result) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(strapSamples, [
        for (final sample in result.samples)
          StrapSamplesCompanion.insert(
            metric: sample.metric,
            tsMs: sample.date.millisecondsSinceEpoch,
            day: isoDay(sample.date),
            value: sample.value,
          ),
      ]);
      batch.insertAllOnConflictUpdate(sleepSessions, [
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
      ]);
      batch.insertAllOnConflictUpdate(storedWorkouts, [
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
      ]);
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
