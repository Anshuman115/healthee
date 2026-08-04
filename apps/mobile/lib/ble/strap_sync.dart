/// The fetch plan: which types, in what order, from when.
///
/// **Ported from** the `_postAuth` body of `~/projects/healthee-legacy/app/lib/
/// ble/strap_client.dart`. The sequence, the windows, the round caps, the
/// stale-feed retry and the two one-shot backfills are unchanged. What moved is
/// where the *answers* come from: legacy asked its own store inline, this takes
/// a [StrapSyncWindow] and returns a [StrapSyncResult]. Nothing here writes to
/// a database or a screen.
///
/// It was lifted out of the session for one reason: the legacy `_postAuth` was
/// a 130-line method that opened characteristics, chose fetch windows, parsed,
/// merged and persisted. Those are four reasons to change in one place, and
/// Standards §1 caps a method at 40 lines.
library;

import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/strap_sync_result.dart';
import 'package:healthee/ble/models/strap_sync_window.dart';
import 'package:healthee/ble/models/workout.dart';
import 'package:healthee/ble/parsers/sleep_parser.dart';
import 'package:healthee/ble/parsers/workout_parser.dart';
import 'package:healthee/ble/strap_session.dart';
import 'package:healthee/core/logging.dart';

/// How far back a metric with no watermark is fetched from.
const Duration kBackfillWindow = Duration(days: 30);

/// The per-metric fetch plan: `(fetch type code, label, watermark metric)`.
///
/// The watermark metric is the one whose newest timestamp decides where this
/// type resumes — it is not always the label, because `0x2E` writes
/// `temperature_c` and `0x38` writes `respiratory_rate`.
const List<(int, String, String)> kFetchPlan = <(int, String, String)>[
  (0x01, 'hr', 'hr'),
  (0x49, 'hrv', 'hrv'),
  (0x25, 'spo2', 'spo2'),
  (0x26, 'spo2_sleep', 'spo2_sleep'),
  (0x2E, 'temperature', 'temperature_c'),
  (0x13, 'stress', 'stress'),
  (0x38, 'sleep_resp', 'respiratory_rate'),
  (0x3A, 'resting_hr', 'resting_hr'),
  (0x3D, 'max_hr', 'max_hr'),
];

/// Runs one full sync over an authenticated [StrapSession].
class StrapSync {
  /// [session] must already be open and authenticated.
  StrapSync(this.session);

  /// The authenticated session this sync drives.
  final StrapSession session;

  final List<StrapSample> _samples = [];
  final List<SleepSession> _sleep = [];
  final List<Workout> _workouts = [];
  bool _stressBackfillRan = false;
  bool _napBackfillRan = false;

  /// Pulls everything the strap has since [window], and hands it back typed.
  Future<StrapSyncResult> run(StrapSyncWindow window) async {
    // Sent FIRST so the asynchronous reply has landed by the time the result is
    // built — this is the authoritative daily step total and it must not be the
    // thing a long fetch crowds out.
    //
    // ONE DELIBERATE CHANGE FROM LEGACY: legacy returned from `_postAuth`
    // BEFORE this line when the activity characteristics were missing, so a
    // strap that could still report its counter reported nothing. The counter
    // is the one measurement with no durable home elsewhere (#121), so it is
    // now requested before that check rather than after it.
    await session.requestDailyTotals();

    if (!session.hasActivityChannel) {
      AppLog.warning('ble', 'no activity channel: totals only, no history');
      return _result(await session.awaitDailyTotals());
    }

    final backfill = DateTime.now().subtract(kBackfillWindow);
    for (final (code, name, metric) in kFetchPlan) {
      await _fetchMetric(code, name, window.lastSampleAt[metric], backfill);
    }
    await _stressBackfill(stressBackfillDone: window.stressBackfillDone);
    await _fetchSleep(window, backfill);
    await _fetchWorkouts(window);

    AppLog.info('ble', 'sensor fetch complete');
    return _result(await session.awaitDailyTotals());
  }

  StrapSyncResult _result(DeviceDailyTotals? totals) => StrapSyncResult(
    samples: List<StrapSample>.unmodifiable(_samples),
    sleepSessions: List<SleepSession>.unmodifiable(_sleep),
    workouts: List<Workout>.unmodifiable(_workouts),
    dailyTotals: totals,
    batteryPercent: session.batteryPercent,
    stressBackfillRan: _stressBackfillRan,
    napBackfillRan: _napBackfillRan,
    completedAt: DateTime.now(),
  );

  /// One metric, incrementally — with the stale-feed recovery.
  ///
  /// A feed can go quiet and resume weeks later (stress stopped writing to the
  /// legacy buffer around 2026-06-04 and came back). The incremental fetch then
  /// starts at the OLD watermark, stalls on the long solid-`0xFF` dead block,
  /// and returns nothing. So when a metric with a watermark older than two days
  /// returns empty, retry from a recent window to re-establish the feed —
  /// proven: a since-2d fetch returned 345 live stress samples where a
  /// since-Jun-4 fetch returned 0.
  Future<void> _fetchMetric(
    int code,
    String name,
    DateTime? last,
    DateTime backfill,
  ) async {
    final since = last?.add(const Duration(minutes: 1)) ?? backfill;
    var samples = await session.fetcher.fetchType(code, since, maxRounds: 400);
    if (samples.isEmpty &&
        last != null &&
        DateTime.now().difference(last) > const Duration(days: 2)) {
      samples = await session.fetcher.fetchType(
        code,
        DateTime.now().subtract(const Duration(days: 2)),
        maxRounds: 400,
      );
    }
    _samples.addAll(samples);
    AppLog.info('ble', '$name: ${samples.length}');
  }

  /// The one-time wide stress pass.
  ///
  /// Stress went quiet on the legacy buffer mid-June, so the incremental
  /// watermark jumped past the older live region when it recovered the latest
  /// days — leaving a hole nothing else would ever fill. Now that the gap-skip
  /// crosses `0xFF` runs for `0x13`, one wide fetch recovers all retained stress
  /// across the gaps. Runs once; the caller persists the flag.
  Future<void> _stressBackfill({required bool stressBackfillDone}) async {
    if (stressBackfillDone) return;
    final samples = await session.fetcher.fetchType(
      0x13,
      DateTime.now().subtract(const Duration(days: 25)),
      maxRounds: 400,
    );
    _samples.addAll(samples);
    _stressBackfillRan = true;
    AppLog.info('ble', 'stress backfill: ${samples.length}');
  }

  /// Sleep (`0x48`).
  ///
  /// Normally re-pulls the last two days, so a day's record picks up an
  /// afternoon NAP appended to it later in the day. The first run after the
  /// nap-parsing update pulls 14 days once, to recover historical naps the old
  /// parser never decoded. Both merges are idempotent.
  Future<void> _fetchSleep(StrapSyncWindow window, DateTime backfill) async {
    final lastSleep = window.lastSleepStart ?? backfill;
    final windowAgo = DateTime.now().subtract(
      Duration(days: window.napBackfillDone ? 2 : 14),
    );
    final sleepSince = lastSleep.isAfter(windowAgo) ? windowAgo : lastSleep;
    await session.fetcher.fetchType(0x48, sleepSince, maxRounds: 400);
    final parsed = SleepParser.parse(session.fetcher.lastRaw);
    _mergeSleep(parsed);
    _napBackfillRan = !window.napBackfillDone;
    AppLog.info(
      'ble',
      'sleep: ${_sleep.length} sessions (parsed ${parsed.length} from '
          '${session.fetcher.lastRaw.length}B, since ${sleepSince.toIso8601String()})',
    );
  }

  /// Workouts (`0x05` sports summaries).
  ///
  /// Incremental: since the last stored workout minus a one-day overlap, so a
  /// same-day bout cannot slip through and the idempotent merge absorbs the
  /// duplicates. A 90-day backfill on the first run. Re-pulling the full 90 days
  /// every sync transferred ~50 rounds of already-known summaries (~4 s) for
  /// nothing.
  Future<void> _fetchWorkouts(StrapSyncWindow window) async {
    final lastWorkout = window.lastWorkoutStart;
    final since = lastWorkout != null
        ? lastWorkout.subtract(const Duration(days: 1))
        : DateTime.now().subtract(const Duration(days: 90));
    await session.fetcher.fetchType(
      0x05,
      since,
      maxRounds: 100,
      timeout: const Duration(seconds: 150),
    );
    _mergeWorkouts(WorkoutParser.parseStream(session.fetcher.lastRaw));
    AppLog.info('ble', 'workouts: ${_workouts.length}');
  }

  /// Deduplicate by session start — overlapping pages return the same record.
  void _mergeSleep(List<SleepSession> incoming) {
    final byStart = {
      for (final s in _sleep) s.sessionStart.millisecondsSinceEpoch: s,
    };
    for (final s in incoming) {
      byStart[s.sessionStart.millisecondsSinceEpoch] = s;
    }
    _sleep
      ..clear()
      ..addAll(
        byStart.values.toList()
          ..sort((a, b) => a.sessionStart.compareTo(b.sessionStart)),
      );
  }

  /// Deduplicate by start — the one-day overlap above guarantees repeats.
  void _mergeWorkouts(List<Workout> incoming) {
    final byStart = {
      for (final w in _workouts) w.start.millisecondsSinceEpoch: w,
    };
    for (final w in incoming) {
      byStart[w.start.millisecondsSinceEpoch] = w;
    }
    _workouts
      ..clear()
      ..addAll(
        byStart.values.toList()..sort((a, b) => a.start.compareTo(b.start)),
      );
  }
}
