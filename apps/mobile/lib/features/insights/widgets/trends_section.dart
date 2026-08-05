/// Where each tracked metric has been going — and the only place `fav`/`unf`
/// appear on this screen.
///
/// **Ported from** `~/projects/healthee-legacy/app/lib/ui/insights_screen.dart`'s
/// trend strip: one card per sparkline metric, the newest value, the sparkline,
/// and the change across the window with an arrow tinted by whether the change
/// was in the good direction.
///
/// ## Why a trend may be coloured when a finding may not
///
/// A trend is this owner's own series against its own past, and
/// `shared/format/metric_polarity.dart` holds the one table that says which way
/// each metric has to move for the owner to be better off. That is a claim the
/// product is willing to make — it is the same claim the recovery ladder makes,
/// and `apps/mobile/README.md` licenses `fav`/`unf` for exactly it: *better or
/// worse than the owner's own normal*.
///
/// A **finding** is a correlation, and the sign of a rank coefficient says
/// *moved together* or *moved opposite*. That is a direction, not a verdict, and
/// no amount of q-correction turns 105 days of one person's history into "this is
/// good for you". `findings_section.dart` therefore spends no judgement colour at
/// all, and `insights_screen.dart` states the split.
///
/// ## The colourless rows are the point of the coloured ones
///
/// Calories carry polarity `neutral` and render with **no** verdict colour, and a
/// metric the table has never heard of renders with none either. That is not the
/// leftover case: a screen that tinted everything would teach the owner that
/// colour here is decoration, and then the two rows where it is a claim would say
/// nothing. `metric_polarity.dart` argues it at length and
/// `test/features/insights_trends_test.dart` breaks it on purpose.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/h_spark.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/format/metric_polarity.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// One metric's window: where it is now, and which way it has been going.
///
/// A value type rather than four positional arguments, so the arithmetic can be
/// checked without a widget. [delta] is legacy's `vals.last - vals.first`.
@immutable
class MetricTrend {
  /// Builds a trend from an already-windowed series.
  const MetricTrend({
    required this.metric,
    required this.series,
    required this.latest,
    required this.delta,
  });

  /// The series for [metric], or null when the payload carried fewer than two
  /// points — one point is a reading, not a trend, and a delta over it would be
  /// zero for a reason that has nothing to do with the owner.
  static MetricTrend? from(String metric, List<TrendPoint> series) {
    if (series.length < 2) {
      return null;
    }
    return MetricTrend(
      metric: metric,
      series: series,
      latest: series.last.value,
      delta: series.last.value - series.first.value,
    );
  }

  /// The canonical metric id.
  final String metric;

  /// The window, oldest first.
  final List<TrendPoint> series;

  /// The newest value in the window.
  final double latest;

  /// Newest minus oldest. Legacy's arithmetic, unchanged.
  final double delta;

  /// What that change means, if anything. Never inferred from the sign alone.
  TrendVerdict get verdict => verdictFor(metric, delta);

  /// How many days the window covers.
  int get days => series.length;
}

/// The tracked metrics, each with its window and its verdict.
class TrendsSection extends StatelessWidget {
  /// [trends] may be empty, in which case nothing renders.
  const TrendsSection({required this.trends, required this.reveals, super.key});

  /// One entry per metric that had a window to show.
  final List<MetricTrend> trends;

  /// Where "this chart has already animated" is remembered. The screen's.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Against your own recent past', style: text.labelSmall),
          const SizedBox(height: Insets.xs),
          Text(
            'Each line is your own history, and the change is across the window '
            'shown. Colour appears only where there is a direction worth having: '
            'nothing here is compared to anybody else.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          for (final trend in trends) ...[
            Divider(color: colors.line2, height: Insets.xl, thickness: hairline),
            TrendRow(trend: trend, reveals: reveals),
          ],
        ],
      ),
    );
  }
}

/// One metric's row. Public so a test can pump it alone with a pinned series.
class TrendRow extends StatelessWidget {
  /// Draws [trend]'s name, its newest value, its line and its change.
  const TrendRow({required this.trend, required this.reveals, super.key});

  /// The window being drawn.
  final MetricTrend trend;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tag = context.hues.tagFor(trend.metric);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sentenceCaseName(trend.metric), style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              _ChangeLabel(trend: trend),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        SizedBox(
          width: 84,
          child: RevealOnce(
            id: 'insights.trend.${trend.metric}',
            registry: reveals,
            builder: (context, t) => HSpark(
              TrendPoint.valuesOf(trend.series),
              color: tag,
              progress: t,
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Text(
          decimalLabel(trend.latest),
          // The figure itself stays in ink. Only the CHANGE carries a verdict —
          // today's value is a measurement, not a judgement, and tinting it would
          // say the number is good rather than that the movement was.
          style: text.titleMedium?.copyWith(color: colors.ink),
        ),
      ],
    );
  }
}

/// `+3.2 over 14 days`, tinted only where the table licenses a verdict.
class _ChangeLabel extends StatelessWidget {
  const _ChangeLabel({required this.trend});

  final MetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    // `null` is the whole safety property of this widget: an unknown or neutral
    // metric gets the ordinary secondary ink every other caption on the screen
    // uses, which is visibly not a claim.
    final Color? verdict = switch (trend.verdict) {
      TrendVerdict.favourable => colors.fav,
      TrendVerdict.unfavourable => colors.unf,
      TrendVerdict.none => null,
    };
    final sign = trend.delta > 0 ? '+' : trend.delta < 0 ? '−' : '';
    return Text(
      '$sign${decimalLabel(trend.delta.abs())} over ${trend.days} days',
      style: text.bodySmall?.copyWith(color: verdict ?? colors.ink3),
    );
  }
}

/// The metric's name with its first letter raised — `metric_names.dart` stores
/// them lower-cased for use mid-sentence, and this is a row label.
String sentenceCaseName(String metric) {
  final name = metricName(metric);
  return name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
}
