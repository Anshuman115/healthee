/// `HRV · 14 days` — the full-width module under the first grid row.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:248` — the
/// module header carrying the current reading on the right instead of a tag dot,
/// a 52 px area chart, 7 px, and the research note under it.
///
/// Legacy draws this only when the sparkline has **more than two** points
/// (`_nums(spark['hrv_sleep_avg']).length > 2`), which is stricter than the two a
/// line needs: two nights is not a trend and a chart of it invites reading one as
/// one. `today_sections.dart` keeps that gate.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/today/widgets/metric_note.dart';
import 'package:healthee/features/today/widgets/trailing_reading.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// A fortnight of overnight HRV, with the note that reads it.
class HrvTrendCard extends StatelessWidget {
  /// [series] is oldest first and is never padded.
  const HrvTrendCard({
    required this.series,
    required this.reading,
    required this.median30d,
    required this.reveals,
    super.key,
  });

  /// The 14 nights.
  final List<double> series;

  /// Last night's value and its honesty state.
  final Reading<double> reading;

  /// The 30-day median the note compares against.
  final double? median30d;

  /// Where "this chart has already animated" is remembered. The screen's.
  final RevealRegistry reveals;

  /// Legacy's `HArea(..., height: 52)`.
  static const double chartHeight = 52;

  @override
  Widget build(BuildContext context) {
    final tint = context.hues.hrv;
    return InstrumentModule(
      label: 'HRV · 14 days',
      tag: tint,
      // `TrailingReading` draws a figure or a hole and CANNOT carry a caveat —
      // a 20 px header slot has no room for one. Without this line a caveated
      // HRV rendered as a bare number: the value shown, the tilt on it silently
      // dropped, which is the exact silence `Caveated` exists to prevent.
      caveats: reading.caveatsOrEmpty,
      minHeight: 0,
      trailing: TrailingReading(
        reading: reading,
        format: (value) => '${value.round()} ms',
        color: tint,
      ),
      children: [
        RevealOnce(
          id: 'today.hrv-trend',
          registry: reveals,
          builder: (context, t) =>
              HArea(series, color: tint, progress: t, height: chartHeight),
        ),
        const SizedBox(height: 7),
        MetricNote(hrvNote(reading.valueOrNull, median30d)),
      ],
    );
  }
}
