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
/// **Null is never filled with an invented line.** It is null on a free account
/// (the AI gate strips it), on any day but today (the cache is keyed to the
/// owner's current day), and before the nightly chain has run.
///
/// The last of those is ordinary rather than exceptional and deserves saying so.
/// Observed on the owner's own device at 08:20: the night had arrived, the chain
/// fires at 10:30 local, and `kv` held a line dated YESTERDAY — so `get_cached`
/// correctly served null and the screen showed a blank band. Nothing was broken;
/// the screen simply refused to explain itself.
///
/// So a premium owner with no line yet is told that one is written each morning
/// and today's is not written yet. That is a statement about the schedule, not
/// about their health, and it invents nothing. A non-premium owner is told
/// nothing at all, because for them a line is not pending — it is not coming, and
/// "not written yet" would be a promise this app does not keep.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/v02/labels.dart';

/// The caption above it.
const String kCoachOpeningLabel = 'YOUR COACH, THIS MORNING';

/// Shown to an entitled owner whose line for today has not been written yet.
///
/// It says WHEN rather than apologising, and it names the two conditions that
/// actually govern it — your night having synced, and the morning run — because
/// those are the two things the owner can recognise in their own day.
const String kCoachOpeningPending =
    'Today’s line isn’t written yet. Your coach writes one each morning, once '
    'your night has synced.';

/// What this line cites, read out of the line itself.
///
/// `TodaySnapshot.action` is a bare string — the payload carries no citation
/// list beside it, unlike a coach reply — so the notes come from the inline
/// markers the server wrote into the sentence. `groundingOf` is the one parser
/// for those, shared with every other grounded surface.
MetricDetail _sources(String line) =>
    MetricDetail.grounded(groundingOf(line), title: kCoachOpeningSources);

/// The sheet's heading.
const String kCoachOpeningSources = 'Behind this line';

/// Today's coaching line, in the coach's voice. Null draws nothing.
class CoachOpening extends StatelessWidget {
  /// [line] is `TodaySnapshot.action` — already generated, already validated.
  /// [pending] says a line is COMING when there is none: true only for an owner
  /// entitled to one, so the waiting sentence is never shown to somebody who will
  /// never receive it.
  const CoachOpening({required this.line, required this.pending, super.key});

  /// `.card { border-radius: 22px; padding: 20px }`.
  static const double radius = 22;

  /// The same.
  static const double padding = 20;

  /// Today's line, or null when there is none to show.
  final String? line;

  /// Whether this owner is entitled to a line at all.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final said = line?.trim();
    final bool hasLine = said != null && said.isNotEmpty;
    if (!hasLine && !pending) {
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
          decoration: ShapeDecoration(
            // `--surface-soft`, not the accent ground an ANSWER uses. This line
            // was not asked for and did not cost a question; it must not wear the
            // styling of one that did.
            color: colors.surface2,
            shape: hSquircle(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // `GroundedProse`, not `Text`. The line arrives with the server's
              // inline citation markers in it — the first build printed
              // "[resting_heart_rate, recovery_readiness]" as literal brackets
              // in the middle of a sentence, which is the raw wire format
              // leaking onto the screen. Every other surface in this app renders
              // these through the same widget, and so does the coach's own
              // replies four lines away in `coach_thread.dart`.
              if (hasLine)
                GroundedProse(
                  text: said,
                  style: TypeScale.coachBody.copyWith(color: colors.ink),
                )
              else
                Text(
                  kCoachOpeningPending,
                  style: TypeScale.coachBody.copyWith(color: colors.ink2),
                ),
              // And the sources behind it, one tap away — the same ⓘ a reply
              // carries. A line that cites nothing draws no dot: an ⓘ opening an
              // empty sheet is worse than none.
              if (hasLine && _sources(said).isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: MetricInfoDot(null, detail: _sources(said)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
