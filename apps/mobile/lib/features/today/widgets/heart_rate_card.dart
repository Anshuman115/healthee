/// Heart rate · 24 h — the full-width strip legacy puts under the grid.
///
/// **Ported from** the `Heart rate · 24h` module in
/// `design_reference/project/hh/screen_today.jsx`: a full-width module whose
/// header carries the day's range on the right instead of a tag dot, a 52 px
/// chart, and the first and last sample times under it.
///
/// The range in the header is the range **of the samples on screen** and nothing
/// more — no baseline band, no shaded normal, no population reference.
/// `day_line_chart.dart` has the argument; the short version is that the honest
/// comparisons are the owner's own rolling baselines and those are the server's.
///
/// This is one of the few modules NOT in the grid, so it is not paired with a
/// fuller card further down — which is why the whole widget stays wrapped in
/// [ReadingView]. A strap that recorded no heart rate gets the complete refusal
/// here, reason and remedy, rather than a hole in a module whose explanation
/// lives somewhere else.
///
/// The chart is wrapped in `RevealOnce`, whose registry belongs to the screen
/// rather than to this widget. That is the whole of the reveal-once rule: this
/// card is built by a `ListView.builder`, so its `State` dies every time it
/// scrolls off and a controller started in `initState` would replay the reveal on
/// every scroll-back — a known, expensive bug in the legacy app.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/shared/charts/day_line_chart.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// The day's heart rate, latest reading and shape.
class HeartRateCard extends StatelessWidget {
  /// [reveals] must be the screen's registry, not one built here.
  const HeartRateCard({required this.day, required this.reveals, this.now, super.key});

  /// The day being shown.
  final DeviceDay day;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// The current instant.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tag = context.hues.heart;
    final series = day.heartRateSeries;
    return ReadingView<double>(
      reading: day.heartRate,
      label: 'Heart rate',
      builder: (context, latest) => InstrumentModule(
        label: 'Heart rate · 24 h',
        tag: null,
        minHeight: 0,
        trailing: Text(
          _rangeLabel(series),
          style: text.labelSmall?.copyWith(color: colors.ink3, fontSize: 10),
        ),
        children: [
          ModuleValue(value: latest.round().toString(), unit: 'bpm'),
          const SizedBox(height: Insets.sm),
          RevealOnce(
            // Stable and about the chart's subject, so inserting a card above it
            // cannot make this "a different chart" and animate again.
            id: 'today.heart-rate',
            registry: reveals,
            builder: (context, t) => DayLineChart(
              points: series,
              progress: t,
              color: tag,
              height: 52,
              showRange: false,
            ),
          ),
          if (series.length >= 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ModuleFoot(clockLabel(series.first.at)),
                ModuleFoot(clockLabel(series.last.at)),
              ],
            ),
        ],
      ),
    );
  }

  /// `49–112 bpm · 869 samples`, or the count alone when a single reading leaves
  /// no range to state. Never a range invented from one point.
  static String _rangeLabel(List<DevicePoint> series) {
    if (series.isEmpty) {
      return 'no samples';
    }
    final values = [for (final point in series) point.value];
    final low = values.reduce((a, b) => a < b ? a : b).round();
    final high = values.reduce((a, b) => a > b ? a : b).round();
    final count = '${series.length} samples';
    return low == high ? count : '$low–$high bpm · $count';
  }
}
