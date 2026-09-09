/// What the coach says before it is asked — its own line, not a headline.
///
/// ## Why this exists
///
/// The screen opened with `.coach-intro`: a symbol, "Let's make sense of your
/// day." and a paragraph explaining the product to someone already inside it. It
/// took about a third of the phone and said nothing, so it was removed — which
/// left an input floating at the top of an empty screen, which was worse.
///
/// The legacy coach (`healthee-legacy/design_reference/project/screens/v2-coach.png`)
/// opens with the coach's actual observation — *"Morning, Maya. You recovered
/// well — readiness is 84, your best in two weeks."* — and that, not the styling,
/// is what makes it feel like something is there.
///
/// ## It costs nothing, and that is the whole point
///
/// This is [TodaySnapshot.action]: the daily coaching line the **nightly chain
/// already generated**, grounded and citation-validated at generation time, cached
/// in `kv` and served on `/api/today` since before this widget existed. The app has
/// been parsing it into `TodaySnapshot.action` and rendering it on Actions, while
/// the coach screen — the one place it is literally the coach speaking — showed a
/// marketing headline instead.
///
/// So no question is spent to show it, no model call is made, and nothing new is
/// authored. `api/routers/today.py` never generates on the read path
/// (`coaching.cached_line`); it replays a record or returns null.
///
/// ## What it must not become
///
/// **It is not an answer to anything the owner asked**, and it must never read as
/// one. It is dated, labelled as today's line, and drawn in the coach's own voice
/// on a recessed ground rather than in the answer style `CoachEntryView` uses for
/// a reply that cost a question. A reader must be able to tell "the coach said
/// this to everyone this morning" from "the coach said this to me because I
/// asked", because only the second one was paid for.
///
/// **Null is silence, never a placeholder.** It is null on a free account (the AI
/// gate strips it), on any day but today (the cache is keyed to the owner's
/// current day), and before the nightly chain has run. In each case this draws
/// nothing at all — a line invented to fill the space would be the exact failure
/// the block it replaced was guilty of.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/labels.dart';

/// The caption above it.
const String kCoachOpeningLabel = 'YOUR COACH, THIS MORNING';

/// Today's coaching line, in the coach's voice. Null draws nothing.
class CoachOpening extends StatelessWidget {
  /// [line] is `TodaySnapshot.action` — already generated, already validated.
  const CoachOpening({required this.line, super.key});

  /// `.card { border-radius: 22px; padding: 20px }`.
  static const double radius = 22;

  /// The same.
  static const double padding = 20;

  /// Today's line, or null when there is none to show.
  final String? line;

  @override
  Widget build(BuildContext context) {
    final said = line?.trim();
    if (said == null || said.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const TinyLabel(kCoachOpeningLabel),
        const SizedBox(height: Insets.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            // `--surface-soft`, not the accent ground an ANSWER uses. This line
            // was not asked for and did not cost a question; it must not wear the
            // styling of one that did.
            color: colors.surface2,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Text(
            said,
            style: TypeScale.coachBody.copyWith(color: colors.ink),
          ),
        ),
      ],
    );
  }
}
