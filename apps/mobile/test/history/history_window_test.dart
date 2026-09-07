/// The window a metric's chart is drawn over — the calendar, and the holes.
///
/// This is the layer the "never interpolate across a missing day" rule is
/// enforced at. `V02LineChart` splits on nulls and its own suite proves it;
/// what could still ship broken is handing it a series with the nulls already
/// squeezed out, which draws twelve evenly-spaced points for a fortnight with
/// two nights missing and joins every one of them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/history/history_window.dart';

const List<TrendPoint> _holed = <TrendPoint>[
  TrendPoint(date: '2026-03-07', value: 40),
  TrendPoint(date: '2026-03-08', value: 42),
  // 09 and 10 are missing.
  TrendPoint(date: '2026-03-11', value: 39),
];

void main() {
  group('the x axis is a calendar', () {
    test('A MISSING DAY IS A SLOT WITH NO VALUE, NEVER A SQUEEZED-OUT ONE', () {
      final window = HistoryWindow(_holed);
      expect(window.days, <String>[
        '2026-03-07',
        '2026-03-08',
        '2026-03-09',
        '2026-03-10',
        '2026-03-11',
      ]);
      expect(window.values, <double?>[40, 42, null, null, 39]);
      // The count a caption may claim is what was MEASURED, not what was drawn.
      expect(window.observed.length, 3);
    });

    test('a missing day is null and never zero', () {
      // Zero steps is a day in bed; a day the strap was not worn is not that,
      // and a chart that plots one as the other has invented a measurement.
      final window = HistoryWindow(const <TrendPoint>[
        TrendPoint(date: '2026-03-07', value: 0),
        TrendPoint(date: '2026-03-09', value: 5000),
      ]);
      expect(window.values, <double?>[0, null, 5000]);
    });

    test('one observation is one slot, never a flat pair', () {
      final window = HistoryWindow(const <TrendPoint>[
        TrendPoint(date: '2026-03-07', value: 40),
      ]);
      expect(window.values, <double?>[40]);
      expect(window.captions, <String>['7 Mar', '7 Mar']);
    });

    test('an empty series captions nothing', () {
      final window = HistoryWindow(const <TrendPoint>[]);
      expect(window.isEmpty, isTrue);
      expect(window.values, isEmpty);
      expect(window.captions, isEmpty);
    });
  });

  group('the window stops on the day the reader chose', () {
    test('a past day cuts the series there, gaps and all', () {
      final window = HistoryWindow(_holed).through('2026-03-09');
      expect(window.days, <String>['2026-03-07', '2026-03-08']);
      expect(window.values, <double?>[40, 42]);
      expect(window.on('2026-03-09'), isNull);
    });

    test('A DAY BEFORE EVERY OBSERVATION IS EMPTY, NOT THE NEAREST ONE', () {
      // The alternative is the nearest reading under the chosen date, which is
      // stale-as-current at one metric's scale.
      final window = HistoryWindow(_holed).through('2026-03-01');
      expect(window.isEmpty, isTrue);
      expect(window.on('2026-03-01'), isNull);
    });

    test('the day itself reads its own value', () {
      final window = HistoryWindow(_holed).through('2026-03-11');
      expect(window.on('2026-03-11'), 39);
      expect(window.on('2026-03-10'), isNull);
    });
  });

  test('every slot carries a label the readout can name it by', () {
    final window = HistoryWindow(_holed);
    expect(window.sampleLabels.length, window.values.length);
    expect(window.sampleLabels.first, '7 Mar');
    expect(window.sampleLabels.last, '11 Mar');
  });
}
