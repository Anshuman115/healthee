/// Where each tracked metric has been going — and the only place `fav`/`unf`
/// appear on this screen.
///
/// `screens-overview.js::H.screens.insights`'s **Your longer patterns**: a
/// `.twin-panels` grid of `H.miniTrend(...)` — a figure, its recent shape, and
/// one line about both — with an `All metrics` action on the section head.
///
/// **The presentation is v02's; the claim is unchanged.** `MetricTrend`,
/// `verdictFor` and `metric_polarity.dart` are the same objects they were before
/// the redesign, and the colour rule they encode is the same rule.
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
/// all, and `insights_sections.dart` states the split.
///
/// ## The colourless rows are the point of the coloured ones
///
/// Calories carry polarity `neutral` and render with **no** verdict colour, and a
/// metric the table has never heard of renders with none either. That is not the
/// leftover case: a screen that tinted everything would teach the owner that
/// colour here is decoration, and then the two rows where it is a claim would say
/// nothing. `metric_polarity.dart` argues it at length and
/// `test/features/insights_trends_test.dart` breaks it on purpose.
///
/// ## The panel's TONE is an identity and is not the verdict
///
/// `toneForMetric` takes an id and nothing else, so the family a panel resolves
/// cannot depend on which way the metric moved. The verdict lives in exactly one
/// place on the card — the change line — which is why flipping the sign of a
/// finding may change nothing and flipping the sign of a *trend* may change only
/// that one colour.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/v02/v02_sparkline.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/format/metric_polarity.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/chapter.dart';
import 'package:healthee/shared/v02/metric_tone.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

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

/// `.twin-panels` of [TrendPanel]s — two across, in [trends]' order.
class TrendsGrid extends StatelessWidget {
  /// [trends] may be empty, in which case nothing renders at all. A heading over
  /// no panels reads as breakage; the honest state is silence, and
  /// `insights_sections.dart` drops the heading with it.
  const TrendsGrid({
    required this.trends,
    required this.reveals,
    this.onOpenMetric,
    super.key,
  });

  /// One entry per metric that had a window to show.
  final List<MetricTrend> trends;

  /// Where "this chart has already animated" is remembered. The screen's.
  final RevealRegistry reveals;

  /// Opens one metric's own history.
  final void Function(String metric)? onOpenMetric;

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }
    final rows = <Widget>[];
    for (var i = 0; i < trends.length; i += 2) {
      final left = _panel(trends[i]);
      // An odd tail draws full width rather than beside a hole. A twin row with
      // one live half is a half-width panel next to nothing, which reads as a
      // card that failed to load.
      rows.add(
        i + 1 < trends.length
            ? TwinPanels(left: left, right: _panel(trends[i + 1]))
            : left,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: PageSpacing.panel),
          rows[i],
        ],
      ],
    );
  }

  Widget _panel(MetricTrend trend) => TrendPanel(
    trend: trend,
    reveals: reveals,
    onDetails: onOpenMetric == null
        ? null
        : () => onOpenMetric!(trend.metric),
  );
}

/// One metric's panel: its name, its newest value, its line and its change.
///
/// Public so a test can pump it alone with a pinned series — which is how the
/// colour rule is asserted, rather than by scrolling a screen.
class TrendPanel extends StatelessWidget {
  /// Draws [trend] as a half-width v02 panel.
  const TrendPanel({
    required this.trend,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// `.chart` inside a twin panel, at the prototype's compact proportions.
  static const double sparklineHeight = 30;

  /// The gap between the figure and the line.
  static const double chartGap = 8;

  /// The window being drawn.
  final MetricTrend trend;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  /// Opens the metric's own history. Null draws no action.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final tone = toneForMetric(trend.metric);
    return Panel(
      tone: tone,
      label: sentenceCaseName(trend.metric),
      head: PanelHead(
        title: sentenceCaseName(trend.metric),
        icon: iconForTone(tone),
        infoKey: trend.metric,
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The figure itself stays in ink. Only the CHANGE carries a verdict —
          // today's value is a measurement, not a judgement, and tinting it
          // would say the number is good rather than that the movement was.
          PanelValue(decimalLabel(trend.latest)),
          const SizedBox(height: chartGap),
          RevealOnce(
            id: 'insights.trend.${trend.metric}',
            registry: reveals,
            builder: (context, t) => V02Sparkline(
              <double?>[for (final point in trend.series) point.value],
              progress: t,
              height: sparklineHeight,
            ),
          ),
          _ChangeNote(trend: trend),
        ],
      ),
    );
  }
}

/// `+3.2 over 14 days`, tinted only where the table licenses a verdict.
class _ChangeNote extends StatelessWidget {
  const _ChangeNote({required this.trend});

  final MetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // `null` is the whole safety property of this widget: an unknown or neutral
    // metric gets the ordinary secondary ink every other caption on the screen
    // uses, which is visibly not a claim.
    final Color? verdict = switch (trend.verdict) {
      TrendVerdict.favourable => colors.fav,
      TrendVerdict.unfavourable => colors.unf,
      TrendVerdict.none => null,
    };
    final sign = trend.delta > 0
        ? '+'
        : trend.delta < 0
        ? '−'
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: PanelNote.compactTopGap),
      child: Text(
        '$sign${decimalLabel(trend.delta.abs())} over ${trend.days} days',
        style: TypeScale.panelNoteCompact.copyWith(
          color: verdict ?? colors.ink2,
        ),
      ),
    );
  }
}

/// The metric's name with its first letter raised — `metric_names.dart` stores
/// them lower-cased for use mid-sentence, and this is a panel title.
String sentenceCaseName(String metric) {
  final name = metricName(metric);
  return name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
}

/// The [Tone] the panel for [metric] resolves. Re-exported for the tests that
/// assert a panel's family is an identity rather than a verdict.
Tone trendTone(String metric) => toneForMetric(metric);
