/// Cadence-aware progress; missing observations are not zero adherence.
class ChallengeProgress {
  const ChallengeProgress({
    required this.cadence,
    required this.target,
    required this.daysLeft,
    required this.unit,
    this.todayValue,
    this.current,
    this.hitDays,
    this.streak,
    this.window,
    this.protectedToday = false,
    this.breached = false,
    this.adaptationReason,
    this.adaptationDirection,
  });

  factory ChallengeProgress.fromJson(Map<String, Object?> json) {
    final adaptation = json['adaptation'] as Map<String, Object?>?;
    return ChallengeProgress(
      cadence: json['cadence']! as String,
      target: (json['target']! as num).toDouble(),
      daysLeft: (json['days_left']! as num).toInt(),
      unit: json['unit']! as String,
      todayValue: (json['today_value'] as num?)?.toDouble(),
      current: (json['current'] as num?)?.toDouble(),
      hitDays: (json['hit_days'] as num?)?.toInt(),
      streak: (json['streak'] as num?)?.toInt(),
      window: (json['window'] as num?)?.toInt(),
      protectedToday: json['protected_today'] == true,
      breached: json['breached'] == true,
      adaptationReason: adaptation?['reason'] as String?,
      adaptationDirection: adaptation?['direction'] as String?,
    );
  }
  final String cadence;
  final double target;
  final int daysLeft;
  final String unit;
  final double? todayValue;
  final double? current;
  final int? hitDays;
  final int? streak;
  final int? window;
  final bool protectedToday;
  final bool breached;
  final String? adaptationReason;
  final String? adaptationDirection;
}
