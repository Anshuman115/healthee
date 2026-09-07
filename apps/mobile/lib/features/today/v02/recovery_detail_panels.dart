/// The three panels the recovery screen adds under `Recovery, explained`.
///
/// `design/mobile-preview/screens-daily.js::H.screens.recovery`:
///
/// ```js
/// H.panel('Compared with your baseline','recovery', signals + note, 'metrics')
/// H.bridge('sleep','Sleep contributes 40% of the model. …','sleep','Explore your sleep')
/// H.panel('Your body overnight','oxygen', H.overnightVitals(), 'sleep','heart')
/// H.panel('Capacity changes through the day','movement',
///         two stats + load bars + note, 'activity','walk')
/// ```
///
/// ## The baseline ladder is the payload's, and a share is never assumed
///
/// The prototype hard-codes three rows at dead centre and writes *"Sleep
/// contributes 40%"* into the bridge. Both come off `recovery` here: the rows
/// are `recovery.signals[]` with their own standard scores, and the bridge names
/// a share only when the sleep factor carried a weight. A model that reweights
/// itself has to be able to say so, and a sentence that states a share the
/// payload did not send is the one number on this screen that would be ours.
///
/// ## The two capacity figures are not one number twice
///
/// `recovery` is the overnight estimate and `readiness` is what is left of it
/// after today's effort. They are drawn side by side because the panel exists to
/// say they differ; when the server sends no readiness the panel draws the
/// overnight figure alone rather than repeating it under a second label.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/v02/v02_bar_chart.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/signal_chart.dart';
import 'package:healthee/shared/v02/vitals_table.dart';

/// What a baseline IS. True on every payload, including one with no summary.
const String kBaselineNote =
    'A baseline is personal, not a population target.';

/// The prototype's own line under the capacity chart.
const String kCapacityNote =
    'Today’s recorded effort changes remaining readiness. The overnight number '
    'does not update to erase that context.';

/// `H.bridge('sleep', …)` — sleep's share of the model, and what a night holds.
const String kNightBridge =
    'The full night includes its stages, its efficiency and its overnight '
    'physiology.';

/// The same bridge with the share the payload actually sent in front of it.
String sleepShareBridge(double? weight) => weight == null
    ? kNightBridge
    : 'Sleep contributes ${_share(weight)} of the model. $kNightBridge';

String _share(double weight) =>
    '${(weight <= 1 ? weight * 100 : weight).round()}%';

/// The sleep factor's weight, or null when the model did not send one.
double? sleepWeight(RecoveryScore score) {
  for (final factor in score.factors) {
    if (factor.name.toLowerCase().contains('sleep')) {
      return factor.weight;
    }
  }
  return null;
}

/// `Compared with your baseline` — each signal against its own normal.
class BaselinePanel extends StatelessWidget {
  /// [signals] is `recovery.signals[]`, in the payload's own order.
  const BaselinePanel({required this.signals, this.onDetails, super.key});

  /// The prototype's title.
  static const String title = 'Compared with your baseline';

  /// The ladder and its summary.
  final RecoverySignals signals;

  /// Opens the metric explorer.
  final VoidCallback? onDetails;

  /// One row per signal, with its position when it has one.
  List<SignalRow> get rows => <SignalRow>[
    for (final signal in signals.signals)
      SignalRow(signal.name, reading(signal), z: signal.z),
  ];

  /// `45 ms`, or an em dash when today's reading did not arrive.
  static String reading(RecoverySignal signal) {
    final value = signal.value;
    if (value == null) {
      return '—';
    }
    final figure = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return signal.unit == null ? figure : '$figure ${signal.unit}';
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      tone: Tone.recovery,
      label: 'Recovery signals',
      head: PanelHead(
        title: title,
        icon: Icons.monitor_heart_outlined,
        infoKey: 'recovery_score',
        detail: MetricDetail(
          notes: <String>[
            for (final signal in signals.signals)
              if (signal.researchNoteId case final String id) id,
          ],
        ),
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SignalChart(rows),
          if (signals.summary case final String summary) PanelNote(summary),
          const PanelNote(kBaselineNote),
        ],
      ),
    );
  }
}

/// `Your body overnight` on the recovery screen — the same five measurements,
/// read off `/api/today` rather than off one night of `/api/sleep`.
class RecoveryVitalsPanel extends StatelessWidget {
  /// [vitals] is built by the screen; this is the frame around it.
  const RecoveryVitalsPanel({
    required this.vitals,
    required this.reveals,
    this.onDetails,
    this.onOpenMetric,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Your body overnight';

  /// The reveal-id namespace for this screen's rows.
  static const String revealPrefix = 'recovery.vital';

  /// The five rows.
  final List<Vital> vitals;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the sleep screen — the prototype's `Details`.
  final VoidCallback? onDetails;

  /// Opens one measurement's own history.
  final void Function(String metric)? onOpenMetric;

  @override
  Widget build(BuildContext context) => Panel(
    tone: Tone.oxygen,
    label: 'Overnight vitals',
    head: PanelHead(
      title: title,
      icon: Icons.favorite_border,
      infoKey: 'sleep',
      actionLabel: onDetails == null ? null : 'Details',
      onAction: onDetails,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        VitalsTable(
          vitals: vitals,
          reveals: reveals,
          revealPrefix: revealPrefix,
          onOpenMetric: onOpenMetric,
        ),
        if (VitalsTable.refusals(vitals) case final List<String> lines
            when lines.isNotEmpty)
          PanelNote(lines.join('\n')),
      ],
    ),
  );
}

/// `Capacity changes through the day` — the overnight estimate, what is left of
/// it, and the effort that spent the difference.
class CapacityPanel extends StatelessWidget {
  /// [load] of null draws the two figures and no chart.
  const CapacityPanel({
    required this.score,
    required this.reveals,
    this.load,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Capacity changes through the day';

  /// The gap above the chart.
  static const double chartGap = 12;

  /// The model's output, and what remains of it.
  final RecoveryScore score;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// The fortnight of effort behind the change.
  final CardioLoad? load;

  /// Opens the activity tab.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final trend = load?.trend30d ?? const <TrendPoint>[];
    return Panel(
      tone: Tone.movement,
      label: 'Recovery · remaining readiness',
      head: PanelHead(
        title: title,
        icon: Icons.directions_walk,
        infoKey: 'recovery_score',
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatRow(<Stat>[
            Stat('Overnight recovery', '${score.recovery}', unit: '/100'),
            if (score.readiness case final int readiness)
              Stat('Remaining readiness', '$readiness', unit: '/100'),
          ]),
          if (trend.length > 1) ...<Widget>[
            const SizedBox(height: chartGap),
            RevealOnce(
              id: 'recovery.capacity-load',
              registry: reveals,
              builder: (context, t) => V02BarChart(
                <double?>[for (final point in trend) point.value],
                progress: t,
                labels: <String>[
                  for (final point in trend) _dayOfMonth(point.date),
                ],
                semanticLabel: 'Training load over the recent days',
              ),
            ),
          ],
          const PanelNote(kCapacityNote),
        ],
      ),
    );
  }

  /// `2026-07-31` → `31`. A bar label, not a date.
  static String _dayOfMonth(String date) =>
      date.length >= 10 ? date.substring(8, 10) : date;
}
