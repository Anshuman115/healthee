/// Frozen result and known confounders; never interpreted as a causal effect.
class ChallengeOutcome {
  const ChallengeOutcome({
    required this.challengeId,
    required this.confidence,
    required this.endedAt,
    this.metric,
    this.status,
    this.baseline,
    this.finalValue,
    this.adherence,
    this.changePercent,
    this.illnessDays,
    this.concurrentChallenges,
    this.regressionRisk,
    this.coOccurrenceNote,
  });
  factory ChallengeOutcome.fromJson(Map<String, Object?> json) {
    final confounds = json['confounds']! as Map<String, Object?>;
    final regression = confounds['regression_to_mean'] as Map<String, Object?>?;
    final concurrent = json['co_occurring'] as Map<String, Object?>?;
    return ChallengeOutcome(
      challengeId: (json['challenge_id']! as num).toInt(),
      confidence: json['data_confidence']! as String,
      endedAt: DateTime.parse(json['ended_at']! as String),
      metric: json['metric'] as String?,
      status: json['status'] as String?,
      baseline: (json['baseline'] as num?)?.toDouble(),
      finalValue: (json['final'] as num?)?.toDouble(),
      adherence: (json['adherence'] as num?)?.toDouble(),
      changePercent: (json['improvement_pct'] as num?)?.toDouble(),
      illnessDays: (confounds['illness_days'] as num?)?.toInt(),
      concurrentChallenges: (confounds['concurrent_challenges'] as num?)
          ?.toInt(),
      regressionRisk: regression?['assessed'] == true
          ? (regression?['at_risk'] as bool?)
          : null,
      coOccurrenceNote: concurrent?['note'] as String?,
    );
  }
  final int challengeId;
  final String confidence;
  final DateTime endedAt;
  final String? metric;
  final String? status;
  final double? baseline;
  final double? finalValue;
  final double? adherence;
  final double? changePercent;
  final int? illnessDays;
  final int? concurrentChallenges;
  final bool? regressionRisk;
  final String? coOccurrenceNote;
}
