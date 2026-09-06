import 'package:healthee/data/challenges/challenge.dart';

class HealthProgram {
  const HealthProgram({
    required this.id,
    required this.title,
    required this.why,
    required this.status,
    required this.rungs,
    required this.settledRungs,
    this.goal,
    this.weeks,
    this.holdReason,
    this.endedReason,
  });
  factory HealthProgram.fromJson(Map<String, Object?> json) => HealthProgram(
    id: (json['id']! as num).toInt(),
    title: json['title']! as String,
    why: json['why']! as String,
    status: json['status']! as String,
    rungs: [
      for (final row in json['rungs']! as List<Object?>)
        Challenge.fromJson(row! as Map<String, Object?>),
    ],
    settledRungs: (json['settled_rungs']! as num).toInt(),
    goal: json['goal'] as String?,
    weeks: (json['weeks'] as num?)?.toInt(),
    holdReason: json['hold_reason'] as String?,
    endedReason: json['ended_reason'] as String?,
  );
  final int id;
  final String title;
  final String why;
  final String status;
  final List<Challenge> rungs;
  final int settledRungs;
  final String? goal;
  final int? weeks;
  final String? holdReason;
  final String? endedReason;
}
