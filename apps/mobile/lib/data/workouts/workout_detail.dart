import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/workouts/workout_summary.dart';

/// Summary, measured HR, and canonical server-derived session metrics.
class WorkoutDetail {
  const WorkoutDetail({
    required this.workout,
    required this.heartRate,
    required this.zones,
    this.withheld = const <String, Disclosure>{},
    this.hrmax,
    this.maxPercentHrmax,
    this.caloriesPerMinute,
    this.dominantZone,
    this.intensity,
    this.paceMinPerKm,
    this.speedKmh,
    this.trimp,
    this.hrDriftBpm,
    this.averagePercentHrmax,
  });

  factory WorkoutDetail.fromJson(Map<String, Object?> json) {
    final summary = WorkoutSummary.fromJson(
      json['workout']! as Map<String, Object?>,
    );
    final metrics = json['metrics']! as Map<String, Object?>;
    return WorkoutDetail(
      workout: summary,
      heartRate: [
        for (final item in json['hr_series']! as List<Object?>)
          _point(item! as Map<String, Object?>, summary.start),
      ],
      zones: [
        for (final value in json['zones']! as List<Object?>)
          (value! as num).toInt(),
      ],
      hrmax: (json['hrmax'] as num?)?.toDouble(),
      intensity: metrics['intensity'] as String?,
      maxPercentHrmax: (metrics['max_pct_hrmax'] as num?)?.toDouble(),
      caloriesPerMinute: (metrics['cal_per_min'] as num?)?.toDouble(),
      dominantZone: (metrics['dominant_zone'] as num?)?.toInt(),
      paceMinPerKm: (metrics['pace_min_per_km'] as num?)?.toDouble(),
      speedKmh: (metrics['speed_kmh'] as num?)?.toDouble(),
      trimp: (metrics['trimp'] as num?)?.toDouble(),
      hrDriftBpm: (metrics['hr_drift_bpm'] as num?)?.toDouble(),
      averagePercentHrmax: (metrics['avg_pct_hrmax'] as num?)?.toDouble(),
      withheld: _withheld(json['metrics_withheld']),
    );
  }

  /// `metrics_withheld` — one disclosure per derived figure the session lacks.
  ///
  /// Empty when the key is absent, which is the honest reading of an older
  /// server rather than an error: `workout_readings.dart` still knows how to
  /// name every absence it can see for itself, and falls back to that.
  static Map<String, Disclosure> _withheld(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return const <String, Disclosure>{};
    }
    return <String, Disclosure>{
      for (final MapEntry<String, Object?> entry in raw.entries)
        if (entry.value case final Map<String, Object?> block)
          if (block['reason'] is String && block['message'] is String)
            entry.key: Disclosure.fromJson(block),
    };
  }

  static DevicePoint _point(Map<String, Object?> row, DateTime start) =>
      DevicePoint(
        start.add(Duration(minutes: (row['min']! as num).toInt())),
        (row['hr']! as num).toDouble(),
      );

  final WorkoutSummary workout;
  final List<DevicePoint> heartRate;
  final List<int> zones;

  /// Server-stated reasons, keyed by the `metrics` key each is about.
  ///
  /// The half `workout_readings.dart` could not have: the session-load gate
  /// turns on a resting heart rate and the owner's sex, and neither is anywhere
  /// on this payload, so the app could only list every input and hope.
  final Map<String, Disclosure> withheld;
  final double? hrmax;
  final double? maxPercentHrmax;
  final double? caloriesPerMinute;
  final int? dominantZone;
  final String? intensity;
  final double? paceMinPerKm;
  final double? speedKmh;
  final double? trimp;
  final double? hrDriftBpm;
  final double? averagePercentHrmax;
}
