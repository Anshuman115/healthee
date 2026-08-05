/// Biological age as a **waterfall**, not a score.
///
/// Brief §5.7: start at chronological age, one bar per contributing term with
/// its `delta_years`, land on biological age. The waterfall is what makes the
/// number arguable — it shows which lever moved it and by how much, so "31.8"
/// stops being an oracle and becomes a sum somebody can check.
///
/// **Excluded terms are drawn as an explicit gap, not omitted.** The payload's
/// `excluded` list says sleep regularity is not one of the levers behind this
/// number, and silently leaving it out would let the owner assume it was
/// counted. The `ExcludedNote` beneath renders the server's reasoning — the SRI
/// hazard "belongs to the software, not to the index" — and offers no retry,
/// because there is nothing to restore.
///
/// [BiologicalAge.disclaimer] is rendered **verbatim**: "Motivational estimate
/// from population data — not a clinical or diagnostic age." It is a safety
/// statement, and re-wording a safety statement in the UI layer is how it gets
/// softened.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/features/activity/widgets/vo2max_card.dart';
import 'package:healthee/shared/measured_card.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The estimate, its levers, and the disclaimer that travels with it.
class BiologicalAgeCard extends StatelessWidget {
  /// Renders [age].
  const BiologicalAgeCard({required this.age, super.key});

  /// The biological-age payload.
  final BiologicalAge age;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biological age', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              HeroValue(value: age.biologicalAge.toStringAsFixed(1), unit: 'years'),
              const Spacer(),
              if (age.chronologicalAge case final double actual)
                Text(
                  'against ${actual.toStringAsFixed(0)}',
                  style: text.labelMedium?.copyWith(color: colors.ink2),
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Text('What moves it', style: text.labelSmall),
          for (final term in age.contributions) ...[
            const SizedBox(height: Insets.sm),
            _ContributionRow(term: term),
          ],
          if (age.disclaimer case final String disclaimer) ...[
            const SizedBox(height: Insets.lg),
            // Verbatim. See the library docstring.
            Text(disclaimer, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: Insets.md),
          CitationRow(noteIds: age.researchNotes),
        ],
      ),
    );
  }
}

/// One lever: its name, what it was measured as, and the years it moved.
class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.term});

  final AgeContribution term;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final delta = term.deltaYears;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name(term.term), style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              Text(
                _detail(term),
                style: text.labelSmall?.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        Text(
          delta == null
              ? '—'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} y',
          style: text.headlineSmall?.copyWith(
            // Colour IS judgement here: years off is favourable, years on is not.
            color: delta == null
                ? colors.ink3
                : (delta <= 0 ? colors.fav : colors.unf),
          ),
        ),
      ],
    );
  }

  static String _name(String term) => switch (term) {
    'fitness' => 'Fitness',
    'sleep' => 'Sleep duration',
    'regularity' => 'Sleep regularity',
    _ => term,
  };

  /// The owner's value against the reference, and — where there is one — the
  /// instrument behind it. A term measured by a questionnaire and one measured
  /// on a run are not the same evidence.
  static String _detail(AgeContribution term) {
    final parts = <String>[
      if (term.value case final double value)
        '${_number(value)}${term.unit == null ? '' : ' ${term.unit}'}',
      if (term.target case final double target) 'against ${_number(target)}',
      if (term.method case final String method)
        Vo2maxCard.instrumentLabel(method).toLowerCase(),
    ];
    return parts.isEmpty ? 'No value for this term' : parts.join(' · ');
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}
