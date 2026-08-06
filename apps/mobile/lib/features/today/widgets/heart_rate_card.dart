/// `Heart rate · 24h` — the day's shape, with the clock under it.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:283` — the
/// module header carrying the day's range on the right instead of a tag dot, a
/// 52 px area chart, 4 px, and five clock captions spread across the width.
///
/// ```text
///   HEART RATE · 24H                            49–112 bpm
///   ╱‾╲__╱‾‾╲___╱‾╲__
///   6a       9a      12p       3p      6p
/// ```
///
/// ## The captions are the data's, and legacy's are not — a repaired flaw
///
/// Legacy hard-codes `['12a', '6a', '12p', '6p', '11p']` and lays them out with
/// `spaceBetween`, so they are captions rather than axis ticks and they describe
/// a full midnight-to-midnight day. The series is `today_hr_series`, which starts
/// at the first hour the strap recorded — 06:00 in the contract snapshot — and
/// ends at the last. **On every partial day, which is every day before bedtime,
/// legacy's labels name hours the curve above them does not cover**: the reader
/// takes the second caption to mean the peak beside it happened at 6 a.m.
///
/// The layout is unchanged — five captions, `spaceBetween`, same style, same
/// 4 px above — and only the strings change: they are sampled at five even
/// positions **of the series itself**, so each one names the hour the curve is
/// actually at. That is what the app claims to be true, not where it is drawn.
///
/// ## The floor under the trace — owner-directed, 2026-08-06
///
/// The header range used to be the whole reference: *"no baseline band, no
/// shaded normal, no population reference."* On the installed build the owner
/// reported that this chart and three others *"all look similar"*, and the cause
/// was that a bare 24-hour trace has nothing to be read against — a peak of 112
/// is only interesting relative to where the day sits when nothing is happening.
///
/// So the chart now draws **the owner's own resting heart rate** as a solid
/// reference line: the floor the day departs from and returns to. It is
/// `rhr_daily` as the server derived it, never a minimum of the visible hours —
/// the day's lowest hour and a resting rate are different quantities and the
/// second is the one with a definition. With no resting rate today the line is
/// absent and the foot says so.
///
/// This is a deliberate departure from the verbatim-legacy rule
/// (`feedback_port_legacy_design_verbatim`); `chart_reference.dart` carries the
/// argument for all four charts.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/today_series.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// The day's heart rate, hour by hour, against the owner's resting rate.
class HeartRateDayCard extends StatelessWidget {
  /// [points] is today's hourly summary, earliest first.
  const HeartRateDayCard({
    required this.points,
    required this.restingHeartRate,
    required this.reveals,
    super.key,
  });

  /// Today's hours, as the server aggregated them.
  final List<HourPoint> points;

  /// `rhr_daily`, the reference line. A withheld reading draws no line.
  final Reading<double> restingHeartRate;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// How many captions sit under the chart. Legacy's five.
  static const int captionCount = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = context.hues.heart;
    final series = <double>[for (final point in points) point.average];
    final low = series.reduce((a, b) => a < b ? a : b).round();
    final high = series.reduce((a, b) => a > b ? a : b).round();
    final resting = restingHeartRate.valueOrNull;
    return InstrumentModule(
      label: 'Heart rate · 24h',
      tag: tint,
      caveats: restingHeartRate.caveatsOrEmpty,
      minHeight: 0,
      trailing: Text(
        '$low–$high bpm',
        style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
      ),
      children: [
        RevealOnce(
          id: 'today.heart-rate',
          registry: reveals,
          builder: (context, t) => HArea(
            series,
            color: tint,
            progress: t,
            height: 52,
            references: <ChartReference>[
              if (resting != null)
                ChartReference.personalBaseline(
                  value: resting,
                  label: 'RESTING ${resting.round()}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in captionsFor(points))
              Text(
                label,
                style: HType.number(
                  colors.ink3,
                  size: 9,
                  weight: FontWeight.w400,
                ),
              ),
          ],
        ),
        if (resting == null)
          const ModuleFoot('No resting rate today — no floor to read this against'),
      ],
    );
  }
}

/// Five captions sampled evenly from [points], naming the hours really drawn.
///
/// Fewer than five hours gives one caption per hour rather than repeating a
/// label to fill the row — a duplicated caption would read as two moments.
List<String> captionsFor(List<HourPoint> points) {
  if (points.isEmpty) {
    return const <String>[];
  }
  if (points.length <= HeartRateDayCard.captionCount) {
    return [for (final point in points) shortClock(point.hour)];
  }
  final last = points.length - 1;
  return [
    for (var i = 0; i < HeartRateDayCard.captionCount; i++)
      shortClock(points[(last * i / (HeartRateDayCard.captionCount - 1)).round()].hour),
  ];
}
