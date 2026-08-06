/// `Blood oxygen · 14 nights` — the nightly MINIMUMS, one mark a night.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:312`. Legacy's
/// own comment says why this one is not a grid tile: *"full-width because the
/// NIGHTLY MINIMUM (desaturation signal) is what matters clinically and needs
/// room"*.
///
/// ```text
///   BLOOD OXYGEN · 14 NIGHTS                            97%
///   ‑‑‑‑‑‑‑‑‑‑ CLINICAL CONVENTION 92% ‑‑‑‑‑‑‑‑‑‑
///     •  •  • •  •  •  • •  •  •  • •  •  •
///   LAST NIGHT LOW 95%  ·  LOWEST 14N 91%
///   No sustained run of low nightly minimums …
/// ```
///
/// ## Two owner-directed departures, 2026-08-06, and one repair
///
/// **The chart draws the minima now.** It drew `spo2_overnight` — the nightly
/// *averages* — while the caption under it and the note under that both talked
/// about the minimum, and the card's own docstring said the minimum "is what
/// matters clinically and needs room". The room was being given to the other
/// series. `wearable_spo2_validity` D2 is about the nightly minimum; this is the
/// chart it is about.
///
/// **One mark a night, unconnected** ([HNightDots]). Fourteen nightly minimums
/// are fourteen discrete measurements, and a smooth line between them asserts
/// saturations at times nobody was asleep. It is also what stops this chart
/// reading like the other three, which was the owner's report.
///
/// **The ~92% line is drawn, dashed and labelled a convention.** That is D2's
/// own wording: it is *"a clinical convention (the ~90% hypoxaemia line plus a
/// caution margin), not a wearable-validated cutoff — none is sourced (#98)"*,
/// and the strap is not a cleared oximeter, so its true error is unquantified
/// and at least ±3.5%. Drawn like a personal baseline it would read as a
/// pass/fail line about this owner's oxygen. Dashed and captioned, it reads as
/// what it is: a borrowed line.
///
/// ## Nothing on this chart flags a night
///
/// D1 and D3 are explicit — *"a trend over multiple nights, never a
/// single-reading alarm"*, *"never call out individual low-reading minutes
/// (most are sensor artefacts)"*. So every dot is identical: no night below the
/// convention line is coloured, enlarged, ringed or joined to its neighbours.
/// The only thing that may say anything is a **sustained run**, it says it in
/// prose, and it routes to a clinician rather than concluding anything — see
/// `metric_note.dart`, which owns that threshold and that sentence.
///
/// Both header figures come from the payload's own sparklines and neither is
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
import 'package:healthee/shared/charts/h_night_dots.dart';
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

  /// Legacy's chart height, unchanged.
  static const double chartHeight = 52;

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
          builder: (context, t) => HNightDots(
            minima,
            color: tint,
            progress: t,
            height: chartHeight,
            reference: ChartReference.convention(
              value: spo2ConventionPercent,
              // The word "convention" is load-bearing and is asserted in
              // `test/features/vitals_charts_test.dart`. See the docstring.
              label:
                  'CLINICAL CONVENTION ${spo2ConventionPercent.round()}% '
                  '— NOT A CUTOFF FOR THIS DEVICE',
            ),
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
        MetricNote(spo2Note(minima)),
      ],
    );
  }
}
