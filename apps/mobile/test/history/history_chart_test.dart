import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/history/history_chart.dart';

import '../shared/_chart_probe.dart';

void main() {
  testWidgets('missing days break lines while consecutive observations join', (
    tester,
  ) async {
    await tester.pumpWidget(
      chartHost(
        const HistoryChart(
          points: [
            TrendPoint(date: '2026-03-07', value: 40),
            TrendPoint(date: '2026-03-08', value: 42),
            TrendPoint(date: '2026-03-10', value: 39),
          ],
        ),
      ),
    );
    final calls = paintedBy(tester, find.byType(HistoryChart));
    expect(countOf(calls, #drawCircle), 3);
    expect(countOf(calls, #drawLine), 1);
  });

  testWidgets('one observation is one mark, never a flat trend', (
    tester,
  ) async {
    await tester.pumpWidget(
      chartHost(
        const HistoryChart(points: [TrendPoint(date: '2026-03-07', value: 40)]),
      ),
    );
    final calls = paintedBy(tester, find.byType(HistoryChart));
    expect(countOf(calls, #drawCircle), 1);
    expect(countOf(calls, #drawLine), 0);
  });
}
