import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({required this.challenge, super.key});
  final Challenge challenge;

  @override
  Widget build(BuildContext context) => StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroundedProse(text: challenge.title, alsoCites: challenge.citations),
        Text(
          '${challenge.status} · ${challenge.difficulty} · ${challenge.cadence}',
        ),
        if (challenge.kind == 'deload')
          const Text('Recovery step · reduced target'),
        Text(
          '${metricName(challenge.metric)} ${challenge.comparator} ${challenge.target} · ${challenge.windowDays} days',
        ),
        TextButton(
          onPressed: () =>
              unawaited(context.push('${Routes.challenge}/${challenge.id}')),
          child: const Text('View challenge'),
        ),
      ],
    ),
  );
}
