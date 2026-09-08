/// Everything one sync pulled off the strap — the end of the protocol layer.
///
/// This is where `ble/` stops. Nothing here is persisted, pushed or rendered;
/// the caller decides all three. That boundary is deliberate: the 60-day store
/// and the push are the next package, and a protocol layer that also wrote to a
/// database would be two reasons to change in one place.
///
/// ## Two things the caller must not drop
///
///  * [dailyTotals] is the strap's own since-midnight counter, and it is the
///    **authoritative** step total — the per-minute sum is frozen or incomplete
///    on this firmware. The server has a durable table for it
///    (`device_daily_total`); it needs to arrive there. See
///    `DeviceDailyTotals` for the whole story.
///  * [stressBackfillRan] and [napBackfillRan] say a one-shot wide pass
///    happened. If they are not persisted, the wide pass runs on every sync
///    forever; if they are persisted when the pass did NOT run, the gap it
///    exists to close never gets closed. They are reported as **ran**, not as
///    "should now be true", so a sync that ended early cannot flip them.
library;

import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_data.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/workout.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:meta/meta.dart';

/// The typed result of one sync.
@immutable
class StrapSyncResult {
  /// Built by `StrapSync.run`.
  const StrapSyncResult({
    required this.samples,
    required this.sleepSessions,
    required this.workouts,
    required this.completedAt,
    required this.activityChannelPresent,
    this.failure,
    this.dailyTotals,
    this.batteryPercent,
    this.stressBackfillRan = false,
    this.napBackfillRan = false,
  });

  /// A failed stream; retained data is partial and backfills must be retried.
  final StrapFailure? failure;

  /// Every decoded per-metric sample, in fetch order.
  final List<StrapSample> samples;

  /// Sleep sessions and naps, deduplicated by session start.
  final List<SleepSession> sleepSessions;

  /// Workout summaries, deduplicated by start.
  final List<Workout> workouts;

  /// Whether the activity-fetch characteristics were there for this pull.
  ///
  /// False means the sync ran the counter request and **stopped** — no samples,
  /// no sleep, no workouts, because the channel that carries them was absent.
  /// That is a materially incomplete pull, and it is reported as a field rather
  /// than inferred from empty lists: an incremental sync with genuinely nothing
  /// new is also empty, and calling that "partial" would cry wolf on the normal
  /// case until nobody read the word.
  final bool activityChannelPresent;

  /// The strap's since-midnight counters, or null if the reply never landed.
  final DeviceDailyTotals? dailyTotals;

  /// Strap battery percent, or null if the characteristic was unavailable.
  final int? batteryPercent;

  /// Whether the one-time wide stress pass ran during this sync.
  final bool stressBackfillRan;

  /// Whether the one-time 14-day nap pass ran during this sync.
  final bool napBackfillRan;

  /// When the sync finished.
  final DateTime completedAt;

  /// The same data as the in-memory aggregate the read helpers work over.
  StrapData asStrapData() => StrapData()
    ..ingest(samples)
    ..sleep = List<SleepSession>.of(sleepSessions)
    ..workouts = List<Workout>.of(workouts)
    ..battery = batteryPercent
    ..dailyTotals = dailyTotals
    ..lastSync = completedAt;

  @override
  String toString() =>
      'sync @${completedAt.toIso8601String()}: ${samples.length} samples · '
      '${sleepSessions.length} sleep · ${workouts.length} workouts · '
      'totals=${dailyTotals != null}';
}
