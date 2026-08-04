/// The on-device tables: one per kind of thing the strap measured.
///
/// Split out of `local_store.dart` because the schema and the database class
/// have different reasons to change (Standards §1), and because there are now
/// five tables where there was one.
///
/// ## Why these hold RAW measurements and nothing else
///
/// Every row here is something a sensor produced: a heart-rate sample, a staged
/// night, a workout summary, the strap's own since-midnight counter. Nothing in
/// this file is computed by the phone, and nothing in this file may become
/// computed by the phone. CLAUDE.md's rule — "ONE canonical definition per
/// metric … two definitions of 'sleep debt' is a lie waiting to surface" — is
/// about *derived* numbers, and the server owns all of them. A table called
/// `recovery_score` would be that rule broken; a table called `strap_samples`
/// is the input those numbers are eventually derived from.
///
/// The distinction is load-bearing enough that `vitals.dart` was deleted from
/// this repo for computing a resting heart rate on the phone beside the
/// server's own definition of one.
///
/// ## Every table carries `day`, and it is TEXT
///
/// The reasoning is `CachedPayloads.day`'s, unchanged and now applied five more
/// times: a calendar date is not an instant, drift's `dateTime()` column stores
/// a Unix timestamp and returns it in the *device's* zone, and a row filed under
/// a different day depending on where the phone was is a row the 60-day prune
/// cannot reason about. `YYYY-MM-DD` sorts lexicographically exactly as it sorts
/// chronologically, so [LocalStore.pruneBeyondHorizon] is a single string
/// comparison on every one of these tables.
///
/// The instants (`tsMs`, `startMs`, `readAtMs`) are stored as epoch
/// milliseconds, which is what they are — a moment the sensor recorded, with no
/// calendar semantics at all. Both types are present because both meanings are
/// present; collapsing them is the confusion this repo has shipped twice.
library;

import 'package:drift/drift.dart';

/// One timestamped reading of one metric, exactly as the strap reported it.
///
/// The primary key is `(metric, tsMs)` rather than a surrogate id, which makes
/// re-storing an overlapping fetch window idempotent for free. That matters
/// because the fetch plan deliberately re-pulls: sleep re-reads two days so a
/// nap appended later is picked up, workouts overlap by a day so a same-day bout
/// cannot slip through. A sync that runs twice must leave the same store behind
/// as a sync that ran once.
@DataClassName('StoredSample')
class StrapSamples extends Table {
  /// The metric's wire name — `hr`, `hrv`, `spo2`, `stress`, `resting_hr`, …
  ///
  /// The same names `StrapSample.metric` uses, unmapped. The legacy push mapped
  /// them to the server's canonical vocabulary on the way out; there is no push
  /// in this package, so there is no mapping and no second name for anything.
  TextColumn get metric => text().withLength(min: 1, max: 32)();

  /// When the strap recorded it, epoch milliseconds.
  IntColumn get tsMs => integer()();

  /// The owner-local calendar date [tsMs] falls on, `YYYY-MM-DD`. Denormalised
  /// from the instant so the horizon prune is one indexed string comparison
  /// rather than 60 days of arithmetic per row.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  /// The decoded value, in the metric's own unit. Untouched.
  RealColumn get value => real()();

  @override
  Set<Column<Object>> get primaryKey => {metric, tsMs};
}

/// One sleep record — a main night or a daytime nap — as the strap staged it.
///
/// The stage timeline is stored as JSON rather than as a sixth table. It is only
/// ever read whole, alongside the session it belongs to, and a `sleep_stages`
/// table would buy a join and cost a second place for a night to be half-written.
@DataClassName('StoredSleepSession')
class SleepSessions extends Table {
  /// The record's own session timestamp, epoch milliseconds. The key the strap
  /// itself deduplicates on, so it is the key here too.
  IntColumn get startMs => integer()();

  /// The owner-local calendar date the session started on.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  /// True for a daytime nap block rather than the main night.
  BoolColumn get isNap => boolean()();

  /// Sleep onset, minutes from (midnight − 24 h), as the record encodes it.
  IntColumn get sleepStartMin => integer()();

  /// Wake, in the same units.
  IntColumn get sleepEndMin => integer()();

  /// The device's average heart rate for the night. 0 for naps — the record
  /// carries no per-nap average and inventing one would be a made-up number.
  IntColumn get avgHr => integer()();

  /// **The device's own sleep score**, 0 for naps.
  ///
  /// Stored and shown attributed to the strap. It is NOT Healthee's sleep-health
  /// score, which is the four-dimension judgement the server derives — the app
  /// must never present one as the other.
  IntColumn get score => integer()();

  /// REM minutes, as the device summed them.
  IntColumn get remMin => integer()();

  /// Light-sleep minutes.
  IntColumn get lightMin => integer()();

  /// Deep-sleep minutes.
  IntColumn get deepMin => integer()();

  /// Awake minutes inside the session.
  IntColumn get wakeMin => integer()();

  /// The stage timeline as `[[startMs, endMs, type], …]` JSON.
  TextColumn get stagesJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {startMs};
}

/// One workout summary, with the device's own heart-rate and calorie figures.
@DataClassName('StoredWorkout')
class StoredWorkouts extends Table {
  /// When the workout began, epoch milliseconds.
  IntColumn get startMs => integer()();

  /// The owner-local calendar date it began on.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  /// The device's sport-type code.
  IntColumn get sportType => integer()();

  /// Duration in seconds.
  IntColumn get durationSec => integer()();

  /// Calories as the DEVICE reported them. CLAUDE.md pins free-living energy to
  /// the server's MET-by-state model; this is the strap's figure, carried
  /// unaltered and labelled as the strap's.
  IntColumn get calories => integer()();

  /// Average heart rate over the workout.
  IntColumn get avgHr => integer()();

  /// Peak heart rate.
  IntColumn get maxHr => integer()();

  /// Lowest heart rate.
  IntColumn get minHr => integer()();

  @override
  Set<Column<Object>> get primaryKey => {startMs};
}

/// The strap's own since-midnight counters — **the authoritative daily total**.
///
/// This table is the phone's answer to #121. On the server the `0x0016` counter
/// went straight into a derived cell with no raw home, so any re-derive pass
/// destroyed it permanently — 142 of 143 production days lost their real step
/// count that way, unrecoverably. The server has `device_daily_total` now.
///
/// **This is that table, one layer up.** Holding the counter only in memory, or
/// only inside a sync result, would recreate exactly the same loss: the strap
/// reports "since midnight", so yesterday's counter is not re-readable tomorrow.
/// One row per day, written on every sync, and never derived from anything.
@DataClassName('StoredDeviceTotals')
class DeviceTotals extends Table {
  /// The owner-local calendar date these counters are for, `YYYY-MM-DD`.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  /// Steps since the strap's local midnight. The authoritative step total — the
  /// per-minute stream is, in the legacy code's own words, "possibly frozen /
  /// incomplete" on this firmware.
  IntColumn get steps => integer()();

  /// Distance in metres since midnight, as the strap computed it.
  IntColumn get distanceM => integer()();

  /// Calories since midnight, as the strap computed them.
  IntColumn get calories => integer()();

  /// When the reply landed, epoch milliseconds. A counter read at 09:00 is a
  /// claim about nine hours, not about a day, and the screen says so.
  IntColumn get readAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

/// Small durable facts about syncing itself: the one-shot flags and the last run.
///
/// A key/value table rather than columns because these are bookkeeping, not
/// measurements, and they change shape as the engine does. Nothing here is ever
/// shown as a health number.
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  /// The fact's name. See `SyncKeys` in `strap_writer.dart`.
  TextColumn get name => text().withLength(min: 1, max: 64)();

  /// Its value, as text. Callers parse; the table stores.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}
