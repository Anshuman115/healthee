/// "Is the strap actually here?" — asked before fifteen seconds are spent on a
/// handshake, and asked the same way by everything that opens a session.
///
/// Extracted from `SyncEngine`, which used to own it privately, when the
/// foreground link became a second thing that connects (Standards §1: second
/// occurrence = extract). The two callers must agree, because the check is not
/// a formality — it is what decides the sentence the owner reads.
///
/// ## What the scan buys
///
/// Without it, a strap in another room fails as "went quiet mid-handshake
/// (15 s)", which sends someone to look at their pairing key rather than at
/// where they left the band.
///
/// ## The one upgrade this makes to the scan's own answer
///
/// A BLE peripheral that is already connected **stops advertising**, so "the
/// Zepp app is holding it" and "it is in another building" are the same silence.
/// When the scan comes up empty we ask the platform whether it holds a live
/// connection to that address, and only when the answer is yes does the failure
/// become [StrapHeldElsewhere] — a different problem with a different remedy,
/// and one that moving closer will never fix. A "no" keeps [StrapNotInRange],
/// whose remedy already raises the possibility. Nothing here upgrades a
/// suspicion into a certainty.
library;

import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/sync/sync_failure.dart';

/// Looks for the paired strap, and names what it found instead.
class PreflightScan {
  /// [pairing] supplies the MAC; [scanner] is the radio.
  const PreflightScan({required this.pairing, required this.scanner});

  /// Where the paired MAC comes from.
  final PairingRepository pairing;

  /// The presence check.
  final StrapScanner scanner;

  /// Runs the check.
  ///
  /// Returns null to proceed, or the named failure that stops the attempt.
  /// [ScanNotPossibleHere] proceeds — iOS cannot match a MAC at all, and
  /// refusing to sync there would be punishing the platform's honesty.
  Future<SyncFailure?> run() async {
    final strap = await pairing.pairedStrap();
    if (strap == null) {
      return SyncFailure.strap(const StrapNotPaired());
    }
    try {
      final outcome = await scanner.confirmInRange(strap.mac);
      if (outcome is ScanNotPossibleHere) {
        AppLog.info('sync', 'presence check unavailable: ${outcome.reason}');
      }
      return null;
    } on PairingException catch (error, stackTrace) {
      AppLog.failure('sync', 'looking for the paired strap', error, stackTrace);
      return _explain(error.failure, strap.mac);
    }
  }

  /// Turns "it did not advertise" into "somebody else has it", on evidence.
  Future<SyncFailure> _explain(PairingFailure failure, String mac) async {
    if (failure is! StrapNotInRange) {
      return SyncFailure.pairing(failure);
    }
    if (await scanner.isConnectedElsewhere(mac)) {
      return SyncFailure.strap(const StrapHeldElsewhere());
    }
    return SyncFailure.pairing(failure);
  }
}
