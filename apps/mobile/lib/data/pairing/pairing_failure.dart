/// Every way pairing can fail, named — and what to do about each one.
///
/// **"Something went wrong" is banned in this product.** It is the interface
/// equivalent of a swallowed exception: it tells the owner a thing happened and
/// leaves them with nowhere to go. The rule the app already applies to *data* —
/// a withheld number names what is missing and what would restore it — applies
/// to *failures* for exactly the same reason, so every case below carries a
/// [headline] that says which failure this is and a [remedy] that says what to
/// do next.
///
/// A `sealed` union rather than an error code, so the screen's `switch` is
/// exhaustive at compile time. Adding a ninth failure without giving it copy and
/// a rendering is not something a reviewer has to notice; it does not build.
///
/// ## What is deliberately NOT in here
///
/// No case carries a password, a token, an auth key, or a response body. The
/// nearest thing to raw detail is [ZeppApiChanged.detail], which holds a status
/// code and a field name — `pairing_secrecy_test.dart` proves that boundary by
/// running the whole flow with sentinel secrets and asserting none of them
/// reaches a log line or a rendered string.
library;

import 'package:meta/meta.dart';

/// A named pairing failure, with the copy the screen renders.
@immutable
sealed class PairingFailure {
  /// Base constructor. Use one of the subclasses.
  const PairingFailure();

  /// A short, specific sentence naming *which* failure this is.
  String get headline;

  /// What the owner can do next. Never empty — a failure with no way forward is
  /// the state this whole file exists to prevent.
  String get remedy;

  /// A stable, secret-free identifier for the log. Not shown to a person.
  String get code;

  /// Whether re-running the same step is worth offering.
  ///
  /// False for [WrongZeppCredentials] (retrying the same password fails the same
  /// way) and for [NoBoundDevices] (the account's answer will not change by
  /// asking again). Both send the owner somewhere else instead.
  bool get canRetry => true;
}

/// Zepp rejected the email and password.
final class WrongZeppCredentials extends PairingFailure {
  /// The account sign-in was refused.
  const WrongZeppCredentials();

  @override
  String get headline => 'Zepp did not accept that email and password';

  @override
  String get remedy =>
      'Check them in the Zepp app itself, then type them again here. If you sign '
      'in to Zepp with Google or Facebook rather than a password, this route '
      'cannot work — use manual entry below.';

  @override
  String get code => 'wrong_zepp_credentials';

  @override
  bool get canRetry => false;
}

/// The request never reached Zepp.
final class NoNetwork extends PairingFailure {
  /// A connection-level failure: DNS, timeout, no route, TLS.
  const NoNetwork();

  @override
  String get headline => "Couldn't reach Zepp";

  @override
  String get remedy =>
      'This is a connection problem, not a wrong password — nothing was sent. '
      'Check the phone is online and try again.';

  @override
  String get code => 'no_network';
}

/// Zepp answered, in a shape this app does not understand.
///
/// The honest reading of "we got something back and could not parse it". It is
/// **not** used as a catch-all: a rejected password, an empty device list and a
/// dead connection each have their own case above and below, and only what
/// remains lands here.
final class ZeppApiChanged extends PairingFailure {
  /// [step] names the call in the owner's words; [detail] is a status code or a
  /// missing field name — never a body, never a token.
  const ZeppApiChanged({required this.step, required this.detail});

  /// Which of the three calls answered oddly, e.g. `'the device list'`.
  final String step;

  /// A short, secret-free hint: `'HTTP 500'`, `'no access token in the redirect'`.
  final String detail;

  @override
  String get headline => "Zepp's reply to $step is not one this app understands";

  @override
  String get remedy =>
      'This usually means Zepp changed their API — it is our problem to fix, not '
      'yours. Use manual entry below; it does not touch the Zepp account at all. '
      '($detail)';

  @override
  String get code => 'zepp_api_changed';
}

/// The account signed in, and has no straps bound to it.
final class NoBoundDevices extends PairingFailure {
  /// Zepp returned an empty device list.
  const NoBoundDevices();

  @override
  String get headline => 'That Zepp account has no devices bound to it';

  @override
  String get remedy =>
      'Pair the strap in the Zepp app once — that is what puts its key on the '
      'account for us to read. If you have more than one Zepp account, this may '
      'be the other one.';

  @override
  String get code => 'no_bound_devices';

  @override
  bool get canRetry => false;
}

/// Bluetooth is switched off.
final class BluetoothOff extends PairingFailure {
  /// The adapter is present but not on.
  const BluetoothOff();

  @override
  String get headline => 'Bluetooth is off';

  @override
  String get remedy =>
      'Turn Bluetooth on, then scan again. The credentials are already in hand — '
      'this step only confirms the strap is actually within reach.';

  @override
  String get code => 'bluetooth_off';
}

/// This device has no Bluetooth LE at all.
final class BluetoothUnavailable extends PairingFailure {
  /// No BLE adapter — an emulator, or a desktop build.
  const BluetoothUnavailable();

  @override
  String get headline => 'This device has no Bluetooth LE';

  @override
  String get remedy =>
      'Nothing here can talk to the strap. The pairing can still be saved, but a '
      'phone with Bluetooth LE has to do the syncing.';

  @override
  String get code => 'bluetooth_unavailable';

  @override
  bool get canRetry => false;
}

/// The owner declined the Bluetooth permission, or the system did.
final class BluetoothPermissionDenied extends PairingFailure {
  /// [permanently] is true once the OS will no longer show the prompt, which
  /// changes the remedy from "allow it" to "allow it in Settings".
  const BluetoothPermissionDenied({required this.permanently});

  /// Whether the OS has stopped asking.
  final bool permanently;

  @override
  String get headline => 'Healthee has no permission to scan for Bluetooth devices';

  @override
  String get remedy => permanently
      ? 'Android has stopped asking, so it has to be granted in Settings › Apps › '
            'Healthee › Permissions › Nearby devices. Scanning is the only thing '
            'this permission is used for.'
      : 'Allow the "nearby devices" permission when asked. Scanning is the only '
            'thing it is used for — Healthee never reads location from it.';

  @override
  String get code => 'bluetooth_permission_denied';
}

/// The scan ran and that MAC never advertised.
final class StrapNotInRange extends PairingFailure {
  /// [seconds] is how long the scan ran, so the message can say so.
  const StrapNotInRange({required this.seconds});

  /// The scan window, in seconds.
  final int seconds;

  @override
  String get headline => "That strap didn't advertise in $seconds seconds";

  @override
  String get remedy =>
      'Bring the strap close and wake its screen, and make sure the Zepp app is '
      'not connected to it — a strap already connected elsewhere stops '
      'advertising. Then scan again.';

  @override
  String get code => 'strap_not_in_range';
}

/// Manually typed input that cannot be a MAC or a key.
///
/// Caught before anything is stored: half a pairing is worse than none, because
/// it fails later, somewhere else, looking like a protocol bug.
final class MalformedPairingInput extends PairingFailure {
  /// [field] is what was wrong; [expected] is the shape it must have.
  const MalformedPairingInput({required this.field, required this.expected});

  /// The offending field, in the owner's words: `'MAC address'`, `'auth key'`.
  final String field;

  /// What a valid value looks like.
  final String expected;

  @override
  String get headline => "That $field isn't the right shape";

  @override
  String get remedy => expected;

  @override
  String get code => 'malformed_pairing_input';
}
