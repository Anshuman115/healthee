import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/milestones.dart';
import 'package:healthee/data/notifications/notify_completions.dart';
import 'package:healthee/shared/metric_info/challenge_sources.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/grounded_text.dart';

/// The ⓘ for one challenge: what its server-written title cites, and the
/// `citations` the payload sent beside it. Draws nothing when it cites nothing.
///
/// The chips used to sit under the title, inside the row. On a list of tiles
/// that put them between a headline and its own subtitle, which is where the
/// owner saw them and asked for them gone.
Widget? _sources(Challenge challenge) {
  final detail = challengeSources(challenge);
  return detail.isEmpty ? null : MetricInfoDot(null, detail: detail);
}

/// Active commitments remain reachable from the daily home, as in legacy.
class TodayFocus extends ConsumerWidget {
  const TodayFocus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notifyCompletionsProvider());
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Today’s focus'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.actions),
          ),
          CachedAsyncView<ChallengeFeed>(
            value: ref.watch(challengeFeedProvider),
            onRetry: () => ref.invalidate(challengeFeedProvider),
            builder: (context, feed) => Column(
              children: [
                if (feed.active.isEmpty)
                  const Text(
                    'No active challenges. Review suggestions in Actions.',
                  ),
                for (final challenge in feed.active)
                  ListTile(
                    title: GroundedProse(text: challenge.title),
                    trailing: _sources(challenge),
                    subtitle: Text(
                      challenge.progress?.protectedToday == true
                          ? 'Today is protected for recovery'
                          : '${challenge.progress?.daysLeft ?? '—'} days left',
                    ),
                    onTap: () => unawaited(
                      context.push('${Routes.challenge}/${challenge.id}'),
                    ),
                  ),
              ],
            ),
          ),
          AccountAsyncView<List<Challenge>>(
            value: ref.watch(milestonesProvider),
            onRetry: () => ref.invalidate(milestonesProvider),
            builder: (context, completed) => Column(
              children: [
                for (final challenge in completed)
                  ListTile(
                    leading: const Icon(Icons.celebration),
                    title: const Text('Challenge completed'),
                    trailing: _sources(challenge),
                    subtitle: GroundedProse(text: challenge.title),
                    onTap: () => unawaited(context.push(Routes.outcomes)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
