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
///
/// ## Every string on this card is model prose, and none of it is printed raw
///
/// This card is where the `[note_id]` leak was seen: the action arrived from the
/// nightly job carrying its citation markers and the card rendered the string.
/// The markers are correct — `insights/morning.py`'s prompt says *"Cite
/// [note_id] for any health claim"* and the blocking validator reads them — and
/// the last hop was not.
///
/// All four fields the model writes ([TodaySnapshot.action] and each rec's
/// `action`, `expected_effect` and `rationale`) go through [GroundedProse], which
/// is the only thing in the app that knows what a bracket means and cannot render
/// a stripped sentence without its sources. The row itself lives in
/// `shared/recommendation_entry.dart` because the Actions tab draws the same one.
///
/// ## ONE recommendation here, and the rest behind `See all`
///
/// The heading over this card says *"One action, and the reading behind it"*, and
/// until Actions had a screen this card drew every rec the payload carried —
/// so the subtitle was describing a shape the card was not keeping. Today is an
/// index (`today_sections.dart`), the server sends its recs highest-rank first,
/// and the whole set is now one tap away on a tab that exists. A screen that
/// showed all of them and a tab that showed all of them would be one destination
/// twice.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/shared/recommendation_entry.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The day's action and the highest-ranked recommendation behind it.
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

  /// The cited actions, highest rank first. Only the first is drawn here.
  final List<Recommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (action == null && recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    final rest = recommendations.length - 1;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today', style: text.labelSmall),
          if (action case final String sentence) ...[
            const SizedBox(height: Insets.sm),
            GroundedProse(text: sentence, style: text.headlineSmall),
          ],
          if (recommendations.isNotEmpty) ...[
            Divider(color: colors.line2, height: Insets.xl, thickness: hairline),
            RecommendationEntry(recommendation: recommendations.first),
          ],
          // Says the number rather than "more": a count is checkable against the
          // tab it points at, and "more" is a promise with no size.
          if (rest > 0) ...[
            const SizedBox(height: Insets.sm),
            Text(
              '$rest more on Actions',
              style: text.labelSmall?.copyWith(color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}
