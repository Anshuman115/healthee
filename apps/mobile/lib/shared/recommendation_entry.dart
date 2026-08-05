/// One cited recommendation, rendered the same way wherever it appears.
///
/// Extracted from `features/today/widgets/daily_action_card.dart` on its second
/// use (Standards §1). Today shows the top one under "Suggested today"; the
/// Actions tab shows the whole set. Two copies of this row would be two chances
/// for one of them to drop a grade, an expected effect, or a citation — and the
/// one that dropped it would look completely normal.
///
/// Every string here is model prose and none of it is printed raw: the action,
/// the expected effect and the rationale all go through [GroundedProse], which is
/// the only thing in the app that knows what a `[note_id]` bracket means. The
/// rec's structured `research_note_ids` ride along on the action so one
/// recommendation shows one set of sources rather than two rows that can
/// disagree.
///
/// The grade is the one on this screen the server actually **proved** —
/// `jobs/recs.py::_provable_grade` replaces the model's declaration with the
/// weakest grade among the notes the rec cites. `data/models/recommendation.dart`
/// has the full argument for why nothing else in the app may show one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/reasoning_note.dart';

/// One recommendation: what to do, what it should change, and why.
class RecommendationEntry extends StatelessWidget {
  /// [showSignal] adds the line naming which reading raised this — worth the
  /// space on a screen that is only about actions, and noise on Today, where the
  /// reading itself is a card away.
  const RecommendationEntry({
    required this.recommendation,
    this.showSignal = false,
    super.key,
  });

  /// The rec being drawn.
  final Recommendation recommendation;

  /// Whether to name the metric that raised it.
  final bool showSignal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroundedProse(
          text: recommendation.action,
          style: text.titleMedium,
          // The structured ids belong to the whole rec, so they hang off its
          // headline rather than sitting in a second row underneath.
          alsoCites: recommendation.researchNoteIds,
          // The one grade in this app that the server actually proved.
          grade: recommendation.gradeLabel,
        ),
        if (recommendation.expectedEffect case final String effect) ...[
          const SizedBox(height: Insets.xs),
          GroundedProse(
            text: effect,
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
        ],
        if (showSignal)
          if (recommendation.signalSource case final String signal)
            Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                // The raw id, not a prettified phrase: `metric_names.dart`
                // argues that inventing an owner-facing name for something
                // nobody named hides the fact that the server grew a field this
                // app has never heard of. `signal_source` is not always a metric
                // id, so it is not run through that table at all.
                'Raised by $signal',
                style: text.labelSmall?.copyWith(color: colors.ink3),
              ),
            ),
        if (recommendation.rationale case final String why) ...[
          const SizedBox(height: Insets.sm),
          // Offered, not forced — an inline disclosure, never a modal (§3).
          // `jobs/recs.py` requires an inline `[note_id]` in here, so this is the
          // one disclosure whose body reliably carries citations.
          ReasoningNote(question: 'Why this, today', answer: why),
        ],
      ],
    );
  }
}
