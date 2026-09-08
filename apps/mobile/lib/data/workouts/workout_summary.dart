class WorkoutSummary {
  const WorkoutSummary({
    required this.start,
    required this.sportName,
    this.durationMin,
    this.distanceM,
    this.calories,
    this.avgHr,
    this.maxHr,
    this.minHr,
  });

  factory WorkoutSummary.fromJson(Map<String, Object?> json) => WorkoutSummary(
    start: DateTime.parse(json['start_iso']! as String),
    sportName: json['sport_name']! as String,
    durationMin: (json['duration_min'] as num?)?.toInt(),
    distanceM: (json['distance_m'] as num?)?.toDouble(),
    calories: (json['calories'] as num?)?.toDouble(),
    avgHr: (json['avg_hr'] as num?)?.toInt(),
    maxHr: (json['max_hr'] as num?)?.toInt(),
    minHr: (json['min_hr'] as num?)?.toInt(),
  );
  final DateTime start;
  final String sportName;
  final int? durationMin;
  final double? distanceM;
  final double? calories;
  final int? avgHr;
  final int? maxHr;
  final int? minHr;
}
