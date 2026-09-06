import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'history_repository.g.dart';

/// Bounded, account-bound daily observations. Missing days are never padded.
@riverpod
Future<List<TrendPoint>> metricHistory(
  Ref ref,
  HistoryMetric metric,
  int days,
) async {
  final dio = ref.watch(apiClientProvider);
  final session = await CacheSession.capture(ref.watch(credentialsProvider));
  final response = await dio.get<Map<String, Object?>>(
    '/api/history',
    queryParameters: {'metric': metric.id, 'days': days},
    options: session.options(),
  );
  await session.ensureCurrent();
  return parseHistory(response.data!, metric);
}

/// Reject a mismatched or malformed response instead of drawing another metric.
List<TrendPoint> parseHistory(Map<String, Object?> json, HistoryMetric metric) {
  if (json['metric'] != metric.id) {
    throw const FormatException('Unexpected history metric');
  }
  final points = <TrendPoint>[];
  for (final item in json['series']! as List<Object?>) {
    final row = item! as Map<String, Object?>;
    final day = row['day']! as String;
    final value = (row['value']! as num).toDouble();
    final date = DateTime.tryParse(day);
    if (!value.isFinite ||
        date == null ||
        date.toIso8601String().substring(0, 10) != day) {
      throw const FormatException('Invalid history observation');
    }
    if (points.isNotEmpty && points.last.date.compareTo(day) >= 0) {
      throw const FormatException('History dates must increase');
    }
    points.add(TrendPoint(date: day, value: value));
  }
  return points;
}
