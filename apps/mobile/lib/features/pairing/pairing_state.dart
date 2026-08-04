/// Where the owner is in the pairing flow, and what is happening to them.
///
/// A sealed [PairingStep] for *where*, plus two orthogonal fields for *what* —
/// a busy label and a failure. They are separate because they compose: a failure
/// belongs to the step it happened on ("Zepp said no" is a fact about the sign-in
/// form, not a screen of its own), and going back to a step must clear it.
///
/// ## Nothing here holds a password
///
/// The Zepp email and password live in private fields on the controller, not in
/// this object, and that is a rule rather than a preference. Riverpod's observer
/// sees every state a notifier publishes; a `ProviderObserver` that logs state
/// transitions — which this app does not have today and might grow tomorrow —
/// would print a credential the moment somebody added one. Keeping it out of the
/// state means that change cannot leak it.
library;

import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/pairing/zepp_device.dart';
import 'package:meta/meta.dart';

/// One screen of the flow.
@immutable
sealed class PairingStep {
  /// Base constructor.
  const PairingStep();
}

/// The Zepp email and password form. Where everyone starts.
final class ZeppSignInStep extends PairingStep {
  /// The sign-in form.
  const ZeppSignInStep();
}

/// Typing a MAC and a key by hand — the fallback, always reachable.
final class ManualEntryStep extends PairingStep {
  /// The manual form.
  const ManualEntryStep();
}

/// The account's straps, waiting to be tapped.
final class ChooseDeviceStep extends PairingStep {
  /// [devices] is never empty — an empty list is [NoBoundDevices] instead.
  const ChooseDeviceStep(this.devices);

  /// The usable devices Zepp returned.
  final List<ZeppDevice> devices;
}

/// One strap picked, being confirmed on the air before anything is stored.
final class ConfirmStrapStep extends PairingStep {
  /// [outcome] is null until a scan has finished.
  const ConfirmStrapStep({required this.strap, this.outcome});

  /// The strap about to be paired.
  final PairedStrap strap;

  /// What the scan found, once it has run.
  final ScanOutcome? outcome;

  /// The same step carrying a scan result.
  ConfirmStrapStep withOutcome(ScanOutcome result) =>
      ConfirmStrapStep(strap: strap, outcome: result);
}

/// Done. The credentials are in the keystore.
final class PairedStep extends PairingStep {
  /// [strap] is what was stored.
  const PairedStep(this.strap);

  /// The paired strap.
  final PairedStrap strap;
}

/// The whole screen's state.
@immutable
class PairingState {
  /// Prefer the transition helpers below over calling this directly.
  const PairingState({
    required this.step,
    this.busyLabel,
    this.failure,
    this.rememberZepp = false,
  });

  /// The starting state: sign in, idle, nothing remembered.
  const PairingState.start() : this(step: const ZeppSignInStep());

  /// Which screen of the flow.
  final PairingStep step;

  /// What is in flight, in the owner's words. Null when idle.
  final String? busyLabel;

  /// The last named failure on [step]. Null when there is none.
  final PairingFailure? failure;

  /// Whether the owner asked us to remember the Zepp sign-in. **Default false**
  /// — storing somebody's password is a thing they opt into, not out of.
  final bool rememberZepp;

  /// True while a step is running.
  bool get isBusy => busyLabel != null;

  /// Moves to [next], idle and with no failure. Arriving somewhere new clears
  /// the last thing that went wrong; carrying it forward would attach a sign-in
  /// error to a scan screen.
  PairingState at(PairingStep next) =>
      PairingState(step: next, rememberZepp: rememberZepp);

  /// Marks work in flight. Clears the failure so a retry does not render the
  /// previous failure underneath its own spinner.
  PairingState working(String label) =>
      PairingState(step: step, busyLabel: label, rememberZepp: rememberZepp);

  /// Stops, on the same step, with a named reason.
  PairingState failing(PairingFailure reason) =>
      PairingState(step: step, failure: reason, rememberZepp: rememberZepp);

  /// Stops, on the same step, with nothing wrong.
  PairingState idle() => PairingState(step: step, rememberZepp: rememberZepp);

  /// Records the opt-in, leaving everything else alone.
  PairingState remembering({required bool value}) => PairingState(
    step: step,
    busyLabel: busyLabel,
    failure: failure,
    rememberZepp: value,
  );
}
