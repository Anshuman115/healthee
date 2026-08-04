/// Last night as the SERVER holds it: the hypnogram, the totals, the vitals.
///
/// The server's copy of the same night `DeviceNight` carries, and the two are
/// deliberately not merged. `DeviceNight` is what this phone read off the strap
/// and can render with no network; this is what the server stored, staged and
/// dated in the owner's timezone, and it is what every derived sleep judgement
/// on this screen was computed from. Showing a judgement beside a *different*
/// copy of the night it was computed from is how two numbers start disagreeing.
///
/// [OvernightVitals] is `last_sleep_extras` — HRV, respiratory rate, SpO₂ and
/// skin temperature over the night. `spo2Min` is the one to draw at full width:
/// the nightly **minimum** is the clinical signal, not the average.
library;

import 'package:meta/meta.dart';

/// One staged span of the night, in minutes from sleep onset.
///
/// Offsets rather than instants, exactly as the server sends them: the
/// hypnogram is a picture of one night's shape and its x-axis is elapsed time,
/// so converting to wall-clock here would only invite a timezone into a drawing
/// that has no use for one.
@immutable
class SleepStageSpan {
  /// A stage between two offsets.
  const SleepStageSpan({
    required this.stage,
    required this.startOffsetMin,
    required this.endOffsetMin,
    required this.durationMin,
  });

  /// Parses one entry of `last_sleep.stages`.
  factory SleepStageSpan.fromJson(Map<String, Object?> json) {
    return SleepStageSpan(
      stage: json['stage']! as String,
      startOffsetMin: (json['start_offset_min'] as num?)?.toDouble() ?? 0,
      endOffsetMin: (json['end_offset_min'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toDouble() ?? 0,
    );
  }

  /// `light` · `deep` · `rem` · `awake`.
  final String stage;

  /// Minutes from sleep onset to the start of this span.
  final double startOffsetMin;

  /// Minutes from sleep onset to its end.
  final double endOffsetMin;

  /// How long the span lasted.
  final double durationMin;
}

/// What the strap measured *while* the owner slept.
@immutable
class OvernightVitals {
  /// Built from `last_sleep_extras`.
  const OvernightVitals({
    required this.hrvRmssdMs,
    required this.respiratoryRate,
    required this.spo2Avg,
    required this.spo2Min,
    required this.skinTempC,
  });

  /// Parses the block, or null when it carries nothing at all.
  static OvernightVitals? maybe(Map<String, Object?> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    final vitals = OvernightVitals(
      hrvRmssdMs: number('hrv_rmssd_ms'),
      respiratoryRate: number('respiratory_rate'),
      spo2Avg: number('spo2_avg'),
      spo2Min: number('spo2_overnight_min') ?? number('spo2_min'),
      skinTempC: number('skin_temp_c'),
    );
    return vitals.isEmpty ? null : vitals;
  }

  /// Overnight HRV (RMSSD), ms.
  final double? hrvRmssdMs;

  /// Breaths per minute over the night.
  final double? respiratoryRate;

  /// Mean overnight blood oxygen, %.
  final double? spo2Avg;

  /// **Lowest** overnight blood oxygen, %. The clinical signal.
  final double? spo2Min;

  /// Overnight skin temperature, °C.
  final double? skinTempC;

  /// True when the block carried no measurement at all.
  bool get isEmpty =>
      hrvRmssdMs == null &&
      respiratoryRate == null &&
      spo2Avg == null &&
      spo2Min == null &&
      skinTempC == null;
}

/// The night the server staged, with its own stage totals.
@immutable
class LastSleep {
  /// Built by [LastSleep.maybe].
  const LastSleep({
    required this.durationMin,
    required this.score,
    required this.avgHr,
    required this.startIso,
    required this.endIso,
    required this.stages,
    required this.totals,
  });

  /// Parses `last_sleep`, or null when there is no night to show.
  static LastSleep? maybe(Map<String, Object?> json) {
    final duration = (json['duration_min'] as num?)?.toInt();
    if (duration == null) {
      return null;
    }
    final totals = json['totals'];
    return LastSleep(
      durationMin: duration,
      score: (json['score'] as num?)?.toInt(),
      avgHr: (json['avg_hr'] as num?)?.toInt(),
      startIso: json['start_iso'] as String?,
      endIso: json['end_iso'] as String?,
      stages: [
        for (final entry in (json['stages'] as List? ?? const []))
          if (entry is Map<String, Object?>) SleepStageSpan.fromJson(entry),
      ],
      totals: <String, int>{
        if (totals is Map<String, Object?>)
          for (final entry in totals.entries)
            if (entry.value is num) entry.key: (entry.value! as num).toInt(),
      },
    );
  }

  /// Total sleep time, minutes.
  final int durationMin;

  /// **The device's own score**, carried through the server unchanged. Shown
  /// attributed, never as Healthee's judgement — that is the four-dimension
  /// breakdown, and two scores under one word is the failure CLAUDE.md names.
  final int? score;

  /// Mean heart rate over the night.
  final int? avgHr;

  /// When the night began, ISO-8601 with the owner's offset.
  final String? startIso;

  /// When it ended.
  final String? endIso;

  /// The hypnogram.
  final List<SleepStageSpan> stages;

  /// Minutes per stage — `deep`, `light`, `rem`, `awake`.
  final Map<String, int> totals;

  /// Minutes in a named stage, or 0 when the night has none of it.
  int minutesIn(String stage) => totals[stage] ?? 0;
}
