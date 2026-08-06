/// `Blood oxygen · 14 nights` — full width, because the nightly LOW is the point.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:312`. Legacy's
/// own comment says why this one is not a grid tile: *"full-width because the
/// NIGHTLY MINIMUM (desaturation signal) is what matters clinically and needs
/// room"*. So: the average trend as a 52 px line, then the last night's minimum
/// and the lowest of the period as one mono caption, then the research note.
///
/// ```text
///   BLOOD OXYGEN · 14 NIGHTS                            97%
///   ╱‾‾╲__╱‾‾╲___
///   LAST NIGHT LOW 95%  ·  LOWEST 14N 91%
///   Healthy overnight oxygen — averages in the normal 95–100% range …
/// ```
///
/// Both figures come from the `spo2_overnight_min` sparkline and neither is
/// invented: with no minima at all the caption is absent rather than showing the
/// average in its place.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/metric_hue.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/widgets/metric_note.dart';
import 'package:healthee/features/today/widgets/trailing_reading.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// The fortnight of overnight oxygen, and what its lows say.
class BloodOxygenCard extends StatelessWidget {
  /// [averages] and [minima] are the two sparklines, oldest first.
  const BloodOxygenCard({
    required this.averages,
    required this.minima,
    required this.reading,
    required this.reveals,
    super.key,
  });

  /// `spo2_overnight` — the nightly averages.
  final List<double> averages;

  /// `spo2_overnight_min` — the nightly minima.
  final List<double> minima;

  /// The current overnight average and its honesty state.
  final Reading<double> reading;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = hueFor(context.hues, TodayMetricIds.bloodOxygen);
    final lastMinimum = minima.isEmpty ? null : minima.last;
    final lowest = minima.isEmpty
        ? null
        : minima.reduce((a, b) => a < b ? a : b);
    return InstrumentModule(
      label: 'Blood oxygen · 14 nights',
      tag: tint,
      // The live case, and it was silent: on the committed contract snapshot
      // `spo2_overnight` has no metric card, so this figure comes from
      // `last_sleep_extras` CAVEATED with the sentence naming the instrument and
      // the night — and `TrailingReading` renders a figure or a hole, never a
      // disclosure. The header mark is where that sentence reaches the screen.
      caveats: reading.caveatsOrEmpty,
      minHeight: 0,
      trailing: TrailingReading(
        reading: reading,
        format: (value) => '${value.round()}%',
        color: tint,
      ),
      children: [
        RevealOnce(
          id: 'today.blood-oxygen',
          registry: reveals,
          builder: (context, t) => HArea(
            averages,
            color: tint,
            progress: t,
            height: 52,
            unit: '%',
          ),
        ),
        if (lastMinimum != null) ...[
          const SizedBox(height: 6),
          Text(
            'LAST NIGHT LOW ${lastMinimum.round()}%'
            '${lowest == null ? '' : '  ·  LOWEST 14N ${lowest.round()}%'}',
            style: HType.number(
              colors.ink3,
              size: 10,
              weight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 7),
        MetricNote(spo2Note(reading.valueOrNull, lastMinimum, lowest)),
      ],
    );
  }
}
