/// `Beyond a single night` — efficiency, regularity and HRV over the fortnight.
///
/// `design/mobile-preview/sleep-history-view.js`:
///
/// ```js
/// ${H.chapter('sleep-trends','Beyond a single night','sleep','insights')}
/// ${['efficiency','regularity','hrv'].map(key => H.historyPanel(key)).join('')}
/// ```
///
/// Each of those is a panel with the latest reading, a full line chart with its
/// gridlines and its touch readout, and a line saying how many dated samples are
/// behind it.
///
/// ## Straight segments, never a spline
///
/// These are **nightly** readings — one number per night, not a dense continuous
/// trace — so the line joins them and does not curve between them. A monotone
/// curve would be defensible for a heart-rate trace sampled every minute; here
/// it would draw an efficiency at 03:00 on a night that has exactly one
/// efficiency, and the rule this project already learned the expensive way is
/// that an interpolation must never produce a value nobody measured.
///
/// ## A gap stays a gap
///
/// A night the strap did not measure enters the series as `null`.
/// `SeriesPainter` breaks the line there rather than joining across it, so a
/// missing night looks missing instead of looking like a straight run.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/honesty/sleep_gap.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/charts/v02/chart_curve.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// One of the three fortnight panels.
@immutable
class SleepTrend {
  /// What to draw, and where its numbers come from.
  const SleepTrend({
    required this.title,
    required this.tone,
    required this.unit,
    required this.metric,
    required this.read,
    this.digits = 0,
    this.infoKey,
  });

  /// The prototype's panel title.
  final String title;

  /// Which family it belongs to.
  final Tone tone;

  /// The unit beside the figure and in the readout.
  final String unit;

  /// The metric this panel opens.
  final String metric;

  /// Pulls this trend's value off one night.
  final Reading<double> Function(SleepNight night) read;

  /// How many decimals the figure carries.
  final int digits;

  /// Which ⓘ entry belongs to it.
  final String? infoKey;
}

/// The three, in the prototype's order.
const List<SleepTrend> kSleepTrends = <SleepTrend>[
  SleepTrend(
    title: 'Sleep efficiency',
    tone: Tone.sleep,
    unit: '%',
    metric: 'efficiency_pct',
    read: _efficiency,
    digits: 1,
    infoKey: 'sleep_health',
  ),
  SleepTrend(
    title: 'Sleep regularity',
    tone: Tone.sleep,
    unit: 'SRI',
    metric: 'sri',
    read: _sri,
    infoKey: 'sleep_consistency',
  ),
  SleepTrend(
    title: 'Heart-rate variability',
    tone: Tone.fitness,
    unit: 'ms',
    metric: 'hrv_sleep_avg',
    read: _hrv,
    infoKey: 'hrv',
  ),
];

Reading<double> _efficiency(SleepNight night) => night.efficiencyPct;
Reading<double> _sri(SleepNight night) => night.sri;
Reading<double> _hrv(SleepNight night) => night.hrvSleepAvg;

/// One `H.historyPanel` — the latest reading and the fortnight behind it.
class SleepTrendPanel extends StatelessWidget {
  /// [recent] is newest first, the order `/api/sleep` sends.
  const SleepTrendPanel({
    required this.trend,
    required this.recent,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The plot's height, before its readout line.
  static const double chartHeight = 150;

  /// The gap between the figure and the chart.
  static const double chartGap = 8;

  /// Which trend this panel draws.
  final SleepTrend trend;

  /// The fortnight, newest first.
  final List<SleepNight> recent;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens this metric's own history.
  final void Function(String metric)? onDetails;

  /// Oldest first, with an unmeasured night kept as a gap.
  List<double?> get series =>
      <double?>[for (final night in recent.reversed) trend.read(night).valueOrNull];

  /// One short date per night, oldest first.
  List<String> get dates =>
      <String>[for (final night in recent.reversed) shortDate(night.date)];

  /// How many of those nights carry a reading.
  int get measured => series.where((value) => value != null).length;

  /// The line under the chart: how much data is behind it.
  String get note {
    if (measured == 0) {
      return 'No night in the last fortnight carries this reading.';
    }
    final through = dates.isEmpty ? '' : ' through ${dates.last}';
    return '$measured ${measured == 1 ? 'night' : 'nights'} '
        'measured$through.';
  }

  @override
  Widget build(BuildContext context) {
    final latest = recent.isEmpty
        ? Withheld<double>(SleepGap.noSession.disclosure)
        : trend.read(recent.first);
    final value = latest.valueOrNull;
    return Panel(
      tone: trend.tone,
      label: trend.title,
      head: PanelHead(
        title: trend.title,
        icon: SolarIconsOutline.chart_2,
        infoKey: trend.infoKey,
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails == null ? null : () => onDetails!(trend.metric),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            value == null ? '—' : value.toStringAsFixed(trend.digits),
            unit: trend.unit,
            context_: dates.isEmpty ? null : dates.last,
          ),
          const SizedBox(height: chartGap),
          RevealOnce(
            id: 'sleep.trend.${trend.metric}',
            registry: reveals,
            builder: (context, t) => V02LineChart(
              series,
              progress: t,
              height: chartHeight,
              unit: trend.unit,
              digits: trend.digits,
              // Nightly readings. See the library docstring.
              curve: SeriesCurve.straight,
              captions: dates.isEmpty
                  ? const <String>[]
                  : <String>[dates.first, dates.last],
              sampleLabels: dates,
              semanticLabel: '${trend.title} over the recent nights',
            ),
          ),
          PanelNote(note),
          if (latest case Withheld<double>(:final disclosure))
            PanelNote('Latest reading: ${disclosure.message}'),
        ],
      ),
    );
  }
}
