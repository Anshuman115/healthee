import 'package:flutter/material.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class ChallengeOutcomeCard extends StatelessWidget {
  const ChallengeOutcomeCard({required this.outcome, super.key});
  final ChallengeOutcome outcome;
  @override
  Widget build(BuildContext context) => StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(metricName(outcome.metric ?? 'Unknown metric')),
        Text(
          '${outcome.status ?? 'Unreported'} · ${outcome.endedAt.toLocal()}',
        ),
        Text('Data confidence: ${outcome.confidence}'),
        if (outcome.baseline != null) Text('Baseline: ${outcome.baseline}'),
        if (outcome.finalValue != null) Text('Final: ${outcome.finalValue}'),
        if (outcome.adherence != null)
          Text('Daily adherence: ${(outcome.adherence! * 100).round()}%')
        else
          const Text('Daily adherence is not applicable or was not assessed.'),
        if (outcome.changePercent != null)
          Text('Recorded change: ${outcome.changePercent}%'),
        if (outcome.illnessDays != null)
          Text('Illness days: ${outcome.illnessDays}'),
        if (outcome.concurrentChallenges != null)
          Text('Concurrent challenges: ${outcome.concurrentChallenges}'),
        Text(
          outcome.regressionRisk == null
              ? 'Regression to the mean was not assessed.'
              : outcome.regressionRisk!
              ? 'Regression to the mean may explain some change.'
              : 'No regression-to-mean risk was flagged.',
        ),
        if (outcome.coOccurrenceNote != null) Text(outcome.coOccurrenceNote!),
        const Text(
          'These observations do not establish that the challenge caused the change.',
        ),
      ],
    ),
  );
}
