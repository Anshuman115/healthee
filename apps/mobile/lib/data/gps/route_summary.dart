class RouteSummary {
  const RouteSummary({
    required this.id,
    required this.start,
    this.distanceKm,
    this.durationS,
  });
  factory RouteSummary.fromJson(Map<String, Object?> json) => RouteSummary(
    id: json['track_id']! as String,
    start: DateTime.parse(json['start_ts']! as String),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    durationS: (json['duration_s'] as num?)?.toInt(),
  );
  final String id;
  final DateTime start;
  final double? distanceKm;
  final int? durationS;
}
