/// [HScatter] — the cloud drawn from a finding's own paired days.
///
/// The finding-detail screen printed the prototype's sentence here — *"A scatter
/// plot appears here when those values are available"* — because
/// `read/findings.py` sent summary statistics only. It sends the pairs now
/// (`docs/BACKEND_GAPS_FROM_UI.md` B1), so these assert the two things a chart of
/// health data must be: drawn from the payload and from nothing else, and absent
/// when the payload cannot support one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/shared/charts/h_scatter.dart';

List<FindingPoint> _points(int count) => <FindingPoint>[
  for (var i = 0; i < count; i++)
    FindingPoint(
      date: '2026-07-${(i + 1).toString().padLeft(2, '0')}',
      a: 40 + i.toDouble(),
      b: 80 - i.toDouble(),
    ),
];

Widget _host(Widget chart) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: chart)),
  ),
);

void main() {
  group('what it will and will not draw', () {
    testWidgets('a cloud of the payload\'s own pairs', (tester) async {
      await tester.pumpWidget(
        _host(HScatter(_points(24), color: Colors.teal, progress: 1)),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('NOTHING at all below the plottable floor', (tester) async {
      // Two points make a perfect line whatever the data is — a picture of
      // arithmetic rather than of the owner. The caller says so in words
      // instead; drawing a shape here would be the invention.
      await tester.pumpWidget(
        _host(
          HScatter(
            _points(Finding.minPlottablePoints - 1),
            color: Colors.teal,
            progress: 1,
          ),
        ),
      );
      final box = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(HScatter),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.child, isNull);
    });
  });

  group('the model gate the caller reads', () {
    test('isPlottable is the same question everywhere', () {
      const bare = Finding(
        kind: 'pairwise_lag',
        metricA: 'caffeine',
        metricB: 'sleep_health_score_4dim',
        eventKind: null,
        description: '',
        effectSize: -0.42,
        effectMetric: 'rho',
        qValue: 0.03,
        nSamples: 24,
        lagDays: 0,
        researchNoteIds: <String>[],
      );
      expect(bare.isPlottable, isFalse, reason: 'no points on the wire');
      expect(bare.points, isEmpty);
    });

    test('a pair with one half missing is DROPPED, never zeroed', () {
      // A zero would put a dot on the axis that no day produced, which is the
      // one thing a chart of health data must not invent.
      expect(
        FindingPoint.maybe(const <String, Object?>{
          'date': '2026-07-01',
          'a': 4,
        }),
        isNull,
      );
      expect(
        FindingPoint.maybe(const <String, Object?>{
          'date': '2026-07-01',
          'a': 4,
          'b': 9,
        })?.b,
        9,
      );
    });
  });
}
