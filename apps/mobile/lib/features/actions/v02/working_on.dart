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
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/features/actions/v02/challenge_card.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:solar_icons/solar_icons.dart';

/// `.stack { gap: var(--space-lg) }`.
const double kStackGap = 16;

/// Why nothing is running — a fact about the data, not an encouragement.
///
/// **It used to carry a title too**, `A little space for what's next`, sitting
/// directly under the section's own `What you're working on` heading. Two
/// headings, one above the other, both saying that nothing is here; the card
/// they made was as tall as a suggestion, for an absence. The sentence is the
/// part worth keeping, and it stays on the face rather than behind a control:
/// it says the server needs history to set a target, which is the reason the
/// two buttons below might not do what the owner expects yet.
const String kNoChallengeBody =
    'Nothing is running. A challenge needs enough of your own history behind '
    'it for the server to set a target you can actually meet.';

/// What to say when a run cleared the server but produced nothing.
///
/// **The engine refusing is not the engine failing.** `program_generate` logs
/// things like *"rung 3 asks for 180, past the evidence target of 150
/// [mvpa_minutes_mortality]"* and *"a ladder has 3-6 rungs, and this one has
/// 2"*, ships them in `rejected`, and returns `200`. Those are the honesty
/// gates working. The owner saw a button that did nothing twice.
///
/// The gates' own wording is shown rather than a paraphrase: it names the rule
/// and the note behind it, and a summary written here would be a second
/// account of a decision this app did not make.
String? _nothingMade(GenerationOutcome outcome, String noun) {
  if (!outcome.producedNothing) {
    return null;
  }
  final why = outcome.rejected.isEmpty
      ? 'Nothing cleared the evidence rules this time.'
      : outcome.rejected.first;
  return 'No $noun this time — $why';
}

/// Which half of a commitment feed a section draws.
///
/// ## ⛔ The two are not one list
///
/// `_Challenges` used to build `[...feed.active, ...feed.suggested]` — one
/// undifferentiated run of cards under the heading `What you're working on`.
/// On the owner's own device that heading sat over two cards both badged
/// `Suggested · 7-day`, for challenges nobody had adopted. **The heading was
/// false**, and the screen was ordered by where the data came from — daily
/// recommendations, then challenges, then programs — rather than by the only
/// question a reader is asking: what am I already doing, and what else is on
/// offer?
///
/// Both feeds carry `active`, `suggested` and `recent`. The screen now reads
/// that distinction instead of flattening it.
enum CommitmentScope {
  /// Adopted challenges and the running ladder. Draws nothing when there are
  /// none — an empty section is not a section, and the heading would lie again.
  running,

  /// Suggested challenges and ladders, plus the controls that ask for more.
  /// Always drawn: the generate buttons are the only way to fill it.
  offered,
}

/// The body of the `What you’re working on` section.
class WorkingOn extends ConsumerWidget {
  /// Reads both feeds; each renders what it has and nothing when it has none.
  const WorkingOn({required this.scope, super.key});

  /// Which half of the feeds to draw. See [CommitmentScope].
  final CommitmentScope scope;

  /// The heading this scope carries, drawn with the content so a section that
  /// turns out to be empty takes its title with it.
  String get heading => switch (scope) {
    CommitmentScope.running => 'What you’re working on',
    // Named against the suggestions ABOVE it, which are for today. This is the
    // same decision at a longer horizon, and saying so is what makes two
    // families of card on one screen legible as one idea.
    CommitmentScope.offered => 'Beyond today',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountAsyncView<CommitmentRepository>(
      value: ref.watch(commitmentRepositoryProvider),
      onRetry: () => ref.invalidate(commitmentRepositoryProvider),
      builder: (context, repository) => _Body(
        key: ObjectKey(repository),
        scope: scope,
        heading: heading,
        repository: repository,
        outerRef: ref,
      ),
    );
  }
}

/// One scope's heading and content, or nothing at all.
class _Body extends ConsumerWidget {
  const _Body({
    required this.scope,
    required this.heading,
    required this.repository,
    required this.outerRef,
    super.key,
  });

  final CommitmentScope scope;
  final String heading;
  final CommitmentRepository repository;
  final WidgetRef outerRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengeFeedProvider).value?.data;
    final programs = ref.watch(programFeedProvider).value?.data;
    final entries = <Challenge>[
      ...?switch (scope) {
        CommitmentScope.running => challenges?.active,
        CommitmentScope.offered => challenges?.suggested,
      },
    ];
    final program = switch (scope) {
      CommitmentScope.running => programs?.active,
      CommitmentScope.offered => programs?.suggested.firstOrNull,
    };
    final generate = scope == CommitmentScope.offered
        ? Refill(ref: outerRef, repository: repository)
        : const SizedBox.shrink();
    // **A running section with nothing running is not drawn.** Its heading was
    // the false one; see `CommitmentScope`.
    if (scope == CommitmentScope.running &&
        entries.isEmpty &&
        program == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionHead(title: heading),
        if (entries.isEmpty && program == null)
          const PanelNote(kNoChallengeBody)
        else ...<Widget>[
          for (var i = 0; i < entries.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: kStackGap),
            ChallengeCard(challenge: entries[i], onOpen: () => _open(context, entries[i])),
          ],
          if (program case final HealthProgram running) ...<Widget>[
            if (entries.isNotEmpty) const SizedBox(height: kStackGap),
            RowCard(<Widget>[
              ListRow(
                icon: SolarIconsOutline.flag,
                title: running.title,
                subtitle: _Programs.subtitleFor(running),
                tone: Tone.movement,
                onTap: () => unawaited(
                  context.push('${Routes.program}/${running.id}'),
                ),
              ),
            ]),
          ],
        ],
        generate,
      ],
    );
  }

  void _open(BuildContext context, Challenge challenge) =>
      unawaited(context.push('${Routes.challenge}/${challenge.id}'));
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
        icon: SolarIconsOutline.flag,
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
/// The two controls that ask the server for more to decide.
///
/// Public because the deck owns them now: "nothing left to decide" and "ask for
/// more" are one thought, and they were stranded at the bottom of a section
/// that no longer exists.
class Refill extends ConsumerWidget {
  /// Builds them. [ref] is the caller's, so an invalidation lands on the
  /// caller's providers rather than on this widget's own element.
  const Refill({required this.ref, required this.repository, super.key});

  /// The caller's ref.
  final WidgetRef ref;

  /// The repository the buttons act through.
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
          busyNote: 'Reading your recent history and writing a target you '
              'could actually meet. This takes a few seconds.',
          action: () async =>
              _nothingMade(await repository.generateChallenges(), 'challenge'),
          onSaved: () => ref.invalidate(commitmentRepositoryProvider),
        ),
      if (needsProgram)
        ServerActionButton(
          label: 'Suggest a program',
          busyNote: 'Building a multi-week plan from your own measurements. '
              'This takes a few seconds.',
          action: () async =>
              _nothingMade(await repository.generateProgram(), 'plan'),
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
