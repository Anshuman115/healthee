import 'package:healthee/data/gps/route_point.dart';

class RecordedRoute {
  const RecordedRoute({
    required this.id,
    required this.start,
    required this.points,
    required this.recordedPoints,
    required this.matchedHrPoints,
    required this.pointsDecimated,
    this.distanceKm,
    this.durationS,
    this.movingS,
    this.avgHr,
    this.maxHr,
    this.elevationMinM,
    this.elevationMaxM,
    this.avgPaceMinKm,
    this.elevationGainM,
    this.elevationLossM,
    this.vo2max,
    this.vo2Method,
    this.r2,
  });
  factory RecordedRoute.fromJson(Map<String, Object?> json) {
    final summary = json['summary']! as Map<String, Object?>;
    final vo2 = summary['vo2max'] as Map<String, Object?>?;
    return RecordedRoute(
      id: json['track_id']! as String,
      start: DateTime.parse(json['start_ts']! as String),
      points: [
        for (final row in json['points']! as List<Object?>)
          RoutePoint.fromJson(row! as Map<String, Object?>),
      ],
      // Facts about the RECORDING, read from the server rather than counted off
      // `points` — see the class docstring. The fallbacks keep a payload written
      // before these keys existed readable, and they fall back to the array's own
      // length, which is exactly right for a response that was never thinned.
      recordedPoints:
          (summary['n_points'] as num?)?.toInt() ??
          (json['points']! as List<Object?>).length,
      matchedHrPoints: (summary['n_hr_points'] as num?)?.toInt(),
      pointsDecimated: summary['points_decimated'] as bool? ?? false,
      distanceKm: (summary['distance_km'] as num?)?.toDouble(),
      durationS: (summary['duration_s'] as num?)?.toInt(),
      movingS: (summary['moving_s'] as num?)?.toInt(),
      avgHr: (summary['avg_hr'] as num?)?.toDouble(),
      maxHr: (summary['max_hr'] as num?)?.toDouble(),
      elevationMinM: (summary['ele_min'] as num?)?.toDouble(),
      elevationMaxM: (summary['ele_max'] as num?)?.toDouble(),
      avgPaceMinKm: (summary['avg_pace_min_km'] as num?)?.toDouble(),
      elevationGainM: (summary['ele_gain_m'] as num?)?.toDouble(),
      elevationLossM: (summary['ele_loss_m'] as num?)?.toDouble(),
      vo2max: (vo2?['vo2max'] as num?)?.toDouble(),
      vo2Method: vo2?['method'] as String?,
      r2: (vo2?['r2'] as num?)?.toDouble(),
    );
  }
  final String id;
  final DateTime start;

  /// The fixes the server SENT — a sample of the recording when it is long.
  ///
  /// Draw these; never count them. See [recordedPoints].
  final List<RoutePoint> points;

  /// How many fixes the recording actually holds (`summary.n_points`).
  ///
  /// Not `points.length`. The server thins a long track for the map view
  /// (`read/gps.py::MAX_MAP_POINTS`, 2,000 — this app's own
  /// `RouteMap.maxDrawnPoints`), so on a maximal 28,800-fix run the array is 7%
  /// of the recording. Every count shown to the owner comes from here, because a
  /// count taken off the array would describe the response instead of their run.
  final int recordedPoints;

  /// How many fixes got a heart rate (`summary.n_hr_points`), or null on a
  /// payload written before the server sent it.
  ///
  /// Same reason as [recordedPoints]: this was counted off `points` and could
  /// only ever have been right while `points` was the whole track.
  final int? matchedHrPoints;

  /// Whether [points] is a sample of the recording rather than all of it.
  final bool pointsDecimated;

  final double? distanceKm;
  final int? durationS;
  final int? movingS;
  final double? avgHr;
  final double? maxHr;
  final double? elevationMinM;
  final double? elevationMaxM;
  final double? avgPaceMinKm;
  final double? elevationGainM;
  final double? elevationLossM;
  final double? vo2max;
  final String? vo2Method;
  final double? r2;
}
