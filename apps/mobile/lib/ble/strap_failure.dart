/// Every way talking to the strap can fail, named — and what to do about each.
///
/// The same rule `data/pairing/pairing_failure.dart` is built on: "something
/// went wrong" is banned, because it is the interface equivalent of a swallowed
/// exception. A `sealed` union rather than an error code, so the screen that
/// eventually renders these has an exhaustive `switch` at compile time.
///
/// Nothing here carries an auth key, a session key, or frame bytes. The nearest
/// thing to raw detail is [HandshakeRefused.reason], which is the short
/// protocol-level phrase the handshake produced ("wrong auth key",
/// "pub-key reply too short (12)") and never a payload.
library;

import 'package:meta/meta.dart';

/// A named failure of the BLE protocol layer.
@immutable
sealed class StrapFailure {
  /// Base constructor. Use one of the subclasses.
  const StrapFailure();

  /// A short, specific sentence naming *which* failure this is.
  String get headline;

  /// What the owner can do next. Never empty.
  String get remedy;

  /// A stable, secret-free identifier for the log.
  String get code;
}

/// There is no paired strap to talk to.
///
/// Distinct from every connection failure below: nothing was attempted, because
/// there is nothing to attempt it against. Half a pairing reads as none — see
/// `PairingRepository.pairedStrap`.
final class StrapNotPaired extends StrapFailure {
  /// No MAC + key in the keystore.
  const StrapNotPaired();

  @override
  String get headline => 'No strap is paired with this phone';

  @override
  String get remedy =>
      'Pair the strap first. Syncing needs its address and its key, and neither '
      'is stored yet.';

  @override
  String get code => 'strap_not_paired';
}

/// The BLE connection could not be established.
final class StrapUnreachable extends StrapFailure {
  /// [detail] is a short, secret-free hint — a timeout, a platform error name.
  const StrapUnreachable(this.detail);

  /// Why the connection did not come up.
  final String detail;

  @override
  String get headline => "Couldn't connect to the strap";

  @override
  String get remedy =>
      'Bring it close and wake its screen, and make sure the Zepp app or '
      'Gadgetbridge is not holding the connection — the strap accepts one at a '
      'time. ($detail)';

  @override
  String get code => 'strap_unreachable';
}

/// Something else on this phone already holds the strap.
///
/// ## Why this is its own case rather than "not in range"
///
/// Most BLE peripherals accept one connection at a time, and a peripheral that
/// is already connected **stops advertising**. So a strap held by the Zepp app
/// or Gadgetbridge looks, to a scan, exactly like a strap left at home — and
/// telling the owner "that strap didn't advertise in 12 seconds" about a band on
/// their own wrist is precisely the kind of plausible-but-wrong sentence this
/// taxonomy exists to prevent. The remedy is different too: nothing about moving
/// closer will help.
///
/// **Raised only on evidence.** `StrapScanner.isConnectedElsewhere` asks the
/// platform whether it holds a live system connection to that address; the
/// answer is only trusted when it is yes. "No evidence" stays [StrapNotInRange],
/// whose own remedy already mentions the possibility.
final class StrapHeldElsewhere extends StrapFailure {
  /// The platform reports a live connection to the strap that is not ours.
  const StrapHeldElsewhere();

  @override
  String get headline => 'Another app on this phone is holding the strap';

  @override
  String get remedy =>
      'The strap accepts one connection at a time, and while it is held it stops '
      'advertising — so nothing here can reach it. Disconnect it in the Zepp app '
      '(or Gadgetbridge) and try again.';

  @override
  String get code => 'strap_held_elsewhere';
}

/// Connected, but the characteristics the protocol needs are not there.
///
/// Either it is not a ZeppOS strap, or the firmware has moved them. Reporting
/// this as "couldn't connect" would send the owner to look at the wrong thing.
final class StrapChannelsMissing extends StrapFailure {
  /// [which] names the characteristic pair that was absent.
  const StrapChannelsMissing(this.which);

  /// Which pair is missing: `'chunked (0x0016/0x0017)'`, `'activity fetch'`.
  final String which;

  @override
  String get headline => 'This device does not speak the strap protocol';

  @override
  String get remedy =>
      'It connected, but the $which characteristics it needs are not there. If '
      'this really is a Helio Strap, its firmware has changed and this is our '
      'problem to fix, not yours.';

  @override
  String get code => 'strap_channels_missing';
}

/// The handshake was refused or could not complete.
final class HandshakeRefused extends StrapFailure {
  /// [reason] is the protocol-level phrase, never a payload.
  const HandshakeRefused(this.reason);

  /// Why the handshake ended, in the protocol's own words.
  final String reason;

  /// Whether the strap said, specifically, that the key is wrong (status 0x25).
  bool get isWrongKey => reason == 'wrong auth key';

  @override
  String get headline => isWrongKey
      ? 'The strap rejected the stored pairing key'
      : 'The strap did not complete the handshake';

  @override
  String get remedy => isWrongKey
      ? 'The key on the strap has changed — that happens when it is re-paired '
            'in the Zepp app. Pair it here again to pick up the new one.'
      : 'Try again with the strap close by and nothing else connected to it. '
            '($reason)';

  @override
  String get code => 'handshake_refused';
}

/// The handshake started and the strap stopped answering.
final class HandshakeTimedOut extends StrapFailure {
  /// [seconds] is how long we waited, so the message can say so.
  const HandshakeTimedOut({required this.seconds});

  /// The handshake window, in seconds.
  final int seconds;

  @override
  String get headline => 'The strap went quiet mid-handshake ($seconds s)';

  @override
  String get remedy =>
      'This is usually another app holding the strap — the Zepp app or '
      'Gadgetbridge. Disconnect it there and try again.';

  @override
  String get code => 'handshake_timed_out';
}
