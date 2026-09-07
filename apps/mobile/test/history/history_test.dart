/// `/api/history`'s parse rules — the layer that decides what a day *is*.
///
/// The screen these observations are drawn on is v02's now and has its own
/// suites (`history_screen_test.dart`, `history_window_test.dart`). What stayed
/// here is the half a redesign must never touch: a mismatched metric, an
/// impossible date and an out-of-order series are all refused, and a real zero
/// is kept apart from a missing day.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';

void main() {
  test('preserves missing days and actual zero observations', () {
    final result = parseHistory({
      'metric': 'steps_total',
      'series': [
        {'day': '2026-01-01', 'value': 0},
        {'day': '2026-01-03', 'value': 5000},
      ],
    }, HistoryMetric.steps);
    expect(result.length, 2);
    expect(result.first.value, 0);
    expect(result.last.date, '2026-01-03');
  });

  test('rejects malformed, unordered and mismatched series', () {
    expect(
      () => parseHistory({
        'metric': 'rhr_daily',
        'series': [],
      }, HistoryMetric.hrv),
      throwsFormatException,
    );
    for (final day in ['not-a-day', '2026-02-31', '2026-01-01T00:00:00']) {
      expect(
        () => parseHistory({
          'metric': 'rhr_daily',
          'series': [
            {'day': day, 'value': 60},
          ],
        }, HistoryMetric.restingHr),
        throwsFormatException,
      );
    }
    expect(
      () => parseHistory({
        'metric': 'rhr_daily',
        'series': [
          {'day': '2026-01-02', 'value': 60},
          {'day': '2026-01-01', 'value': 61},
        ],
      }, HistoryMetric.restingHr),
      throwsFormatException,
    );
  });
}
