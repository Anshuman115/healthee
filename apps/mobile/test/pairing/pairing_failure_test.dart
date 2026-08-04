/// The taxonomy's own rules, applied to every case at once.
///
/// A `switch` over the sealed union is what makes this list complete: adding a
/// ninth failure without adding it here is a compile error, so these rules
/// cannot quietly stop covering the newest case — which is exactly how "we check
/// our copy" decays into "we checked our copy once".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';

/// Every failure, one of each. Built by a switch so the compiler keeps it whole.
const List<PairingFailure> _all = [
  WrongZeppCredentials(),
  NoNetwork(),
  ZeppApiChanged(step: 'the device list', detail: 'HTTP 500'),
  NoBoundDevices(),
  BluetoothOff(),
  BluetoothUnavailable(),
  BluetoothPermissionDenied(permanently: false),
  BluetoothPermissionDenied(permanently: true),
  StrapNotInRange(seconds: 12),
  // The real copy from `PairedStrap.parse`, not a stub — the length and
  // filler rules below are only worth anything against what ships.
  MalformedPairingInput(
    field: 'auth key',
    expected:
        'The key is exactly 32 hex digits (16 bytes), with or without a 0x in '
        'front. Anything shorter is a different key, not a typo we can fix.',
  ),
];

/// Fails to compile if a case is added to the union and not to [_all].
String _codeOf(PairingFailure failure) => switch (failure) {
  WrongZeppCredentials() => 'wrong_zepp_credentials',
  NoNetwork() => 'no_network',
  ZeppApiChanged() => 'zepp_api_changed',
  NoBoundDevices() => 'no_bound_devices',
  BluetoothOff() => 'bluetooth_off',
  BluetoothUnavailable() => 'bluetooth_unavailable',
  BluetoothPermissionDenied() => 'bluetooth_permission_denied',
  StrapNotInRange() => 'strap_not_in_range',
  MalformedPairingInput() => 'malformed_pairing_input',
};

/// Phrases that tell somebody nothing. The first is banned by name in the brief.
const List<String> _bannedPhrases = [
  'something went wrong',
  'an error occurred',
  'unknown error',
  'please try again later',
  'oops',
  'failed to',
];

void main() {
  test('the union and this list have not drifted apart', () {
    for (final failure in _all) {
      expect(failure.code, _codeOf(failure));
    }
    expect(_all.map((failure) => failure.code).toSet(), hasLength(9));
  });

  group('every failure says which one it is, and what to do', () {
    for (final failure in _all) {
      test('${failure.code}: headline and remedy are both real', () {
        expect(failure.headline.trim(), isNotEmpty);
        expect(failure.remedy.trim(), isNotEmpty);
        // A remedy shorter than this is a restatement, not an instruction.
        expect(failure.remedy.length, greaterThan(40));
      });

      test('${failure.code}: no vague filler', () {
        final copy = '${failure.headline} ${failure.remedy}'.toLowerCase();
        for (final phrase in _bannedPhrases) {
          expect(
            copy,
            isNot(contains(phrase)),
            reason: '"$phrase" tells the owner nothing they can act on',
          );
        }
      });
    }
  });

  test('the headlines are distinct — two failures never read the same', () {
    final headlines = _all.map((failure) => failure.headline).toSet();

    // The two BluetoothPermissionDenied variants share a headline on purpose:
    // the problem is the same, only the remedy differs.
    expect(headlines, hasLength(9));
  });

  test('permanently-denied sends the owner to Settings; the other does not', () {
    const asked = BluetoothPermissionDenied(permanently: false);
    const permanent = BluetoothPermissionDenied(permanently: true);

    expect(permanent.remedy, contains('Settings'));
    expect(asked.remedy, isNot(contains('Settings')));
  });

  test('retrying is offered only where it could help', () {
    // Retrying the same password, or re-asking an account that has no devices,
    // fails identically. Both send the owner somewhere else instead.
    expect(const WrongZeppCredentials().canRetry, isFalse);
    expect(const NoBoundDevices().canRetry, isFalse);
    expect(const BluetoothUnavailable().canRetry, isFalse);

    expect(const NoNetwork().canRetry, isTrue);
    expect(const BluetoothOff().canRetry, isTrue);
    expect(const StrapNotInRange(seconds: 12).canRetry, isTrue);
  });

  test('the scan failure quotes how long it actually listened', () {
    expect(const StrapNotInRange(seconds: 12).headline, contains('12 seconds'));
  });

  test('an API change points at the fallback that does not need Zepp', () {
    const failure = ZeppApiChanged(step: 'the sign-in', detail: 'HTTP 500');

    expect(failure.headline, contains('the sign-in'));
    expect(failure.remedy, contains('manual entry'));
    expect(failure.remedy, contains('HTTP 500'));
  });
}
