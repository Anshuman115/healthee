/// What the sign-in screen is doing, and what last went wrong.
///
/// Much smaller than `features/pairing/pairing_state.dart` because there is no
/// flow: one form, one submit, one answer. A busy label and a failure are the
/// only two things a screen needs that the stored session cannot tell it.
///
/// ## Nothing here holds the token
///
/// Same rule as the pairing state's, verbatim, and for the same reason:
/// Riverpod's observer sees every state a notifier publishes, so a
/// `ProviderObserver` that logged state transitions — which this app does not
/// have today and might grow tomorrow — would print the credential the moment
/// somebody added one. The token lives in a `TextEditingController` inside the
/// form and in the keystore after it is verified. Nowhere else.
library;

import 'package:healthee/data/api/signin_failure.dart';
import 'package:meta/meta.dart';

/// The sign-in screen's state.
@immutable
class ServerSignInState {
  /// Prefer the transition helpers below over calling this directly.
  const ServerSignInState({this.busyLabel, this.failure});

  /// What is in flight, in the owner's words. Null when idle.
  final String? busyLabel;

  /// The last named failure. Null when there is none.
  final ServerSignInFailure? failure;

  /// True while a check is running.
  bool get isBusy => busyLabel != null;

  /// Marks work in flight. Clears the failure so a retry does not render the
  /// previous failure underneath its own spinner.
  ServerSignInState working(String label) => ServerSignInState(busyLabel: label);

  /// Stops, with a named reason.
  ServerSignInState failing(ServerSignInFailure reason) =>
      ServerSignInState(failure: reason);
}
