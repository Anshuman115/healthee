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

  // The arrow between two correlated metrics. It must stay DOUBLE-headed: a
  // correlation has no direction, and every single-headed replacement claims
  // one. Whether the bundled face can actually DRAW it is a separate question,
  // guarded by the derived coverage check in `test/core/typography_test.dart`.
  // Splitting the two is the point: the first version of this test asserted a
  // U+FE0E selector and passed while the character still rendered as a colour
  // emoji on the phone, because a codepoint assertion cannot see a font.
  test('THE PAIR ARROW IS DOUBLE-HEADED, AND CARRIES NOTHING ELSE', () {
    expect(kPairArrow.runes.toList(), <int>[0x2194]);
  });
}
