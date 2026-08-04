/// Decoder for the 594-byte ZeppOS sleep-session blob (fetch type `0x48`).
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// sleep_parser.dart`. Each record holds the MAIN night sleep AND, if present,
/// one or more daytime NAPs — the naps are a second block in the same record,
/// which is why a naive parser reading only the night fields never surfaced
/// them.
///
/// ## Offset table — the 594-byte record
///
/// | offset | size | field |
/// |---|---|---|
/// | 0x000 | 4 | session timestamp, epoch seconds, uint32 LE |
/// | 0x004 | 4 | midnight timestamp, epoch seconds, uint32 LE |
/// | 0x008 | 1 | marker, must be `1` |
/// | 0x009 | 1 | marker, must be `1` |
/// | 0x00a | 2 | night sleep start, minutes, uint16 LE |
/// | 0x00c | 2 | night sleep end, minutes, uint16 LE |
/// | 0x015 | 1 | average heart rate |
/// | 0x016 | 1 | the device's sleep score |
/// | 0x018 | 6×n | nap descriptors `{start u16, end u16, duration u16}`, `start == 0 && duration == 0` ends the array (runs up to 0x054) |
/// | 0x054 | 1 | number of night stage segments |
/// | 0x056 | 5×≤51 | night stages `{start u16, end u16, type u8}` |
/// | 0x155 | 5×≤49 | nap stages — ALL naps on one timeline, same triple |
/// | 0x24a | 2 | night REM minutes, uint16 LE |
/// | 0x24c | 2 | night light minutes, uint16 LE |
/// | 0x24e | 2 | night deep minutes, uint16 LE |
/// | 0x250 | 2 | night awake minutes, uint16 LE |
///
/// All stage minutes are offsets from **(midnight − 24 h)**, not from midnight.
///
/// Stage types: `4` light · `5` deep · `8` REM · `7` awake · `0x80` = a gap
/// between blocks, which is a marker and not a stage. A `{0, 0}` start/end pair
/// terminates the night array.
///
/// This layout is recorded in the legacy file as verified against the Zepp app
/// byte-for-byte; `test/ble/sleep_parser_test.dart` builds its fixture from the
/// table above rather than from the code below.
library;

import 'dart:typed_data';

import 'package:healthee/ble/models/sleep_session.dart';

/// Decodes sleep records into sessions.
class SleepParser {
  /// The fixed record size. Every record is this long, aligned from offset 0.
  static const int recordSize = 594;

  /// The revision of the offset table above. See `activity_parser.dart` for why
  /// this is our version and not the device's.
  static const int layoutVersion = 1;

  static DateTime _epoch(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000);

  static bool _isStage(int ty) => ty == 4 || ty == 5 || ty == 7 || ty == 8;

  /// Parse `count` contiguous night-stage segments from `off`, skipping gap
  /// markers (0x80) and stopping at the zero-terminator. `base` = midnight − 24h.
  static List<SleepStageSeg> _stages(ByteData bd, int off, int count, int base) {
    final out = <SleepStageSeg>[];
    for (var i = 0; i < count && off + 5 * i + 5 <= recordSize; i++) {
      final s = bd.getUint16(off + 5 * i, Endian.little);
      final e = bd.getUint16(off + 5 * i + 2, Endian.little);
      final ty = bd.getUint8(off + 5 * i + 4);
      if (s == 0 && e == 0) break; // zero-terminated
      if (!_isStage(ty)) continue; // skip gap (0x80) markers
      out.add(SleepStageSeg(_epoch(base + s * 60), _epoch(base + e * 60), ty));
    }
    return out;
  }

  static int _sumType(List<SleepStageSeg> st, int type) => st
      .where((g) => g.type == type)
      .fold(0, (a, g) => a + g.end.difference(g.start).inMinutes);

  /// Decodes every valid record in [data].
  static List<SleepSession> parse(Uint8List data) {
    final out = <SleepSession>[];
    var off = 0;
    while (off + recordSize <= data.length) {
      final bd = ByteData.sublistView(data, off, off + recordSize);
      final tsSession = bd.getUint32(0x00, Endian.little);
      final tsMidnight = bd.getUint32(0x04, Endian.little);
      // Validate the record header (plausible epochs + the 0x0101 marker).
      // SKIP (not break) a bad 594-byte slot — e.g. an empty/aborted session
      // (marker 1,0, 0 stages) — and keep scanning. Records are fixed-size
      // aligned, so a single bad blob between two valid ones must NOT stop the
      // whole parse: breaking here was dropping later real sessions (e.g. last
      // night's sleep sitting after an empty trek-night record). The strict
      // epoch+marker check still prevents inventing phantom sessions from garbage.
      if (tsSession < 1600000000 ||
          tsSession > 2000000000 ||
          tsMidnight < 1600000000 ||
          tsMidnight > 2000000000 ||
          bd.getUint8(0x08) != 1 ||
          bd.getUint8(0x09) != 1) {
        off += recordSize;
        continue;
      }
      final base = tsMidnight - 24 * 3600;
      final avgHr = bd.getUint8(0x15);
      final score = bd.getUint8(0x16);

      // ── main night sleep ──
      final numStages = bd.getUint8(0x54);
      final night = _stages(bd, 0x56, numStages > 51 ? 51 : numStages, base);
      out.add(
        SleepSession(
          sessionStart: _epoch(tsSession),
          sleepStartMin: bd.getUint16(0x0a, Endian.little),
          sleepEndMin: bd.getUint16(0x0c, Endian.little),
          avgHr: avgHr,
          score: score,
          stages: night,
          remMin: bd.getUint16(0x24a, Endian.little),
          lightMin: bd.getUint16(0x24c, Endian.little),
          deepMin: bd.getUint16(0x24e, Endian.little),
          wakeMin: bd.getUint16(0x250, Endian.little),
        ),
      );

      // ── daytime naps: a 6-byte descriptor array {start,end,dur} at 0x18 ──
      final napWindows = <(int, int)>[];
      for (var p = 0x18; p + 6 <= 0x54; p += 6) {
        final ns = bd.getUint16(p, Endian.little);
        final ne = bd.getUint16(p + 2, Endian.little);
        final nd = bd.getUint16(p + 4, Endian.little);
        if (ns == 0 && nd == 0) break; // end of array
        if (nd > 0 && ne > ns) napWindows.add((ns, ne));
      }
      if (napWindows.isNotEmpty) {
        // All naps' stages share one timeline at 0x155 (0x80 = gaps, skipped).
        final segs = <(int, int, int)>[]; // startMin, endMin, type
        for (var i = 0; i < 49 && 0x155 + 5 * i + 5 <= recordSize; i++) {
          final q = 0x155 + 5 * i;
          final s = bd.getUint16(q, Endian.little);
          final e = bd.getUint16(q + 2, Endian.little);
          final ty = bd.getUint8(q + 4);
          if (s == 0 && e == 0) continue;
          if (_isStage(ty)) segs.add((s, e, ty));
        }
        for (final (ns, ne) in napWindows) {
          final st = [
            for (final (s, e, ty) in segs)
              if (s >= ns && s <= ne)
                SleepStageSeg(
                  _epoch(base + s * 60),
                  _epoch(base + e * 60),
                  ty,
                ),
          ];
          if (st.isEmpty) continue; // need stages to push the session
          out.add(
            SleepSession(
              sessionStart: _epoch(base + ns * 60),
              sleepStartMin: ns,
              sleepEndMin: ne,
              avgHr: 0,
              score: 0,
              stages: st,
              remMin: _sumType(st, 8),
              lightMin: _sumType(st, 4),
              deepMin: _sumType(st, 5),
              wakeMin: _sumType(st, 7),
              isNap: true,
            ),
          );
        }
      }
      off += recordSize;
    }
    return out;
  }
}
