/// The retention window, applied — and the one place a measurement can die.
///
/// Split out of `local_store.dart` because the database class and the retention
/// policy have different reasons to change (Standards §1), and because the
/// policy is no longer one line.
///
/// ## The defect this file exists to close
///
/// The prune used to delete from all five day-keyed tables **by `day` alone**.
/// A measurement that had never reached the server was therefore destroyed the
/// moment it fell out of the 60-day window — silently, uncounted, and with no
/// way to tell afterwards that a hole in a chart had ever been data. It needed a
/// push queue stuck for two months to happen, which is exactly the kind of
/// narrow window that ships.
///
/// ## Three tiers, because the five tables do not hold the same kind of thing
///
/// ```text
///   cached_payloads   derivable        pruned at 60 days, always
///   sleep_sessions    measured, few    kept past 60 days while unsent, no bound
///   stored_workouts   measured, few    kept past 60 days while unsent, no bound
///   device_totals     measured, few    kept past 60 days while unsent, no bound
///   strap_samples     measured, many   kept past 60 days while unsent, to 1 year
/// ```
///
/// **Tier 1 — `cached_payloads`.** A copy of what the server sent us. It is not
/// the owner's measurement and losing it costs one HTTP request, so the horizon
/// applies to it unconditionally. It has no `pushed_at_ms` and must never gain
/// one: it travels the other way.
///
/// **Tier 2 — the event tables.** Nights, workouts and the strap's daily
/// counter. These are measurements with no other home, and `device_totals` is
/// the one this repo has already paid for: the server's `0x0016` counter had no
/// raw table and 142 of 143 production days were destroyed permanently (#121).
/// So an unsent row here is kept past the horizon, and — unlike the samples
/// below — it has **no second bound at all**.
///
/// That is a storage argument, and it was measured rather than assumed. A row in
/// each of these tables is one *event*: one counter a day, at most a handful of
/// nights and workouts. Measured on a real drift/SQLite file (index included), a
/// sleep row with a 40-span stage timeline costs ~1.4 kB and dominates the other
/// two; four sleep records a day is ~2 MB a *year*, ~20 MB a decade. A table
/// that grows by events per day cannot make a phone grow without limit, so a
/// bound here would buy nothing measurable and would cost the exact measurement
/// #121 was about. There is no honest bound to set, so none is set.
///
/// **Tier 3 — `strap_samples`.** Eight per-minute streams, 11,520 rows a worn
/// day. Measured the same way: ~60 bytes a row on disk, so ~0.66 MB per worn
/// day. This is the only table where retention is a real storage question, so it
/// is the only one with a second bound — and the only one that can ever appear
/// in [PruneReport.unsentSamples].
///
/// ## Why the second bound is one year
///
/// [kUnsentSampleRetentionDays] is 365. The reasoning, in order:
///
///   * **Every cause of a stuck queue resolves in days or weeks.** Signed out, a
///     rotated token, a server down, a fortnight abroad with no signal — none of
///     them lasts a year. A bound short enough to catch one of those would be a
///     bound that destroys data while the cause is still live. A year cannot be
///     reached by anything transient, so reaching it means this phone is never
///     going to send these rows.
///   * **The owner has been told, every day, all year.** `health_lines.dart`
///     renders a loud line whenever anything is pending and the push is signed
///     out or faulted. At the bound that sentence has been on the Today screen
///     roughly 365 times. Cutting sooner destroys data while the warning could
///     still be news to someone.
///   * **The ceiling is bounded and stated.** 365 × 0.66 MB ≈ **240 MB** of
///     samples, worst case, reached only by wearing the strap continuously for a
///     year with nothing ever pushed. That is a real cost and it is the price of
///     not deleting a year of somebody's health data behind their back.
///
/// The horizon therefore means what it should have meant all along: 60 days of
/// history the app will *show* you, not 60 days after which your unsent
/// measurements are destroyed.
///
/// ## Nothing here happens quietly
///
/// A tier-3 drop is counted, dated, written durably into [SyncMeta] and logged.
/// `PushReader.lastAttempt` reads it back onto [PushStamp] and the data-health
/// card states it in full ink. It is never folded into the prune's row total —
/// see `prune_report.dart` for why one number would have hidden it.
library;

import 'package:drift/drift.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/prune_report.dart';
import 'package:healthee/data/store/strap_writer.dart';
import 'package:healthee/data/store/tables.dart';

part 'horizon_prune.g.dart';

/// Applies the retention window, and records anything it had to destroy.
@DriftAccessor(
  tables: [
    CachedPayloads,
    StrapSamples,
    SleepSessions,
    StoredWorkouts,
    DeviceTotals,
    SyncMeta,
  ],
)
class HorizonPrune extends DatabaseAccessor<LocalStore> with _$HorizonPruneMixin {
  /// Built by drift as `store.horizonPrune`.
  HorizonPrune(super.db);

  /// Applies both bounds for the owner's [today] (`YYYY-MM-DD`).
  ///
  /// One transaction: a prune that recorded a loss and then failed to delete the
  /// rows would over-report, and one that deleted them and failed to record
  /// would be the defect this file closes, back again.
  ///
  /// [SyncMeta] is deliberately never pruned — its rows are bookkeeping about
  /// syncing, not dated measurements, and dropping the one-shot backfill flags
  /// would make a wide pass run again forever.
  Future<PruneReport> run({required String today, DateTime? at}) {
    final horizon = horizonStart(today);
    return transaction(() async {
      // Order is not load-bearing (the two predicates are disjoint on
      // `pushed_at_ms`) but reads better: destroy first and loudly, then do the
      // routine work.
      final lost = await _dropUnsentSamples(
        unsentSampleFloor(today),
        at ?? DateTime.now(),
      );
      final cached = await (delete(cachedPayloads)
            ..where((r) => r.day.isSmallerThanValue(horizon)))
          .go();
      return PruneReport(
        cachedPayloads: cached,
        sentMeasurements: await _dropSentMeasurements(horizon),
        unsentSamples: lost.rows,
        unsentThroughDay: lost.throughDay,
      );
    });
  }

  /// What this phone has destroyed before the server ever saw it, or null.
  ///
  /// Cumulative and never cleared. See [UnsentLoss].
  Future<UnsentLoss?> loss() async {
    final rows = int.tryParse(await _meta(SyncKeys.droppedUnsentRows) ?? '');
    final throughDay = await _meta(SyncKeys.droppedUnsentThroughDay);
    if (rows == null || rows <= 0 || throughDay == null) {
      return null;
    }
    final at = int.tryParse(await _meta(SyncKeys.droppedUnsentAtMs) ?? '');
    return UnsentLoss(
      rows: rows,
      throughDay: throughDay,
      at: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  /// Drops rows past the horizon that the server has already acknowledged.
  ///
  /// `pushed_at_ms IS NOT NULL` is the whole guard, and it is written out per
  /// table rather than looped: a loop would need the columns reached
  /// reflectively, and a table added later would then prune nothing at runtime
  /// instead of failing to compile here.
  Future<int> _dropSentMeasurements(String horizon) async {
    var removed = 0;
    removed += await (delete(strapSamples)..where(
      (r) => r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull(),
    )).go();
    removed += await (delete(sleepSessions)..where(
      (r) => r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull(),
    )).go();
    removed += await (delete(storedWorkouts)..where(
      (r) => r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull(),
    )).go();
    removed += await (delete(deviceTotals)..where(
      (r) => r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull(),
    )).go();
    return removed;
  }

  /// The only deletion in this app that ends a measurement's life.
  ///
  /// Counts and dates the rows **before** removing them, because after the
  /// DELETE there is nothing left to ask. The count comes from the DELETE itself
  /// so the number reported is the number actually removed rather than the
  /// number a preceding SELECT saw.
  Future<_Lost> _dropUnsentSamples(String floor, DateTime at) async {
    final newest = strapSamples.day.max();
    final doomed = selectOnly(strapSamples)
      ..addColumns([newest])
      ..where(
        strapSamples.day.isSmallerThanValue(floor) &
            strapSamples.pushedAtMs.isNull(),
      );
    final throughDay = (await doomed.getSingle()).read(newest);
    if (throughDay == null) {
      return const _Lost();
    }
    final rows = await (delete(strapSamples)..where(
      (r) => r.day.isSmallerThanValue(floor) & r.pushedAtMs.isNull(),
    )).go();
    await _recordLoss(rows, throughDay, at);
    AppLog.warning(
      'store',
      '$rows measurements through $throughDay were removed without ever '
          'reaching the server — they had been waiting past '
          '$kUnsentSampleRetentionDays days',
    );
    return _Lost(rows: rows, throughDay: throughDay);
  }

  /// Adds this pass to the running total. Later prunes drop *newer* days than
  /// earlier ones (the floor moves forward with the calendar), so the newest
  /// day lost is a max and not simply the latest write.
  Future<void> _recordLoss(int rows, String throughDay, DateTime at) async {
    final prior = await loss();
    final priorThrough = prior?.throughDay;
    await _setMeta(SyncKeys.droppedUnsentRows, '${(prior?.rows ?? 0) + rows}');
    await _setMeta(
      SyncKeys.droppedUnsentThroughDay,
      priorThrough != null && priorThrough.compareTo(throughDay) > 0
          ? priorThrough
          : throughDay,
    );
    await _setMeta(SyncKeys.droppedUnsentAtMs, '${at.millisecondsSinceEpoch}');
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
}

/// One pass's destruction, before it becomes a [PruneReport].
class _Lost {
  const _Lost({this.rows = 0, this.throughDay});

  final int rows;
  final String? throughDay;
}
