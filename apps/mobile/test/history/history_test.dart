import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/history/history_marker.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/history/history_screen.dart';

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

  testWidgets('period selection loads new data and renders dated values', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyMarkersProvider(90).overrideWith((ref) async => []),
          historyMarkersProvider(30).overrideWith((ref) async => []),
          metricHistoryProvider(HistoryMetric.hrv, 90).overrideWith(
            (ref) async => [const TrendPoint(date: '2026-01-01', value: 42)],
          ),
          metricHistoryProvider(
            HistoryMetric.hrv,
            30,
          ).overrideWith((ref) async => []),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42.0 ms'), findsOneWidget);
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(find.text('42.0 ms'), findsNothing);
    expect(find.text('No observations in this period'), findsOneWidget);
  });
}
