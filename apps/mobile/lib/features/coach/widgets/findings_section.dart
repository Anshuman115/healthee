/// Personal findings — the app's most personal claim, and its narrowest.
///
/// These are correlations discovered in **this one owner's** data. Brief §5.9
/// requires the label to say so, and it is not a disclaimer bolted on: the
/// finding was found by searching many metric pairs across one person's history,
/// so the sample size and the multiple-comparison correction are part of the
/// claim rather than footnotes to it.
///
/// So the wording is **"moved with"**, never "helps" or "improves". Those are
/// causal verbs and this is an observational n-of-1 — the exact over-reach the
/// whole evidence apparatus exists to prevent.
///
/// ## What this file used to render, and why it was wrong
///
/// It printed `Finding.description` as the headline. That field is the server's
/// `description_raw`, and `analytics/correlations.py::_pairwise_finding` builds it
/// like this:
///
/// ```python
/// desc = f"Spearman({a}, {b}) = {rho:+.2f} over {n} days (p={p:.3f})"
/// ```
///
/// which reached the owner's home screen verbatim as
///
/// > Spearman(hrv_sleep_avg, recovery_score) = +0.72 over 105 days (p=0.000)
/// > — they moved together
///
/// with a second line of `spearman_r 0.72 · over 105 days · same day · q = 0.000
/// after correcting for the search` under it. Two renderings of the same numbers,
/// neither of them a sentence.
///
/// The server's own read layer calls the shape it sends *"structured fields for a
/// plain-English card"* (`read/findings.py::_shape`) and names that string `_raw`.
/// The plain-English card is this file's job and it was not doing it.
///
/// ## What it renders now, and what did NOT change
///
/// The headline is the finding in the owner's language — which two metrics, which
/// direction — with one line of context under it for the window and the lag. The
/// coefficient, the correction, the lag in full and the raw server string are all
/// still here, one tap away behind [ReasoningNote], in the same spirit as the
/// VO₂max card's "Why this instrument, and not another".
///
/// **The honesty did not move.** The single-subject/observational framing is still
/// on the surface, above the findings, where it cannot be collapsed. No verb in
/// the rewrite is causal — the metrics are joined by "moved with" and "moved
/// opposite to" — and the disclosure repeats the point in its last paragraph so a
/// reader who opens it for the arithmetic gets the caveat with it. Trading the
/// caveat for readability is the one way this change could have made things worse.
///
/// Renders nothing when there are no findings. An empty heading over a blank card
/// reads as breakage; the honest state is silence.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/reasoning_note.dart';
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
          // The one wording, shared with every `[personal_finding:…]` chip a
          // cited answer draws (`citation_row.dart`). Two copies of a caveat is
          // one copy that can be softened without the other moving.
          Text(
            kSingleSubjectFraming,
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
        Text(findingHeadline(finding), style: text.titleSmall),
        const SizedBox(height: Insets.xs),
        Text(
          findingWindow(finding),
          style: text.bodySmall?.copyWith(color: colors.ink2),
        ),
        ReasoningNote(
          question: 'The statistic behind this',
          answer: findingStatistics(finding),
        ),
        CitationRow(noteIds: finding.researchNoteIds),
      ],
    );
  }
}

/// The finding as a sentence: which two things, and which way they moved.
///
/// Deliberately non-causal. See the library docstring. Public because the tests
/// assert on the wording directly — the wording IS the honesty contract here, and
/// pumping a widget to read it back would test the layout instead.
String findingHeadline(Finding finding) {
  final a = finding.metricA;
  final b = finding.metricB;
  if (a == null) {
    return 'A pattern in your own data';
  }
  // An event finding carries one metric and an event kind, not a pair.
  if (b == null) {
    final event = finding.eventKind;
    return event == null
        ? 'Your ${metricName(a)}, on the days it was recorded'
        : 'Your ${metricName(a)} on $event days, against your other days';
  }
  final joiner = switch (finding.effectSize) {
    final double size when size < 0 => 'moved opposite to',
    _ => 'moved with',
  };
  return 'Your ${metricName(a)} $joiner your ${metricName(b)}';
}

/// The one line of context under the headline: how strong, over how much, at
/// what lag.
///
/// The strength is a word rather than a coefficient — the number belongs behind
/// the disclosure with the rest of the arithmetic, and "closely" is what 0.72
/// means to somebody who is not going to look it up. The bands are the
/// conventional ones for a rank correlation and nothing about this owner.
String findingWindow(Finding finding) {
  final parts = <String>[
    if (_strength(finding.effectSize) case final String word) word,
    if (finding.nSamples case final int n) 'across $n days of your own history',
    if (finding.lagDays case final int lag when lag != 0)
      'strongest $lag day${lag == 1 ? '' : 's'} apart',
  ];
  if (parts.isEmpty) {
    return 'Found in your own history.';
  }
  final first = parts.first;
  final rest = parts.skip(1);
  return '${first[0].toUpperCase()}${first.substring(1)}'
      '${rest.isEmpty ? '' : ', ${rest.join(', ')}'}.';
}

/// Everything a reader who wants the arithmetic would ask for — and, last, the
/// caveat again, so opening the numbers never means leaving the framing behind.
String findingStatistics(Finding finding) {
  final lines = <String>[
    if (finding.effectSize case final double size)
      '${finding.effectMetric ?? 'Effect'} = ${size.toStringAsFixed(2)}, on a '
          'scale from −1 to +1.',
    if (finding.nSamples case final int n)
      'Computed over $n days on which both were recorded.',
    if (finding.lagDays case final int lag)
      lag == 0
          ? 'Same day: both values come from the same calendar day.'
          : 'Lagged $lag day${lag == 1 ? '' : 's'}: the second value is taken '
                '$lag day${lag == 1 ? '' : 's'} after the first.',
    if (finding.qValue case final double q)
      'q = ${q.toStringAsFixed(3)} after correcting for the size of the search. '
          'Many pairs of metrics were tested, so an uncorrected p-value would '
          'find "significant" patterns in noise. This is the corrected one.',
    'One person, one stretch of time, nothing controlled. It says the two moved '
        'together — not that either one caused the other.',
  ];
  return lines.join('\n\n');
}

/// The conventional band for a rank correlation, as a word.
String? _strength(double? effect) {
  if (effect == null) {
    return null;
  }
  final size = effect.abs();
  if (size >= 0.6) {
    return 'closely';
  }
  if (size >= 0.4) {
    return 'moderately';
  }
  return 'weakly';
}
