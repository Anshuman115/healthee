/// **Spec-derived.** The 594-byte record is built here from the offset table
/// documented in `sleep_parser.dart` — which the legacy file records as
/// "verified against the Zepp app, byte-for-byte" — and never by reading what
/// the parser does.
///
/// The table is also internally consistent in a way worth noticing, because it
/// is evidence the offsets are real rather than fitted: 51 night stages × 5
/// bytes from `0x56` end exactly at `0x155`, where the nap timeline begins, and
/// 49 nap stages × 5 bytes end exactly at `0x24a`, where the night summary
/// begins. Three independently-recovered constants that tile without a gap.
///
/// Still not verification against hardware: no captured BLE bytes exist in this
/// repo. If the *document* is wrong about a field, this suite is wrong with it,
/// and only the owner's strap can say.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/parsers/sleep_parser.dart';

/// 2026-08-03 00:00 UTC-ish — any plausible epoch inside the parser's window.
const int _midnight = 1785196800;
const int _base = _midnight - 24 * 3600;

DateTime _at(int minuteFromBase) =>
    DateTime.fromMillisecondsSinceEpoch((_base + minuteFromBase * 60) * 1000);

/// Builds one record straight from the documented offset table.
Uint8List sleepRecord({
  int sessionTs = _midnight + 3600,
  int midnightTs = _midnight,
  int marker0x08 = 1,
  int marker0x09 = 1,
  int sleepStartMin = 1380,
  int sleepEndMin = 1620,
  int avgHr = 58,
  int score = 74,
  int? numStagesOverride,
  List<(int, int, int)> nightStages = const [],
  List<(int, int, int)> napDescriptors = const [],
  List<(int, int, int)> napStages = const [],
  int remMin = 61,
  int lightMin = 132,
  int deepMin = 44,
  int wakeMin = 9,
}) {
  final out = Uint8List(SleepParser.recordSize);
  final bd = ByteData.sublistView(out)
    ..setUint32(0x00, sessionTs, Endian.little)
    ..setUint32(0x04, midnightTs, Endian.little)
    ..setUint8(0x08, marker0x08)
    ..setUint8(0x09, marker0x09)
    ..setUint16(0x0a, sleepStartMin, Endian.little)
    ..setUint16(0x0c, sleepEndMin, Endian.little)
    ..setUint8(0x15, avgHr)
    ..setUint8(0x16, score)
    ..setUint8(0x54, numStagesOverride ?? nightStages.length)
    ..setUint16(0x24a, remMin, Endian.little)
    ..setUint16(0x24c, lightMin, Endian.little)
    ..setUint16(0x24e, deepMin, Endian.little)
    ..setUint16(0x250, wakeMin, Endian.little);

  for (var i = 0; i < napDescriptors.length; i++) {
    final (start, end, duration) = napDescriptors[i];
    final p = 0x18 + 6 * i;
    bd
      ..setUint16(p, start, Endian.little)
      ..setUint16(p + 2, end, Endian.little)
      ..setUint16(p + 4, duration, Endian.little);
  }
  for (var i = 0; i < nightStages.length; i++) {
    final (start, end, type) = nightStages[i];
    final p = 0x56 + 5 * i;
    bd
      ..setUint16(p, start, Endian.little)
      ..setUint16(p + 2, end, Endian.little)
      ..setUint8(p + 4, type);
  }
  for (var i = 0; i < napStages.length; i++) {
    final (start, end, type) = napStages[i];
    final p = 0x155 + 5 * i;
    bd
      ..setUint16(p, start, Endian.little)
      ..setUint16(p + 2, end, Endian.little)
      ..setUint8(p + 4, type);
  }
  return out;
}

Uint8List _concat(List<Uint8List> records) {
  final out = Uint8List(records.length * SleepParser.recordSize);
  for (var i = 0; i < records.length; i++) {
    out.setRange(
      i * SleepParser.recordSize,
      (i + 1) * SleepParser.recordSize,
      records[i],
    );
  }
  return out;
}

void main() {
  group('the night record', () {
    test('every documented field comes back where the table says it is', () {
      final sessions = SleepParser.parse(
        sleepRecord(
          nightStages: const [(1380, 1440, 4), (1440, 1500, 5), (1500, 1560, 8)],
        ),
      );

      expect(sessions, hasLength(1));
      final night = sessions.single;
      expect(night.isNap, isFalse);
      expect(
        night.sessionStart,
        DateTime.fromMillisecondsSinceEpoch((_midnight + 3600) * 1000),
      );
      expect(night.sleepStartMin, 1380);
      expect(night.sleepEndMin, 1620);
      expect(night.avgHr, 58);
      expect(night.score, 74);
      expect(night.remMin, 61);
      expect(night.lightMin, 132);
      expect(night.deepMin, 44);
      expect(night.wakeMin, 9);
      expect(night.totalMin, 61 + 132 + 44 + 9);
    });

    test('stage minutes are offsets from midnight MINUS 24 h, not midnight', () {
      final night = SleepParser.parse(
        sleepRecord(nightStages: const [(1380, 1440, 4)]),
      ).single;

      expect(night.stages, hasLength(1));
      expect(night.stages.single.start, _at(1380));
      expect(night.stages.single.end, _at(1440));
      // 1380 minutes past (midnight − 24 h) is 23:00 the evening BEFORE the
      // record's midnight. Reading the base as midnight itself would put the
      // whole night a day late.
      expect(
        night.stages.single.start.millisecondsSinceEpoch,
        lessThan(_midnight * 1000),
      );
    });

    test('the four stage codes map to their names', () {
      final night = SleepParser.parse(
        sleepRecord(
          nightStages: const [
            (10, 20, 4),
            (20, 30, 5),
            (30, 40, 8),
            (40, 50, 7),
          ],
        ),
      ).single;

      expect(
        night.stages.map((s) => s.kind).toList(),
        ['light', 'deep', 'rem', 'awake'],
      );
    });

    test('a 0x80 gap marker is skipped, never counted as a stage', () {
      final night = SleepParser.parse(
        sleepRecord(
          nightStages: const [(10, 20, 4), (20, 30, 0x80), (30, 40, 5)],
        ),
      ).single;

      expect(night.stages, hasLength(2));
      expect(night.stages.map((s) => s.type), [4, 5]);
    });

    test('a zero start/end pair terminates the array early', () {
      final night = SleepParser.parse(
        sleepRecord(
          numStagesOverride: 51,
          nightStages: const [(10, 20, 4), (0, 0, 5), (30, 40, 5)],
        ),
      ).single;

      expect(night.stages, hasLength(1));
    });

    test('a count above 51 is clamped rather than read off the end', () {
      final night = SleepParser.parse(
        sleepRecord(
          numStagesOverride: 250,
          nightStages: List<(int, int, int)>.generate(
            51,
            (i) => (10 + i, 11 + i, 4),
          ),
        ),
      ).single;

      expect(night.stages, hasLength(51));
    });
  });

  group('daytime naps — the second block in the same record', () {
    test('a descriptor plus stages inside its window becomes a nap session', () {
      final sessions = SleepParser.parse(
        sleepRecord(
          nightStages: const [(1380, 1440, 4)],
          napDescriptors: const [(1900, 1960, 60)],
          napStages: const [(1900, 1930, 4), (1930, 1960, 5)],
        ),
      );

      expect(sessions, hasLength(2));
      final nap = sessions.last;
      expect(nap.isNap, isTrue);
      expect(nap.sessionStart, _at(1900));
      expect(nap.sleepStartMin, 1900);
      expect(nap.sleepEndMin, 1960);
      expect(nap.lightMin, 30);
      expect(nap.deepMin, 30);
      expect(nap.remMin, 0);
      expect(nap.wakeMin, 0);
      expect(
        nap.avgHr,
        0,
        reason: 'the record carries no per-nap average; 0 is "not measured"',
      );
      expect(nap.score, 0);
    });

    test('two naps split ONE shared timeline by their descriptor windows', () {
      final sessions = SleepParser.parse(
        sleepRecord(
          napDescriptors: const [(1900, 1960, 60), (2100, 2150, 50)],
          napStages: const [
            (1900, 1930, 4),
            (1930, 1960, 5),
            (2100, 2150, 8),
          ],
        ),
      );

      expect(sessions, hasLength(3), reason: 'the night plus two naps');
      expect(sessions[1].stages, hasLength(2));
      expect(sessions[2].stages, hasLength(1));
      expect(sessions[2].remMin, 50);
    });

    test('a descriptor with no stages of its own is dropped, not invented', () {
      final sessions = SleepParser.parse(
        sleepRecord(
          napDescriptors: const [(1900, 1960, 60)],
          napStages: const [(2500, 2530, 4)],
        ),
      );

      expect(sessions, hasLength(1), reason: 'the night only');
    });

    test('the descriptor array ends at start == 0 && duration == 0', () {
      final sessions = SleepParser.parse(
        sleepRecord(
          napDescriptors: const [(0, 0, 0), (1900, 1960, 60)],
          napStages: const [(1900, 1930, 4)],
        ),
      );

      expect(sessions, hasLength(1), reason: 'the terminator stops the scan');
    });

    test('a zero-duration descriptor is not a nap', () {
      final sessions = SleepParser.parse(
        sleepRecord(
          napDescriptors: const [(1900, 1960, 0), (1900, 1960, 60)],
          napStages: const [(1900, 1930, 4)],
        ),
      );

      // The first entry has duration 0 but a non-zero start, so it is skipped
      // rather than treated as the terminator; the second is a real nap.
      expect(sessions, hasLength(2));
      expect(sessions.last.isNap, isTrue);
    });
  });

  group('a bad record must not stop the scan — the regression that cost a night', () {
    test('an empty slot between two valid records is SKIPPED, not fatal', () {
      final data = _concat([
        sleepRecord(sessionTs: _midnight + 100, nightStages: const [(10, 20, 4)]),
        sleepRecord(marker0x09: 0), // an aborted session: marker 1,0
        sleepRecord(sessionTs: _midnight + 300, nightStages: const [(30, 40, 5)]),
      ]);

      final sessions = SleepParser.parse(data);
      expect(sessions, hasLength(2));
      expect(
        sessions.last.sessionStart.millisecondsSinceEpoch,
        (_midnight + 300) * 1000,
        reason: 'breaking on the bad slot used to drop everything after it',
      );
    });

    test('an implausible epoch is not decoded into a phantom session', () {
      expect(SleepParser.parse(sleepRecord(sessionTs: 12345)), isEmpty);
      expect(SleepParser.parse(sleepRecord(midnightTs: 2500000000)), isEmpty);
      expect(SleepParser.parse(sleepRecord(marker0x08: 2)), isEmpty);
    });

    test('a partial trailing record is ignored', () {
      final data = Uint8List(SleepParser.recordSize + 100)
        ..setRange(
          0,
          SleepParser.recordSize,
          sleepRecord(nightStages: const [(10, 20, 4)]),
        );
      expect(SleepParser.parse(data), hasLength(1));
    });

    test('an empty buffer yields nothing rather than throwing', () {
      expect(SleepParser.parse(Uint8List(0)), isEmpty);
      expect(SleepParser.parse(Uint8List(593)), isEmpty);
    });
  });
}
