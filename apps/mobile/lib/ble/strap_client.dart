/// The way in: connect to the paired strap, authenticate, pull a day.
///
/// This is where the credentials enter the protocol layer, and the shape of it
/// is the whole point of the rebuild. The legacy app read its MAC and AUTHKEY
/// from `String.fromEnvironment` — baked into the binary at build time, which
/// is what made it a single-owner app. Here they come from
/// `PairingRepository.pairedStrap()`, which reads the platform keystore and
/// returns a validated [PairedStrap] or null. `core/env.dart` says at length
/// why neither value may ever be a dart-define again.
///
/// Nothing in `ble/` reads a dart-define. If a future file here does, that is
/// the legacy bug being carried forward.
///
/// ## Injection
///
/// Two collaborators, both injected: the repository that holds the credentials,
/// and a [StrapLinkFactory] that builds the radio. In the app the factory is
/// [BluetoothStrapLink.new]; in a test it is a fake device that answers the
/// handshake from `research/protocol/zeppos_ble_handshake.md`.
library;

import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/models/strap_sync_result.dart';
import 'package:healthee/ble/models/strap_sync_window.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/strap_session.dart';
import 'package:healthee/ble/strap_sync.dart';
import 'package:healthee/ble/transport/bluetooth_strap_link.dart';
import 'package:healthee/ble/transport/strap_link.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'strap_client.g.dart';

/// Opens authenticated sessions with the paired strap.
class StrapClient {
  /// [pairing] supplies the MAC and the auth key; [linkFactory] the radio.
  const StrapClient({
    required this.pairing,
    required this.linkFactory,
    this.handshakeTimeout = kHandshakeTimeout,
    this.dailyTotalsWait = kDailyTotalsWait,
  });

  /// Where the credentials come from. Never a dart-define.
  final PairingRepository pairing;

  /// Builds the transport for a MAC.
  final StrapLinkFactory linkFactory;

  /// How long the handshake may take. Shortened only by tests.
  final Duration handshakeTimeout;

  /// How long to wait for the daily-totals reply. Shortened only by tests.
  final Duration dailyTotalsWait;

  /// Connects and runs the handshake.
  ///
  /// The caller owns the returned session and MUST close it. Throws
  /// [StrapException] carrying [StrapNotPaired], [StrapUnreachable],
  /// [StrapChannelsMissing], [HandshakeRefused] or [HandshakeTimedOut] — a
  /// missing pairing and a refused key are different problems with different
  /// remedies, and stay distinguishable all the way up.
  Future<StrapSession> connect() async {
    final strap = await pairing.pairedStrap();
    if (strap == null) {
      throw const StrapException(StrapNotPaired());
    }
    AppLog.info('ble', 'connecting to strap …${strap.shortMac}');

    final session = StrapSession(
      linkFactory(strap.mac),
      handshakeTimeout: handshakeTimeout,
      dailyTotalsWait: dailyTotalsWait,
    );
    try {
      await session.open(parseAuthKey(strap.authKey));
    } on StrapException {
      // Close what was opened before rethrowing: a half-open link holds the
      // strap, and the strap accepts one connection at a time — leaking it
      // makes the next attempt fail for a reason that has nothing to do with
      // the first.
      await session.close();
      rethrow;
    }
    return session;
  }

  /// Connect, sync once, disconnect — the whole protocol layer in one call.
  ///
  /// The session is closed on every path, including a failed sync, for the
  /// reason above.
  Future<StrapSyncResult> syncOnce(StrapSyncWindow window) async {
    final session = await connect();
    try {
      return await StrapSync(session).run(window);
    } finally {
      await session.close();
    }
  }
}

/// The app's strap client.
@Riverpod(keepAlive: true)
StrapClient strapClient(Ref ref) {
  return StrapClient(
    pairing: ref.watch(pairingRepositoryProvider),
    linkFactory: BluetoothStrapLink.new,
  );
}
