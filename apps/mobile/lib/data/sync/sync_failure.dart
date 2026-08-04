/// One failure of a sync, keeping the three sentences the original wrote.
///
/// ## Why this exists rather than a shared supertype
///
/// A sync can fail in two vocabularies. The pre-flight scan throws
/// [PairingFailure] (`Bluetooth is off`, `That strap didn't advertise in 12
/// seconds`) and the protocol throws [StrapFailure] (`The strap rejected the
/// stored pairing key`, `The strap went quiet mid-handshake`). Both unions were
/// written to the same rule — a named case per failure, each with a headline, a
/// remedy and a stable code — and neither should be retrofitted into the other's
/// hierarchy just so one field can hold either.
///
/// So this carries the three sentences **verbatim** and keeps [source] pointing
/// at the case they came from. Nothing is summarised, nothing is mapped onto a
/// nearest neighbour, and there is no `other` bucket. The brief's rule for the
/// connection state is that the taxonomy must be surfaced rather than collapsed
/// to a dot; copying the specific words is how that is kept, and [source] is
/// there so a screen that wants to branch on a particular case still can.
library;

import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:meta/meta.dart';

/// A named reason a sync stopped, from either failure taxonomy.
@immutable
class SyncFailure {
  /// Prefer [SyncFailure.strap] or [SyncFailure.pairing].
  const SyncFailure({
    required this.headline,
    required this.remedy,
    required this.code,
    required this.source,
  });

  /// A protocol-layer failure — connect, handshake, characteristics.
  SyncFailure.strap(StrapFailure failure)
    : this(
        headline: failure.headline,
        remedy: failure.remedy,
        code: failure.code,
        source: failure,
      );

  /// A radio or presence failure raised by the pre-flight scan.
  SyncFailure.pairing(PairingFailure failure)
    : this(
        headline: failure.headline,
        remedy: failure.remedy,
        code: failure.code,
        source: failure,
      );

  /// A short, specific sentence naming *which* failure this is.
  final String headline;

  /// What the owner can do next. Never empty — both source unions guarantee it.
  final String remedy;

  /// A stable, secret-free identifier for the log and for tests.
  final String code;

  /// The case this came from: a [StrapFailure] or a [PairingFailure].
  ///
  /// Kept so nothing is lost in the copy. A screen that wants to treat, say,
  /// [BluetoothOff] specially can still ask; one that does not gets two correct
  /// sentences without knowing either union exists.
  final Object source;

  @override
  String toString() => 'SyncFailure($code)';
}
