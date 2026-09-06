import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/workouts/workout_repository.dart';
import 'package:healthee/data/workouts/workout_summary.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Recorded workouts')),
    body: AsyncView<List<WorkoutSummary>>(
      value: currentAccountValue(ref.watch(workoutHistoryProvider)),
      onRetry: () => ref.invalidate(workoutHistoryProvider),
      builder: (context, workouts) => workouts.isEmpty
          ? const EmptyState(
              message: 'No uploaded workouts yet',
              hint:
                  'Sync your strap. This history shows up to 100 recorded sessions of at least 10 minutes.',
            )
          : ListView.builder(
              itemCount: workouts.length + 1,
              itemBuilder: (context, index) => index == 0
                  ? const ListTile(
                      subtitle: Text(
                        'Latest 100 uploaded sessions · at least 10 minutes',
                      ),
                    )
                  : _row(context, workouts[index - 1]),
            ),
    ),
  );

  Widget _row(BuildContext context, WorkoutSummary workout) => ListTile(
    title: Text(workout.sportName),
    subtitle: Text('${workout.start.toLocal()}'),
    trailing: Text(
      workout.durationMin == null
          ? 'Duration unavailable'
          : durationLabel(workout.durationMin!),
    ),
    onTap: () => unawaited(
      context.push(
        Uri(
          path: Routes.workout,
          queryParameters: {'start': workout.start.toIso8601String()},
        ).toString(),
      ),
    ),
  );
}
