/// `.focus-card` carrying one cited recommendation — the prototype's
/// **Today's suggestion**.
///
/// ```js
/// // screens-actions.js
/// <div class="focus-card" data-tone="sleep">
///   <span class="focus-title">Today’s suggestion</span> ⌄icon
///   <h3>Sleep earlier tonight.</h3>
///   <p>Your sample history has 2 hours of modelled sleep debt…</p>
///   <button class="check-action" aria-pressed="…">
///     <strong>I’ll try this tonight</strong>
///     <small>One manageable change to start with.</small>
///   </button>
///   H.evidence('sleep_need_debt', 'Why this suggestion')
/// </div>
/// ```
///
/// ## Three things this card will not do
///
/// **The tone is the rec's own category, never a colour a call site picked.** The
/// prototype hard-codes `data-tone="sleep"` because its fixture is a sleep
/// suggestion; ours reads `category` off the wire. That is data choosing the
/// family, which is the whole point of the cascade.
///
/// **Adopting says intent and nothing more.** The `small` under the checkbox is
/// the prototype's own sentence and it is the honest one — the server records an
/// intention, not a completed action, and `recommendation_history.dart` says so
/// too. A tick that read "done" would be this app inventing an observation.
///
/// **A rec with no server id gets no checkbox.** There is nowhere to write the
/// adoption to, and a control that silently does nothing is worse than none.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/data/recommendations/recommendation_history.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/actions/v02/evidence_sheet.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/v02/choices.dart';
import 'package:healthee/shared/v02/controls.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// What the checkbox says before and after it is ticked. The prototype's own.
const String kAdoptLabel = 'I’ll try this';

/// The same, once the intention is recorded.
const String kAdoptedLabel = 'Added to your intentions';

/// The line under the box, unticked.
const String kAdoptNote = 'One manageable change to start with.';

/// The line under the box, ticked. **Not** "completed".
const String kAdoptedNote = 'An intention, not a completed action.';

/// `Raised by your sleep debt` — the reading behind a suggestion, in words.
///
/// **Never the raw id.** `metric_names.dart` argues that an unknown id should
/// keep its id, and that is right where the id is the SUBJECT of a statistic a
/// reader may want to look up. It is wrong here: this is a provenance line on a
/// card, where `sleep_debt` is a log line and nothing else. `signal_source` is
/// also not always a metric id, so an id this build cannot name is reported as
/// exactly that rather than printed or prettified into a phrase nobody chose.
String? signalLabel(String? signal) {
  if (signal == null) {
    return null;
  }
  return hasMetricName(signal)
      ? 'Raised by your ${metricName(signal)}'
      : 'Raised by a reading this build cannot name yet';
}

/// The eyebrow over the first suggestion of the day.
const String kFirstEyebrow = 'Today’s suggestion';

/// The eyebrow over every suggestion after it.
///
/// The prototype's fixture carries ONE recommendation and `/api/today` carries a
/// ranked set. The element is repeated rather than a new one invented; only the
/// eyebrow can say which of the two it is, so only the eyebrow changes.
const String kAlsoEyebrow = 'Also suggested today';

/// The family a category names.
Tone toneForCategory(String? category) => switch (category) {
  'sleep' => Tone.sleep,
  'activity' || 'movement' || 'steps' => Tone.movement,
  'heart' => Tone.heart,
  'breathing' || 'oxygen' => Tone.oxygen,
  'stress' => Tone.stress,
  _ => Tone.fitness,
};

/// The glyph a category wears on the eyebrow row.
IconData iconForCategory(String? category) => switch (category) {
  'sleep' => Icons.bedtime_outlined,
  'activity' || 'movement' || 'steps' => Icons.directions_walk,
  'heart' => Icons.favorite_outline,
  'breathing' || 'oxygen' => Icons.air,
  'stress' => Icons.wb_sunny_outlined,
  _ => Icons.eco_outlined,
};

/// One recommendation, in the prototype's focus card.
class SuggestionCard extends ConsumerStatefulWidget {
  /// [first] picks the eyebrow; see [kAlsoEyebrow].
  const SuggestionCard({
    required this.recommendation,
    this.first = true,
    super.key,
  });

  /// The rec being drawn.
  final Recommendation recommendation;

  /// Whether this is the top of the ranked set.
  final bool first;

  @override
  ConsumerState<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<SuggestionCard> {
  bool _busy = false;
  String? _trouble;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rec = widget.recommendation;
    final adopted = rec.adopted ?? false;
    return FocusCard(
      tone: toneForCategory(rec.category),
      icon: iconForCategory(rec.category),
      eyebrow: widget.first ? kFirstEyebrow : kAlsoEyebrow,
      title: GroundedProse(
        text: rec.action,
        style: TypeScale.focusTitle.copyWith(color: colors.ink),
        // The structured ids belong to the whole rec and ride its headline, so
        // one recommendation shows one set of sources.
        alsoCites: rec.researchNoteIds,
        grade: rec.gradeLabel,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (rec.expectedEffect case final String effect) Text(effect),
          // The part that does not fit on Today's index: which reading raised
          // this one.
          if (signalLabel(rec.signalSource) case final String raised)
            Text(
              raised,
              style: TypeScale.tinyLabel.copyWith(color: colors.ink3),
            ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (rec.id case final int id)
            CheckAction(
              pressed: adopted,
              title: adopted ? kAdoptedLabel : kAdoptLabel,
              note: adopted ? kAdoptedNote : kAdoptNote,
              onPressed: _busy ? null : () => unawaited(_toggle(id, adopted)),
            ),
          if (_trouble case final String message)
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TypeScale.tinyLabel.copyWith(color: colors.ink2),
              ),
            ),
          if (rec.rationale case final String why)
            TextLink(
              label: 'Why this suggestion',
              icon: Icons.info_outline,
              onPressed: () => showEvidenceSheet(
                context,
                title: 'Behind this suggestion',
                prose: why,
                alsoCites: rec.researchNoteIds,
                grade: rec.gradeLabel,
              ),
            ),
        ],
      ),
    );
  }

  /// Writes the adoption, then re-reads. Never flips the box on its own: the
  /// tick has to mean "the server has this", not "the tap happened".
  Future<void> _toggle(int id, bool adopted) async {
    setState(() {
      _busy = true;
      _trouble = null;
    });
    try {
      final api = await ref.read(accountApiProvider.future);
      await setRecommendationAdoption(api, id, adopted ? 'dismiss' : 'adopt');
      if (!mounted) {
        return;
      }
      ref.invalidate(todaySnapshotProvider);
      ref.invalidate(recommendationHistoryProvider);
    } on Exception catch (error, stack) {
      AppLog.failure('actions', 'recording an intention', error, stack);
      if (mounted) {
        setState(() => _trouble = apiProblem(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
