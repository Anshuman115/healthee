import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/history/dated_history.dart';
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
///
/// The echo check is this form's own — the single-metric endpoint names what it
/// answered for, and a response about a different metric under this metric's
/// heading is a wrong chart rather than a missing one. The points themselves go
/// through `parseSeries`, which the batched read uses too: two parsers over one
/// wire format is two chances for one of them to accept a day the other refuses.
List<TrendPoint> parseHistory(Map<String, Object?> json, HistoryMetric metric) {
  if (json['metric'] != metric.id) {
    throw const FormatException('Unexpected history metric');
  }
  return parseSeries(json['series'], metric.id);
}
