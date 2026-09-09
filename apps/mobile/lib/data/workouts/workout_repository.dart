/// `/api/activity`, and the two things this app reads off it.
///
/// **One request, two providers.** `workoutHistory` used to fetch the endpoint
/// and discard everything but `workouts` — including `fitness_plan`, which the
/// server builds on every call and which nothing in the app had a model for.
/// Adding a second provider that fetched the same URL again would have put a
/// duplicate 22 KB request on every Activity build, so the response is fetched
/// once here and both readers derive from it.
library;

import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/models/fitness_plan.dart';
import 'package:healthee/data/workouts/workout_detail.dart';
import 'package:healthee/data/workouts/workout_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_repository.g.dart';

/// The whole `/api/activity` response, fetched once.
@riverpod
Future<Map<String, Object?>> activitySnapshot(Ref ref) async {
  final api = await ref.watch(accountApiProvider.future);
  return api.get('/api/activity');
}

@riverpod
Future<List<WorkoutSummary>> workoutHistory(Ref ref) async {
  final data = await ref.watch(activitySnapshotProvider.future);
  return [
    for (final item in data['workouts']! as List<Object?>)
      WorkoutSummary.fromJson(item! as Map<String, Object?>),
  ];
}

/// The VO₂max plan, or null when the server sent no block for it.
@riverpod
Future<FitnessPlan?> fitnessPlan(Ref ref) async {
  final data = await ref.watch(activitySnapshotProvider.future);
  return FitnessPlan.maybe(data['fitness_plan']);
}

@riverpod
Future<WorkoutDetail> workoutDetail(Ref ref, String start) async {
  final api = await ref.watch(accountApiProvider.future);
  return WorkoutDetail.fromJson(
    await api.get('/api/activity/workout', query: {'start': start}),
  );
}
