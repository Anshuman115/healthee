/// The Huami 8-byte time encoding used by the activity-fetch start command, and
/// the parser for the device's start-date metadata reply.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// huami_time.dart`.
///
/// ## Offset table — the 8-byte time value we send
///
/// | offset | size | field |
/// |---|---|---|
/// | 0 | 2 | year, uint16 LE |
/// | 2 | 1 | month, 1–12 |
/// | 3 | 1 | day, 1–31 |
/// | 4 | 1 | hour, 0–23 |
/// | 5 | 1 | minute, 0–59 |
/// | 6 | 1 | second — always written as 0 |
/// | 7 | 1 | timezone, in 15-minute units, `& 0xFF` |
///
/// The value is **local** time: the strap records against the wall clock the
/// owner set on it, and the tz byte is what reconciles the two. Standards §3
/// bans timezone string literals in feature code; this is the device's own
/// encoding, not a configured zone.
///
/// ## Offset table — the control reply to the start command
///
/// | offset | size | field |
/// |---|---|---|
/// | 0 | 1 | `0x10` — RESPONSE |
/// | 1 | 1 | `0x01` — echo of CMD_START_DATE |
/// | 2 | 1 | status (`0x01` = ok) |
/// | 3 | 4 | expected packet count, uint32 LE |
/// | 7 | 2 | year, uint16 LE |
/// | 9 | 1 | month |
/// | 10 | 1 | day |
/// | 11 | 1 | hour |
/// | 12 | 1 | minute |
/// | 13 | 1 | second |
///
/// A reply of `expected == 0` means "supported, nothing to send" — the date
/// fields are then not read, which is why that branch returns `DateTime.now()`
/// rather than decoding whatever is in bytes 7–13.
library;

import 'dart:typed_data';

/// Encoder/decoder for the activity-fetch time fields.
class HuamiTime {
  /// The 8-byte local-time value the start command carries.
  static Uint8List bytes(DateTime dt) {
    final local = dt.toLocal();
    final tzUnits = (local.timeZoneOffset.inMinutes ~/ 15) & 0xFF;
    final out = Uint8List(8);
    final bd = ByteData.sublistView(out);
    bd.setUint16(0, local.year, Endian.little);
    out[2] = local.month;
    out[3] = local.day;
    out[4] = local.hour;
    out[5] = local.minute;
    out[6] = 0;
    out[7] = tzUnits;
    return out;
  }

  /// Parses the control reply to the start command.
  ///
  /// Returns null when the reply is too short to hold the date block.
  static ({int expected, DateTime start})? parseStartDate(Uint8List d) {
    if (d.length < 14) return null;
    final expected = ByteData.sublistView(d, 3, 7).getUint32(0, Endian.little);
    if (expected == 0) return (expected: 0, start: DateTime.now());
    final year = ByteData.sublistView(d, 7, 9).getUint16(0, Endian.little);
    final start = DateTime(year, d[9], d[10], d[11], d[12], d[13]);
    return (expected: expected, start: start);
  }
}
