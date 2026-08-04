/// The one exception the BLE protocol layer throws, carrying a named failure.
///
/// Mirrors `data/pairing/pairing_exception.dart` deliberately: Standards §3
/// requires a `catch` to have an `on` clause, and `on StrapException` is that
/// clause. Because it wraps a sealed [StrapFailure], the handler on the far side
/// is exhaustive rather than a string comparison.
library;

import 'package:healthee/ble/strap_failure.dart';

/// A strap operation failed for a reason we can name.
class StrapException implements Exception {
  /// Wraps [failure] for throwing across an async boundary.
  const StrapException(this.failure);

  /// Which failure this is, and the copy that goes with it.
  final StrapFailure failure;

  /// Deliberately the secret-free [StrapFailure.code] only. An exception's
  /// `toString` ends up in a crash reporter or an unawaited-future print —
  /// places nobody audits — so it may never be what carries a key out.
  @override
  String toString() => 'StrapException(${failure.code})';
}
