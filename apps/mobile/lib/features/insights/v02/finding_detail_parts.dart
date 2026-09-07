/// The finding-detail screen's blocks, and the wording that carries its claim.
///
/// Split from the screen for the reason `workout_detail_sections.dart` is split
/// from its screen: the screen is composition, and this is what it says. The
/// sentences are the whole point of this surface, so the tests assert on the
/// functions here directly rather than pumping a widget to read them back.
///
/// ## Why this screen exists at all
///
/// The prototype's `H.screens.insight` is reached from the Insights
/// relationship card. In the app that card was **inert** — the owner:
/// *"clicking on it nothing happens where as in our design demo on clicked it
/// shows data related."* The block already carried every number this screen
/// shows; there was nowhere for it to go.
///
/// ## The one thing that must not be softened
///
/// `.observation` is transcribed from `screens.css:73-75`, and its two-line
/// statement is the prototype's, verbatim, down to the line break:
///
/// > They moved together.
/// > That doesn't tell us why.
///
/// The first line varies with the sign of the coefficient, because the card
/// that led here says "moved with" or "moved opposite to"
/// (`shared/findings_section.dart`) and a detail screen that contradicts its own
/// entry point is worse than either wording alone. The second line never varies.
///
/// This is an n-of-1 observational correlation found by searching many metric
/// pairs across one person's history. No verb on this screen is causal.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/shared/charts/h_scatter.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/v02/stat_block.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// `.observation` — the statement and the caveat under it.
class ObservationBlock extends StatelessWidget {
  /// [headline] is two lines; [body] the paragraph beneath.
  const ObservationBlock({
    required this.headline,
    required this.body,
    super.key,
  });

  /// `.observation { padding-block: 20px }`.
  static const double padding = 20;

  /// `.observation h3 { margin-block: 10px 6px }`.
  static const double titleTop = 10;

  /// The same, below.
  static const double titleBottom = 6;

  /// The statement.
  final String headline;

  /// The caveat.
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.only(top: padding, bottom: padding),
      decoration: BoxDecoration(
        // `.observation { border-bottom: 1px solid var(--line) }`.
        border: Border(
          bottom: BorderSide(color: colors.line, width: hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: titleTop),
          Text(
            headline,
            style: TypeScale.observationTitle.copyWith(color: colors.ink),
          ),
          const SizedBox(height: titleBottom),
          Text(
            body,
            style: TypeScale.observationBody.copyWith(color: colors.ink2),
          ),
        ],
      ),
    );
  }
}

/// The arithmetic: two figures, a rule, and what the numbers do not contain.
class StatisticsCard extends StatelessWidget {
  /// Builds the card for [finding].
  const StatisticsCard({required this.finding, super.key});

  /// `.two { gap: var(--space-md) }`.
  static const double columnGap = 12;

  /// The finding whose numbers these are.
  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = TypeScale.small.copyWith(color: colors.ink2);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: StatBlock(
                  label: effectLabel(finding),
                  value: effectValue(finding),
                ),
              ),
              const SizedBox(width: columnGap),
              Expanded(
                child: StatBlock(
                  label: 'Paired observations',
                  value: finding.nSamples?.toString(),
                ),
              ),
            ],
          ),
          const CardDivider(),
          Text(correctionLine(finding), style: small),
          const SizedBox(height: Insets.lg),
          // The prototype's own sentence used to sit here, and it promised this
          // chart: "A scatter plot appears here when those values are
          // available." `read/findings.py` sent summary statistics only, so the
          // points never left the server. It sends them now, so the promise is
          // kept — and where it still cannot, the sentence says which of the two
          // reasons it is rather than the one that has stopped being true.
          if (finding.isPlottable) ...<Widget>[
            HScatter(
              finding.points,
              color: colors.accent,
              progress: 1,
              height: scatterHeight,
            ),
            const SizedBox(height: Insets.sm),
            Text(scatterCaption(finding), style: small),
          ] else
            Text(pairedValuesAbsent(finding), style: small),
        ],
      ),
    );
  }

  /// How tall the cloud is drawn. Enough for a shape, short enough that the
  /// sentence above it stays the thing the eye lands on first.
  static const double scatterHeight = 148;
}

/// Why there is no cloud, for a finding that cannot carry one.
///
/// Two different states and two different sentences, because they are not the
/// same fact about the owner's data. An event finding compares two GROUPS of
/// days and has no paired points at all — that is permanent and about the
/// method. Too few pairs is about this finding today.
String pairedValuesAbsent(Finding finding) {
  if (finding.metricB == null) {
    return 'This one compares two groups of days rather than pairing them up, '
        'so there are no paired values to plot.';
  }
  return 'Fewer than ${Finding.minPlottablePoints} paired days reached us for '
      'this one, which is too few to be a shape rather than a line.';
}

/// What the cloud is, and whether it is all of it.
///
/// The count is stated because it can differ from `Paired observations` above:
/// that figure is what the statistic was computed from, and the chart may hold
/// fewer. A reader comparing the two and finding no explanation would be right
/// to distrust both.
String scatterCaption(Finding finding) {
  final drawn = finding.points.length;
  final metrics =
      '${metricName(finding.metricA ?? '')} against '
      '${metricName(finding.metricB ?? '')}';
  if (!finding.pointsTruncated) {
    return 'Each dot is one day — $metrics. Nothing is fitted through them.';
  }
  return 'Each dot is one day — $metrics, the most recent $drawn of '
      '${finding.nSamples ?? drawn}. Nothing is fitted through them.';
}

/// The two-line statement. See the library docstring — line two never varies.
String observationHeadline(Finding finding) {
  final effect = finding.effectSize;
  final opposite = effect != null && effect < 0;
  return opposite
      ? 'They moved in opposite directions.\nThat doesn’t tell us why.'
      : 'They moved together.\nThat doesn’t tell us why.';
}

/// The caveat under the statement: what was associated with what, and what else
/// could be in the picture.
///
/// "Associated with" and nothing stronger. The trailing sentence is the
/// prototype's, generalised off its caffeine example — the confounders it names
/// are the ones that apply to any pair of daily measures.
String observationBody(Finding finding) {
  final a = finding.metricA;
  final b = finding.metricB;
  if (a == null || b == null) {
    return 'This pattern was found by searching your own history. '
        'Timing, stressful days and other habits could be part of the picture.';
  }
  final effect = finding.effectSize;
  final direction = effect != null && effect < 0 ? 'negatively' : 'positively';
  final name = metricName(a);
  return '${name[0].toUpperCase()}${name.substring(1)} was $direction '
      'associated with ${metricName(b)} in this analysis. '
      'Timing, stressful days and other habits could be part of the picture.';
}

/// The screen's name — the prototype's `Coffee & your sleep.`
///
/// A noun phrase with a full stop, like every other v02 detail title
/// (`Workout.`). Not the relationship card's `A ↔ B`: the card is a label in a
/// grid and this is a sentence at 27px.
String findingTitle(Finding finding) {
  final a = finding.metricA;
  final b = finding.metricB;
  if (a == null || b == null) {
    return 'A pattern in your own data.';
  }
  final name = metricName(a);
  return '${name[0].toUpperCase()}${name.substring(1)} & your ${metricName(b)}.';
}

/// `Observational · 24 samples` — the badge over everything else.
String observationalBadge(Finding finding) {
  final samples = finding.nSamples;
  return samples == null ? 'Observational' : 'Observational · $samples samples';
}

/// The label over the coefficient.
///
/// `spearman_r` is the only effect metric the server computes today
/// (`analytics/correlations.py`), and ρ is its symbol; anything else is named
/// rather than given a symbol it may not own.
String effectLabel(Finding finding) {
  final metric = finding.effectMetric;
  return metric == null || metric == 'spearman_r'
      ? 'Correlation · ρ'
      : 'Effect · $metric';
}

/// The coefficient, with a real minus sign rather than a hyphen.
String? effectValue(Finding finding) {
  final effect = finding.effectSize;
  if (effect == null) {
    return null;
  }
  final magnitude = effect.abs().toStringAsFixed(2);
  return effect < 0 ? '−$magnitude' : '+$magnitude';
}

/// `Adjusted q-value 0.03 · same-day association`.
///
/// **A very small q is written as an inequality, not rounded to zero.** The
/// owner's live payload carries `q = 3.15e-27`; `toStringAsFixed(3)` renders
/// that as `0.000`, which reads as an exact zero and is the one number on this
/// card that would be a lie.
String correctionLine(Finding finding) {
  final parts = <String>[
    if (qValueLabel(finding.qValue) case final String q) q,
    lagLabel(finding.lagDays),
  ];
  return parts.join(' · ');
}

/// `Adjusted q-value 0.03`, or `Adjusted q-value < 0.001` when it is smaller
/// than three decimals can show.
String? qValueLabel(double? q) {
  if (q == null) {
    return null;
  }
  return q < 0.001
      ? 'Adjusted q-value < 0.001'
      : 'Adjusted q-value ${q.toStringAsFixed(3)}';
}

/// `same-day association`, or the lag spelled out.
String lagLabel(int? lag) {
  if (lag == null || lag == 0) {
    return 'same-day association';
  }
  final days = lag.abs();
  return 'strongest $days day${days == 1 ? '' : 's'} apart';
}
