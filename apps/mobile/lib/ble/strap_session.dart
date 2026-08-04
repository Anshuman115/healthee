/// One authenticated connection to the strap: the channels, opened and routed.
///
/// This is the top half of the legacy `strap_client.dart` — connect, handshake,
/// post-auth wiring, the daily-totals request, disconnect — with the store, the
/// sync bus and the fetch plan lifted out. The fetch plan lives in
/// `strap_sync.dart`; the store is the next package's problem.
///
/// ## Why the notify routing has a mutable handler
///
/// Char `0x0017` carries the handshake first and every post-auth frame after.
/// The legacy code swapped a single `_notifyHandler` at the moment auth
/// succeeded, and this does the same: one subscription, re-pointed, rather than
/// two subscriptions racing for the same characteristic during the swap.
///
/// ## What is deliberately NOT logged
///
/// The legacy `_handlePayload` hex-dumped every frame it received. Frames on
/// this channel are health data, and after auth they arrive decrypted. So this
/// logs the endpoint and the length and stops there — except for the two frames
/// it actually decodes, whose decoded values it names.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:healthee/ble/fetch/activity_fetcher.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/transport/huami_comms.dart';
import 'package:healthee/ble/transport/strap_link.dart';
import 'package:healthee/ble/transport/zeppos_auth.dart';
import 'package:healthee/core/logging.dart';

/// How long the five-step handshake may take before we give up on it.
const Duration kHandshakeTimeout = Duration(seconds: 15);

/// The chunked endpoint that answers with the strap's since-midnight counters.
const int kDailyTotalsEndpoint = 0x0016;

/// How long to wait for the daily-totals reply before giving up on it.
///
/// Legacy fired the request and read the field later, hoping. That is fine when
/// a long fetch sits in between and wrong when one does not — and this is the
/// one measurement with no durable home anywhere else (#121), so "we probably
/// got it" is not good enough.
const Duration kDailyTotalsWait = Duration(seconds: 5);

/// An open, authenticated session. Build one through `StrapClient.connect`.
class StrapSession {
  /// Wraps an unopened [link]. Call [open] before anything else.
  ///
  /// The two timeouts are parameters rather than constants only so a test can
  /// shorten them; the defaults are the production values.
  StrapSession(
    this._link, {
    this.handshakeTimeout = kHandshakeTimeout,
    this.dailyTotalsWait = kDailyTotalsWait,
  });

  final StrapLink _link;

  /// How long the handshake may take.
  final Duration handshakeTimeout;

  /// How long to wait for the daily-totals reply.
  final Duration dailyTotalsWait;

  void Function(Uint8List)? _route;
  StreamSubscription<Uint8List>? _chunkedSub;
  StreamSubscription<Uint8List>? _controlSub;
  StreamSubscription<Uint8List>? _dataSub;

  HuamiComms? _comms;
  ActivityFetcher? _fetcher;

  /// Strap battery percent, read once on connect. Null when unavailable.
  int? batteryPercent;

  /// The strap's since-midnight counters, once the reply lands.
  ///
  /// Requested early and read late, as the legacy sync did — but [awaitDailyTotals]
  /// makes the read a wait rather than a hope.
  DeviceDailyTotals? dailyTotals;

  final Completer<DeviceDailyTotals> _dailyTotalsReply =
      Completer<DeviceDailyTotals>();

  /// The post-auth framed channel.
  HuamiComms get comms => _comms!;

  /// The activity-fetch driver. Only usable when [hasActivityChannel].
  ActivityFetcher get fetcher => _fetcher!;

  /// Whether the activity-fetch characteristics were found on this device.
  bool get hasActivityChannel => _link.hasActivityChannel;

  /// Connects, authenticates with [authKey], and opens every channel present.
  ///
  /// Throws [StrapException] carrying [StrapUnreachable],
  /// [StrapChannelsMissing], [HandshakeRefused] or [HandshakeTimedOut].
  Future<void> open(Uint8List authKey) async {
    await _link.open();
    batteryPercent = await _link.readBatteryPercent();

    _chunkedSub = _link.chunkedNotifications.listen((value) {
      _route?.call(value);
    });

    final auth = await _authenticate(authKey);
    _comms = HuamiComms(
      sessionKey: auth.sessionKey,
      sequence: auth.sequence ?? 0,
      writeChunk: _link.writeChunk,
      writeAck: _link.writeChunkedAck,
      onPayload: _handlePayload,
    );
    _route = (value) => unawaited(_comms!.onNotify(value));

    // Activity fetch runs on the legacy plaintext path (proven on this strap):
    // control on char 0x0004, data on char 0x0005.
    if (!_link.hasActivityChannel) {
      AppLog.warning('ble', 'activity-fetch chars not found; history unavailable');
      return;
    }
    await _link.openActivityChannel();
    _fetcher = ActivityFetcher(_link.writeActivityControl);
    _controlSub = _link.activityControl.listen(_fetcher!.onControl);
    _dataSub = _link.activityData.listen(_fetcher!.onData);
  }

  Future<ZeppOsAuth> _authenticate(Uint8List authKey) async {
    final done = Completer<String?>();
    final auth = ZeppOsAuth(
      authKey: authKey,
      writeChunk: _link.writeChunk,
      onSuccess: () {
        if (!done.isCompleted) done.complete(null);
      },
      onFailure: (reason) {
        if (!done.isCompleted) done.complete(reason);
      },
    );
    _route = auth.onNotify;

    AppLog.info('ble', 'starting handshake');
    await auth.start();

    final reason = await done.future.timeout(
      handshakeTimeout,
      onTimeout: () => _timedOut,
    );
    if (reason == _timedOut) {
      throw StrapException(
        HandshakeTimedOut(seconds: handshakeTimeout.inSeconds),
      );
    }
    if (reason != null) {
      throw StrapException(HandshakeRefused(reason));
    }
    return auth;
  }

  /// A sentinel the timeout branch returns, so "refused" and "went quiet" stay
  /// distinguishable — Standards §1 keeps those two states apart everywhere.
  static const String _timedOut = '__timed_out__';

  /// Asks the strap for its since-midnight counters.
  ///
  /// The answer arrives asynchronously on [dailyTotals]. Failure to ask is
  /// logged and not thrown: the totals are one of several things a sync
  /// collects, and losing them must not cost the rest.
  Future<void> requestDailyTotals() async {
    try {
      await comms.send(kDailyTotalsEndpoint, Uint8List.fromList([0x03]));
    } on Exception catch (error, stackTrace) {
      AppLog.failure(
        'ble',
        "requesting the strap's daily totals",
        error,
        stackTrace,
      );
    }
  }

  /// Waits for the daily-totals reply, or reports that it never came.
  ///
  /// Null here means the strap did not answer — which is a different thing from
  /// "the strap has no steps today", and the caller can tell them apart.
  Future<DeviceDailyTotals?> awaitDailyTotals() async {
    final already = dailyTotals;
    if (already != null) return already;
    try {
      return await _dailyTotalsReply.future.timeout(dailyTotalsWait);
    } on TimeoutException {
      AppLog.warning(
        'ble',
        'the strap did not report its daily totals within '
            '${dailyTotalsWait.inMilliseconds} ms',
      );
      return null;
    }
  }

  void _handlePayload(int endpoint, Uint8List payload) {
    AppLog.info(
      'ble',
      'endpoint 0x${endpoint.toRadixString(16).padLeft(4, '0')} '
          '(${payload.length}B)',
    );
    if (endpoint == kDailyTotalsEndpoint &&
        payload.length >= 15 &&
        payload[0] == 0x04 &&
        payload[1] == 0x01) {
      _readDailyTotals(payload);
    }
    if (endpoint == 0x0000 && payload.length >= 3 && payload[0] == 0x04) {
      _readServiceList(payload);
    }
  }

  /// Daily activity totals reply — see [DeviceDailyTotals] for the offsets and
  /// for why this value is the authoritative step count.
  void _readDailyTotals(Uint8List payload) {
    final bd = ByteData.sublistView(payload);
    final totals = DeviceDailyTotals(
      steps: bd.getUint32(3, Endian.little),
      distanceM: bd.getUint32(7, Endian.little),
      calories: bd.getUint32(11, Endian.little),
      readAt: DateTime.now(),
    );
    dailyTotals = totals;
    if (!_dailyTotalsReply.isCompleted) _dailyTotalsReply.complete(totals);
    AppLog.info('ble', '$totals');
  }

  /// Services list reply: `[0x04, count u16 LE, (endpoint u16 LE, encrypted u8) × N]`.
  ///
  /// Kept from the legacy client because of what it proves: the strap reports
  /// activity-fetch service `0x004b` as UNSUPPORTED, which is what makes the
  /// char-0x0004 path correct rather than a fallback.
  void _readServiceList(Uint8List payload) {
    final bd = ByteData.sublistView(payload);
    final n = bd.getUint16(1, Endian.little);
    final services = <String>[];
    var has4b = false;
    var off = 3;
    for (var i = 0; i < n && off + 3 <= payload.length; i++) {
      final ep = bd.getUint16(off, Endian.little);
      final encrypted = payload[off + 2] != 0;
      if (ep == 0x004b) has4b = true;
      services.add(
        '0x${ep.toRadixString(16).padLeft(4, '0')}${encrypted ? '*' : ''}',
      );
      off += 3;
    }
    AppLog.info('ble', 'services ($n) [*=encrypted]: ${services.join(' ')}');
    AppLog.info(
      'ble',
      'activity-fetch service 0x004b supported: $has4b '
          '(false ⇒ the char-0x0004 path is correct)',
    );
  }

  /// Cancels every subscription and drops the connection.
  Future<void> close() async {
    _route = null;
    await _chunkedSub?.cancel();
    await _controlSub?.cancel();
    await _dataSub?.cancel();
    _chunkedSub = null;
    _controlSub = null;
    _dataSub = null;
    await _link.close();
  }
}
