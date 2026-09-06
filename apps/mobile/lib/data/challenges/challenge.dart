import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/data/challenges/challenge_progress.dart';

class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.why,
    required this.status,
    required this.metric,
    required this.target,
    required this.comparator,
    required this.cadence,
    required this.windowDays,
    required this.difficulty,
    required this.kind,
    required this.citations,
    this.howTo,
    this.expectedOutcome,
    this.progress,
    this.programId,
    this.outcome,
  });

  factory Challenge.fromJson(Map<String, Object?> json) => Challenge(
    id: (json['id']! as num).toInt(),
    title: json['title']! as String,
    why: json['why']! as String,
    status: json['status']! as String,
    metric: json['metric']! as String,
    target: (json['target_value']! as num).toDouble(),
    comparator: json['comparator']! as String,
    cadence: json['cadence']! as String,
    windowDays: (json['window_days']! as num).toInt(),
    difficulty: json['difficulty']! as String,
    kind: json['kind']! as String,
    citations: [
      for (final id in json['research_note_ids'] as List<Object?>? ?? [])
        id! as String,
    ],
    howTo: json['how_to'] as String?,
    expectedOutcome: json['expected_outcome'] as String?,
    programId: (json['program_id'] as num?)?.toInt(),
    outcome: json['outcome'] == null
        ? null
        : ChallengeOutcome.fromJson(json['outcome']! as Map<String, Object?>),
    progress: json['progress'] == null
        ? null
        : ChallengeProgress.fromJson(json['progress']! as Map<String, Object?>),
  );
  final int id;
  final String title;
  final String why;
  final String status;
  final String metric;
  final double target;
  final String comparator;
  final String cadence;
  final int windowDays;
  final String difficulty;
  final String kind;
  final List<String> citations;
  final String? howTo;
  final String? expectedOutcome;
  final ChallengeProgress? progress;
  final int? programId;
  final ChallengeOutcome? outcome;
}
