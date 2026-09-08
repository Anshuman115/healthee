import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/fetch/activity_fetcher.dart';
import 'package:healthee/ble/fetch/fetch_exception.dart';

/// Scripted notification loss, independent of the production packet collector.
ActivityFetcher peer({required bool alwaysDrop, required List<int> asks}) {
  late ActivityFetcher fetcher;
  var rounds = 0;
  fetcher = ActivityFetcher((command) async {
    if (command.first == 1) {
      asks.add(command[7]); // minute in the requested Huami time
      rounds++;
      scheduleMicrotask(
        () => fetcher.onControl(
          Uint8List.fromList([
            0x10,
            1,
            1,
            rounds > 2 && !alwaysDrop ? 0 : 3,
            0,
            0,
            0,
            0xea,
            0x07,
            8,
            1,
            0,
            0,
            0,
          ]),
        ),
      );
    } else if (command.first == 2) {
      scheduleMicrotask(() {
        fetcher.onData(Uint8List.fromList([0, 40]));
        if (!alwaysDrop && rounds > 1) {
          fetcher.onData(Uint8List.fromList([1, 60]));
        }
        fetcher.onData(Uint8List.fromList([2, 80]));
        fetcher.onControl(Uint8List.fromList([0x10, 2, 1]));
      });
    }
  });
  return fetcher;
}

void main() {
  test(
    'a missing packet retries the same cursor without shifting timestamps',
    () async {
      final asks = <int>[];
      final fetcher = peer(alwaysDrop: false, asks: asks);
      final start = DateTime(2026, 8, 1);
      final samples = await fetcher.fetchType(0x13, start, maxRounds: 5);
      expect(asks.take(2), [0, 0]);
      expect(samples.map((s) => s.value), [40, 60, 80]);
      expect(samples.last.date, start.add(const Duration(minutes: 2)));
      expect(fetcher.lastRaw, [40, 60, 80]);
    },
  );

  test(
    'repeated packet loss fails without retaining corrupted bytes',
    () async {
      final asks = <int>[];
      final fetcher = peer(alwaysDrop: true, asks: asks);
      await expectLater(
        fetcher.fetchType(0x13, DateTime(2026, 8, 1)),
        throwsA(
          isA<FetchException>()
              .having((e) => e.samples, 'samples', isEmpty)
              .having((e) => e.raw, 'raw', isEmpty),
        ),
      );
      expect(asks, [0, 0, 0]);
    },
  );
}
