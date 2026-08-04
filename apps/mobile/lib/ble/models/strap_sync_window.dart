/// What the caller already has, so the sync knows where to start.
///
/// The legacy sync asked its own store these questions inline — `lastTs(metric)`,
/// `lastSleepStart()`, `getMeta('nap_backfill_v2')`. This port does not carry
/// that store across (drift supersedes it, and wiring it is the next package),
/// so the same questions are asked once, by the caller, and handed in as data.
///
/// The arithmetic that turns these into fetch windows is unchanged and lives in
/// `strap_sync.dart`; only the source of the answers moved.
///
/// ## The two one-shot flags are not decoration
///
/// Both exist because a *narrower* incremental fetch was found to be silently
/// leaving holes:
///
///  * `stressBackfillDone` — stress stopped writing to the legacy buffer around
///    2026-06-04 and resumed weeks later. The incremental watermark then jumped
///    past the older live region when it recovered the newest days, leaving a
///    gap in the middle that no future incremental fetch would ever revisit.
///  * `napBackfillDone` — daytime naps live in a second block of the same sleep
///    record, which an earlier parser never read. Once it could, the two-day
///    re-pull window was too short to recover the naps already on the band.
///
/// Each is answered "have we ever done the wide pass?", not "when did we last
/// sync?". The caller persists them; this type only carries them.
library;

import 'package:meta/meta.dart';

/// The watermarks and one-shot flags one sync starts from.
@immutable
class StrapSyncWindow {
  /// Everything optional, because a first-ever sync knows none of it.
  const StrapSyncWindow({
    this.lastSampleAt = const {},
    this.lastSleepStart,
    this.lastWorkoutStart,
    this.stressBackfillDone = false,
    this.napBackfillDone = false,
  });

  /// A phone that has never synced: full backfill, both one-shot passes due.
  const StrapSyncWindow.firstEver() : this();

  /// The newest sample already held, per metric wire name (`hr`, `hrv`,
  /// `spo2`, `spo2_sleep`, `temperature_c`, `stress`, `respiratory_rate`,
  /// `resting_hr`, `max_hr`). A metric that is absent is fetched from the
  /// 30-day backfill floor.
  final Map<String, DateTime> lastSampleAt;

  /// The start of the newest sleep session already held.
  final DateTime? lastSleepStart;

  /// The start of the newest workout already held.
  final DateTime? lastWorkoutStart;

  /// Whether the one-time wide stress pass has already run.
  final bool stressBackfillDone;

  /// Whether the one-time 14-day nap pass has already run.
  final bool napBackfillDone;
}
