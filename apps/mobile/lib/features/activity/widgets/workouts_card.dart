/// Sessions the strap recorded today, with the device's own figures.
///
/// **No identity tag.** A session is not a metric: each row carries a duration,
/// two heart rates and the strap's calorie count, which is three families at
/// once. `instrument_hues.dart` gives a tag to a card about ONE metric, and this is
/// the same reason the daily action and the data-health strip do not have one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_workout.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Today's recorded sessions, or an honest empty state.
class WorkoutsCard extends StatelessWidget {
  /// [workouts] is newest first; an empty list renders [EmptyState].
  const WorkoutsCard({required this.workouts, super.key});

  /// The sessions the strap recorded on this day.
  final List<DeviceWorkout> workouts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (workouts.isEmpty) {
      // Empty, not withheld. Nothing is missing here — the strap recorded no
      // session, and that is an answer rather than a gap (Standards §3: every
      // async consumer renders an empty state, and it says how to change it).
      return const EmptyState(
        message: 'No recorded sessions today',
        hint: 'Start a workout on the strap and it appears here after a sync.',
      );
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recorded sessions', style: text.labelSmall),
          for (final workout in workouts) ...[
            Divider(color: colors.line2, height: Insets.lg, thickness: hairline),
            _WorkoutRow(workout: workout),
          ],
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout});

  final DeviceWorkout workout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workout.sportLabel, style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              Text(
                _detail(workout),
                style: text.bodySmall?.copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        Text(
          durationLabel(workout.duration.inMinutes),
          style: text.headlineSmall,
        ),
      ],
    );
  }

  /// Start time, heart rates, and the strap's calorie figure — named as such.
  static String _detail(DeviceWorkout workout) {
    final parts = <String>[clockLabel(workout.start)];
    if (workout.avgHr > 0) {
      parts.add('${workout.avgHr} bpm avg · ${workout.maxHr} peak');
    }
    if (workout.calories > 0) {
      parts.add("${workout.calories} kcal by the strap's count");
    }
    return parts.join(' · ');
  }
}
