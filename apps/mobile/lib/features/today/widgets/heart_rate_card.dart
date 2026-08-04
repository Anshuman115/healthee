/// The day's heart rate: the latest reading, and the shape of the day behind it.
///
/// The chart is wrapped in `RevealOnce`, whose registry belongs to the screen
/// rather than to this widget. That is the whole of the reveal-once rule: this
/// card is built by a `ListView.builder`, so its `State` dies every time it
/// scrolls off and a controller started in `initState` would replay the reveal
/// on every scroll-back — a known, expensive bug in the legacy app.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/features/today/widgets/measured_card.dart';
import 'package:healthee/shared/charts/day_line_chart.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// Latest heart rate with the day's line under it.
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
    final series = day.heartRateSeries;
    return ReadingView<double>(
      reading: day.heartRate,
      label: 'Heart rate',
      builder: (context, latest) => MeasuredCard(
        title: 'Heart rate',
        measuredAt: series.isEmpty ? null : series.last.at,
        now: now,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroValue(value: latest.round().toString(), unit: 'bpm'),
            RevealOnce(
              // Stable and about the chart's subject, so inserting a card above
              // it cannot make this "a different chart" and animate again.
              id: 'today.heart-rate',
              registry: reveals,
              builder: (context, t) =>
                  DayLineChart(points: series, progress: t),
            ),
          ],
        ),
      ),
    );
  }
}
