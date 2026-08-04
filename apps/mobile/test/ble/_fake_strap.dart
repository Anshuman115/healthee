/// A strap that answers the protocol, built from the spec rather than the code.
///
/// The device half of everything in `lib/ble/` — the five-step handshake, the
/// chunked framing, the daily-totals reply and the activity-fetch round
/// protocol — implemented here from `research/protocol/zeppos_ble_handshake.md`
/// and the round protocol written down in `activity_fetcher.dart`'s own header.
///
/// ## What this proves, and what it does not
///
/// It genuinely checks the **framing and the derivation**: the device computes
/// the session key from the doc's formula, written out below, and encrypts its
/// reply with it. If `zeppos_auth.dart` derived a different key, or the chunked
/// codec disagreed about a header byte, nothing would decode.
///
/// It does **not** independently verify the ECDH itself — both halves call
/// `EcdhSect163k1`, because there is no second implementation on this machine.
/// That gap is closed separately by `ecdh_sect163k1_test.dart`, which checks the
/// curve constants against the ones published in the handshake doc.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:healthee/ble/crypto/ecdh_sect163k1.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/transport/huami_chunk.dart';
import 'package:healthee/ble/transport/strap_link.dart';

/// A scripted strap. Hand it to `StrapClient` through its link factory.
class FakeStrap implements StrapLink {
  /// [authKey] is the 16-byte key the device will check the proof against.
  FakeStrap({
    required this.authKey,
    this.rejectAuthKey = false,
    this.silentDuringHandshake = false,
    this.unreachable = false,
    this.hasActivityChannel = true,
    this.batteryPercent = 71,
    this.dailyTotals,
    Map<int, List<Uint8List>>? rounds,
  }) : rounds = rounds ?? <int, List<Uint8List>>{};

  /// The key the device holds.
  final Uint8List authKey;

  /// Answer step 5 with status `0x25` — "wrong auth key".
  final bool rejectAuthKey;

  /// Never answer the public-key frame at all.
  final bool silentDuringHandshake;

  /// Refuse to open.
  final bool unreachable;

  /// Whether chars `0x0004`/`0x0005` exist on this device.
  @override
  final bool hasActivityChannel;

  /// What char `0x2A19` reports.
  final int? batteryPercent;

  /// `(steps, distanceM, calories)` to answer the endpoint-`0x0016` request
  /// with, or null to stay silent.
  final (int, int, int)? dailyTotals;

  /// Fetch-type code → the raw rounds it will serve, oldest first.
  final Map<int, List<Uint8List>> rounds;

  // ── what the app did ──────────────────────────────────────────────────────

  /// Every chunk written to `0x0016`.
  final List<Uint8List> chunkWrites = [];

  /// Every ACK written to `0x0017`.
  final List<Uint8List> ackWrites = [];

  /// Every command written to `0x0004`.
  final List<List<int>> controlWrites = [];

  /// The `since` of every start command, decoded from the 8 time bytes.
  final List<DateTime> requestedSince = [];

  /// The fetch code of every start command, in the same order.
  final List<int> requestedCodes = [];

  /// The `since` of the first start command for [code], or null.
  DateTime? firstRequestFor(int code) {
    final at = requestedCodes.indexOf(code);
    return at < 0 ? null : requestedSince[at];
  }

  /// The step-1 payload, exactly as it arrived on endpoint `0x0082`.
  Uint8List? publicKeyFrame;

  /// The step-4 payload, exactly as it arrived.
  Uint8List? proofFrame;

  /// The session key the DEVICE derived, by the doc's formula.
  Uint8List? deviceSessionKey;

  /// The sequence number the DEVICE derived.
  int? deviceSequence;

  /// True once the device is satisfied with both halves of the proof.
  bool proofAccepted = false;

  // ── internals ─────────────────────────────────────────────────────────────

  final StreamController<Uint8List> _chunked =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _control =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _data =
      StreamController<Uint8List>.broadcast();

  final HuamiChunkedDecoder _inbound = HuamiChunkedDecoder();
  final HuamiChunkedEncoder _outbound = HuamiChunkedEncoder();

  Uint8List? _deviceRandom;
  final Map<int, int> _roundCursor = {};
  int _pendingCode = 0;

  /// Whether [close] has been called.
  bool closed = false;

  @override
  Future<void> open() async {
    if (unreachable) {
      throw const StrapException(StrapUnreachable('fake: nothing there'));
    }
  }

  @override
  Future<void> openActivityChannel() async {
    if (!hasActivityChannel) {
      throw const StrapException(StrapChannelsMissing('activity fetch'));
    }
  }

  @override
  Future<int?> readBatteryPercent() async => batteryPercent;

  @override
  Stream<Uint8List> get chunkedNotifications => _chunked.stream;

  @override
  Stream<Uint8List> get activityControl => _control.stream;

  @override
  Stream<Uint8List> get activityData => _data.stream;

  @override
  Future<void> writeChunk(Uint8List chunk) async {
    chunkWrites.add(chunk);
    final frame = _inbound.feed(chunk, sessionKey: deviceSessionKey);
    if (frame == null) return;
    if (frame.endpoint == 0x0082) {
      _onAuthFrame(frame.payload);
    } else if (frame.endpoint == 0x0016) {
      _onDailyTotalsRequest(frame.payload);
    }
  }

  @override
  Future<void> writeChunkedAck(Uint8List ack) async => ackWrites.add(ack);

  @override
  Future<void> writeActivityControl(List<int> command) async {
    controlWrites.add(List<int>.of(command));
    if (command.isEmpty) return;
    switch (command[0]) {
      case 0x01:
        _onStartDate(command);
      case 0x02:
        _onFetchData();
      default:
        break; // 0x03 is our ack; the device has nothing to say back
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await _chunked.close();
    await _control.close();
    await _data.close();
  }

  // ── the handshake, per zeppos_ble_handshake.md ────────────────────────────

  void _onAuthFrame(Uint8List payload) {
    if (payload.length == 52 && payload[0] == 0x04) {
      publicKeyFrame = payload;
      if (silentDuringHandshake) return;
      _replyToPublicKey(payload);
    } else if (payload.isNotEmpty && payload[0] == 0x05) {
      proofFrame = payload;
      _replyToProof(payload);
    }
  }

  /// Step 2: `[0x10, 0x04, 0x01] ‖ random(16) ‖ devicePublicEC(48)`.
  void _replyToPublicKey(Uint8List payload) {
    final appPublic = Uint8List.sublistView(payload, 4, 52);
    final (priv, pub) = EcdhSect163k1.generateKeypair();
    _deviceRandom = Uint8List.fromList(
      List<int>.generate(16, (i) => (i * 37 + 11) & 0xFF),
    );

    // Step 3, the device's half — the doc's formula, written out here so it is
    // NOT read from zeppos_auth.dart.
    final shared = EcdhSect163k1.generateShared(priv, appPublic);
    deviceSequence = ByteData.sublistView(
      shared,
      0,
      4,
    ).getUint32(0, Endian.little);
    final session = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      session[i] = shared[i + 8] ^ authKey[i];
    }
    deviceSessionKey = session;
    _outbound.setEncryption(session, deviceSequence!);

    final reply = Uint8List(67)
      ..[0] = 0x10
      ..[1] = 0x04
      ..[2] = 0x01
      ..setRange(3, 19, _deviceRandom!)
      ..setRange(19, 67, pub);
    _emit(0x0082, reply);
  }

  /// Step 5: check both encryptions, then confirm or refuse.
  void _replyToProof(Uint8List payload) {
    final expected1 = aesEcbEncrypt(authKey, _deviceRandom!);
    final expected2 = aesEcbEncrypt(deviceSessionKey!, _deviceRandom!);
    proofAccepted =
        _sameBytes(Uint8List.sublistView(payload, 1, 17), expected1) &&
        _sameBytes(Uint8List.sublistView(payload, 17, 33), expected2);
    final status = (rejectAuthKey || !proofAccepted) ? 0x25 : 0x01;
    _emit(0x0082, Uint8List.fromList([0x10, 0x05, status]));
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The endpoint-`0x0016` reply, per the offset table in
  /// `device_daily_totals.dart`. Sent ENCRYPTED, because that is what the
  /// post-auth channel does and it is the strongest available check that both
  /// sides derived the same session key.
  void _onDailyTotalsRequest(Uint8List payload) {
    final totals = dailyTotals;
    if (payload.isEmpty || payload[0] != 0x03 || totals == null) return;
    final reply = Uint8List(15);
    reply[0] = 0x04;
    reply[1] = 0x01;
    reply[2] = 0x0c;
    ByteData.sublistView(reply)
      ..setUint32(3, totals.$1, Endian.little)
      ..setUint32(7, totals.$2, Endian.little)
      ..setUint32(11, totals.$3, Endian.little);
    _emit(0x0016, reply, encrypt: true);
  }

  void _emit(int endpoint, Uint8List payload, {bool encrypt = false}) {
    for (final chunk in _outbound.encode(endpoint, payload, encrypt: encrypt)) {
      if (!_chunked.isClosed) _chunked.add(chunk);
    }
  }

  // ── the activity-fetch round protocol ─────────────────────────────────────

  /// `[0x01, type] ‖ HuamiTime.bytes(since)` → the metadata reply.
  void _onStartDate(List<int> command) {
    final code = command[1];
    _pendingCode = code;
    final time = Uint8List.fromList(command.sublist(2, 10));
    final year = ByteData.sublistView(time, 0, 2).getUint16(0, Endian.little);
    requestedSince.add(DateTime(year, time[2], time[3], time[4], time[5]));
    requestedCodes.add(code);

    final queue = rounds[code] ?? const <Uint8List>[];
    final cursor = _roundCursor[code] ?? 0;
    final expected = cursor < queue.length ? queue[cursor].length : 0;
    _replyControl(_startDateReply(expected, requestedSince.last));
  }

  Uint8List _startDateReply(int expected, DateTime start) {
    final reply = Uint8List(14);
    reply[0] = 0x10;
    reply[1] = 0x01;
    reply[2] = 0x01;
    ByteData.sublistView(reply)
      ..setUint32(3, expected, Endian.little)
      ..setUint16(7, start.year, Endian.little);
    reply[9] = start.month;
    reply[10] = start.day;
    reply[11] = start.hour;
    reply[12] = start.minute;
    reply[13] = start.second;
    return reply;
  }

  /// `[0x02]` → the data packets on char `0x0005`, then the completion reply.
  void _onFetchData() {
    final code = _pendingCode;
    final queue = rounds[code] ?? const <Uint8List>[];
    final cursor = _roundCursor[code] ?? 0;
    if (cursor >= queue.length) {
      _replyControl(Uint8List.fromList([0x10, 0x02, 0x01]));
      return;
    }
    final raw = queue[cursor];
    _roundCursor[code] = cursor + 1;

    var counter = 0;
    for (var off = 0; off < raw.length; off += 19) {
      final end = (off + 19 < raw.length) ? off + 19 : raw.length;
      final packet = Uint8List(1 + (end - off))
        ..[0] = counter & 0xFF
        ..setRange(1, 1 + (end - off), raw.sublist(off, end));
      counter++;
      if (!_data.isClosed) _data.add(packet);
    }
    _replyControl(Uint8List.fromList([0x10, 0x02, 0x01]));
  }

  void _replyControl(Uint8List reply) {
    // Deferred to the next event-loop turn, not just the next microtask. Stream
    // delivery is a microtask, so a microtask here would land BEFORE the data
    // packets queued above — and the fetcher would parse a half-received round.
    // The real device sends every packet before it says the round is done, and
    // the fake has to keep that ordering or it tests a race instead of a
    // protocol.
    Timer.run(() {
      if (!_control.isClosed) _control.add(reply);
    });
  }
}
