/// `Blood oxygen · 14 nights` — the nightly MINIMUMS, as one line.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:312`. Legacy's
/// own comment says why this one is not a grid tile: *"full-width because the
/// NIGHTLY MINIMUM (desaturation signal) is what matters clinically and needs
/// room"*.
///
/// ```text
///   BLOOD OXYGEN · 14 NIGHTS                            97%
///     •‑•‑‑•‑•‑‑•‑‑•‑•‑‑•‑•
///   ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑ ‑
///   92% IS A CLINICAL CONVENTION — NOT A CUTOFF FOR THIS STRAP
///   LAST NIGHT LOW 95%  ·  LOWEST 14N 91%
///   No sustained run of low nightly minimums …
/// ```
///
/// ## What is drawn, and the two reversals behind it
///
/// **The minimums, not the averages.** It drew `spo2_overnight` while the
/// caption under it and the note under that both talked about the minimum, and
/// this card's own docstring said the minimum "needs room". The room was being
/// given to the other series. That repair stands.
///
/// **A connected line, and that reverses 2026-08-06's own first attempt.** It
/// shipped as unconnected per-night dots. `wearable_spo2_validity` D1 makes SpO2
/// readable only *as a trend across multiple nights*, and a scatter is the shape
/// that hides a trend best — so the mark was arguing against the only reading
/// the corpus allows. [HNightLine] carries the honest half of the dots forward:
/// the segments are straight, because a smoothed curve through fourteen nights
/// can dip below every night measured and invent a lower low.
///
/// ## The scale is FIXED at [scaleFloorPercent]–[scaleCeilingPercent]
///
/// Owner report: *"the y-scale crushes 93–98% onto the 92% line while one night
/// at 85% sets the floor."* An auto-scale has two failure modes here and this
/// card had both. On an ordinary fortnight it resolves tenths of a percent on a
/// sensor whose error is unquantified and **at least ±3.5%** (#98) — drawing
/// noise as shape, differently every night. On a fortnight with one bad night it
/// spends the whole box on that night.
///
/// So the window is fixed and stated:
///
///   * **100%** because saturation cannot exceed it, so no padding above is
///     anything but empty plot.
///   * **88%** because that is the ~92% convention minus the sensor's own stated
///     error — the line and its caution margin are always both on the chart.
///   * a night outside the window **widens** it (nothing is ever clipped or
///     hidden), and when that happens the card says so in its foot.
///
/// The plot is [chartHeight] px rather than legacy's 52 for the same reason
/// legacy gave this card the full width: at 52 px one percentage point is under
/// 4 px, which is less than a night-mark's own diameter, so consecutive nights
/// overlap into a smear. `test/features/vitals_scales_test.dart` holds both the
/// fixed window and the per-percent separation.
///
/// ## Nothing on this chart flags a night
///
/// D1 and D3 are explicit — *"a trend over multiple nights, never a
/// single-reading alarm"*, *"never call out individual low-reading minutes (most
/// are sensor artefacts)"*. So every night is drawn identically: none below the
/// convention line is coloured, enlarged or ringed. The only thing that may say
/// anything is a **sustained run**, it says it in prose, and it routes to a
/// clinician rather than concluding anything — see `metric_note.dart`, which
/// owns that threshold and that sentence.
///
/// Both caption figures come from the payload's own sparklines and neither is
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
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/h_night_line.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// The fortnight of overnight minimums, and what a sustained run of them says.
class BloodOxygenCard extends StatelessWidget {
  /// [minima] is `spo2_overnight_min`, oldest first — the drawn series.
  const BloodOxygenCard({
    required this.minima,
    required this.reading,
    required this.reveals,
    super.key,
  });

  /// `spo2_overnight_min` — the nightly minimums. See the library docstring on
  /// why this and not the averages.
  final List<double> minima;

  /// The current overnight average and its honesty state — the header figure.
  final Reading<double> reading;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// Taller than legacy's 52 so a percentage point is legible. See the docstring.
  static const double chartHeight = 76;

  /// The fixed floor: the convention minus the sensor's own ≥±3.5% error (#98).
  static const double scaleFloorPercent = 88;

  /// The fixed ceiling. Saturation cannot exceed it.
  static const double scaleCeilingPercent = 100;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = hueFor(context.hues, TodayMetricIds.bloodOxygen);
    final lastMinimum = minima.isEmpty ? null : minima.last;
    final lowest = minima.isEmpty
        ? null
        : minima.reduce((a, b) => a < b ? a : b);
    // The word "convention" is load-bearing and is asserted in
    // `test/features/vitals_thresholds_test.dart`. See `chart_reference.dart`.
    final convention = ChartReference.convention(
      value: spo2ConventionPercent,
      label:
          '${spo2ConventionPercent.round()}% is a clinical convention '
          '— not a cutoff for this strap',
    );
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
          builder: (context, t) => HNightLine(
            minima,
            color: tint,
            progress: t,
            height: chartHeight,
            window: (low: scaleFloorPercent, high: scaleCeilingPercent),
            reference: convention,
          ),
        ),
        ChartReferenceCaption(<ChartReference>[convention]),
        if (lastMinimum != null) ...[
          const SizedBox(height: 4),
          Text(
            'LAST NIGHT LOW ${lastMinimum.round()}%'
            '${lowest == null ? '' : '  ·  LOWEST 14N ${lowest.round()}%'}',
            style: HType.number(colors.ink3, size: 10, weight: FontWeight.w500),
          ),
        ],
        // Said only when it happened: a fixed scale that silently stopped being
        // fixed would be the worst of both.
        if (lowest != null && lowest < scaleFloorPercent)
          ModuleFoot(
            'Scale widened below ${scaleFloorPercent.round()}% '
            'to keep every night on it',
          ),
        const SizedBox(height: 7),
        MetricNote(spo2Note(minima)),
      ],
    );
  }
}
