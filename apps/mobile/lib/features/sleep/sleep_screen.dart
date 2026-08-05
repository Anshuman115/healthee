/// Sleep — last night, the week behind it, and every instrument read at rest.
///
/// **This is where Today's sleep half went.** Today's grid indexes it: the Sleep,
/// HRV, Resting HR and Resp/SpO₂ cells all open this screen, and each of them is
/// allowed to draw a bare hole where its number would be *because* the card here
/// carries the reason and the remedy in full (`grid_module.dart` strikes that
/// bargain; this screen is the other half of it).
///
/// ## Why the autonomic instruments live here and not on an "Activity" screen
///
/// Resting heart rate, overnight HRV, breathing rate and blood oxygen are all
/// measured **while the owner is asleep** — `derive/rhr.py` takes the minimum of
/// 5-minute mean heart rate inside the sleep session, and `hrv_sleep_avg` is the
/// bounded mean of overnight RMSSD in the same window. They are readings *of the
/// night*, not of the day, and the recovery ladder that compares them to their own
/// baselines is the same set of signals. Splitting them across two tabs would put
/// a number on one screen and the thing it was measured during on another.
///
/// The cards are the ones Today used, unchanged. This pass moved them; it did not
/// redesign them.
library;

import 'package:flutter/widgets.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/features/sleep/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/sleep/widgets/recovery_ladder.dart';
import 'package:healthee/features/sleep/widgets/sleep_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_debt_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_dimensions_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_night_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_week_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_head.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// The Sleep tab.
class SleepScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const SleepScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return InstrumentScreen(now: now, sections: sleepSections);
  }
}

/// Builds the ordered section list for one render of Sleep.
List<PageSection> sleepSections(ScreenData data) {
  final snapshot = data.snapshot;
  final reveals = data.reveals;
  return <PageSection>[
    const PageSection(
      PageHead(eyebrow: 'Last night', title: 'Sleep'),
      gap: PageSpacing.section,
    ),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,

    // The server's staged night when it has one, the strap's own when it does
    // not. Not a fallback dressed as the same card: each says which instrument
    // it came from, and with no network at all the owner still sees the night
    // their phone read (brief §7.4). Showing the server's judgements beside the
    // server's copy of the night is what keeps the two from disagreeing.
    if (snapshot != null && snapshot.lastSleep.hasValue)
      PageSection(
        ReadingView<LastSleep>(
          reading: snapshot.lastSleep,
          label: 'Last night',
          builder: (context, night) => SleepNightCard(
            night: night,
            reveals: reveals,
            vitals: snapshot.overnightVitals,
          ),
        ),
      )
    else
      PageSection(SleepCard(day: data.day, now: data.now)),
    if (snapshot != null)
      PageSection(
        ReadingView<SleepHealth>(
          reading: snapshot.sleepHealth,
          label: 'Sleep health',
          builder: (context, health) => SleepDimensionsCard(health: health),
        ),
      ),

    const PageSection(
      SectionHeading(
        'The week',
        subtitle: 'The fortnight behind last night',
        metric: 'sleep_duration',
      ),
    ),
    if (snapshot != null)
      PageSection(
        ReadingView<SleepDebt>(
          reading: snapshot.sleepDebt,
          label: 'Sleep debt',
          builder: (context, debt) => SleepDebtCard(
            debt: debt,
            nights: snapshot.sleepHistory7d,
            reveals: reveals,
          ),
        ),
      ),
    if (snapshot != null)
      PageSection(
        SleepWeekCard(nights: snapshot.sleepHistory7d, reveals: reveals),
        gap: PageSpacing.section,
      ),

    const PageSection(
      SectionHeading(
        'Measured at rest',
        subtitle:
            'Resting heart rate, HRV, breathing and blood oxygen are all read '
            'inside the sleep window — they are readings of the night.',
        metric: 'hrv_sleep_avg',
      ),
    ),
    if (snapshot != null)
      PageSection(
        ReadingView<RecoverySignals>(
          reading: snapshot.recoverySignals,
          label: 'Recovery signals',
          builder: (context, signals) => RevealOnce(
            id: 'sleep.ladder',
            registry: reveals,
            builder: (context, t) => RecoveryLadder(signals: signals, progress: t),
          ),
        ),
      ),
    if (snapshot?.overnightVitals case final vitals?)
      PageSection(
        BloodOxygenCard(
          vitals: vitals,
          nightlyMinimums: snapshot!.sparkline('spo2_overnight_min'),
          reveals: reveals,
        ),
      ),
  ];
}
