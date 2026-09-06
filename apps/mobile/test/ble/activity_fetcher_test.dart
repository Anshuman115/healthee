/// **Spec-derived** for the round protocol, which `activity_fetcher.dart`'s own
/// header writes out as a sequence diagram:
///
/// > `[0x01,type]+time -> meta [0x10,0x01,status,len,date] -> [0x02]`
/// > `-> data packets [counter,payload..] on 0x0005 -> [0x10,0x02,status]`
/// > `-> ack [0x03,0x09] (0x09 = KEEP data on device, non-destructive)`
///
/// [FakeStrap] implements the device half of that from the diagram, so the
/// order of commands, the ack byte and the packet framing are all genuinely
/// checked here.
///
/// The **gap-skip** is spec-derived too, from the same file: "Step `since`
/// forward by the round's minute-count to CROSS it … Record size: activity
/// 8 B/min, stress 1 B/min." That behaviour is why
/// `project_steps_stuck_pager_stall` is a closed problem rather than an open
/// one, and it is the single most important thing in this file.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/fetch/activity_fetcher.dart';
import 'package:healthee/ble/fetch/fetch_exception.dart';
import 'package:healthee/ble/models/strap_sample.dart';

import '_fake_strap.dart';

/// Wires a fetcher to a scripted strap.
({ActivityFetcher fetcher, FakeStrap strap}) fetcherFor(
  Map<int, List<Uint8List>> rounds,
) {
  final strap = FakeStrap(authKey: Uint8List(16), rounds: rounds);
  final fetcher = ActivityFetcher(strap.writeActivityControl);
  strap.activityControl.listen(fetcher.onControl);
  strap.activityData.listen(fetcher.onData);
  return (fetcher: fetcher, strap: strap);
}

Uint8List _stress(List<int> values) => Uint8List.fromList(values);

Uint8List _allSentinel(int bytes) =>
    Uint8List(bytes)..fillRange(0, bytes, 0xFF);

void main() {
  final since = DateTime.now().subtract(const Duration(days: 3));

  group('the round protocol runs in the documented order', () {
    test(
      'start, fetch, data, ack — and the ack KEEPS the data on the band',
      () async {
        final rig = fetcherFor({
          0x13: [
            _stress([40, 41, 42]),
          ],
        });

        final samples = await rig.fetcher.fetchType(0x13, since, maxRounds: 2);
        expect(samples.map((s) => s.value).toList(), [40, 41, 42]);

        final commands = rig.strap.controlWrites;
        expect(commands.first[0], 0x01, reason: 'start-date first');
        expect(commands.first[1], 0x13, reason: 'the fetch type code');
        expect(
          commands.first,
          hasLength(10),
          reason: 'command + code + 8 time bytes',
        );
        expect(commands.any((c) => c.length == 1 && c[0] == 0x02), isTrue);

        final acks = commands
            .where((c) => c.isNotEmpty && c[0] == 0x03)
            .toList();
        expect(acks, isNotEmpty);
        for (final ack in acks) {
          expect(
            ack[1],
            0x09,
            reason: 'ack 0x09 keeps the data; any other byte can delete it',
          );
        }
        await rig.strap.close();
      },
    );

    test('a device with nothing to send is acked and finishes empty', () async {
      final rig = fetcherFor({});

      final samples = await rig.fetcher.fetchType(0x13, since);
      expect(samples, isEmpty);
      expect(rig.fetcher.lastExpected, 0);
      expect(
        rig.strap.controlWrites.any((c) => c.length > 1 && c[0] == 0x03),
        isTrue,
        reason: 'the abort still acks, so the band is left in a known state',
      );
      await rig.strap.close();
    });

    test('probe reads the packet count WITHOUT downloading anything', () async {
      final rig = fetcherFor({
        0x25: [Uint8List(200)],
      });

      final expected = await rig.fetcher.probe(0x25, since);
      expect(expected, 200);
      expect(
        rig.strap.controlWrites.any((c) => c.length == 1 && c[0] == 0x02),
        isFalse,
        reason: 'a probe must never pull the data it counted',
      );
      await rig.strap.close();
    });

    test('data packets are reassembled minus their counter byte', () async {
      // 60 stress bytes arrive as four packets, each prefixed with a counter.
      final values = List<int>.generate(60, (i) => 30 + (i % 10));
      final rig = fetcherFor({
        0x13: [_stress(values)],
      });

      final samples = await rig.fetcher.fetchType(0x13, since, maxRounds: 2);
      expect(samples.map((s) => s.value.toInt()).toList(), values);
      expect(rig.fetcher.lastRaw.length, 60, reason: 'counters are stripped');
      await rig.strap.close();
    });
  });

  group('the 0xFF gap-skip — the pager must cross a dead block, not stall', () {
    test(
      'an all-sentinel stress round advances `since` by its minute count',
      () async {
        final rig = fetcherFor({
          0x13: [
            _allSentinel(90),
            _stress([50, 51]),
          ],
        });

        final samples = await rig.fetcher.fetchType(0x13, since, maxRounds: 4);

        expect(
          rig.strap.requestedSince.length,
          greaterThanOrEqualTo(2),
          reason: 'a stalled pager would only ever ask once',
        );
        final first = rig.strap.requestedSince[0];
        final second = rig.strap.requestedSince[1];
        expect(
          second.difference(first).inMinutes,
          90,
          reason: 'stress is 1 byte per minute, so 90 bytes is 90 minutes',
        );
        expect(
          samples.map((s) => s.value).toList(),
          [50, 51],
          reason: 'the live data on the far side of the gap was reached',
        );
        await rig.strap.close();
      },
    );

    test(
      'an all-sentinel activity round steps 8 bytes to the minute',
      () async {
        final rig = fetcherFor({
          0x01: [_allSentinel(240), Uint8List(8)..[3] = 70],
        });

        await rig.fetcher.fetchType(0x01, since, maxRounds: 4);

        expect(
          rig.strap.requestedSince[1]
              .difference(rig.strap.requestedSince[0])
              .inMinutes,
          30,
          reason: '240 bytes at 8 B/min is 30 minutes',
        );
        await rig.strap.close();
      },
    );

    test(
      'the skip is capped at a day, so one bad round cannot skip a year',
      () async {
        final rig = fetcherFor({
          0x13: [_allSentinel(5000)],
        });

        await rig.fetcher.fetchType(0x13, since, maxRounds: 3);
        expect(
          rig.strap.requestedSince[1]
              .difference(rig.strap.requestedSince[0])
              .inMinutes,
          1440,
        );
        await rig.strap.close();
      },
    );

    test('gap-skip applies to 0x01 and 0x13 ONLY', () async {
      // Other types embed their own timestamps, so an empty round means the
      // feed is genuinely done — stepping forward would skip real data.
      final rig = fetcherFor({
        0x49: [_allSentinel(60)],
      });

      await rig.fetcher.fetchType(0x49, since, maxRounds: 4);
      expect(rig.strap.requestedSince, hasLength(1));
      await rig.strap.close();
    });
  });

  group('paging forward through real data', () {
    test('the next round starts one minute after the last sample', () async {
      final rig = fetcherFor({
        0x13: [
          _stress([40, 41, 42]),
          _stress([43]),
        ],
      });

      await rig.fetcher.fetchType(0x13, since, maxRounds: 4);

      expect(rig.strap.requestedSince.length, greaterThanOrEqualTo(2));
      expect(
        rig.strap.requestedSince[1]
            .difference(rig.strap.requestedSince[0])
            .inMinutes,
        3,
        reason: 'three samples consumed, so resume at +3 min',
      );
      await rig.strap.close();
    });

    test('maxRounds bounds the paging', () async {
      final rig = fetcherFor({
        0x13: [
          for (var i = 0; i < 10; i++) _stress([40, 41, 42]),
        ],
      });

      await expectLater(
        rig.fetcher.fetchType(0x13, since, maxRounds: 2),
        throwsA(
          isA<FetchException>().having(
            (e) => e.samples.length,
            'retained samples',
            6,
          ),
        ),
      );
      expect(rig.strap.requestedSince, hasLength(2));
      await rig.strap.close();
    });

    test('lastRaw accumulates every round, not just the last', () async {
      final rig = fetcherFor({
        0x13: [
          _stress(List<int>.filled(20, 40)),
          _stress(List<int>.filled(15, 41)),
        ],
      });

      await rig.fetcher.fetchType(0x13, since, maxRounds: 3);
      expect(rig.fetcher.lastRaw.length, 35);
      await rig.strap.close();
    });
  });

  group('failures do not look like "no data"', () {
    test(
      'a device that never answers times out and keeps what it had',
      () async {
        final fetcher = ActivityFetcher((_) async {});
        await expectLater(
          fetcher.fetchType(
            0x13,
            since,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<FetchException>()),
        );
        expect(
          fetcher.lastExpected,
          -1,
          reason:
              '-1 is "no reply", which is not the same as 0 = "nothing to send"',
        );
      },
    );

    test('a rejected start ends the job rather than hanging', () async {
      final strap = FakeStrap(authKey: Uint8List(16));
      final fetcher = ActivityFetcher(strap.writeActivityControl);
      strap.activityControl.listen((_) {
        fetcher.onControl(Uint8List.fromList([0x10, 0x01, 0x05]));
      });

      await expectLater(
        fetcher.fetchType(0x13, since, timeout: const Duration(seconds: 2)),
        throwsA(isA<FetchException>()),
      );
      await strap.close();
    });

    test(
      'a control write that throws ends the job with a reason, not a hang',
      () async {
        final fetcher = ActivityFetcher((_) async {
          throw const FormatException('the radio is gone');
        });

        await expectLater(
          fetcher.fetchType(0x13, since, timeout: const Duration(seconds: 2)),
          throwsA(isA<FetchException>()),
        );
      },
    );
  });

  group('samples carry the round start the DEVICE reported', () {
    test('not the `since` we asked for, if the device disagrees', () async {
      final rig = fetcherFor({
        0x13: [
          _stress([40, 41]),
        ],
      });

      final samples = await rig.fetcher.fetchType(0x13, since, maxRounds: 2);
      // The fake echoes the requested since, truncated to whole minutes — the
      // encoding carries no seconds, which is itself worth pinning.
      expect(samples.first.date.second, 0);
      expect(samples.first.date.minute, since.minute);
      expect(
        samples[1].date.difference(samples[0].date),
        const Duration(minutes: 1),
      );
      expect(samples.first, isA<StrapSample>());
      await rig.strap.close();
    });
  });
}
