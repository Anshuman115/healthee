import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/workouts/workout_detail.dart';
import 'package:healthee/data/workouts/workout_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_repository.g.dart';

@riverpod
Future<List<WorkoutSummary>> workoutHistory(Ref ref) async {
  final api = await ref.watch(accountApiProvider.future);
  final data = await api.get('/api/activity');
  return [
    for (final item in data['workouts']! as List<Object?>)
      WorkoutSummary.fromJson(item! as Map<String, Object?>),
  ];
}

@riverpod
Future<WorkoutDetail> workoutDetail(Ref ref, String start) async {
  final api = await ref.watch(accountApiProvider.future);
  return WorkoutDetail.fromJson(
    await api.get('/api/activity/workout', query: {'start': start}),
  );
}
