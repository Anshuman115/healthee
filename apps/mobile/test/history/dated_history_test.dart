/// The batched read's parse — the boundary the dated panels all sit behind.
///
/// One malformed point reaching a chart is a line drawn through a reading
/// nobody took, so this layer throws rather than skipping. What is asserted
/// here is that it throws on each of the four ways a payload can be wrong, and
/// that it keeps the one distinction the UI turns on: a metric the server
/// answered with nothing is not the same as a metric nobody asked about.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/history/dated_history.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';

Map<String, Object?> _payload(Map<String, Object?> series, {Object? days = 90}) =>
    <String, Object?>{'days': days, 'series': series};

const List<Object?> _twoDays = <Object?>[
  <String, Object?>{'day': '2026-03-07', 'value': 40},
  <String, Object?>{'day': '2026-03-09', 'value': 42},
];

void main() {
  group('the batched payload', () {
    test('every metric asked for is a key, empty answers included', () {
      final history = parseDatedHistory(
        _payload(<String, Object?>{
          'rhr_daily': _twoDays,
          'vo2max_estimate': const <Object?>[],
        }),
      );
      expect(history.days, 90);
      expect(history['rhr_daily'].length, 2);
      expect(history['vo2max_estimate'], isEmpty);
    });

    test('"NO READINGS" AND "NOT ASKED ABOUT" ARE NOT THE SAME ANSWER', () {
      // Both read as an empty list, and only one of them means the owner has no
      // data. A panel that could not tell them apart would print "no readings"
      // for a metric the request never mentioned.
      final history = parseDatedHistory(
        _payload(<String, Object?>{'rhr_daily': const <Object?>[]}),
      );
      expect(history.covers('rhr_daily'), isTrue);
      expect(history['rhr_daily'], isEmpty);
      expect(history.covers('steps_total'), isFalse);
      expect(history['steps_total'], isEmpty);
    });

    test('A MISSING DAY IS ABSENT, NOT PADDED OR CARRIED FORWARD', () {
      // 8 March is simply not in the answer. Nothing here invents it; the
      // calendar is put back by `HistoryWindow`, with a hole.
      final points = parseDatedHistory(
        _payload(<String, Object?>{'rhr_daily': _twoDays}),
      )['rhr_daily'];
      expect(points.map((p) => p.date), <String>['2026-03-07', '2026-03-09']);
    });

    test('a window that is not a positive day count is refused', () {
      expect(
        () => parseDatedHistory(_payload(const <String, Object?>{}, days: 0)),
        throwsFormatException,
      );
      expect(
        () => parseDatedHistory(_payload(const <String, Object?>{}, days: 'lots')),
        throwsFormatException,
      );
    });

    test('a body that is not keyed by metric is refused', () {
      expect(
        () => parseDatedHistory(<String, Object?>{'days': 90, 'series': <Object?>[]}),
        throwsFormatException,
      );
    });
  });

  group('one series', () {
    test('a non-ascending series is refused rather than reordered', () {
      // Sorting it here would hide a server that answered out of order, and the
      // window builder would then disagree with the table under it.
      expect(
        () => parseSeries(const <Object?>[
          <String, Object?>{'day': '2026-03-09', 'value': 42},
          <String, Object?>{'day': '2026-03-07', 'value': 40},
        ], 'rhr_daily'),
        throwsFormatException,
      );
    });

    test('a repeated day is refused', () {
      expect(
        () => parseSeries(const <Object?>[
          <String, Object?>{'day': '2026-03-07', 'value': 40},
          <String, Object?>{'day': '2026-03-07', 'value': 41},
        ], 'rhr_daily'),
        throwsFormatException,
      );
    });

    test('a day that is not the date it claims to be is refused', () {
      expect(
        () => parseSeries(const <Object?>[
          <String, Object?>{'day': '2026-02-30', 'value': 40},
        ], 'rhr_daily'),
        throwsFormatException,
      );
    });

    test('a non-numeric or absent value is refused', () {
      expect(
        () => parseSeries(const <Object?>[
          <String, Object?>{'day': '2026-03-07', 'value': null},
        ], 'rhr_daily'),
        throwsFormatException,
      );
      expect(
        () => parseSeries(const <Object?>[
          <String, Object?>{'day': '2026-03-07'},
        ], 'rhr_daily'),
        throwsFormatException,
      );
    });

    test('the metric is named in the failure, so a log says which chart', () {
      expect(
        () => parseSeries(const <Object?>['nonsense'], 'cardio_load'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('cardio_load'),
          ),
        ),
      );
    });
  });

  group('the two forms share one parser', () {
    test('THE SINGLE-METRIC READ AND THE BATCH AGREE ON THE SAME POINTS', () {
      // One definition of a series on the client too: `parseHistory` shapes the
      // echo check and nothing else, so the metric screen and a dated panel
      // cannot accept different days.
      final single = parseHistory(<String, Object?>{
        'metric': 'rhr_daily',
        'series': _twoDays,
      }, HistoryMetric.restingHr);
      final batch = parseDatedHistory(
        _payload(<String, Object?>{'rhr_daily': _twoDays}),
      )['rhr_daily'];
      expect(single, batch);
    });

    test('a response about another metric is still refused by the single form', () {
      expect(
        () => parseHistory(<String, Object?>{
          'metric': 'steps_total',
          'series': _twoDays,
        }, HistoryMetric.restingHr),
        throwsFormatException,
      );
    });
  });
}
