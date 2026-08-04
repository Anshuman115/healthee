/// Last night as the STRAP staged it. Measurement only — no judgement.
///
/// The strap decides where sleep began, where it ended, and which stage each
/// span was; this type carries those decisions unchanged. What it deliberately
/// does not carry is any figure the server derives from them:
///
///   * **no sleep-health score** — the server's four-dimension judgement, with
///     its own published cutoffs (7–9 h, ≥85%, SRI ≥70, midpoint 02:00–04:00);
///   * **no sleep debt** — a 14-night accumulation the phone holds only 60 days
///     of inputs for and has no need model for;
///   * **no efficiency percentage** — asleep÷in-bed looks like arithmetic, but
///     it is one of those four dimensions and it is scored against a cutoff.
///     Computing it here would put the numerator of a server judgement on the
///     phone, one rename away from becoming a second definition of it.
///
/// [deviceScore] is the exception that proves the rule, and it is labelled: it
/// is the strap's OWN score, the number the Zepp app shows. Hiding it would be
/// its own small dishonesty — the owner can read it on their wrist — so it is
/// shown with the instrument named, exactly as VO₂max names which method spoke.
library;

import 'package:meta/meta.dart';

/// One span of one stage, as the record encodes it.
@immutable
class DeviceStage {
  /// A [kind]-named stage between two instants.
  const DeviceStage({required this.start, required this.end, required this.kind});

  /// When the span began.
  final DateTime start;

  /// When it ended.
  final DateTime end;

  /// `light` · `deep` · `rem` · `awake` · `any`.
  ///
  /// `any` is the strap's own unrecognised code and stays unrecognised — mapping
  /// it to `light` because light is the commonest would be inventing a stage.
  final String kind;

  /// How long the span lasted.
  Duration get length => end.difference(start);
}

/// One sleep record — a main night or a nap — with nothing added to it.
@immutable
class DeviceNight {
  /// Built by [package:healthee/data/store/strap_reader].
  const DeviceNight({
    required this.start,
    required this.end,
    required this.isNap,
    required this.remMin,
    required this.lightMin,
    required this.deepMin,
    required this.wakeMin,
    required this.deviceScore,
    required this.avgHr,
    required this.stages,
  });

  /// The record's session start.
  final DateTime start;

  /// The end of the last staged span, or [start] when there are no stages.
  final DateTime end;

  /// True for a daytime nap block.
  final bool isNap;

  /// REM minutes, as the device summed them.
  final int remMin;

  /// Light-sleep minutes.
  final int lightMin;

  /// Deep-sleep minutes.
  final int deepMin;

  /// Awake minutes inside the session.
  final int wakeMin;

  /// **The strap's own sleep score**, 0–100. Zero for naps: the record carries
  /// none, and a nap scored 0 would read as a terrible nap rather than an
  /// unscored one — which is why the UI must check [isNap] before showing it.
  final int deviceScore;

  /// The device's average heart rate for the night. 0 for naps.
  final int avgHr;

  /// The stage timeline, in order.
  final List<DeviceStage> stages;

  /// Minutes staged as sleep — REM + light + deep.
  ///
  /// A sum of the device's own four summary fields, which is arithmetic on
  /// measurements rather than a model: no cutoff, no baseline, no need
  /// estimate, nothing published being applied. The server's sleep DURATION
  /// dimension scores this against 7–9 h; that scoring stays on the server.
  int get asleepMin => remMin + lightMin + deepMin;

  /// Minutes the record spans in total, including time awake in bed.
  int get inBedMin => asleepMin + wakeMin;

  /// Whether the strap gave this record a score of its own.
  bool get hasDeviceScore => !isNap && deviceScore > 0;
}
