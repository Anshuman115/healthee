/// Per-type byte parsers for the activity-fetch data stream (char `0x0005`).
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// activity_parser.dart`, which came from HelioCore's `HelioLegacyParser` —
/// the same byte format Gadgetbridge decodes. No offset was adjusted, no loop
/// modernised: odd-looking arithmetic in a reverse-engineered format is usually
/// load-bearing.
///
/// Two timestamp styles: **round-relative** (+60 s per record from the
/// `roundStart` the device reported) for activity / stress / temperature, and
/// **absolute epoch seconds embedded in the record** for everything else.
///
/// ## The 0xFF sentinel is not optional
///
/// The strap allocates minutes it may never write, and leaves `0xFF` in them.
/// Treating one as a reading inflates steps, distance and calories, and makes a
/// heart rate out of a hole. `project_steps_stuck_pager_stall` exists because
/// this stream demonstrably stalls. Every decoder below that can see the
/// sentinel drops it; `activity_fetcher.dart` does the matching thing one layer
/// up, stepping the pager across an all-`0xFF` round instead of stalling on it.
///
/// ## Offset tables
///
/// Each row is one fixed-size record; the stream is a run of them.
///
/// **0x01 — per-minute activity** (8-byte records; 4 if the length is not a
/// multiple of 8):
///
/// | offset | size | field |
/// |---|---|---|
/// | +2 | 1 | steps in that minute (`0xFF` = sentinel, `0` = none) |
/// | +3 | 1 | heart rate (`0xFF` = sentinel, `0` = none) |
///
/// **0x13 — all-day stress** (1-byte records, one per minute):
///
/// | offset | size | field |
/// |---|---|---|
/// | +0 | 1 | stress 0–100 (`0xFF` = sentinel) |
///
/// **0x2E — skin temperature** (8-byte records, one per minute):
///
/// | offset | size | field |
/// |---|---|---|
/// | +2 | 2 | temperature ×100, int16 LE → °C |
///
/// **0x02 / 0x12 / 0x3A / 0x3D — the 6-byte heart-rate family**
/// (manual HR, manual stress, resting HR, max HR):
///
/// | offset | size | field |
/// |---|---|---|
/// | +0 | 4 | epoch seconds, uint32 LE |
/// | +5 | 1 | value (`0xFF` = sentinel, `0` = none) |
///
/// **0x49 — HRV** (6-byte records): same layout as the family above.
///
/// **0x38 — sleep respiratory rate** (8-byte records):
///
/// | offset | size | field |
/// |---|---|---|
/// | +0 | 4 | epoch seconds, uint32 LE |
/// | +5 | 1 | breaths per minute (`0xFF` = sentinel) |
///
/// **0x25 — spot SpO₂**: one version byte (must be `2`), then 65-byte records:
///
/// | offset | size | field |
/// |---|---|---|
/// | +0 | 4 | epoch seconds, uint32 LE |
/// | +4 | 1 | SpO₂, with the high bit used as a flag (`raw − 128` when set) |
///
/// **0x26 — sleep SpO₂**: one version byte (must be `2`), then 30-byte records:
///
/// | offset | size | field |
/// |---|---|---|
/// | +0 | 4 | epoch seconds, uint32 LE |
/// | +4 | 1 | SpO₂ percent (accepted only in 1–100) |
/// | +5 | 1 | duration |
/// | +6 | 24 | detail bytes, not decoded |
///
/// **0x48 — sleep session**: 594-byte records. Only the session timestamp is
/// read here (uint32 LE at +0), as a marker; the full record is decoded by
/// `sleep_parser.dart`, which owns that layout.
library;

import 'dart:typed_data';

import 'package:healthee/ble/models/strap_sample.dart';

/// Decoders for the fetch stream, one per fetch type code.
class ActivityParser {
  /// The revision of the offset tables above.
  ///
  /// The strap sends no layout version for most of these types (0x25 and 0x26
  /// carry a leading `2` and are the exception), so this constant does not read
  /// anything off the wire. It marks **this decoder's** layout so a stored
  /// sample can say which table decoded it, and so a future firmware change is
  /// a version bump rather than a silent reinterpretation.
  static const int layoutVersion = 1;

  /// Decodes one round of [data] for fetch type [code].
  ///
  /// [roundStart] is the timestamp the device reported for this round; it
  /// anchors the round-relative types and is ignored by the rest.
  static List<StrapSample> parse(int code, Uint8List data, DateTime roundStart) {
    switch (code) {
      case 0x01:
        return _activity(data, roundStart);
      case 0x02:
        return _hr6(data, 'manual_hr');
      case 0x12:
        return _hr6(data, 'stress_manual');
      case 0x13:
        return _stress(data, roundStart);
      case 0x25:
        return _spo2(data);
      case 0x26:
        return _spo2Sleep(data);
      case 0x2E:
        return _temperature(data, roundStart);
      case 0x38:
        return _sleepRespRate(data);
      case 0x3A:
        return _hr6(data, 'resting_hr');
      case 0x3D:
        return _hr6(data, 'max_hr');
      case 0x48:
        return _sleepSession(data);
      case 0x49:
        return _hrv(data);
      default:
        return const [];
    }
  }

  static int _u32(Uint8List d, int i) =>
      ByteData.sublistView(d, i, i + 4).getUint32(0, Endian.little);

  static DateTime _epoch(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000);

  static List<StrapSample> _temperature(Uint8List d, DateTime roundStart) {
    final out = <StrapSample>[];
    var ts = roundStart;
    var i = 0;
    while (i + 8 <= d.length) {
      final raw = ByteData.sublistView(
        d,
        i + 2,
        i + 4,
      ).getInt16(0, Endian.little);
      out.add(StrapSample(ts, 'temperature_c', raw / 100.0));
      ts = ts.add(const Duration(minutes: 1));
      i += 8;
    }
    return out;
  }

  static List<StrapSample> _activity(Uint8List d, DateTime roundStart) {
    final out = <StrapSample>[];
    final size = (d.length % 8 == 0) ? 8 : 4;
    var ts = roundStart;
    var i = 0;
    while (i + size <= d.length) {
      final hr = d[i + 3];
      if (hr != 0xFF && hr > 0) out.add(StrapSample(ts, 'hr', hr.toDouble()));
      final steps = d[i + 2];
      // 0xFF is the sentinel/saturation byte (not a real cadence) — drop it,
      // same as HR above. Otherwise it inflates daily steps/distance/calories.
      if (steps > 0 && steps != 0xFF) {
        out.add(StrapSample(ts, 'steps', steps.toDouble()));
      }
      ts = ts.add(const Duration(minutes: 1));
      i += size;
    }
    return out;
  }

  static List<StrapSample> _stress(Uint8List d, DateTime roundStart) {
    final out = <StrapSample>[];
    var ts = roundStart;
    for (final b in d) {
      if (b != 0xFF) out.add(StrapSample(ts, 'stress', b.toDouble()));
      ts = ts.add(const Duration(minutes: 1));
    }
    return out;
  }

  static List<StrapSample> _spo2(Uint8List d) {
    if (d.isEmpty || d[0] != 2) return const [];
    final out = <StrapSample>[];
    var i = 1;
    while (i + 65 <= d.length) {
      final sec = _u32(d, i);
      final raw = d[i + 4]; // int8
      final spo2 = raw >= 128 ? raw - 128 : raw;
      out.add(StrapSample(_epoch(sec), 'spo2', spo2.toDouble()));
      i += 65;
    }
    return out;
  }

  static List<StrapSample> _hr6(Uint8List d, String metric) {
    final out = <StrapSample>[];
    var i = 0;
    while (i + 6 <= d.length) {
      final sec = _u32(d, i);
      final hr = d[i + 5];
      if (hr != 0xFF && hr > 0) {
        out.add(StrapSample(_epoch(sec), metric, hr.toDouble()));
      }
      i += 6;
    }
    return out;
  }

  static List<StrapSample> _sleepRespRate(Uint8List d) {
    final out = <StrapSample>[];
    var i = 0;
    while (i + 8 <= d.length) {
      final sec = _u32(d, i);
      final rate = d[i + 5];
      if (rate != 0xFF && rate > 0) {
        out.add(StrapSample(_epoch(sec), 'respiratory_rate', rate.toDouble()));
      }
      i += 8;
    }
    return out;
  }

  static List<StrapSample> _hrv(Uint8List d) {
    final out = <StrapSample>[];
    var i = 0;
    while (i + 6 <= d.length) {
      final sec = _u32(d, i);
      final hrv = d[i + 5];
      if (hrv != 0xFF && hrv > 0) {
        out.add(StrapSample(_epoch(sec), 'hrv', hrv.toDouble()));
      }
      i += 6;
    }
    return out;
  }

  // Sleep SpO2 (0x26): 1 version byte (==2) then 30-byte records;
  // sec(u32 @0) + spo2(@4) + duration(@5) + 24 detail bytes.
  static List<StrapSample> _spo2Sleep(Uint8List d) {
    if (d.isEmpty || d[0] != 2) return const [];
    final out = <StrapSample>[];
    var i = 1;
    while (i + 30 <= d.length) {
      final sec = _u32(d, i);
      final spo2 = d[i + 4];
      if (spo2 > 0 && spo2 <= 100) {
        out.add(StrapSample(_epoch(sec), 'spo2_sleep', spo2.toDouble()));
      }
      i += 30;
    }
    return out;
  }

  // Sleep session (0x48): 594-byte blobs per session; sec(u32 @0) is the
  // session start. Emit one marker per session — the full stage decode lives in
  // sleep_parser.dart, which owns the 594-byte layout.
  static List<StrapSample> _sleepSession(Uint8List d) {
    final out = <StrapSample>[];
    var i = 0;
    while (i + 594 <= d.length) {
      final sec = _u32(d, i);
      out.add(StrapSample(_epoch(sec), 'sleep_session', 1));
      i += 594;
    }
    return out;
  }
}
