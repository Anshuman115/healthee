import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/shared/format/metric_names.dart';

/// Every metric the app can put in a sentence has a name.
///
/// `metricName` falls back to the id, so a metric with no entry renders its
/// database name — `sleep_debt_min` reached the owner's Insights screen that way
/// and nothing failed, because a silent fallback cannot fail. This is the guard
/// that would have caught it: the fallback stays (an unknown id should still
/// render something) and this asserts the set we actually emit is covered.
void main() {
  test('EVERY HISTORY METRIC HAS A NAME — the id must never reach a sentence', () {
    final unnamed = HistoryMetric.values
        .where((m) => !hasMetricName(m.id))
        .map((m) => m.id)
        .toList();
    expect(
      unnamed,
      isEmpty,
      reason: 'these would render their database id to the owner: $unnamed',
    );
  });

  test('and no name is merely the id echoed back', () {
    for (final m in HistoryMetric.values) {
      expect(metricName(m.id), isNot(m.id), reason: '${m.id} has no real name');
    }
  });
}
