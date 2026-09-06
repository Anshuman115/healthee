import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recommendation_history.g.dart';

class DatedRecommendation {
  const DatedRecommendation(this.day, this.recommendation);
  final String day;
  final Recommendation recommendation;
}

@riverpod
Future<List<DatedRecommendation>> recommendationHistory(
  Ref ref,
  int days,
  int page,
) async {
  final api = await ref.watch(accountApiProvider.future);
  final data = await api.get(
    '/api/recommendations',
    query: {'days': days, 'offset': page * 100},
  );
  return [
    for (final row in data['recommendations']! as List<Object?>)
      _parse(row! as Map<String, Object?>),
  ];
}

DatedRecommendation _parse(Map<String, Object?> row) =>
    DatedRecommendation(row['date']! as String, Recommendation.fromJson(row));

Future<void> setRecommendationAdoption(
  AccountApi api,
  int id,
  String action,
) async {
  if (!const ['adopt', 'dismiss'].contains(action)) {
    throw ArgumentError.value(action);
  }
  final result = await api.request(
    '/api/recommendations/$id/$action',
    method: 'POST',
  );
  if (result['ok'] != true) {
    throw const FormatException('Action was not acknowledged.');
  }
}
