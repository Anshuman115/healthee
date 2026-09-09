/// The two panels that close the fitness screen: the work, and the rhythm.
///
/// `design/mobile-preview/screens-fitness.js::H.screens.fitness`:
///
/// ```js
/// H.panel('The work behind your capacity','heart',
///         value('55','TRIMP','7-day average 55<br>28-day average 55')
///         + load bars + note,'activity','heart')
/// H.panel('A rhythm to build on','movement',
///         three stats + note + link('Your movement program','program'),'program','flag')
/// ```
///
/// ## Same number, different framing — and deliberately not a second definition
///
/// `CardioLoad` is the Activity tab's block and this panel draws the same figure
/// off the same field. What changes is the question the panel is answering:
/// Activity asks *how hard was today*, and the fitness screen asks *what work is
/// behind this capacity*. The prototype gives the two panels different titles
/// and different notes for exactly that reason; neither computes a load of its
/// own, which is the part CLAUDE.md's one-definition rule is about.
///
/// **The prototype's `7-day average / 28-day average` pair is not on the wire.**
/// `cardio_load` carries today's `load` and `baseline_30d` and nothing that
/// averages a second window, so the context line names the two terms it has —
/// the same substitution `training_panels.dart` recorded when it was first made.
///
/// ## The rhythm panel has no link, because the destination needs an id
///
/// `H.link('Your movement program','program')` opens `#program`. The app's
/// program screen is `/program/:id` and `/api/today` carries no programme id, so
/// there is nothing to open. `entry_card.dart`: *"an entry point that leads
/// nowhere is worse than an absent entry point"* — so the three figures are
/// drawn and the control is not.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/strength.dart';
import 'package:healthee/features/activity/v02/movement_panels.dart';
import 'package:healthee/features/activity/v02/training_panels.dart';
import 'package:healthee/shared/charts/v02/v02_bar_chart.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's line under the load bars, minus the sample's own ratio.
const String kWorkNote =
    'It describes recent effort, not your fitness level.';

/// The prototype's line under the three figures.
const String kRhythmNote =
    'These are complementary views of activity. A sustainable routine needs '
    'room for both effort and recovery.';

/// `The work behind your capacity` — the load this capacity was built on.
class WorkPanel extends StatelessWidget {
  /// [load] is the payload's `cardio_load` block.
  const WorkPanel({
    required this.load,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'The work behind your capacity';

  /// Today's training load and the fortnight behind it.
  final CardioLoad load;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the activity tab.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final trend = load.trend30d;
    return Panel(
      tone: Tone.heart,
      label: 'Strain · cardio load',
      head: PanelHead(
        title: title,
        icon: SolarIconsOutline.heart,
        infoKey: 'cardio_load',
        detail: MetricDetail(notes: load.researchNotes),
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            load.load.round().toString(),
            unit: 'TRIMP',
            context_: TrainingLoadPanel.ratioLine(load),
          ),
          if (trend.length > 1)
            RevealOnce(
              id: 'fitness.cardio-load',
              registry: reveals,
              builder: (context, t) => V02BarChart(
                <double?>[for (final point in trend) point.value],
                progress: t,
                labels: <String>[
                  for (final point in trend) dayOfMonth(point.date),
                ],
                semanticLabel: 'Training load over the recent days',
              ),
            ),
          const PanelNote(kWorkNote),
        ],
      ),
    );
  }
}

/// `A rhythm to build on` — the week's minutes, its strength, and the day's
/// steps, side by side and never summed.
class RhythmPanel extends StatelessWidget {
  /// Any of the three may be null; the panel draws what it was given.
  const RhythmPanel({this.mvpa, this.strength, this.steps, super.key});

  /// The prototype's title.
  static const String title = 'A rhythm to build on';

  /// This week's moderate-to-vigorous minutes.
  final Mvpa? mvpa;

  /// This week's strength minutes.
  final Strength? strength;

  /// Today's step count.
  final double? steps;

  /// Whether there is anything at all to draw.
  bool get hasSomething =>
      mvpa != null || strength != null || steps != null;

  @override
  Widget build(BuildContext context) => Panel(
    tone: Tone.movement,
    label: 'Weekly rhythm',
    head: const PanelHead(title: title, icon: SolarIconsOutline.flag),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        StatRow(<Stat>[
          if (mvpa case final Mvpa week)
            Stat('Weekly activity', '${week.weekMin}', unit: 'min'),
          if (strength case final Strength lifted)
            Stat('Strength', '${lifted.weekMin}', unit: 'min'),
          if (steps case final double today)
            Stat('Daily steps', groupedInt(today.round())),
        ]),
        const PanelNote(kRhythmNote),
      ],
    ),
  );
}
