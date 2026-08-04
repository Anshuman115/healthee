/// Two kinds of test live here, and the group names say which is which.
///
/// **SPEC-DERIVED** — the layout is stated in a document or a written comment
/// that is not this parser's code, so the fixture is an independent check:
///
///  * the `0xFF` sentinel rule (stated in prose in the parser's own header and
///    in `activity_fetcher.dart`, and the reason `project_steps_stuck_pager_stall`
///    exists),
///  * the per-minute record sizes — "activity 8 B/min, stress 1 B/min", written
///    down in `activity_fetcher.dart`'s gap-skip comment,
///  * sleep SpO₂ `0x26` — "1 version byte (==2) then 30-byte records; sec(u32
///    @0) + spo2(@4) + duration(@5) + 24 detail bytes",
///  * the 594-byte sleep-session stride, which `sleep_parser.dart` documents.
///
/// **REGRESSION PIN** — the layout exists ONLY in the parser, so a fixture
/// built from it can only prove that today's behaviour is still today's
/// behaviour. That is worth having, and it is not verification. These byte
/// positions were recovered from HelioCore and have never been checked against
/// a capture in this repo; the owner has the only strap that can settle them.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/parsers/activity_parser.dart';

final DateTime _roundStart = DateTime(2026, 8, 3, 6);

DateTime _epoch(int sec) => DateTime.fromMillisecondsSinceEpoch(sec * 1000);

const int _someEpoch = 1785222000; // a plausible device timestamp

/// n records of [size] bytes, filled by [fill].
Uint8List _records(int count, int size, void Function(int i, Uint8List r) fill) {
  final out = Uint8List(count * size);
  for (var i = 0; i < count; i++) {
    final record = Uint8List(size);
    fill(i, record);
    out.setRange(i * size, (i + 1) * size, record);
  }
  return out;
}

List<StrapSample> _of(List<StrapSample> samples, String metric) =>
    samples.where((s) => s.metric == metric).toList();

void main() {
  group('SPEC-DERIVED · the 0xFF sentinel is dropped, never read as a value', () {
    test('stress 0x13: one byte per minute, 0xFF minutes vanish', () {
      final data = Uint8List.fromList([40, 0xFF, 0xFF, 55, 0]);
      final samples = ActivityParser.parse(0x13, data, _roundStart);

      expect(samples.map((s) => s.value).toList(), [40, 55, 0]);
      expect(
        samples.map((s) => s.date).toList(),
        [
          _roundStart,
          _roundStart.add(const Duration(minutes: 3)),
          _roundStart.add(const Duration(minutes: 4)),
        ],
        reason: 'a skipped minute still advances the clock',
      );
      expect(samples.every((s) => s.metric == 'stress'), isTrue);
    });

    test('stress: an all-0xFF round decodes to nothing at all', () {
      // This is exactly the shape that stalls the pager, which is why
      // activity_fetcher.dart steps `since` forward by the minute count instead.
      final data = Uint8List(120)..fillRange(0, 120, 0xFF);
      expect(ActivityParser.parse(0x13, data, _roundStart), isEmpty);
    });

    test('activity 0x01: a 0xFF step byte does not inflate the day', () {
      final data = _records(3, 8, (i, r) {
        r[2] = i == 1 ? 0xFF : 40; // steps
        r[3] = 70; // hr
      });
      final samples = ActivityParser.parse(0x01, data, _roundStart);

      expect(_of(samples, 'steps').map((s) => s.value).toList(), [40, 40]);
      expect(
        _of(samples, 'steps').fold<double>(0, (a, s) => a + s.value),
        80,
        reason: '0xFF would have added 255 phantom steps to the total',
      );
    });

    test('activity 0x01: a 0xFF heart rate is a hole, not a reading', () {
      final data = _records(2, 8, (i, r) {
        r[2] = 10;
        r[3] = i == 0 ? 0xFF : 62;
      });
      expect(_of(ActivityParser.parse(0x01, data, _roundStart), 'hr'), hasLength(1));
    });

    test('a zero is not a reading either, for hr and steps alike', () {
      final data = _records(1, 8, (_, r) {
        r[2] = 0;
        r[3] = 0;
      });
      expect(ActivityParser.parse(0x01, data, _roundStart), isEmpty);
    });

    test('0xFF is dropped by every timestamped decoder too', () {
      for (final (code, size, valueOffset, metric) in const [
        (0x49, 6, 5, 'hrv'),
        (0x3A, 6, 5, 'resting_hr'),
        (0x3D, 6, 5, 'max_hr'),
        (0x38, 8, 5, 'respiratory_rate'),
      ]) {
        final data = _records(2, size, (i, r) {
          ByteData.sublistView(r).setUint32(0, _someEpoch + i * 60, Endian.little);
          r[valueOffset] = i == 0 ? 0xFF : 42;
        });
        final samples = ActivityParser.parse(code, data, _roundStart);
        expect(samples, hasLength(1), reason: 'code 0x${code.toRadixString(16)}');
        expect(samples.single.metric, metric);
        expect(samples.single.value, 42);
      }
    });
  });

  group('SPEC-DERIVED · the documented record sizes', () {
    test('activity is 8 bytes per minute', () {
      final data = _records(5, 8, (_, r) => r[3] = 70);
      final hr = _of(ActivityParser.parse(0x01, data, _roundStart), 'hr');
      expect(hr, hasLength(5));
      expect(hr.last.date, _roundStart.add(const Duration(minutes: 4)));
    });

    test('a buffer that is not a multiple of 8 falls back to 4-byte records', () {
      // Documented in the parser and in the fetcher's gap-skip arithmetic.
      final data = Uint8List(12)
        ..[3] = 70
        ..[7] = 71
        ..[11] = 72;
      expect(
        _of(ActivityParser.parse(0x01, data, _roundStart), 'hr'),
        hasLength(3),
        reason: '12 is not a multiple of 8, so the stride is 4',
      );
    });

    test('stress is 1 byte per minute', () {
      final data = Uint8List.fromList(List<int>.generate(90, (i) => 30 + i % 5));
      final samples = ActivityParser.parse(0x13, data, _roundStart);
      expect(samples, hasLength(90));
      expect(samples.last.date, _roundStart.add(const Duration(minutes: 89)));
    });

    test('sleep sessions are 594-byte records, one marker each', () {
      final data = _records(3, 594, (i, r) {
        ByteData.sublistView(r).setUint32(0, _someEpoch + i * 86400, Endian.little);
      });
      final samples = ActivityParser.parse(0x48, data, _roundStart);
      expect(samples, hasLength(3));
      expect(samples.first.metric, 'sleep_session');
      expect(samples.first.value, 1);
      expect(samples.first.date, _epoch(_someEpoch));
    });
  });

  group('SPEC-DERIVED · sleep SpO₂ 0x26, whose layout the comment states', () {
    Uint8List sleepSpo2(List<(int, int)> readings) {
      final out = Uint8List(1 + readings.length * 30)..[0] = 2;
      for (var i = 0; i < readings.length; i++) {
        final (sec, value) = readings[i];
        final at = 1 + i * 30;
        ByteData.sublistView(out).setUint32(at, sec, Endian.little);
        out[at + 4] = value;
        out[at + 5] = 30; // duration
      }
      return out;
    }

    test('version byte, then 30-byte records with sec@0 and spo2@4', () {
      final samples = ActivityParser.parse(
        0x26,
        sleepSpo2([(_someEpoch, 96), (_someEpoch + 300, 94)]),
        _roundStart,
      );

      expect(samples, hasLength(2));
      expect(samples.first.metric, 'spo2_sleep');
      expect(samples.first.value, 96);
      expect(samples.first.date, _epoch(_someEpoch));
      expect(samples.last.value, 94);
    });

    test('a version byte that is not 2 yields nothing — a layout guard', () {
      final data = sleepSpo2([(_someEpoch, 96)])..[0] = 3;
      expect(ActivityParser.parse(0x26, data, _roundStart), isEmpty);
      expect(ActivityParser.parse(0x26, Uint8List(0), _roundStart), isEmpty);
    });

    test('a percentage outside 1..100 is refused, not clamped', () {
      final samples = ActivityParser.parse(
        0x26,
        sleepSpo2([(_someEpoch, 0), (_someEpoch, 101), (_someEpoch, 100)]),
        _roundStart,
      );
      expect(samples.map((s) => s.value).toList(), [100]);
    });
  });

  group('REGRESSION PIN · byte positions that exist only in the parser', () {
    test('activity: steps at +2 and heart rate at +3 of an 8-byte record', () {
      final data = _records(1, 8, (_, r) {
        r[0] = 0x11;
        r[1] = 0x22;
        r[2] = 45; // steps
        r[3] = 68; // hr
        r[4] = 0x55;
      });
      final samples = ActivityParser.parse(0x01, data, _roundStart);
      expect(_of(samples, 'steps').single.value, 45);
      expect(_of(samples, 'hr').single.value, 68);
    });

    test('temperature 0x2E: int16 LE at +2, divided by 100', () {
      final data = _records(2, 8, (i, r) {
        ByteData.sublistView(r).setInt16(2, i == 0 ? 3412 : -150, Endian.little);
      });
      final samples = ActivityParser.parse(0x2E, data, _roundStart);

      expect(samples.map((s) => s.metric).toSet(), {'temperature_c'});
      expect(samples.first.value, closeTo(34.12, 1e-9));
      expect(
        samples.last.value,
        closeTo(-1.5, 1e-9),
        reason: 'signed — an unsigned read would give 655.36',
      );
    });

    test('the 6-byte HR family: epoch at +0, value at +5', () {
      for (final (code, metric) in const [
        (0x02, 'manual_hr'),
        (0x12, 'stress_manual'),
        (0x3A, 'resting_hr'),
        (0x3D, 'max_hr'),
      ]) {
        final data = _records(1, 6, (_, r) {
          ByteData.sublistView(r).setUint32(0, _someEpoch, Endian.little);
          r[4] = 0x99; // deliberately not the value
          r[5] = 57;
        });
        final samples = ActivityParser.parse(code, data, _roundStart);
        expect(samples.single.metric, metric);
        expect(samples.single.value, 57);
        expect(samples.single.date, _epoch(_someEpoch));
      }
    });

    test('hrv 0x49: 6-byte records, value at +5', () {
      final data = _records(2, 6, (i, r) {
        ByteData.sublistView(r).setUint32(0, _someEpoch + i * 300, Endian.little);
        r[5] = 40 + i;
      });
      final samples = ActivityParser.parse(0x49, data, _roundStart);
      expect(samples.map((s) => s.value).toList(), [40, 41]);
      expect(samples.first.metric, 'hrv');
    });

    test('sleep respiratory rate 0x38: 8-byte records, value at +5', () {
      final data = _records(1, 8, (_, r) {
        ByteData.sublistView(r).setUint32(0, _someEpoch, Endian.little);
        r[5] = 14;
      });
      final samples = ActivityParser.parse(0x38, data, _roundStart);
      expect(samples.single.metric, 'respiratory_rate');
      expect(samples.single.value, 14);
    });

    test('spot SpO₂ 0x25: 65-byte records, and the high bit is a flag', () {
      final out = Uint8List(1 + 2 * 65)..[0] = 2;
      ByteData.sublistView(out)
        ..setUint32(1, _someEpoch, Endian.little)
        ..setUint32(66, _someEpoch + 600, Endian.little);
      out[5] = 97; // plain
      out[70] = 128 + 95; // flagged
      final samples = ActivityParser.parse(0x25, out, _roundStart);

      expect(samples.map((s) => s.metric).toSet(), {'spo2'});
      expect(samples.map((s) => s.value).toList(), [97, 95]);
    });
  });

  group('nothing is invented from a short or unknown buffer', () {
    test('an unknown fetch code decodes to nothing', () {
      expect(ActivityParser.parse(0x77, Uint8List(64), _roundStart), isEmpty);
    });

    test('a buffer shorter than one record decodes to nothing', () {
      expect(ActivityParser.parse(0x49, Uint8List(5), _roundStart), isEmpty);
      expect(ActivityParser.parse(0x2E, Uint8List(7), _roundStart), isEmpty);
      expect(ActivityParser.parse(0x48, Uint8List(593), _roundStart), isEmpty);
      expect(ActivityParser.parse(0x01, Uint8List(0), _roundStart), isEmpty);
    });

    test('a trailing partial record is ignored, not padded with zeroes', () {
      final data = Uint8List(6 + 3);
      ByteData.sublistView(data).setUint32(0, _someEpoch, Endian.little);
      data[5] = 44;
      expect(ActivityParser.parse(0x49, data, _roundStart), hasLength(1));
    });

    test('the layout version is stated, so a stored sample can name it', () {
      expect(ActivityParser.layoutVersion, 1);
    });
  });
}
