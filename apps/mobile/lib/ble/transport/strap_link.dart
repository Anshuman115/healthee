/// The radio, behind an interface — "these five characteristics, opened".
///
/// Everything above this line is pure byte handling and can be tested on a
/// laptop: the ECDH, the chunked codec, the handshake, the fetch round protocol
/// and the parsers. Everything below it is `flutter_blue_plus`, which is a
/// platform channel and does not exist inside `flutter test`.
///
/// Putting the seam exactly here is what makes the handshake testable end to
/// end against a fake device that follows `research/protocol/
/// zeppos_ble_handshake.md`. It is the same reason `strap_scanner.dart` is an
/// interface, one layer up: in front of the seam those paths would be
/// untestable, which in practice means untested.
///
/// ## The characteristics, and what each one is for
///
/// | UUID | role |
/// |---|---|
/// | `00000016-…` | chunked transport WRITE (app → device) |
/// | `00000017-…` | chunked transport NOTIFY (device → app) + our ACKs |
/// | `00000004-…` | activity-fetch CONTROL |
/// | `00000005-…` | activity-fetch DATA |
/// | `00002A19-…` | standard BLE battery level |
///
/// Base UUID suffix `-0000-3512-2118-0009af100700`, per the handshake doc.
library;

import 'dart:typed_data';

/// One strap's GATT channels, opened and ready.
///
/// Implementations throw `StrapException` for every failure; nothing here
/// returns a sentinel to mean "it did not work".
abstract interface class StrapLink {
  /// Chunked-transfer WRITE characteristic (app → device).
  static const String writeUuid = '00000016-0000-3512-2118-0009af100700';

  /// Chunked-transfer READ/NOTIFY characteristic (device → app).
  static const String notifyUuid = '00000017-0000-3512-2118-0009af100700';

  /// Activity-fetch CONTROL characteristic.
  static const String controlUuid = '00000004-0000-3512-2118-0009af100700';

  /// Activity-fetch DATA characteristic.
  static const String dataUuid = '00000005-0000-3512-2118-0009af100700';

  /// Connects, negotiates the MTU, discovers services and subscribes to the
  /// chunked notify characteristic.
  ///
  /// Throws `StrapException(StrapUnreachable)` if the connection does not come
  /// up and `StrapException(StrapChannelsMissing)` if `0x0016`/`0x0017` are not
  /// on the device.
  Future<void> open();

  /// Whether the activity-fetch pair (`0x0004`/`0x0005`) was found.
  ///
  /// A getter rather than a throw, because the handshake and the daily totals
  /// still work without it — history is what would be missing, and the caller
  /// decides whether that is fatal.
  bool get hasActivityChannel;

  /// Subscribes to the activity-fetch control and data characteristics.
  ///
  /// Throws `StrapException(StrapChannelsMissing)` when [hasActivityChannel] is
  /// false, so a missed check fails loudly rather than silently fetching
  /// nothing.
  Future<void> openActivityChannel();

  /// Reads the standard BLE battery level (char `0x2A19`), or null if the
  /// characteristic is absent or the value is out of range.
  Future<int?> readBatteryPercent();

  /// Notifications from the chunked characteristic `0x0017`.
  Stream<Uint8List> get chunkedNotifications;

  /// Notifications from the activity-fetch control characteristic `0x0004`.
  Stream<Uint8List> get activityControl;

  /// Notifications from the activity-fetch data characteristic `0x0005`.
  Stream<Uint8List> get activityData;

  /// Writes one chunk to `0x0016`, without response.
  Future<void> writeChunk(Uint8List chunk);

  /// Writes one chunked ACK to `0x0017`, without response.
  Future<void> writeChunkedAck(Uint8List ack);

  /// Writes one activity-fetch control command to `0x0004`, without response.
  Future<void> writeActivityControl(List<int> command);

  /// Drops the connection. Safe to call more than once.
  Future<void> close();
}

/// Builds a link for one MAC.
///
/// Injected rather than constructed, so the tests can hand the client a fake
/// device and the app can hand it a radio.
typedef StrapLinkFactory = StrapLink Function(String mac);
