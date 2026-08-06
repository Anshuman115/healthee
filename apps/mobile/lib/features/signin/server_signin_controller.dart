/// The sign-in screen's one piece of logic. The widgets below it only draw.
///
/// Both methods have the same shape as the pairing controller's: publish a busy
/// label, run one repository call, land on idle or on a named failure. `on
/// ServerSignInException` is the only catch and it always sets
/// [ServerSignInState.failure], so "the button did nothing" is not reachable.
///
/// ## The token passes through and is not kept
///
/// [signIn] takes it as a parameter, hands it to the repository, and returns.
/// It is never assigned to a field and never put in the state — see
/// `server_signin_state.dart`. The repository is what decides whether it is
/// stored, and it only stores one the server accepted.
library;

import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/features/signin/server_signin_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_signin_controller.g.dart';

/// Drives the server sign-in screen.
@riverpod
class ServerSignInController extends _$ServerSignInController {
  @override
  ServerSignInState build() => const ServerSignInState();

  /// Checks [token] against [url] and, only if the server accepts it, stores it.
  ///
  /// Returns true when the sign-in landed, so the screen can leave without
  /// having to re-derive that from the state it just published.
  Future<bool> signIn({required String url, required String token}) async {
    state = state.working('Checking with your server…');
    try {
      await ref.read(serverSessionRepositoryProvider).signIn(
        url: url,
        token: token,
      );
    } on ServerSignInException catch (error) {
      state = state.failing(error.failure);
      return false;
    }
    ref.invalidate(serverSessionProvider);
    state = const ServerSignInState();
    return true;
  }

  /// Clears the session. The strap pairing is deliberately untouched.
  Future<void> signOut() async {
    state = state.working('Signing out…');
    await ref.read(serverSessionRepositoryProvider).signOut();
    ref.invalidate(serverSessionProvider);
    state = const ServerSignInState();
  }

  /// Drops a failure so the form is clean again, e.g. after an edit.
  void clearFailure() {
    if (state.failure != null) {
      state = const ServerSignInState();
    }
  }
}
