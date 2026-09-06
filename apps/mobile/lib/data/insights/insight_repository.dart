import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/insights/generated_insight.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'insight_repository.g.dart';

/// The target is a metric id or a workout start instant for those two scopes.
@riverpod
Future<GeneratedInsight> generatedInsight(
  Ref ref,
  String scope,
  String target,
) async {
  final api = await ref.watch(accountApiProvider.future);
  final path = switch (scope) {
    'sleep' => '/api/sleep/insight',
    'activity' => '/api/activity/insight',
    'metric' => '/api/metric/insight',
    'workout' => '/api/activity/workout/insight',
    _ => throw ArgumentError.value(scope, 'scope'),
  };
  final data = await api.get(
    path,
    query: {
      if (scope == 'metric') 'metric': target,
      if (scope == 'workout') 'start': target,
    },
  );
  return GeneratedInsight.fromJson(data);
}
