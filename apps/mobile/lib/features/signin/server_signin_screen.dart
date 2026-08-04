/// The server sign-in screen: composition only.
///
/// Standards §3 — "a screen file lays out modules; each module widget lives in
/// its own file". The logic is in `server_signin_controller.dart`.
///
/// ## This screen is a destination, never a gate
///
/// Nothing redirects here. **Strap-only is a supported mode**: the whole
/// measured half of Today comes off this phone's own store and renders with no
/// network at all, and a sign-in wall in front of it would take the owner's own
/// measurements away until they satisfied a server. The screen is reached from
/// the Today data-health section, which already speaks about sync state and says
/// plainly when there is no session, and from the pairing screen, which is the
/// existing surface for "what this phone holds".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/features/signin/server_signin_controller.dart';
import 'package:healthee/features/signin/widgets/server_session_card.dart';
import 'package:healthee/features/signin/widgets/server_signin_form.dart';
import 'package:healthee/features/signin/widgets/signin_failure_card.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Sign in to the Healthee server, or review the session already held.
class ServerSignInScreen extends ConsumerWidget {
  /// [onDone] is the route back into the app. Null in tests.
  const ServerSignInScreen({this.onDone, super.key});

  /// Called after a sign-in lands.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your server')),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          AsyncView<ServerSessionStatus>(
            value: ref.watch(serverSessionProvider),
            onRetry: () => ref.invalidate(serverSessionProvider),
            loadingLabel: 'Checking what is already signed in',
            errorMessage: "Couldn't read this phone's keystore",
            builder: (context, session) =>
                _SignInBody(session: session, onDone: onDone),
          ),
        ],
      ),
    );
  }
}

class _SignInBody extends ConsumerStatefulWidget {
  const _SignInBody({required this.session, required this.onDone});

  final ServerSessionStatus session;
  final VoidCallback? onDone;

  @override
  ConsumerState<_SignInBody> createState() => _SignInBodyState();
}

class _SignInBodyState extends ConsumerState<_SignInBody> {
  /// True once the owner has asked to point at a different server, so the form
  /// replaces the summary without the session having been cleared first.
  bool _replacing = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverSignInControllerProvider);
    final controller = ref.read(serverSignInControllerProvider.notifier);
    final session = widget.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.signedIn && !_replacing)
          ServerSessionCard(
            baseUrl: session.baseUrl!,
            enabled: !state.isBusy,
            onSignOut: () => unawaited(controller.signOut()),
            onReplace: () => setState(() => _replacing = true),
          )
        else
          ServerSignInForm(
            // The stored server when there is one, so "use a different server"
            // starts from what is actually in use rather than from the build's
            // compiled-in default.
            initialUrl: session.baseUrl ?? Env.apiBaseUrl,
            enabled: !state.isBusy,
            onEdited: controller.clearFailure,
            onSubmit: (url, token) => unawaited(_submit(url: url, token: token)),
          ),
        if (state.failure case final failure?) ...[
          const SizedBox(height: Insets.lg),
          SignInFailureCard(failure: failure, onRetry: controller.clearFailure),
        ],
        if (state.isBusy) ...[
          const SizedBox(height: Insets.lg),
          LoadingState(label: state.busyLabel),
        ],
      ],
    );
  }

  /// Runs the check and leaves only if it landed.
  ///
  /// The `mounted` guard is not ceremony: the check is a network round trip and
  /// this screen can be popped while it is in flight.
  Future<void> _submit({required String url, required String token}) async {
    final controller = ref.read(serverSignInControllerProvider.notifier);
    final signedIn = await controller.signIn(url: url, token: token);
    if (!signedIn || !mounted) {
      return;
    }
    setState(() => _replacing = false);
    widget.onDone?.call();
  }
}
