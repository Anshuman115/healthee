/// **Spec-derived.** The blobs below are encoded from the protobuf field table
/// documented in `workout_parser.dart`, using a protobuf writer written here —
/// not by reading the reader. And the values are the ones the legacy file
/// records as VERIFIED against a real workout:
///
/// > 2026-05-01: duration 6:49 = 409 s, 53 kcal, avg HR 122
///
/// So this is a known-answer test on real numbers, through an independently
/// written encoder. What it does not prove is that the *field numbers* are
/// right — those were recovered by inspection and only the strap can confirm
/// them, though a wrong one would have produced a wrong duration on a workout
/// somebody had just done, which is how they were found in the first place.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/parsers/workout_parser.dart';

// ── a minimal protobuf WRITER, so the test does not lean on the reader ──

void _tag(BytesBuilder b, int field, int wireType) =>
    _varint(b, (field << 3) | wireType);

void _varint(BytesBuilder b, int value) {
  var v = value;
  while (v >= 0x80) {
    b.addByte((v & 0x7f) | 0x80);
    v >>= 7;
  }
  b.addByte(v);
}

void _varintField(BytesBuilder b, int field, int value) {
  _tag(b, field, 0);
  _varint(b, value);
}

void _bytesField(BytesBuilder b, int field, List<int> value) {
  _tag(b, field, 2);
  _varint(b, value.length);
  b.add(value);
}

Uint8List _submessage(void Function(BytesBuilder) build) {
  final b = BytesBuilder();
  build(b);
  return b.toBytes();
}

/// One workout summary, per the documented field table.
Uint8List workoutBlob({
  required int startSec,
  int sportType = 1,
  int durationSec = 409,
  int calories = 53,
  int avgHr = 122,
  int maxHr = 154,
  int minHr = 96,
  String version = '2.1',
}) {
  final b = BytesBuilder();
  _bytesField(b, 1, version.codeUnits);
  _bytesField(
    b,
    2,
    _submessage((m) {
      _varintField(m, 1, startSec);
      _varintField(m, 3, sportType);
    }),
  );
  _bytesField(b, 7, _submessage((m) => _varintField(m, 1, durationSec)));
  _bytesField(b, 16, _submessage((m) => _varintField(m, 1, calories)));
  _bytesField(
    b,
    19,
    _submessage((m) {
      _varintField(m, 1, avgHr);
      _varintField(m, 2, maxHr);
      _varintField(m, 3, minHr);
    }),
  );
  return b.toBytes();
}

/// The 2026-05-01 workout, at 07:30 local.
final int _realStart =
    DateTime(2026, 5, 1, 7, 30).millisecondsSinceEpoch ~/ 1000;

void main() {
  group('the verified 2026-05-01 workout decodes to its known values', () {
    test('duration 409 s, 53 kcal, avg HR 122', () {
      final workouts = WorkoutParser.parseStream(
        workoutBlob(startSec: _realStart),
      );

      expect(workouts, hasLength(1));
      final w = workouts.single;
      expect(w.durationSec, 409, reason: '6:49 on the watch face');
      expect(w.calories, 53);
      expect(w.avgHr, 122);
      expect(w.maxHr, 154);
      expect(w.minHr, 96);
      expect(w.sportType, 1);
      expect(w.start.millisecondsSinceEpoch, _realStart * 1000);
    });

    test('field 16 is a two-byte tag and is still found', () {
      // (16 << 3) | 2 = 130, which needs two varint bytes — a reader that
      // assumed one-byte tags would read calories as garbage or miss it.
      final w = WorkoutParser.parseStream(
        workoutBlob(startSec: _realStart, calories: 999),
      ).single;
      expect(w.calories, 999);
    });

    test('field 19 is a two-byte tag and all three HRs come back', () {
      final w = WorkoutParser.parseStream(
        workoutBlob(startSec: _realStart, avgHr: 130, maxHr: 171, minHr: 88),
      ).single;
      expect([w.avgHr, w.maxHr, w.minHr], [130, 171, 88]);
    });
  });

  group('a stream of several summaries', () {
    /// Records are separated by a 2-byte header, which is why the split point
    /// for record n is `start[n+1] - 2`.
    Uint8List stream(List<Uint8List> blobs) {
      final b = BytesBuilder();
      for (var i = 0; i < blobs.length; i++) {
        if (i > 0) b.add([0x00, 0x00]); // the 2-byte record header
        b.add(blobs[i]);
      }
      return b.toBytes();
    }

    test('three back-to-back summaries all decode', () {
      final data = stream([
        workoutBlob(startSec: _realStart, durationSec: 409),
        workoutBlob(startSec: _realStart + 86400, durationSec: 1800),
        workoutBlob(startSec: _realStart + 172800, durationSec: 2700),
      ]);

      final workouts = WorkoutParser.parseStream(data);
      expect(workouts, hasLength(3));
      expect(
        workouts.map((w) => w.durationSec).toList(),
        [409, 1800, 2700],
        reason: 'the split must not truncate the record before the marker',
      );
    });

    test('an empty stream yields nothing rather than throwing', () {
      expect(WorkoutParser.parseStream(Uint8List(0)), isEmpty);
      expect(WorkoutParser.parseStream(Uint8List(200)), isEmpty);
    });
  });

  group('what is refused', () {
    test('a summary with an implausible start time is dropped', () {
      // The parser requires startSec >= 1_000_000_000; anything less is a
      // misparse, and a workout dated 1970 is worse than no workout.
      expect(
        WorkoutParser.parseStream(workoutBlob(startSec: 999999999)),
        isEmpty,
      );
    });

    test('a blob with no version marker is not found at all', () {
      final b = BytesBuilder();
      _bytesField(
        b,
        2,
        _submessage((m) => _varintField(m, 1, _realStart)),
      );
      expect(WorkoutParser.parseStream(b.toBytes()), isEmpty);
    });

    test('missing optional submessages read as 0, not as null or a throw', () {
      final b = BytesBuilder();
      _bytesField(b, 1, '2.1'.codeUnits);
      _bytesField(
        b,
        2,
        _submessage((m) => _varintField(m, 1, _realStart)),
      );
      final w = WorkoutParser.parseStream(b.toBytes()).single;
      expect(w.durationSec, 0);
      expect(w.calories, 0);
      expect(w.avgHr, 0);
      expect(w.sportType, 0);
    });

    test('a truncated length-delimited field stops the read, not the process', () {
      final full = workoutBlob(startSec: _realStart);
      final truncated = Uint8List.sublistView(full, 0, full.length - 4);
      expect(
        () => WorkoutParser.parseStream(truncated),
        returnsNormally,
      );
    });
  });
}
