/// How a refusal looks. The product's most careful moment gets its own widget.
///
/// `docs/APP_DESIGN.md` §0 rule 3: "Withheld states are first-class UI, not error
/// states. VO₂max with too few RHR days shows 'Insufficient data — need 3+
/// nights', not a fabricated estimate."
///
/// Two things this widget will not do, both structural rather than conventional:
///
///   * **It never offers a retry.** A withhold is an answer, and the remedy is
///     the owner's ("log a weight", "sync the strap"), not a button that re-asks
///     the same question. Retry belongs to [ErrorState] and stays there.
///   * **It never shows the reason id alone.** [Disclosure.message] is the whole
///     point of the block — the server writes it in the second person precisely
///     so the owner learns what would bring the number back. Rendering
///     `logged_weight_stale` at a person is telling them they are stuck.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// "We won't guess" — a value withheld, with the action that restores it.
class WithheldCard extends StatelessWidget {
  /// Renders one refusal.
  const WithheldCard({required this.disclosure, this.label, super.key});

  /// Why there is no value, and what would bring one back.
  final Disclosure disclosure;

  /// The metric's name, e.g. "VO₂max". Shown above the sentence so the card is
  /// self-describing when it appears in a scrolling list of other cards.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      // The honesty hue, never the error colour. A held breath, not an alarm.
      accent: colors.withheld,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label case final String name) ...[
            Text(name, style: text.labelSmall?.copyWith(color: colors.inkFaint)),
            const SizedBox(height: Insets.xs),
          ],
          Text('Not enough data', style: text.titleSmall?.copyWith(color: colors.withheld)),
          const SizedBox(height: Insets.sm),
          // The remedy. The load-bearing line of the whole card.
          Text(disclosure.message, style: text.bodyMedium),
          if (_lastSeen(disclosure) case final String seen) ...[
            const SizedBox(height: Insets.sm),
            Text(seen, style: text.labelSmall?.copyWith(color: colors.inkFaint)),
          ],
        ],
      ),
    );
  }

  /// Dates the last value we DID have, when the block carries one.
  ///
  /// Shown as history and never as a number: it sits in small faint type below
  /// the explanation, not where a current reading would be. The server puts the
  /// stale value inside the withheld block for exactly this reason — "where
  /// nothing can mistake it for today's".
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

/// "Nobody can price this" — a lever permanently left out, with the reasoning.
///
/// Separate from [WithheldCard] because the owner can do nothing about it. The
/// copy says so: no action, no "yet". Offering either would be a claim about what
/// we could do with more data, and the exclusion exists because we cannot.
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exclusion.term == null
                      ? 'Left out of this number'
                      : 'Left out: ${exclusion.term}',
                  style: text.labelSmall?.copyWith(color: colors.withheld),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  exclusion.message,
                  style: text.bodySmall?.copyWith(color: colors.inkSoft),
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
/// [ReadingView] renders this automatically for a `Caveated`, so that silence
/// takes a deliberate act rather than an oversight.
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
            child: Text(
              caveat.message,
              style: text.bodySmall?.copyWith(color: colors.inkSoft),
            ),
          ),
      ],
    );
  }
}
