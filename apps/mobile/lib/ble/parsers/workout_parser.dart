/// Parser for the ZeppOS protobuf workout-summary blobs (fetch type `0x05`).
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// workout_parser.dart`, including the hand-rolled minimal protobuf reader.
/// That reader is deliberately not replaced with a generated one: there is no
/// `.proto` for this message, the field map below was recovered by inspection,
/// and a generated decoder would fail closed on the unknown fields this one
/// walks past.
///
/// ## Field table — the top-level summary message
///
/// | field | wire type | contents |
/// |---|---|---|
/// | 1 | bytes | version string, `"2.1"` |
/// | 2 | message | `{1 = startTime (epoch s), 3 = sportType}` |
/// | 7 | message | `{1 = durationSec}` |
/// | 16 | message | `{1 = calories}` |
/// | 19 | message | `{1 = avgHr, 2 = maxHr, 3 = minHr}` |
///
/// VERIFIED against a real workout (2026-05-01: duration 6:49 = 409 s, 53 kcal,
/// avg HR 122). `test/ble/workout_parser_test.dart` encodes a blob from this
/// table and asserts those same values come back.
///
/// ## Record framing inside a stream
///
/// A fetch round can carry several summaries back to back. Each one begins with
/// the protobuf version field — bytes `0a 03 32 2e`, i.e. field 1, length 3,
/// `"2."` — and each is preceded by a 2-byte record header, which is why the
/// split point for record *n* is `start[n+1] − 2`.
library;

import 'dart:typed_data';

import 'package:healthee/ble/models/workout.dart';

/// Decodes workout summaries out of a fetch stream.
class WorkoutParser {
  /// The revision of the field table above. See `activity_parser.dart` for why
  /// this is our version rather than the device's — though here the device does
  /// send one, the `"2.1"` string in field 1, which is what the split marker
  /// matches on.
  static const int layoutVersion = 1;

  /// A stream may contain multiple summaries; each begins with the protobuf
  /// version field `0a 03 32 2e` ("2."). Split on that, parse each.
  static List<Workout> parseStream(Uint8List data) {
    final out = <Workout>[];
    const marker = [0x0a, 0x03, 0x32, 0x2e]; // field1 len3 "2."
    final starts = <int>[];
    for (var i = 0; i + 4 <= data.length; i++) {
      if (data[i] == marker[0] &&
          data[i + 1] == marker[1] &&
          data[i + 2] == marker[2] &&
          data[i + 3] == marker[3]) {
        starts.add(i);
      }
    }
    for (var s = 0; s < starts.length; s++) {
      final end = s + 1 < starts.length ? starts[s + 1] - 2 : data.length;
      final begin = starts[s] < end ? starts[s] : end;
      final w = _parseOne(
        Uint8List.sublistView(data, begin, end < begin ? begin : end),
      );
      if (w != null) out.add(w);
    }
    return out;
  }

  static Workout? _parseOne(Uint8List blob) {
    final top = _msg(blob);
    final meta = _sub(top, 2);
    final dur = _sub(top, 7);
    final cal = _sub(top, 16);
    final hr = _sub(top, 19);
    final startSec = _int(meta, 1);
    if (startSec == null || startSec < 1000000000) return null; // need a sane ts
    return Workout(
      start: DateTime.fromMillisecondsSinceEpoch(startSec * 1000),
      sportType: _int(meta, 3) ?? 0,
      durationSec: _int(dur, 1) ?? 0,
      calories: _int(cal, 1) ?? 0,
      avgHr: _int(hr, 1) ?? 0,
      maxHr: _int(hr, 2) ?? 0,
      minHr: _int(hr, 3) ?? 0,
    );
  }

  // ── minimal protobuf reader ──
  // field -> list of (kind, value): kind 0=varint(int), 2=bytes(Uint8List)
  static Map<int, List<(int, Object)>> _msg(Uint8List d) {
    final m = <int, List<(int, Object)>>{};
    var i = 0;
    while (i < d.length) {
      final (tag, ni) = _varint(d, i);
      if (ni <= i) break;
      i = ni;
      final field = tag >> 3;
      final wt = tag & 7;
      switch (wt) {
        case 0: // varint
          final (v, j) = _varint(d, i);
          i = j;
          (m[field] ??= []).add((0, v));
        case 2: // length-delimited
          final (ln, j) = _varint(d, i);
          i = j;
          if (i + ln > d.length) return m;
          (m[field] ??= []).add((2, Uint8List.sublistView(d, i, i + ln)));
          i += ln;
        case 5: // fixed32
          if (i + 4 > d.length) return m;
          i += 4;
        case 1: // fixed64
          if (i + 8 > d.length) return m;
          i += 8;
        default:
          return m;
      }
    }
    return m;
  }

  static Map<int, List<(int, Object)>> _sub(
    Map<int, List<(int, Object)>> m,
    int field,
  ) {
    final v = m[field];
    if (v == null) return const {};
    for (final (k, val) in v) {
      if (k == 2 && val is Uint8List) return _msg(val);
    }
    return const {};
  }

  static int? _int(Map<int, List<(int, Object)>> m, int field) {
    final v = m[field];
    if (v == null) return null;
    for (final (k, val) in v) {
      if (k == 0 && val is int) return val;
    }
    return null;
  }

  static (int, int) _varint(Uint8List d, int i) {
    var v = 0;
    var s = 0;
    while (i < d.length) {
      final b = d[i++];
      v |= (b & 0x7f) << s;
      if (b & 0x80 == 0) return (v, i);
      s += 7;
    }
    return (v, i);
  }
}
