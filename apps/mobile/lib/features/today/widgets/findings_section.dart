/// Personal findings — the app's most personal claim, and its narrowest.
///
/// These are correlations discovered in **this one owner's** data. Brief §5.9
/// requires the label to say so, and it is not a disclaimer bolted on: the
/// finding was found by searching many metric pairs across one person's history,
/// so the sample size and the multiple-comparison correction are part of the
/// claim rather than footnotes to it.
///
/// So every row states `n` days and the corrected q-value, and the wording is
/// **"moved together"**, never "helps" or "improves". Those are causal verbs and
/// this is an observational n-of-1 — the exact over-reach the whole evidence
/// apparatus exists to prevent.
///
/// Renders nothing when there are no findings. An empty "Insights" heading over
/// a blank card reads as breakage; the honest state is silence.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// What the analytics layer found in the owner's own history.
class FindingsSection extends StatelessWidget {
  /// [findings] may be empty, in which case nothing renders.
  const FindingsSection({required this.findings, super.key});

  /// The findings, strongest first.
  final List<Finding> findings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (findings.isEmpty) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('In your own data', style: text.labelSmall),
          const SizedBox(height: Insets.xs),
          Text(
            'Single-subject and observational: these are patterns found in your '
            'history, not effects shown in a trial. They say what moved '
            'together, never what caused what.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          for (final finding in findings) ...[
            Divider(color: colors.line2, height: Insets.xl, thickness: hairline),
            _FindingRow(finding: finding),
          ],
        ],
      ),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_headline(finding), style: text.titleSmall),
        const SizedBox(height: Insets.xs),
        Text(
          _statistics(finding),
          style: text.labelSmall?.copyWith(color: colors.ink3),
        ),
        const SizedBox(height: Insets.sm),
        CitationRow(noteIds: finding.researchNoteIds),
      ],
    );
  }

  /// Deliberately non-causal wording. See the library docstring.
  static String _headline(Finding finding) {
    final description = finding.description;
    final direction = finding.directionLabel;
    if (description == null) {
      return 'A pattern between ${finding.metricA} and ${finding.metricB}';
    }
    return direction == null ? description : '$description — they $direction';
  }

  static String _statistics(Finding finding) {
    final parts = <String>[
      if (finding.effectSize case final double size)
        '${finding.effectMetric ?? 'effect'} ${size.toStringAsFixed(2)}',
      if (finding.nSamples case final int n) 'over $n days',
      if (finding.lagDays case final int lag)
        lag == 0 ? 'same day' : '$lag-day lag',
      if (finding.qValue case final double q)
        'q = ${q.toStringAsFixed(3)} after correcting for the search',
    ];
    return parts.join(' · ');
  }
}
