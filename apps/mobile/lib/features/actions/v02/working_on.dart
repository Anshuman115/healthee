/// `What you’re working on` — the challenges and the program, in one stack.
///
/// ```js
/// // screens-actions.js
/// H.section('What you’re working on', `<div class="stack">
///   ${H.state.challengeEnded ? H.notice(…) : activeChallenge()}
///   <div class="card flush">${H.row('flag','Build a walking rhythm',…)}</div>
/// </div>`)
/// ```
/// `.stack { display:grid; gap: var(--space-lg) }`.
///
/// ## Two departures, both forced by having more data than the fixture
///
/// **The card is repeated, not redesigned.** The prototype's fixture has one
/// challenge; a feed has active ones and suggested ones. Both are drawn with the
/// same `.challenge-card`, and only the `.tiny-label` says which — see
/// `ChallengeCard.windowLabel`. Inventing a second card shape for a suggestion
/// would be design judgement, which is not ours on this screen.
///
/// **The generate controls appear only when there is nothing to pick up.** The
/// prototype has no such control because its fixture always has a challenge and
/// a program. Ours can have neither, and a screen that offers no way out of that
/// state is a dead end. They are drawn in the prototype's own `.two` row of
/// `.button.secondary`, which is what its challenge screen uses.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/challenge_feed.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/features/actions/v02/challenge_card.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// `.stack { gap: var(--space-lg) }`.
const double kStackGap = 16;

/// What the section says when the feed holds nothing at all.
const String kNoChallengeTitle = 'A little space for what’s next';

/// And why. The server needs enough history to calibrate a target, which is a
/// fact about the data rather than an encouragement.
const String kNoChallengeBody =
    'Nothing is running. A challenge needs enough of your own history behind '
    'it for the server to set a target you can actually meet.';

/// The body of the `What you’re working on` section.
class WorkingOn extends ConsumerWidget {
  /// Reads both feeds; each renders what it has and nothing when it has none.
  const WorkingOn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountAsyncView<CommitmentRepository>(
      value: ref.watch(commitmentRepositoryProvider),
      onRetry: () => ref.invalidate(commitmentRepositoryProvider),
      builder: (context, repository) => Column(
        key: ObjectKey(repository),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CachedAsyncView<ChallengeFeed>(
            value: ref.watch(challengeFeedProvider),
            onRetry: () => ref.invalidate(challengeFeedProvider),
            builder: (context, feed) => _Challenges(feed: feed),
          ),
          const SizedBox(height: kStackGap),
          CachedAsyncView<ProgramFeed>(
            value: ref.watch(programFeedProvider),
            onRetry: () => ref.invalidate(programFeedProvider),
            builder: (context, feed) => _Programs(feed: feed),
          ),
          _Generate(ref: ref, repository: repository),
        ],
      ),
    );
  }
}

class _Challenges extends StatelessWidget {
  const _Challenges({required this.feed});

  final ChallengeFeed feed;

  @override
  Widget build(BuildContext context) {
    final entries = <Challenge>[...feed.active, ...feed.suggested];
    if (entries.isEmpty) {
      return const Notice(title: kNoChallengeTitle, body: kNoChallengeBody);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < entries.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: kStackGap),
          Builder(
            builder: (context) => ChallengeCard(
              challenge: entries[i],
              onOpen: () => unawaited(
                context.push('${Routes.challenge}/${entries[i].id}'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Programs extends StatelessWidget {
  const _Programs({required this.feed});

  final ProgramFeed feed;

  @override
  Widget build(BuildContext context) {
    final program = feed.active ?? feed.suggested.firstOrNull;
    // Null renders nothing: no empty card, no heading over an absence.
    if (program == null) {
      return const SizedBox.shrink();
    }
    return RowCard(<Widget>[
      ListRow(
        icon: Icons.flag_outlined,
        title: program.title,
        subtitle: subtitleFor(program),
        tone: Tone.movement,
        onTap: () => unawaited(context.push('${Routes.program}/${program.id}')),
      ),
    ]);
  }

  /// `Your active program · week 3 of 4`, or the prototype's line for one that
  /// has not been started. Both are the server's own numbers.
  static String subtitleFor(HealthProgram program) {
    if (program.status != 'active') {
      final weeks = program.weeks;
      return weeks == null
          ? 'A program, at your pace'
          : 'A $weeks-week program, at your pace';
    }
    final total = program.rungs.length;
    return total == 0
        ? 'Your active program'
        : 'Your active program · step ${program.settledRungs + 1} of $total';
  }
}

/// The way out of an empty feed. Absent whenever there is something to pick up.
class _Generate extends ConsumerWidget {
  const _Generate({required this.ref, required this.repository});

  final WidgetRef ref;
  final CommitmentRepository repository;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final challenges = ref.watch(challengeFeedProvider).value?.data;
    final programs = ref.watch(programFeedProvider).value?.data;
    final needsChallenge = challenges != null && challenges.suggested.isEmpty;
    final needsProgram =
        programs != null && programs.active == null && programs.suggested.isEmpty;
    if (!needsChallenge && !needsProgram) {
      return const SizedBox.shrink();
    }
    final buttons = <Widget>[
      if (needsChallenge)
        ServerActionButton(
          label: 'Suggest a challenge',
          action: repository.generateChallenges,
          onSaved: () => ref.invalidate(commitmentRepositoryProvider),
        ),
      if (needsProgram)
        ServerActionButton(
          label: 'Suggest a program',
          action: repository.generateProgram,
          onSaved: () => ref.invalidate(commitmentRepositoryProvider),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: kStackGap),
      child: buttons.length == 1
          ? buttons.single
          : Row(
              children: <Widget>[
                Expanded(child: buttons.first),
                const SizedBox(width: 12),
                Expanded(child: buttons.last),
              ],
            ),
    );
  }
}
