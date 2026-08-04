/// How a refusal looks. The product's most careful moment gets its own widget.
///
/// `docs/APP_DESIGN_BRIEF.md` §1: *"When the data is not there, the API returns a
/// **withheld** block explaining what is missing and what would restore it, and
/// the app must render that as a **confident, designed state** — not an error,
/// not a spinner, not a greyed-out card that looks broken."*
///
/// Three things this widget will not do, all structural rather than conventional:
///
///   * **It never offers a retry.** A withhold is an answer, and the remedy is
///     the owner's ("log a weight", "wear the strap overnight"), not a button
///     that re-asks the same question. Retry belongs to `ErrorState`.
///   * **It never shows the reason id alone.** [Disclosure.message] is the point
///     of the block — the server writes it in the second person precisely so the
///     owner learns what would bring the number back. Rendering
///     `logged_weight_stale` at a person is telling them they are stuck.
///   * **It is not tinted.** Brief §2 rations colour to judgement, so a refusal
///     spends none: a [ValueHole] where the number would be, the reason in ink,
///     and the card frame unchanged from every other card. It reads as careful
///     because it kept the number's footprint, not because it is coloured.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// "We won't guess" — a value withheld, with the action that restores it.
///
/// The anatomy is the approved design's, in order: the metric's own title, a
/// [ValueHole] where the number would have been, a hairline rule, the word
/// **Withheld**, the remedy sentence, and — when the caller can open one — a
/// "What would restore it" pill. That pill is an *explainer*, not a retry: it
/// opens the reasoning, it does not re-ask the question.
class WithheldCard extends StatelessWidget {
  /// Renders one refusal.
  const WithheldCard({
    required this.disclosure,
    this.label,
    this.onExplain,
    super.key,
  });

  /// Why there is no value, and what would bring one back.
  final Disclosure disclosure;

  /// The metric's name, e.g. "VO₂max". Kept in the same position and style a
  /// reported card would use it, so the card has the same footprint and title as
  /// its happy-path sibling (brief §3).
  final String? label;

  /// Opens the longer "what would restore this" explanation, when one exists.
  ///
  /// Optional because a card with nothing to open must not render a dead pill —
  /// and because the explainer sheet is a screen-level concern that lands with
  /// the first screen to have one.
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label case final String name) ...[
            Text(name, style: text.labelSmall),
            const SizedBox(height: Insets.sm),
          ],
          // The number-shaped hole, exactly where the number would have been.
          const ValueHole.hero(),
          const SizedBox(height: Insets.lg),
          Divider(color: colors.line, height: hairline, thickness: hairline),
          const SizedBox(height: Insets.md),
          // Names the state plainly. Not an apology, not an error heading.
          Text('WITHHELD', style: text.labelSmall?.copyWith(letterSpacing: 0.9)),
          const SizedBox(height: Insets.sm),
          // The remedy. The load-bearing line of the whole card, in primary ink
          // because it is the answer — not a footnote to a missing number.
          Text(disclosure.message, style: text.bodyLarge),
          if (_lastSeen(disclosure) case final String seen) ...[
            const SizedBox(height: Insets.sm),
            Text(seen, style: text.labelSmall?.copyWith(color: colors.ink3)),
          ],
          if (onExplain case final VoidCallback explain) ...[
            const SizedBox(height: Insets.md),
            Align(
              alignment: Alignment.centerLeft,
              child: _ExplainPill(onTap: explain),
            ),
          ],
        ],
      ),
    );
  }

  /// Dates the last value we DID have, when the block carries one.
  ///
  /// Shown as history and never as a number: small, faint, below the explanation
  /// — not where a current reading would be. The server puts the stale value
  /// inside the withheld block for exactly this reason, "where nothing can
  /// mistake it for today's".
  static String? _lastSeen(Disclosure disclosure) {
    final date = disclosure.asOfDate;
    if (date == null) {
      return null;
    }
    final age = disclosure.ageDays;
    return age == null
        ? 'Last reading $date'
        : 'Last reading $date — $age ${age == 1 ? 'day' : 'days'} ago';
  }
}

/// The accent-outlined pill the design uses to open a withheld explanation.
class _ExplainPill extends StatelessWidget {
  const _ExplainPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: colors.accent, width: hairline),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          'What would restore it',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colors.accent),
        ),
      ),
    );
  }
}

/// "Nobody can price this" — a lever permanently left out, with the reasoning.
///
/// Separate from [WithheldCard] because the owner can do nothing about it. The
/// copy says so: no action, no "yet". Offering either would be a claim about what
/// we could do with more data, and the exclusion exists because we cannot.
///
/// The design draws an excluded term in the biological-age waterfall as the same
/// dashed hole — an explicit gap in the bar run rather than a silently missing
/// bar (brief §5.7) — so the two states share a visual language on purpose.
class ExcludedNote extends StatelessWidget {
  /// Renders the exclusions attached to a value.
  const ExcludedNote({required this.exclusions, super.key});

  /// What was left out, and why.
  final List<Disclosure> exclusions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exclusion in exclusions)
          Padding(
            padding: const EdgeInsets.only(top: Insets.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: ValueHole.inline(),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exclusion.term == null
                            ? 'Left out of this number'
                            : 'Left out: ${exclusion.term}',
                        style: text.labelSmall,
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        exclusion.message,
                        style: text.bodySmall?.copyWith(color: colors.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The tilts attached to a value that IS reported.
///
/// `caveat_block`'s docstring: "this block must reach every surface that renders
/// it. A caveat only the database can see is the same silence somewhere new."
/// `ReadingView` renders this automatically for a `Caveated`, so that silence
/// takes a deliberate act rather than an oversight.
///
/// Brief §3 calls the caveats "the most interesting one" and asks for "an
/// unobtrusive marker on the number that expands — never a modal, never a badge
/// that demands attention". The accent dot below is that marker; the expansion
/// lands with the first screen that needs it.
class CaveatNote extends StatelessWidget {
  /// Renders the caveats attached to a value.
  const CaveatNote({required this.caveats, super.key});

  /// What tilts the number, and which way.
  final List<Disclosure> caveats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final caveat in caveats)
          Padding(
            padding: const EdgeInsets.only(top: Insets.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 6, right: Insets.sm),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                Expanded(
                  child: Text(
                    caveat.message,
                    style: text.bodySmall?.copyWith(color: colors.ink2),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
