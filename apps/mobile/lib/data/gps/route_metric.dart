import 'package:healthee/data/gps/route_point.dart';

enum RouteMetric {
  elevation('Elevation', 'm'),
  heartRate('Heart rate', 'bpm'),
  pace('Pace', 'min/km');

  const RouteMetric(this.label, this.unit);
  final String label;
  final String unit;
  double? value(RoutePoint point) => switch (this) {
    elevation => point.elevationM,
    heartRate => point.hr,
    pace => point.paceMinKm,
  };
}

/// Display-only thinning retains both endpoints. Uploads retain every valid fix.
List<RoutePoint> mapPoints(List<RoutePoint> points, {int limit = 2000}) {
  if (points.length <= limit) return points;
  return [
    for (var i = 0; i < limit; i++)
      points[(i * (points.length - 1) / (limit - 1)).round()],
  ];
}
