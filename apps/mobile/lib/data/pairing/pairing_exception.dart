/// The one exception the pairing layer throws, carrying a named failure.
///
/// It exists so the boundary between "the data layer knows the request died" and
/// "the screen knows what to tell the owner" is a single typed hop. Standards §3
/// requires a `catch` to have an `on` clause; `on PairingException` is that
/// clause, and because it wraps a sealed [PairingFailure] the handler on the
/// other side is exhaustive rather than a string comparison.
library;

import 'package:healthee/data/pairing/pairing_failure.dart';

/// A pairing step failed for a reason we can name.
class PairingException implements Exception {
  /// Wraps [failure] for throwing across an async boundary.
  const PairingException(this.failure);

  /// Which failure this is, and the copy that goes with it.
  final PairingFailure failure;

  /// Deliberately the secret-free [PairingFailure.code], not the copy and not
  /// any captured detail. An exception's `toString` ends up in places nobody
  /// audits — a crash reporter, a `Future` error print — so it may never be the
  /// thing that carries a token out of the app.
  @override
  String toString() => 'PairingException(${failure.code})';
}
