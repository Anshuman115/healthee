import 'package:healthee/data/gps/route_point.dart';

class RecordedRoute {
  const RecordedRoute({
    required this.id,
    required this.start,
    required this.points,
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
  final List<RoutePoint> points;
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
