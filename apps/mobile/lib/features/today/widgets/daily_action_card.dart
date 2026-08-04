/// Today's action — one sentence, always cited, and the only graded claim here.
///
/// Two payload fields, and they are not the same thing. `action` is the AI
/// one-liner the nightly job warms; `recommendations[]` are the cited, ranked
/// actions with a **proven** evidence grade on each (see `recommendation.dart`
/// for where that number comes from and why it is the only grade Today may
/// show).
///
/// A null `action` renders **nothing**, never a spinner and never a refusal
/// card. `docs/APP_DESIGN.md` §3.1 is explicit, and the reason is honest: an
/// un-warmed premium surface is not a withheld measurement, and dressing it in a
/// hole would tell the owner their data is missing when it is not.
///
/// Nothing here congratulates anyone. Brief §6: never congratulate, never scold,
/// never use urgency to drive engagement.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/reasoning_note.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The day's action and the cited recommendations behind it.
class DailyActionCard extends StatelessWidget {
  /// [action] may be null; [recommendations] may be empty. Both being so means
  /// this card does not render at all.
  const DailyActionCard({
    required this.action,
    required this.recommendations,
    super.key,
  });

  /// The AI one-liner, or null until the nightly job has warmed it.
  final String? action;

  /// The cited actions, highest rank first.
  final List<Recommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (action == null && recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today', style: text.labelSmall),
          if (action case final String sentence) ...[
            const SizedBox(height: Insets.sm),
            Text(sentence, style: text.headlineSmall),
          ],
          for (final rec in recommendations) ...[
            Divider(color: colors.line2, height: Insets.xl, thickness: hairline),
            _RecommendationRow(recommendation: rec),
          ],
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(recommendation.action, style: text.titleMedium),
        if (recommendation.expectedEffect case final String effect) ...[
          const SizedBox(height: Insets.xs),
          Text(effect, style: text.bodySmall?.copyWith(color: colors.ink2)),
        ],
        if (recommendation.rationale case final String why) ...[
          const SizedBox(height: Insets.sm),
          // Offered, not forced — an inline disclosure, never a modal (§3).
          ReasoningNote(question: 'Why this, today', answer: why),
        ],
        const SizedBox(height: Insets.sm),
        CitationRow(
          noteIds: recommendation.researchNoteIds,
          // The one grade on this screen that the server actually proved.
          grade: recommendation.gradeLabel,
        ),
      ],
    );
  }
}
