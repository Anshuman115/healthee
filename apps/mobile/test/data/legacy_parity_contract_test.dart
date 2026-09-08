import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';
import 'package:healthee/data/journal/journal_feed.dart';

Map<String, Object?> _snapshot(String name) =>
    jsonDecode(
          File(
            '../../packages/contracts/snapshots/$name.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

void main() {
  test(
    'journal consumes the seeded server contract without guessed values',
    () {
      final feed = JournalFeed.fromJson(_snapshot('log_recent'));
      expect(feed.entries.first.type, 'weight');
      expect(feed.entries.first.amount, 72.5);
      expect(feed.entries.first.unit, 'kg');
      expect(feed.fastOpen, isTrue);
      expect(feed.fastMinutes, 300);
    },
  );

  test('history consumes the seeded server daily-series contract', () {
    final points = parseHistory(_snapshot('history'), HistoryMetric.steps);
    expect(points, isNotEmpty);
    expect(points.first.date, '2026-07-02');
    expect(points.first.value, 8200);
  });
}
