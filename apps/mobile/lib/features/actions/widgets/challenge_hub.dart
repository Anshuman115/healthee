import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/features/actions/widgets/challenge_card.dart';
import 'package:healthee/features/actions/widgets/program_overview.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';

class ChallengeHub extends ConsumerWidget {
  const ChallengeHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AccountAsyncView<CommitmentRepository>(
        value: ref.watch(commitmentRepositoryProvider),
        onRetry: () => ref.invalidate(commitmentRepositoryProvider),
        builder: (context, repository) => Column(
          key: ObjectKey(repository),
          children: [
            const ProgramOverview(),
            CachedAsyncView<ChallengeFeed>(
              value: ref.watch(challengeFeedProvider),
              onRetry: () => ref.invalidate(challengeFeedProvider),
              builder: (context, feed) => _feed(context, ref, repository, feed),
            ),
          ],
        ),
      );

  Widget _feed(
    BuildContext context,
    WidgetRef ref,
    CommitmentRepository repository,
    ChallengeFeed feed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Challenges · ${feed.active.length}/${feed.maxActive} active',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (feed.active.isEmpty) const Text('No active challenges'),
      for (final challenge in feed.active)
        Padding(
          padding: const EdgeInsets.only(top: Insets.md),
          child: ChallengeCard(challenge: challenge),
        ),
      const Text('Suggested for you'),
      if (feed.suggested.isEmpty)
        const Text(
          'No suggestions yet. The server needs enough data to calibrate a target.',
        ),
      for (final challenge in feed.suggested)
        Padding(
          padding: const EdgeInsets.only(top: Insets.md),
          child: ChallengeCard(challenge: challenge),
        ),
      ServerActionButton(
        label: 'Generate challenges',
        action: repository.generateChallenges,
        onSaved: () => ref.invalidate(commitmentRepositoryProvider),
      ),
      if (feed.recent.isNotEmpty)
        ExpansionTile(
          title: const Text('Recent challenges'),
          children: [
            for (final challenge in feed.recent)
              ChallengeCard(challenge: challenge),
          ],
        ),
      TextButton(
        onPressed: () => unawaited(context.push(Routes.outcomes)),
        child: const Text('Review outcomes'),
      ),
    ],
  );
}
