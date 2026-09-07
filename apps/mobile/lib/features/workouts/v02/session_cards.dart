/// The workout screen's two figure cards — the opening `.three` and `.two`.
///
/// `screens-explore.js::H.screens.workout`, first and last:
///
/// ```js
/// <div class="card">
///   <div class="three">{4.2 km Distance}{30 min Duration}{7:09 /km Avg. pace}</div>
///   H.source('Helio Strap · recorded workout')
/// </div>
/// …
/// H.section('Session details',
///   `<div class="card"><div class="two">
///      {250 kcal Estimated energy}{36.9 TRIMP load}
///      {8.4 km/h Average speed}{10 bpm Heart-rate drift}
///    </div></div>`)
/// ```
///
/// `.card` is 20 px of padding, so the statistics are `.stat`'s **base** sizes —
/// [StatBlock], not `.panel .three`'s [StatRow]. `stat_block.dart` and
/// `history_panel.dart` both record that distinction; this is the third site
/// that depends on it.
///
/// ## The energy figure names its instrument, because it is not ours
///
/// `CLAUDE.md` pins free-living energy to the MET-by-state model. This number is
/// **not that model**: `read/workout.py` passes the strap's own `calories`
/// column straight through, and `cal_per_min` is that same figure divided by the
/// duration. So the card says so, on its face, beside the number — a kcal
/// figure whose instrument is unnamed is the one an owner will assume came from
/// the model that the rest of the app uses.
///
/// ## HR drift is a measurement and nothing more
///
/// The pre-v02 card carried *"HR drift alone does not establish fatigue or
/// dehydration"* and it is kept, on the card, unchanged. That is a
/// qualification of the number beside it rather than method detail, which is the
/// line `metric_detail.dart` draws for what may move to the ⓘ and what may not.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/workouts/workout_readings.dart';
import 'package:healthee/features/workouts/v02/refused_figures.dart';
import 'package:healthee/shared/format/workout_labels.dart';
import 'package:healthee/shared/v02/labels.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/stat_block.dart';
import 'package:healthee/shared/v02/surfaces.dart';

/// `.three { gap: var(--space-sm) }`.
const double kThreeGap = 8;

/// `.two { gap: var(--space-md) }`.
const double kTwoGap = 12;

/// `H.source('Helio Strap · recorded workout')`.
const String kWorkoutSource = 'Helio Strap · recorded workout';

/// What the energy figure actually is, said where the figure is.
const String kEnergyInstrument =
    "The energy figure is the strap's own count for this session. It is not "
    "the app's MET-by-state model, and the two are not interchangeable.";

/// What a second-half heart-rate change is, and is not.
const String kDriftCaveat =
    'Heart-rate drift is the second half of the session against the first. On '
    'its own it does not establish fatigue or dehydration.';

/// The opening card: distance, duration, pace, and where they came from.
class SessionSummaryCard extends StatelessWidget {
  /// Renders [readings].
  const SessionSummaryCard({required this.readings, super.key});

  /// The session, with its absences.
  final WorkoutReadings readings;

  @override
  Widget build(BuildContext context) {
    final cells = <RefusedFigure>[
      RefusedFigure('Distance', readings.distanceKm),
      RefusedFigure('Duration', readings.durationMin),
      RefusedFigure('Avg. pace', readings.pace),
    ];
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: StatBlock(
                  label: 'Distance',
                  value: readings.distanceKm.valueOrNull?.toStringAsFixed(1),
                  unit: 'km',
                ),
              ),
              const SizedBox(width: kThreeGap),
              Expanded(
                child: StatBlock(
                  label: 'Duration',
                  value: readings.durationMin.valueOrNull?.toString(),
                  unit: 'min',
                ),
              ),
              const SizedBox(width: kThreeGap),
              Expanded(
                child: StatBlock(
                  label: 'Avg. pace',
                  value: paceLabel(readings.pace.valueOrNull),
                  unit: '/km',
                ),
              ),
            ],
          ),
          RefusedFigures(cells),
          const SourceNote(kWorkoutSource),
        ],
      ),
    );
  }
}

/// `Session details` — the four derived figures, two across.
class SessionDetailsCard extends StatelessWidget {
  /// Renders [readings].
  const SessionDetailsCard({required this.readings, super.key});

  /// The prototype's section title.
  static const String title = 'Session details';

  /// The session, with its absences.
  final WorkoutReadings readings;

  @override
  Widget build(BuildContext context) {
    final energy = readings.calories;
    final drift = readings.hrDrift;
    final cells = <RefusedFigure>[
      RefusedFigure('Estimated energy', energy),
      RefusedFigure('TRIMP load', readings.trimp),
      RefusedFigure('Average speed', readings.speed),
      RefusedFigure('Heart-rate drift', drift),
    ];
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _row(
            StatBlock(
              label: 'Estimated energy',
              value: energy.valueOrNull?.toString(),
              unit: 'kcal',
            ),
            StatBlock(
              label: 'TRIMP load',
              value: readings.trimp.valueOrNull?.toStringAsFixed(1),
            ),
          ),
          const SizedBox(height: kTwoGap),
          _row(
            StatBlock(
              label: 'Average speed',
              value: readings.speed.valueOrNull?.toStringAsFixed(1),
              unit: 'km/h',
            ),
            StatBlock(
              label: 'Heart-rate drift',
              value: driftLabel(drift.valueOrNull),
              unit: 'bpm',
            ),
          ),
          RefusedFigures(cells),
          // Both sentences qualify a number ON this card, so both stay on it.
          if (energy.hasValue) const PanelNote(kEnergyInstrument),
          if (drift.hasValue) const PanelNote(kDriftCaveat),
        ],
      ),
    );
  }

  /// One row of `.two`, with each cell taking half the width.
  Widget _row(Widget left, Widget right) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(child: left),
      const SizedBox(width: kTwoGap),
      Expanded(child: right),
    ],
  );
}
