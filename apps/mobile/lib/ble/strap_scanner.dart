/// "Can we actually see this strap?" — the contract, and what an answer looks like.
///
/// Holding a MAC and an auth key is not the same as being able to talk to the
/// strap. The account route can hand back a device the owner sold, or a second
/// strap in a drawer, and nothing about those credentials would look wrong. One
/// scan turns "we have credentials" into "we have credentials **and** it is
/// here", which is the difference worth a step in the flow.
///
/// This is NOT the BLE protocol layer. No connection, no handshake, no
/// characteristic reads — an advertisement is the whole of it. The protocol
/// lands separately (`ble/README.md`).
///
/// ## Why an interface with a provider
///
/// `flutter_blue_plus` and `permission_handler` are platform channels, which a
/// `flutter test` host does not have. Behind this interface the pairing screen's
/// scan states are testable with a fake; in front of it they would be untestable,
/// which in practice means untested — and "Bluetooth off" and "not in range" are
/// two of the failure messages this work package exists to get right.
library;

import 'package:healthee/ble/bluetooth_strap_scanner.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'strap_scanner.g.dart';

/// How long to listen before calling a strap absent.
///
/// The strap advertises on a slow duty cycle when idle, so a two-second look is
/// a coin toss. Twelve seconds is long enough to be evidence and short enough
/// that nobody walks away from it; the number is in the [StrapNotInRange]
/// message so the owner knows what was actually tried.
const Duration kScanWindow = Duration(seconds: 12);

/// The result of looking for a strap. Failures are thrown, not returned:
/// Bluetooth off, permission denied and not-in-range are all [PairingFailure]s.
@immutable
sealed class ScanOutcome {
  /// Base constructor.
  const ScanOutcome();
}

/// The strap advertised, and here is how strongly.
final class StrapSighted extends ScanOutcome {
  /// [rssi] in dBm — negative, closer to zero is nearer.
  const StrapSighted({required this.rssi, required this.advertisedName});

  /// Signal strength in dBm.
  final int rssi;

  /// The name in the advertisement, empty when it carried none.
  final String advertisedName;
}

/// The platform cannot answer this question, and here is why.
///
/// iOS is the real case: CoreBluetooth never exposes a peripheral's hardware
/// address — it hands out a per-install UUID instead — so a MAC from the Zepp
/// account cannot be matched against anything a scan returns there. Reporting
/// "not in range" would be a lie about the strap; this says the truth about the
/// platform, and pairing continues without the confirmation.
final class ScanNotPossibleHere extends ScanOutcome {
  /// [reason] is shown to the owner verbatim.
  const ScanNotPossibleHere(this.reason);

  /// Why no answer is available on this platform.
  final String reason;
}

/// Looks for one strap, by MAC.
abstract interface class StrapScanner {
  /// Scans for [mac] for up to [window].
  ///
  /// Returns a [ScanOutcome]; throws [PairingException] carrying [BluetoothOff],
  /// [BluetoothUnavailable], [BluetoothPermissionDenied] or [StrapNotInRange].
  Future<ScanOutcome> confirmInRange(String mac, {Duration window});
}

/// The app's scanner. Overridden in tests.
@Riverpod(keepAlive: true)
StrapScanner strapScanner(Ref ref) => const BluetoothStrapScanner();
