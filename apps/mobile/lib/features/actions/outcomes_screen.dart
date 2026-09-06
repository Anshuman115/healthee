import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/challenges/challenge_outcome.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/shared/challenge_outcome_card.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class OutcomesScreen extends ConsumerWidget {
  const OutcomesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Challenge outcomes')),
    body: CachedAsyncView<List<ChallengeOutcome>>(
      value: ref.watch(challengeOutcomesProvider),
      onRetry: () => ref.invalidate(challengeOutcomesProvider),
      builder: (context, outcomes) => outcomes.isEmpty
          ? const EmptyState(
              message: 'No completed evaluations yet',
              hint: 'Outcomes appear after the server settles a challenge.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(Insets.lg),
              itemCount: outcomes.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: Insets.lg),
              itemBuilder: (context, index) =>
                  ChallengeOutcomeCard(outcome: outcomes[index]),
            ),
    ),
  );
}
