import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';

class ProgramOverview extends ConsumerWidget {
  const ProgramOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AccountAsyncView<CommitmentRepository>(
        value: ref.watch(commitmentRepositoryProvider),
        onRetry: () => ref.invalidate(commitmentRepositoryProvider),
        builder: (context, repository) => CachedAsyncView<ProgramFeed>(
          value: ref.watch(programFeedProvider),
          onRetry: () => ref.invalidate(programFeedProvider),
          builder: (context, feed) => Column(
            key: ObjectKey(repository),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Programs', style: Theme.of(context).textTheme.titleLarge),
              if (feed.active != null) _row(context, feed.active!),
              for (final program in feed.suggested) _row(context, program),
              if (feed.active == null && feed.suggested.isEmpty)
                const Text('No program yet'),
              ServerActionButton(
                label: 'Generate a program',
                action: repository.generateProgram,
                onSaved: () => ref.invalidate(commitmentRepositoryProvider),
              ),
              if (feed.recent.isNotEmpty)
                ExpansionTile(
                  title: const Text('Past programs'),
                  children: [
                    for (final program in feed.recent) _row(context, program),
                  ],
                ),
            ],
          ),
        ),
      );

  Widget _row(BuildContext context, HealthProgram program) => ListTile(
    title: Text(program.title),
    subtitle: Text(
      '${program.status} · ${program.settledRungs}/${program.rungs.length} steps settled',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => unawaited(context.push('${Routes.program}/${program.id}')),
  );
}
