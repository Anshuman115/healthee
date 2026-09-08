import 'package:healthee/data/api/account_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'history_marker.g.dart';

class HistoryMarker {
  const HistoryMarker({
    required this.day,
    required this.kind,
    required this.count,
  });
  factory HistoryMarker.fromJson(Map<String, Object?> data) => HistoryMarker(
    day: data['day']! as String,
    kind: data['kind']! as String,
    count: (data['count']! as num).toInt(),
  );
  final String day;
  final String kind;
  final int count;
}

@riverpod
Future<List<HistoryMarker>> historyMarkers(Ref ref, int days) async {
  final api = await ref.watch(accountApiProvider.future);
  final data = await api.get('/api/history/logs', query: {'days': days});
  return [
    for (final row in data['markers']! as List<Object?>)
      HistoryMarker.fromJson(row! as Map<String, Object?>),
  ];
}
