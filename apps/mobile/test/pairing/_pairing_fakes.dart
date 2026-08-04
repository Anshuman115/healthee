/// Fakes for the two platform edges pairing touches: the keystore and the radio.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';

/// A keystore that is a map, and remembers what it was asked to do.
class FakeSecretStore implements SecretStore {
  /// Everything currently stored, key → value.
  final Map<String, String> values = {};

  /// Every write, in order: `('write', key, value)` / `('delete', key, null)`.
  final List<(String, String, String?)> operations = [];

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
    operations.add(('write', key, value));
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
    operations.add(('delete', key, null));
  }
}

/// A scanner that answers however the test says, without a radio.
class FakeStrapScanner implements StrapScanner {
  /// [outcome] is returned; [failure], if set, is thrown instead.
  FakeStrapScanner({this.outcome, this.failure});

  /// What a successful scan reports.
  ScanOutcome? outcome;

  /// What a failing scan throws.
  PairingFailure? failure;

  /// The MACs this scanner was asked about.
  final List<String> asked = [];

  @override
  Future<ScanOutcome> confirmInRange(String mac, {Duration? window}) async {
    asked.add(mac);
    final reason = failure;
    if (reason != null) {
      throw PairingException(reason);
    }
    return outcome ?? const StrapSighted(rssi: -61, advertisedName: 'Helio');
  }
}
