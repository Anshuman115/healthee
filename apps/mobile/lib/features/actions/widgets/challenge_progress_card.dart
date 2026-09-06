import 'package:flutter/material.dart';
import 'package:healthee/data/challenges/challenge_progress.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class ChallengeProgressCard extends StatelessWidget {
  const ChallengeProgressCard({required this.progress, super.key});
  final ChallengeProgress progress;

  @override
  Widget build(BuildContext context) => StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${progress.daysLeft} days left'),
        Text(
          progress.todayValue == null
              ? 'No observation for today yet'
              : 'Today: ${progress.todayValue} ${progress.unit}',
        ),
        if (progress.cadence == 'daily') ...[
          Text('${progress.hitDays} of ${progress.window} days met the target'),
          if (progress.streak != null)
            Text('Current streak: ${progress.streak} days'),
        ] else
          Text(
            'Running total: ${progress.current ?? 'unavailable'} ${progress.unit}',
          ),
        if (progress.protectedToday)
          const Text('Today is protected for recovery.'),
        if (progress.breached)
          const Text('The cap has been exceeded in this window.'),
        if (progress.adaptationReason != null) Text(progress.adaptationReason!),
      ],
    ),
  );
}
