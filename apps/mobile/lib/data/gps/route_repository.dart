import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/gps/recorded_route.dart';
import 'package:healthee/data/gps/route_summary.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'route_repository.g.dart';

@riverpod
Future<List<RouteSummary>> recordedRoutes(Ref ref) async {
  final api = await ref.watch(accountApiProvider.future);
  final data = await api.get('/api/workout/gps', query: {'limit': 100});
  return [
    for (final row in data['tracks']! as List<Object?>)
      RouteSummary.fromJson(row! as Map<String, Object?>),
  ];
}

@riverpod
Future<RecordedRoute> recordedRoute(Ref ref, String id) async {
  final api = await ref.watch(accountApiProvider.future);
  return RecordedRoute.fromJson(
    await api.get('/api/workout/gps/${Uri.encodeComponent(id)}'),
  );
}
