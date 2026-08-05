/// Three fortnightly trends — efficiency, regularity, HRV.
///
/// **Legacy** `sleep_screen.dart:432–440` and `_trend` at 565. Each row is the
/// metric at `sans(ink2, 12, w600)`, its target at `lbl(ink3, 8.5, 0.04)`, the
/// latest value right-aligned at `num(hue, 12, w700)`, then a 30 px `HArea` in
/// the same hue. Duration is deliberately absent — the debt and seven-night
/// charts above already carry it, and legacy says so in a comment.
///
/// ## The honesty change, and it is the sharpest one on the screen
///
/// Legacy drew `HArea(data.length >= 2 ? data : [0, 0], …)`. **A metric with one
/// night of history, or none, was drawn as a flat line at zero** — a chart of
/// two data points this app invented, in the metric's own colour, indistinguishable
/// from a real fortnight of zeroes. There is no reading of that which is honest.
///
/// A series too short to plot renders as a line of text saying how many nights it
/// has and how many it needs, in the same 30 px the chart would have occupied. The
/// row keeps its footprint; the fabricated data goes.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument_module.dart';

/// One trend row's inputs.
@immutable
class SleepTrend {
  /// Builds a trend.
  const SleepTrend({
    required this.label,
    required this.target,
    required this.series,
    required this.unit,
    required this.colour,
    this.digits = 0,
  });

  /// The metric's name.
  final String label;

  /// Legacy's target caption — `aim ≥85%`, `median 81`, `vs baseline`.
  final String target;

  /// The measured values, **chronological**, with the gaps left out.
  final List<double> series;

  /// The unit shown after the latest value.
  final String unit;

  /// The metric's own hue.
  final Color colour;

  /// Decimal places on the latest value.
  final int digits;

  /// Two points is the fewest `HArea` can draw a line between.
  static const int minimumPoints = 2;

  /// Whether there is enough history to plot.
  bool get isPlottable => series.length >= minimumPoints;
}

/// Legacy's "Trends · 14 nights" module.
class SleepTrendsCard extends StatelessWidget {
  /// [recent] is the fortnight, **newest first** — legacy's `recent`.
  const SleepTrendsCard({required this.recent, required this.progress, super.key});

  /// The fortnight of nights.
  final List<SleepNight> recent;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's `_series`: chronological, with the missing nights dropped rather
  /// than zero-filled. A gap is not a zero, and joining across one is the
  /// smallest lie a line chart can tell.
  static List<double> series(
    List<SleepNight> nights,
    double? Function(SleepNight night) read,
  ) => <double>[
    for (final night in nights.reversed)
      if (read(night) case final double value) value,
  ];

  /// The three trends, in legacy's order, with legacy's captions and hues.
  List<SleepTrend> trends(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return <SleepTrend>[
      SleepTrend(
        label: 'Efficiency',
        target: 'aim ≥85%',
        series: series(recent, (night) => night.efficiencyPct.valueOrNull),
        unit: '%',
        colour: colors.fav,
      ),
      SleepTrend(
        label: 'Regularity (SRI)',
        target: 'median 81',
        series: series(recent, (night) => night.sri.valueOrNull),
        unit: '',
        colour: hues.readiness,
      ),
      SleepTrend(
        label: 'HRV',
        target: 'vs baseline',
        series: series(recent, (night) => night.hrvSleepAvg.valueOrNull),
        unit: 'ms',
        colour: hues.hrv,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = trends(context);
    return InstrumentModule(
      label: 'Trends · 14 nights',
      tag: null,
      minHeight: 0,
      children: <Widget>[
        for (var index = 0; index < rows.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 16),
          _TrendRow(trend: rows[index], progress: progress),
        ],
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend, required this.progress});

  final SleepTrend trend;
  final double progress;

  /// Legacy's `SizedBox(height: 30)`.
  static const double _chartHeight = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  trend.label,
                  style: HType.sans(colors.ink2, size: 12, weight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  trend.target,
                  style: HType.label(colors.ink3, size: 8.5, tracking: 0.04),
                ),
              ],
            ),
            if (trend.series.isNotEmpty)
              Text(
                '${trend.series.last.toStringAsFixed(trend.digits)}${trend.unit}',
                style: HType.number(trend.colour, size: 12),
              ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: _chartHeight,
          child: trend.isPlottable
              ? HArea(
                  trend.series,
                  color: trend.colour,
                  progress: progress,
                  height: _chartHeight,
                  unit: trend.unit,
                  digits: trend.digits,
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _tooThin(trend.series.length),
                    style: HType.sans(colors.ink3, size: 11.5, height: 1.4),
                  ),
                ),
        ),
      ],
    );
  }

  /// What a series too short to plot says instead of a fabricated flat line.
  static String _tooThin(int measured) => measured == 0
      ? 'No nights measured this yet — nothing to plot.'
      : '$measured night measured so far. A line needs at least '
            '${SleepTrend.minimumPoints}.';
}
