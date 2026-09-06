import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/workouts/workout_detail.dart';
import 'package:healthee/shared/charts/day_line_chart.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/insight_card.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

List<Widget> workoutDetailSections(
  BuildContext context,
  WorkoutDetail detail,
) => [
  _summary(detail),
  if (detail.heartRate.isEmpty)
    const EmptyState(
      message: 'No heart-rate samples for this session',
      hint: 'The workout summary can exist before its HR samples upload.',
    )
  else
    StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Heart rate · minute averages'),
          RepaintBoundary(
            child: DayLineChart(
              points: detail.heartRate,
              progress: 1,
              color: context.colors.accent,
            ),
          ),
          Text('${detail.heartRate.length} recorded minutes'),
        ],
      ),
    ),
  _zones(detail),
  _metrics(detail),
  InsightCard(
    scope: 'workout',
    target: detail.workout.start.toIso8601String(),
    title: 'Workout analysis',
  ),
];

Widget _summary(WorkoutDetail detail) {
  final workout = detail.workout;
  return StateCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(workout.sportName),
        Text('${workout.start.toLocal()}'),
        if (workout.durationMin != null)
          Text(durationLabel(workout.durationMin!)),
        if (workout.distanceM != null)
          Text('${(workout.distanceM! / 1000).toStringAsFixed(2)} km'),
        if (workout.avgHr != null) Text('${workout.avgHr} bpm average'),
        if (workout.maxHr != null) Text('${workout.maxHr} bpm peak'),
        if (workout.minHr != null) Text('${workout.minHr} bpm minimum'),
        if (workout.calories != null)
          Text('${workout.calories} kcal · strap estimate'),
      ],
    ),
  );
}

Widget _zones(WorkoutDetail detail) => StateCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Heart-rate zones'),
      if (detail.hrmax == null)
        const Text('An HRmax estimate is needed to assign zones.')
      else ...[
        Text('Based on server HRmax: ${detail.hrmax} bpm'),
        for (var i = 0; i < detail.zones.length; i++)
          Text('Zone ${i + 1}: ${detail.zones[i]} min'),
      ],
    ],
  ),
);

Widget _metrics(WorkoutDetail detail) => StateCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Session metrics'),
      if (detail.intensity != null) Text('Intensity: ${detail.intensity}'),
      if (detail.averagePercentHrmax != null)
        Text('Average: ${detail.averagePercentHrmax}% of HRmax'),
      if (detail.paceMinPerKm != null) Text('${detail.paceMinPerKm} min/km'),
      if (detail.speedKmh != null) Text('${detail.speedKmh} km/h'),
      if (detail.trimp != null) Text('${detail.trimp} TRIMP'),
      if (detail.maxPercentHrmax != null)
        Text('Peak: ${detail.maxPercentHrmax}% of HRmax'),
      if (detail.caloriesPerMinute != null)
        Text('${detail.caloriesPerMinute} kcal/min · strap estimate'),
      if (detail.dominantZone != null)
        Text('Most time in zone ${detail.dominantZone}'),
      if (detail.hrDriftBpm != null)
        Text('Second-half HR change: ${detail.hrDriftBpm} bpm'),
      const Text(
        'Metrics requiring missing inputs are omitted. HR drift alone does not establish fatigue or dehydration.',
      ),
    ],
  ),
);
