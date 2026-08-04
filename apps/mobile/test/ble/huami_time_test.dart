/// **Spec-derived from the legacy file's own layout comment**, which reads:
///
/// > Bytes: year(u16 LE) month day hour minute second(=0) tz(15-min units)
///
/// and, for the reply:
///
/// > `[0x10, 0x01, status, expected(u32 LE @3), year(u16 @7), mon, day, hr, min, sec]`
///
/// That is a written layout, not the code, so the fixtures below are built from
/// it and genuinely check the encoder and decoder. It is **not** verification
/// against captured hardware bytes — no BLE capture exists in this repo, and
/// only the owner's strap can settle whether the layout itself is right.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/transport/huami_time.dart';

void main() {
  group('the 8-byte time value we send', () {
    test('every field lands where the layout says', () {
      final bytes = HuamiTime.bytes(DateTime(2026, 8, 4, 13, 47, 29));

      expect(bytes.length, 8);
      expect(
        ByteData.sublistView(bytes, 0, 2).getUint16(0, Endian.little),
        2026,
        reason: 'year, uint16 LE',
      );
      expect(bytes[2], 8, reason: 'month');
      expect(bytes[3], 4, reason: 'day');
      expect(bytes[4], 13, reason: 'hour');
      expect(bytes[5], 47, reason: 'minute');
      expect(bytes[6], 0, reason: 'seconds are always written as zero');
    });

    test('the timezone byte is the local offset in 15-minute units', () {
      final now = DateTime.now();
      final expected = (now.timeZoneOffset.inMinutes ~/ 15) & 0xFF;
      expect(HuamiTime.bytes(now)[7], expected);
    });

    test('a UTC instant is encoded as its LOCAL wall clock', () {
      // The strap records against the wall clock its owner set on it, so the
      // conversion has to happen here and not be assumed away.
      final instant = DateTime.utc(2026, 1, 2, 3, 4);
      final local = instant.toLocal();
      final bytes = HuamiTime.bytes(instant);
      expect(bytes[2], local.month);
      expect(bytes[3], local.day);
      expect(bytes[4], local.hour);
      expect(bytes[5], local.minute);
    });
  });

  group('the start-date reply', () {
    Uint8List reply(int expected, DateTime start) {
      final out = Uint8List(14);
      out[0] = 0x10;
      out[1] = 0x01;
      out[2] = 0x01;
      ByteData.sublistView(out)
        ..setUint32(3, expected, Endian.little)
        ..setUint16(7, start.year, Endian.little);
      out[9] = start.month;
      out[10] = start.day;
      out[11] = start.hour;
      out[12] = start.minute;
      out[13] = start.second;
      return out;
    }

    test('the packet count and the round start both come back', () {
      final start = DateTime(2026, 7, 19, 6, 5, 4);
      final parsed = HuamiTime.parseStartDate(reply(1234, start))!;
      expect(parsed.expected, 1234);
      expect(parsed.start, start);
    });

    test('expected == 0 means "nothing to send" and the date is not read', () {
      // Bytes 7..13 are deliberately garbage: with expected == 0 the device has
      // not filled them in, and decoding them would invent a round start.
      final out = reply(0, DateTime(2026, 7, 19, 6, 5, 4));
      for (var i = 7; i < 14; i++) {
        out[i] = 0xFF;
      }
      final parsed = HuamiTime.parseStartDate(out)!;
      expect(parsed.expected, 0);
      expect(parsed.start.year, greaterThan(2020), reason: 'now, not year 65535');
    });

    test('a truncated reply is null, not a half-decoded date', () {
      expect(HuamiTime.parseStartDate(Uint8List(13)), isNull);
      expect(HuamiTime.parseStartDate(Uint8List(0)), isNull);
    });

    test('a round trip through bytes() and parseStartDate() holds', () {
      final start = DateTime(2026, 12, 31, 23, 59);
      final encoded = HuamiTime.bytes(start);
      final asReply = Uint8List(14)
        ..[0] = 0x10
        ..[1] = 0x01
        ..[2] = 0x01
        ..setRange(7, 13, encoded.sublist(0, 6))
        ..[13] = 0;
      ByteData.sublistView(asReply).setUint32(3, 1, Endian.little);
      expect(HuamiTime.parseStartDate(asReply)!.start, start);
    });
  });
}
