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

  // The arrow between two correlated metrics. U+2194 alone takes EMOJI
  // presentation on Android and rendered as a boxed colour glyph mid-sentence;
  // U+FE0E asks for the text form. The selector is invisible in an editor and
  // reads like a stray byte, so this is the note that stops it being tidied
  // away — and it asserts the arrow itself is still the prototype's, since a
  // single-headed replacement would claim a direction the statistic lacks.
  test('THE PAIR ARROW CARRIES ITS TEXT-PRESENTATION SELECTOR', () {
    expect(kPairArrow.runes.toList(), <int>[0x2194, 0xFE0E]);
  });
}
