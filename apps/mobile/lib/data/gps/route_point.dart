class RoutePoint {
  const RoutePoint({
    required this.at,
    required this.latitude,
    required this.longitude,
    this.elevationM,
    this.hr,
    this.paceMinKm,
  });
  factory RoutePoint.fromJson(Map<String, Object?> json) => RoutePoint(
    at: DateTime.fromMillisecondsSinceEpoch(
      ((json['t']! as num) * 1000).round(),
      isUtc: true,
    ),
    latitude: (json['lat']! as num).toDouble(),
    longitude: (json['lng']! as num).toDouble(),
    elevationM: (json['ele'] as num?)?.toDouble(),
    hr: (json['hr'] as num?)?.toDouble(),
    paceMinKm: (json['pace'] as num?)?.toDouble(),
  );
  final DateTime at;
  final double latitude;
  final double longitude;
  final double? elevationM;
  final double? hr;
  final double? paceMinKm;
}
