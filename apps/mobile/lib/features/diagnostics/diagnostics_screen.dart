/// Diagnostics — is the instrument working, and which instrument is speaking.
///
/// **This is where Today's "Baselines" and "From the strap" sections went, and
/// it is deliberately not a tab.** Both answer *"is the instrument working"*,
/// which is a question the owner asks when something looks wrong and never at
/// 7am. Fourteen rows of raw stream state above the daily read was the largest
/// single block of Today and the least often useful part of it. It is reached
/// from the pairing screen, which is where the avatar on Today already goes.
///
/// ## The two resting heart rates, and the rule this screen writes down
///
/// The owner caught it: **resting heart rate appeared twice on one screen with
/// different numbers** — 56.2 bpm under Baselines, 63 bpm under From-the-strap —
/// and HRV likewise, 33 ms from the strap against 49 in the recovery sub-scores.
/// CLAUDE.md's first hard rule is one canonical definition per metric.
///
/// **They are two instruments, not two answers.** Traced through the server:
///
/// ```text
///   resting heart rate
///     canonical  rhr_daily        derive/rhr.py — the MINIMUM of 5-minute mean
///                                 heart rate inside the sleep session, from the
///                                 raw `hr` stream, bounded 30–220 bpm
///     the other  resting_hr       BLE fetch 0x3A — the strap firmware's own
///                                 estimate, a one-byte integer sampled through
///                                 the day; the phone shows the LATEST, usually
///                                 taken awake
///
///   HRV
///     canonical  hrv_sleep_avg    derive/hrv_spo2_resp.py — the bounded mean of
///                                 overnight RMSSD inside the sleep window, 5–200 ms
///     the other  hrv              BLE fetch 0x49 — one spot sample, the latest of
///                                 the day, which may fall outside the sleep window
///                                 entirely
/// ```
///
/// A sleeping minimum sitting five to ten bpm under an awake estimate is ordinary
/// physiology, and `packages/knowledge/sports-science/metrics/resting-heart-rate.md`
/// says so in as many words — *"posture matters (supine < sitting < standing by
/// several bpm)"*, and *"mixing methods destroys the signal"*. The `.2` on 56.2 is
/// the giveaway: it is a bucket mean, and the strap's number is always an integer.
///
/// **The strap's own values are never pushed to the server** — `push_batch.dart`
/// leaves `resting_hr` and `max_hr` off the wire precisely so the server has one
/// definition — so the disagreement was only ever a presentation one.
///
/// ### The rule
///
/// 1. **The canonical daily read is the server's.** `rhr_daily` and
///    `hrv_sleep_avg` are what Today's grid shows and what every judgement is
///    computed from.
/// 2. **The strap's own estimates are still shown, and are named.** They are real
///    measurements and this screen is where a measurement is checked. Every row
///    here states its instrument, and `_instrumentNote` says how it differs from
///    the canonical one — the same thing the VO₂max card does with `gps_graded`
///    against `jurca_non_exercise`.
/// 3. **A label may never carry two definitions.** Where Today's grid falls back
///    to a strap value because the server sent none, the cell's label becomes
///    `Resting HR · strap` (`metric_grid.dart`). Moving the two apart onto
///    separate screens would have hidden the contradiction rather than resolved
///    it; naming them resolves it.
///
/// ### One thing that is a real defect, and is not ours to fix here
///
/// `read/today_series.py::_derived_card` ships `rhr_daily` with **no date and no
/// freshness gate** — `latest_derived_many` has no day bound — so a value derived
/// from an older night renders as today's. Every other reader on that path dates
/// or withholds a stale value (`_weight_card` carries `as_of_date`, `read/vo2max.py`
/// withholds outright). That is a server change and belongs in a server PR; it is
/// recorded here because it is the one way the canonical 56.2 could be *wrong*
/// rather than merely *different*.
library;

import 'package:flutter/widgets.dart';
import 'package:healthee/features/diagnostics/widgets/metric_strip.dart';
import 'package:healthee/features/diagnostics/widgets/server_metric_strip.dart';
import 'package:healthee/shared/device_health_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_head.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_heading.dart';

/// The diagnostics route. Not a tab — see the library docstring.
class DiagnosticsScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const DiagnosticsScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    // The Today tab stays lit: this screen is reached from the pairing surface,
    // not from the bar, and lighting nothing would leave the bar looking broken.
    return InstrumentScreen(tabIndex: 0, now: now, sections: diagnosticsSections);
  }
}

/// Builds the ordered section list for one render of Diagnostics.
List<PageSection> diagnosticsSections(ScreenData data) {
  final snapshot = data.snapshot;
  return <PageSection>[
    const PageSection(
      PageHead(eyebrow: 'Instruments', title: 'Diagnostics'),
      gap: PageSpacing.section,
    ),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,

    if (snapshot != null && snapshot.metrics.isNotEmpty) ...[
      const PageSection(
        SectionHeading(
          'Baselines',
          subtitle:
              "The server's canonical daily values, each against your own "
              '30-day normal. These are the numbers every judgement in the app '
              'is computed from.',
        ),
      ),
      PageSection(
        ServerMetricStrip(
          metrics: snapshot.metrics,
          sparklines: snapshot.sparklines,
          reveals: data.reveals,
        ),
        gap: PageSpacing.section,
      ),
    ],

    const PageSection(
      SectionHeading(
        'From the strap',
        subtitle:
            'What this phone read off the device, with nothing added. Two of '
            'these measure the same thing as a baseline above by a different '
            'method, and each says which — they are not expected to agree.',
      ),
    ),
    PageSection(MetricStrip(metrics: data.day.metrics, now: data.now)),
    PageSection(DeviceHealthCard(day: data.day, now: data.now)),
  ];
}
