/// When to try the strap again, and when trying again is a battery bug.
///
/// ## The two failures this file exists to prevent
///
/// **A tight reconnect loop.** The app holds the link while it is in front, so a
/// strap left at home would otherwise be scanned for, continuously, for as long
/// as the owner has Healthee open. Twelve seconds of radio per attempt, forever.
/// That is a battery bug that looks like a feature, which is why the delay grows.
///
/// **Retrying something that cannot succeed.** Bluetooth is off; the permission
/// was refused; the key on the strap changed; another app is holding it. None of
/// those is fixed by waiting, and hammering the radio against them spends power
/// to keep re-deriving a sentence the owner has already read. Those stop.
///
/// ## "Permanent" means "no wait will fix this", not "never again"
///
/// Bluetooth being off is the clearest case: it is entirely recoverable, but
/// only by the owner, and every one of these failures ships with a [remedy]
/// naming the action. So the link stops its automatic retries and rests on the
/// failure with its remedy on screen; `Sync now` and the next foreground both
/// start again from a clean attempt counter. Calling that "permanent" is a
/// statement about the retry loop, not about the strap.
library;

import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/sync/sync_failure.dart';
import 'package:meta/meta.dart';

/// The delay before each successive attempt, and the floor it settles at.
///
/// Chosen for the case that actually happens: the owner walks out of range and
/// walks back. The first three delays cover a short interruption within half a
/// minute; the last is the steady state for a strap that is genuinely elsewhere,
/// where one 12-second scan every five minutes is ~4% radio duty and still
/// reconnects on its own when the band comes back.
const List<Duration> kReconnectDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 6),
  Duration(seconds: 20),
  Duration(seconds: 60),
  Duration(minutes: 5),
];

/// Decides whether to try again, and how long to wait first.
@immutable
class ReconnectPolicy {
  /// The production policy. [delays] is overridden only by tests.
  const ReconnectPolicy({this.delays = kReconnectDelays});

  /// The schedule, shortest first. The last entry is the steady state.
  final List<Duration> delays;

  /// How long to wait before attempt number [attempt] (0-based).
  ///
  /// Holds at the last delay rather than giving up, because the app is in the
  /// foreground: the owner can see the state, and a strap that comes back into
  /// range should reconnect without being asked to.
  Duration delayFor(int attempt) =>
      delays[attempt < delays.length - 1 ? attempt : delays.length - 1];

  /// Whether retrying [failure] on a timer can ever help.
  ///
  /// Exhaustive over both taxonomies on purpose. A `default` branch here would
  /// silently classify the next failure somebody adds, and the two directions of
  /// being wrong are not symmetric: a transient misfiled as permanent costs one
  /// tap, a permanent misfiled as transient costs the battery all day.
  bool isPermanent(SyncFailure failure) => switch (failure.source) {
    // ── the radio, or our right to use it ──────────────────────────────────
    BluetoothOff() => true,
    BluetoothUnavailable() => true,
    BluetoothPermissionDenied() => true,
    // ── credentials ────────────────────────────────────────────────────────
    StrapNotPaired() => true,
    MalformedPairingInput() => true,
    WrongZeppCredentials() => true,
    NoBoundDevices() => true,
    // The strap says the stored key is wrong. It will say so again in two
    // seconds, and in five minutes. Re-pairing is the only way through.
    HandshakeRefused(isWrongKey: true) => true,
    // Somebody else has the strap. Ours to report, theirs to release.
    StrapHeldElsewhere() => true,
    // It connected and the protocol is not there — a firmware problem, not a
    // moment's problem.
    StrapChannelsMissing() => true,
    // ── worth another go ───────────────────────────────────────────────────
    StrapNotInRange() => false,
    StrapUnreachable() => false,
    HandshakeTimedOut() => false,
    HandshakeRefused() => false,
    ZeppApiChanged() => false,
    NoNetwork() => false,
    // `SyncFailure.source` is typed `Object` so neither union had to be
    // retrofitted into the other's hierarchy (see `sync_failure.dart`). That
    // leaves this switch open at the type level, so the honest default is the
    // conservative one: do not retry something we cannot name.
    _ => true,
  };
}
