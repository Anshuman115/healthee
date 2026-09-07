import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/metric_info/challenge_sources.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: GroundedProse(text: challenge.title)),
            // What the title cites, off the card face and one tap away.
            if (challengeSources(challenge) case final MetricDetail detail
                when detail.isNotEmpty)
              MetricInfoDot(
                null,
                detail: detail,
                fallbackTitle: metricName(challenge.metric),
              ),
          ],
        ),
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
