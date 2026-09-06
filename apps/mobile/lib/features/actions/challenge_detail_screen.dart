import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/features/actions/widgets/challenge_progress_card.dart';
import 'package:healthee/shared/challenge_outcome_card.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({required this.id, super.key});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Challenge')),
    body: AccountAsyncView<CommitmentRepository>(
      value: ref.watch(commitmentRepositoryProvider),
      onRetry: () => ref.invalidate(commitmentRepositoryProvider),
      builder: (context, repository) => CachedAsyncView<ChallengeFeed>(
        value: ref.watch(challengeFeedProvider),
        onRetry: () => ref.invalidate(challengeFeedProvider),
        builder: (context, feed) => switch (feed.find(id)) {
          final Challenge challenge => _content(ref, repository, challenge),
          null => const EmptyState(
            message: 'Challenge unavailable',
            hint: 'It may have moved out of the recent history.',
          ),
        },
      ),
    ),
  );

  Widget _content(
    WidgetRef ref,
    CommitmentRepository repository,
    Challenge challenge,
  ) {
    final sections = <Widget>[
      GroundedProse(text: challenge.title, alsoCites: challenge.citations),
      Text(
        '${challenge.status} · ${challenge.difficulty} · ${challenge.windowDays} days',
      ),
      Text(
        '${metricName(challenge.metric)} ${challenge.comparator} ${challenge.target} · ${challenge.cadence}',
      ),
      GroundedProse(text: challenge.why, alsoCites: challenge.citations),
      if (challenge.howTo != null)
        GroundedProse(text: challenge.howTo!, alsoCites: challenge.citations),
      if (challenge.expectedOutcome != null)
        GroundedProse(
          text: challenge.expectedOutcome!,
          alsoCites: challenge.citations,
        ),
      if (challenge.outcome != null)
        ChallengeOutcomeCard(outcome: challenge.outcome!),
      if (challenge.progress != null)
        ChallengeProgressCard(progress: challenge.progress!),
      if (challenge.status == 'suggested')
        _action(ref, repository, 'adopt', 'Start challenge'),
      if (challenge.status == 'active') ...[
        if (challenge.progress?.adaptationDirection != null &&
            challenge.progress?.adaptationDirection != 'withheld')
          _action(ref, repository, 'adapt', 'Apply recalibration'),
        _action(ref, repository, 'abandon', 'Stop challenge'),
      ],
    ];
    return ListView.separated(
      key: ObjectKey(repository),
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: Insets.lg),
      itemBuilder: (context, index) => sections[index],
    );
  }

  Widget _action(
    WidgetRef ref,
    CommitmentRepository repository,
    String action,
    String label,
  ) => ServerActionButton(
    label: label,
    action: () => repository.challengeAction(id, action),
    onSaved: () => ref.invalidate(commitmentRepositoryProvider),
  );
}
