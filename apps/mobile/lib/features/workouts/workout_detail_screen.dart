import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/workouts/workout_detail.dart';
import 'package:healthee/data/workouts/workout_repository.dart';
import 'package:healthee/features/workouts/workout_detail_sections.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({required this.start, super.key});
  final String start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = workoutDetailProvider(start);
    return Scaffold(
      appBar: AppBar(title: const Text('Workout detail')),
      body: AsyncView<WorkoutDetail>(
        value: currentAccountValue(ref.watch(provider)),
        onRetry: () => ref.invalidate(provider),
        builder: (context, detail) {
          final sections = workoutDetailSections(context, detail);
          return ListView.separated(
            padding: const EdgeInsets.all(Insets.lg),
            itemCount: sections.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: Insets.lg),
            itemBuilder: (context, index) => sections[index],
          );
        },
      ),
    );
  }
}
