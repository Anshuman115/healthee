/// `Movement → recovery` — the two panels the chapter opens with.
///
/// `screens-overview.js::dayCharts`: heart rate and stress on one hour axis,
/// then steps with the energy the day cost.
///
/// ## The linked chart is the showpiece and it carries its own caveat
///
/// `V02LinkedChart` prints *"A coinciding change is context, not proof that one
/// signal caused the other"* under itself, always. The panel does not repeat it
/// and could not remove it: it is the chart's own default, for the reason
/// `v02_linked_chart.dart` records — two traces with a shared cursor is a
/// machine for producing causal readings, and a caveat a call site can forget is
/// a caveat that will be forgotten.
///
/// **Both signals or neither.** The chart withholds and keeps its slot unless
/// both panes have something to draw. A "linked" chart with one live pane is a
/// different chart under a title promising a comparison the reader cannot make.
///
/// ## The step chart is buckets, and a gap in it is a gap
///
/// `V02BucketChart` draws one column per fifteen minutes; a bucket the strap did
/// not see draws nothing and a bucket measured as zero draws a mark on the
/// baseline. "You moved every hour except two" and "we only saw twenty-two
/// hours" are different days.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/today_series.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/charts/v02/v02_bucket_chart.dart';
import 'package:healthee/shared/charts/v02/v02_linked_chart.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// What the bucket chart is and is not, said under it.
const String kStepBucketNote =
    'Bars show the fifteen-minute intervals the strap recorded, not the '
    'full-day total. Energy is modelled.';

/// `Heart rate & stress` — two signals, one hour cursor, two labelled scales.
class HeartStressPanel extends StatelessWidget {
  /// [heartRate] and [stress] are the payload's hourly series.
  const HeartStressPanel({
    required this.heartRate,
    required this.stress,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Heart rate & stress';

  /// Today's heart rate, hour by hour.
  final List<HourPoint> heartRate;

  /// Today's stress, hour by hour.
  final List<HourPoint> stress;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the heart-rate metric screen.
  final VoidCallback? onDetails;

  /// Whether either signal has enough to draw. Two hours is not a day, and a
  /// panel whose only content is an empty slot is a heading over nothing.
  static bool hasSomethingToDraw(
    List<HourPoint> heartRate,
    List<HourPoint> stress,
  ) => heartRate.length > 2 && stress.length > 2;

  @override
  Widget build(BuildContext context) {
    final hours = heartRate.length < stress.length
        ? heartRate.length
        : stress.length;
    return Panel(
      tone: Tone.heart,
      head: PanelHead(
        title: title,
        icon: Icons.favorite_outline,
        infoKey: 'stress',
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: RevealOnce(
        id: 'today.heart-stress',
        registry: reveals,
        builder: (context, t) => V02LinkedChart(
          <LinkedPane>[
            LinkedPane(
              tone: Tone.heart,
              label: 'Heart rate',
              unit: 'bpm',
              values: <double?>[
                for (var i = 0; i < hours; i++) heartRate[i].average,
              ],
            ),
            LinkedPane(
              tone: Tone.stress,
              label: 'Stress',
              values: <double?>[
                for (var i = 0; i < hours; i++) stress[i].average,
              ],
            ),
          ],
          progress: t,
          captions: hours < 2
              ? const <String>[]
              : <String>[
                  shortClock(heartRate.first.hour),
                  shortClock(heartRate[hours - 1].hour),
                ],
          sampleLabels: <String>[
            for (var i = 0; i < hours; i++) shortClock(heartRate[i].hour),
          ],
          semanticLabel: 'Heart rate and stress through today, by hour',
        ),
      ),
    );
  }
}

/// `Steps & energy` — the day's shape, and what it cost.
class StepsEnergyPanel extends StatelessWidget {
  /// [facts] is the screen's one parse of the payload.
  const StepsEnergyPanel({
    required this.facts,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Steps & energy';

  /// The gap above the statistics row.
  static const double statsGap = 12;

  /// The figures and series this render is built from.
  final TodayFacts facts;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the activity screen.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final steps = facts.steps.valueOrNull;
    final buckets = facts.stepStrip;
    return Panel(
      tone: Tone.movement,
      label: 'Steps',
      head: PanelHead(
        title: title,
        icon: Icons.directions_walk,
        infoKey: 'steps_total',
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            steps == null ? '—' : commaGrouped(steps.round()),
            unit: 'steps',
            context_: steps == null
                ? _refusal(facts.steps)
                : 'Daily total\n${facts.medianFootFor(TodayMetricIds.steps)}',
          ),
          RevealOnce(
            id: 'today.step-buckets',
            registry: reveals,
            builder: (context, t) => V02BucketChart(
              <double?>[...buckets],
              progress: t,
              captions: _captions(facts.snapshot.stepBuckets),
              semanticLabel: "Today's steps, fifteen minutes to a bar",
            ),
          ),
          if (_energy() case final List<Stat> stats) ...<Widget>[
            const SizedBox(height: statsGap),
            StatRow(stats),
          ],
          const PanelNote(kStepBucketNote),
        ],
      ),
    );
  }

  /// The server's own reason, beside the dash, when it refused the count.
  ///
  /// An [Excluded] reading has no single sentence to put on one line, so it
  /// falls through to null and the panel shows a dash with no explanation
  /// **only** in a state the payload does not produce for this metric — the
  /// exclusion list is a recommendations concept. If it ever did, the dash would
  /// be honest and silent rather than wrong.
  static String? _refusal(Reading<double> steps) =>
      steps is Withheld<double> ? steps.disclosure.message : null;

  /// The first and last interval the strap actually recorded — never a fixed
  /// `06:00 → 17:15`, which would describe hours the bars above do not cover.
  static List<String> _captions(List<StepBucket> buckets) {
    if (buckets.length < 2) {
      return const <String>[];
    }
    final first = buckets.first.time;
    final last = buckets.last.time;
    return first == null || last == null
        ? const <String>[]
        : <String>[first, last];
  }

  /// Active, resting and total — only the ones the payload carried.
  List<Stat> _energy() {
    final active = facts.activeEnergy.valueOrNull;
    return <Stat>[
      if (active != null)
        Stat('Active', commaGrouped(active.round()), unit: 'kcal'),
      if (facts.basalEnergy case final double basal)
        Stat('Resting', commaGrouped(basal.round()), unit: 'kcal'),
      if (facts.totalEnergy case final double total)
        Stat('Total', commaGrouped(total.round()), unit: 'kcal'),
    ];
  }
}
