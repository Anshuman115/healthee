import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/features/actions/widgets/challenge_progress_card.dart';
import 'package:healthee/shared/challenge_outcome_card.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({required this.id, super.key});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Program')),
    body: AccountAsyncView<CommitmentRepository>(
      value: ref.watch(commitmentRepositoryProvider),
      onRetry: () => ref.invalidate(commitmentRepositoryProvider),
      builder: (context, repository) => CachedAsyncView<ProgramFeed>(
        value: ref.watch(programFeedProvider),
        onRetry: () => ref.invalidate(programFeedProvider),
        builder: (context, feed) => switch (feed.find(id)) {
          final HealthProgram program => _content(ref, repository, program),
          null => const EmptyState(
            message: 'Program unavailable',
            hint: 'Refresh the program feed.',
          ),
        },
      ),
    ),
  );

  Widget _content(
    WidgetRef ref,
    CommitmentRepository repository,
    HealthProgram program,
  ) {
    final citations = program.rungs
        .expand((rung) => rung.citations)
        .toSet()
        .toList();
    final sections = <Widget>[
      GroundedProse(text: program.title, alsoCites: citations),
      Text('${program.status} · ${program.weeks ?? '—'} weeks'),
      GroundedProse(text: program.why, alsoCites: citations),
      if (program.goal != null)
        GroundedProse(text: program.goal!, alsoCites: citations),
      if (program.holdReason != null) Text('On hold: ${program.holdReason}'),
      if (program.endedReason != null) Text('Ended: ${program.endedReason}'),
      for (final rung in program.rungs) _rung(rung),
      if (program.status == 'suggested')
        _action(ref, repository, 'adopt', 'Start program'),
      if (program.status == 'active')
        _action(ref, repository, 'abandon', 'Stop program'),
      const Text(
        'Steps advance after server evaluation. Recovery holds and reduced steps are part of the program.',
      ),
    ];
    return ListView.separated(
      key: ObjectKey(repository),
      padding: const EdgeInsets.all(Insets.lg),
      itemCount: sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: Insets.lg),
      itemBuilder: (context, index) => sections[index],
    );
  }

  Widget _rung(Challenge rung) => ExpansionTile(
    title: Text(rung.title),
    subtitle: Text('${rung.status} · ${rung.kind}'),
    children: [
      GroundedProse(text: rung.why, alsoCites: rung.citations),
      if (rung.howTo != null)
        GroundedProse(text: rung.howTo!, alsoCites: rung.citations),
      if (rung.outcome != null) ChallengeOutcomeCard(outcome: rung.outcome!),
      if (rung.progress != null)
        ChallengeProgressCard(progress: rung.progress!),
    ],
  );

  Widget _action(
    WidgetRef ref,
    CommitmentRepository repository,
    String action,
    String label,
  ) => ServerActionButton(
    label: label,
    action: () => repository.programAction(id, action),
    onSaved: () => ref.invalidate(commitmentRepositoryProvider),
  );
}
