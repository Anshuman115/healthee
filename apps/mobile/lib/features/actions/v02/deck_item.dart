/// [DeckItem] — one thing the owner has to decide, from either feed.
///
/// Split out of `decision_deck.dart` when the deck took that file past the
/// 400-line limit. The division is the honest one: this is what a decision IS
/// — where it came from, what it commits you to, and what backs it — and the
/// deck is how decisions are asked. A third feed would touch this file only.
///
/// Why a daily recommendation and a suggested challenge are one type at all is
/// argued on the deck itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/data/recommendations/recommendation_history.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/actions/v02/suggestion_card.dart';
import 'package:solar_icons/solar_icons.dart';

/// One thing to decide: a suggestion for today, or a longer commitment.
class DeckItem {
  /// Builds an item. [adopt] is what "yes" does; it may talk to the server.
  const DeckItem({
    required this.horizon,
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    required this.raisedBy,
    required this.grounding,
    required this.rationale,
    required this.grade,
    required this.adopt,
    required this.meta,
    required this.adopted,
    this.howTo,
    this.payoff,
    this.difficulty,
    this.targetLine,
    this.window,
  });

  /// From a daily recommendation.
  factory DeckItem.recommendation(Recommendation rec, WidgetRef ref) => DeckItem(
    horizon: 'Today',
    meta: rec.category?.toUpperCase(),
    adopted: rec.adopted ?? false,
    tone: toneForCategory(rec.category),
    icon: iconForCategory(rec.category),
    title: rec.action,
    body: rec.expectedEffect,
    raisedBy: signalLabel(rec.signalSource),
    grounding: rec.grounding,
    rationale: rec.rationale,
    grade: rec.gradeLabel,
    adopt: rec.id == null
        ? null
        : () async {
            final api = await ref.read(accountApiProvider.future);
            await setRecommendationAdoption(api, rec.id!, 'adopt');
            ref.invalidate(todaySnapshotProvider);
            ref.invalidate(recommendationHistoryProvider);
          },
  );

  /// From a suggested challenge.
  factory DeckItem.challenge(
    Challenge challenge,
    CommitmentRepository repository,
    WidgetRef ref,
  ) => DeckItem(
    horizon: '${challenge.windowDays}-day',
    meta: challenge.metric.replaceAll('_', ' ').toUpperCase(),
    adopted: challenge.status == 'active',
    howTo: challenge.howTo,
    payoff: challenge.expectedOutcome,
    difficulty: challenge.difficulty.toUpperCase(),
    // The commitment as the reference design writes it: monospace, the
    // comparator kept, the cadence after a middot. `≥ 380 min sleep · daily`.
    targetLine:
        '${challenge.comparator} ${challenge.target.round()} '
        '${challenge.metric.replaceAll('_', ' ')} · ${challenge.cadence}',
    window: '${challenge.windowDays}-day',
    tone: Tone.movement,
    icon: SolarIconsOutline.flag,
    title: challenge.title,
    body: challenge.why,
    // The commitment itself, in the metric's own terms — the one line that
    // says what adopting actually signs you up to.
    raisedBy:
        '${challenge.metric.replaceAll('_', ' ')} '
        '${challenge.comparator} ${challenge.target.round()}',
    grounding: challenge.grounding,
    rationale: challenge.why,
    grade: null,
    adopt: () async {
      await repository.challengeAction(challenge.id, 'adopt');
      ref.invalidate(commitmentRepositoryProvider);
    },
  );

  /// From a suggested PROGRAM — a ladder of rungs rather than one commitment.
  ///
  /// ⛔ **Programs had no route to any screen at all.** The deck was built for
  /// recommendations, extended to carry suggested challenges, and never extended
  /// again — so `create_program` wrote a ladder in `suggested`, the feed served
  /// it correctly, and nothing drew it. `actions_screen.dart` mounts only the
  /// RUNNING section, on the stated principle that "what was merely on offer is
  /// in the deck above"; the deck simply never learned about this third feed.
  ///
  /// Found because the coach designed a six-week ladder and the owner could not
  /// find it anywhere in the app. It is why the program is still `suggested`
  /// with no `adopted_at`: there was never a button to press.
  ///
  /// What differs from a challenge is the honest part: a ladder does not commit
  /// you to one target, it commits you to a SEQUENCE. So the horizon is the
  /// program's weeks, and the line that says what you are signing up to names
  /// the rung count rather than a single number that would be only the first
  /// step's.
  factory DeckItem.program(
    HealthProgram program,
    CommitmentRepository repository,
    WidgetRef ref,
  ) => DeckItem(
    horizon: program.weeks == null ? 'Program' : '${program.weeks}-week',
    meta: 'PROGRAM',
    adopted: program.status == 'active',
    payoff: program.goal,
    window: program.weeks == null ? null : '${program.weeks}-week',
    tone: Tone.movement,
    icon: SolarIconsOutline.flag,
    title: program.title,
    body: program.why,
    // The SEQUENCE, not a target. Naming one number here would quote the first
    // rung as if it were the commitment, and the whole point of a ladder is that
    // the target moves.
    raisedBy:
        '${program.rungs.length} rungs, one at a time'
        '${program.goal == null ? '' : ' · ${program.goal}'}',
    // A ladder has no citations of its own — its evidence is whatever its RUNGS
    // cite, so they are merged rather than a grounding being invented for it. An
    // empty result is the honest one for a program whose rungs cite nothing.
    grounding: groundingOfAll(<String?>[
      program.why,
      for (final rung in program.rungs) rung.why,
    ]),
    rationale: program.why,
    grade: null,
    adopt: () async {
      await repository.programAction(program.id, 'adopt');
      ref.invalidate(commitmentRepositoryProvider);
    },
  );

  /// `Today`, `7-day` — the horizon this asks for.
  final String horizon;

  /// The family the card wears.
  final Tone tone;

  /// Its glyph.
  final IconData icon;

  /// The commitment, as the server wrote it. Markers included.
  final String title;

  /// What it is expected to do. Null draws nothing.
  final String? body;

  /// What raised it, or what it commits you to.
  final String? raisedBy;

  /// Everything backing it.
  final Grounding grounding;

  /// The longer reasoning, behind the evidence sheet.
  final String? rationale;

  /// The evidence grade, when the payload named one.
  final String? grade;

  /// Says yes. Null when the item carries no id to act on.
  final Future<void> Function()? adopt;

  /// The tiny-caps line under the title — the mockup's `CIRCADIAN · 10 MIN`.
  ///
  /// **Category only, never a duration.** The reference design pairs the
  /// category with a time cost, and no recommendation on this wire carries one.
  /// Inventing "10 min" would be a claim about the owner's day made by the
  /// layout.
  final String? meta;

  /// Whether the owner has already said yes to this.
  final bool adopted;

  /// The server's own steps, when it wrote any. Null draws no list.
  final String? howTo;

  /// What sticking to it is expected to buy — the reference design's `PAYOFF`.
  ///
  /// **On the wire as `expected_outcome` since the endpoint existed, rendered
  /// nowhere.** The same shape as `fitness_plan` and `zone_minutes`: the server
  /// writes it, the client drops it.
  final String? payoff;

  /// `STANDARD` — the server's own word for how hard this is.
  final String? difficulty;

  /// `≥ 380 min sleep · daily`, for the monospace strip.
  final String? targetLine;

  /// `7-day` — how long the commitment runs.
  final String? window;

  /// The title with its citation markers taken out, for a sheet heading.
  ///
  /// The raw field carries `[note_id]` markers; a heading is not prose and does
  /// not run through `GroundedProse`, so it is stripped here rather than shown
  /// with the markers in it.
  String get plainTitle => parseGrounded(title).prose;
}

