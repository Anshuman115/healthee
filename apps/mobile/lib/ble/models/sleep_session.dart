/// One night (or one nap) as the strap recorded it, and the stage segments
/// inside it.
///
/// **Ported verbatim** from the `SleepStageSeg` and `SleepSession` classes in
/// `~/projects/healthee-legacy/app/lib/ble/sleep_parser.dart`, minus their
/// `toJson`/`fromJson` pair: that serialisation existed only for the legacy
/// `store.dart`, which this port deliberately does not carry across (drift
/// supersedes it). Reintroducing it before the store exists would be dead code.
///
/// Two public classes in one file because a segment is a part of a session and
/// has no independent life; Standards §1 allows the helper alongside the class
/// it serves.
library;

import 'package:meta/meta.dart';

/// One stage of sleep, between two instants.
@immutable
class SleepStageSeg {
  /// A [type]-coded stage from [start] to [end].
  const SleepStageSeg(this.start, this.end, this.type);

  /// When the stage began.
  final DateTime start;

  /// When the stage ended.
  final DateTime end;

  /// The device's stage code: 4 = light, 5 = deep, 8 = REM, 7 = awake.
  final int type;

  /// The stage code as a name. `any` for a code we do not recognise, which is
  /// deliberately not "light" — an unknown stage is not a known one.
  String get kind => switch (type) {
    4 => 'light',
    5 => 'deep',
    8 => 'rem',
    7 => 'awake',
    _ => 'any',
  };
}

/// A sleep record: one main night, or one daytime nap.
@immutable
class SleepSession {
  /// All fields come straight from the 594-byte record; see `sleep_parser.dart`
  /// for the offsets each one is read from.
  const SleepSession({
    required this.sessionStart,
    required this.sleepStartMin,
    required this.sleepEndMin,
    required this.avgHr,
    required this.score,
    required this.stages,
    required this.remMin,
    required this.lightMin,
    required this.deepMin,
    required this.wakeMin,
    this.isNap = false,
  });

  /// The record's own session timestamp.
  final DateTime sessionStart;

  /// Sleep onset, in minutes from (midnight − 24 h).
  final int sleepStartMin;

  /// Wake, in minutes from (midnight − 24 h).
  final int sleepEndMin;

  /// The device's average heart rate for the night. 0 for naps — the record
  /// carries no per-nap average, and inventing one would be a made-up number.
  final int avgHr;

  /// The device's own sleep score. 0 for naps, for the same reason.
  final int score;

  /// The stage timeline.
  final List<SleepStageSeg> stages;

  /// REM minutes, as the device summed them.
  final int remMin;

  /// Light-sleep minutes.
  final int lightMin;

  /// Deep-sleep minutes.
  final int deepMin;

  /// Awake minutes inside the session.
  final int wakeMin;

  /// True for a daytime nap block rather than the main night.
  final bool isNap;

  /// Time in bed as the four summary fields add up.
  int get totalMin => remMin + lightMin + deepMin + wakeMin;

  @override
  String toString() =>
      'sleep ${sessionStart.toIso8601String()} score=$score avgHr=$avgHr '
      'L/D/R/W=$lightMin/$deepMin/$remMin/$wakeMin min, ${stages.length} stages';
}
