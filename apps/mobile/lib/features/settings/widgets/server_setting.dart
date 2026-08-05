/// Your server — which one, whether this phone is signed in, and the way out.
///
/// This card moved off the pairing screen, where it had been living because the
/// Today avatar went there and that was "the only identity surface that exists".
/// It is not about pairing and never was: signing out of a server is not
/// unpairing a watch, and `data/api/server_session.dart` keeps them apart in the
/// keystore for the same reason.
///
/// **Sign-out is reached, not re-implemented.** `features/signin/` owns the whole
/// session — the probe, the storage order, the taxonomy and the sign-out — and
/// Standards §3 forbids a feature reaching into another's code. A second sign-out
/// button here would be a second call site for a keystore write whose correctness
/// is the difference between "signed out" and "believes it is signed in and
/// serves 401s to every screen".
///
/// The address is shown, the token never is. It is not read back for display at
/// all: `server_session_card.dart` argues why a stored secret with no consumer
/// should not acquire one just so it can be rendered into a screenshot and an
/// accessibility tree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The server session, in one row.
class ServerSetting extends ConsumerWidget {
  /// The server row.
  const ServerSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    // `.value` and not `.requireValue`: the keystore read is asynchronous and
    // announcing "not signed in" during it would flash the wrong answer at an
    // owner who already is.
    final session = ref.watch(serverSessionProvider).value;
    final signedIn = session?.signedIn ?? false;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your server', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Text(
            switch (session) {
              null => 'Checking…',
              _ when session.signedIn => 'Signed in',
              _ => 'Not signed in',
            },
            style: text.titleSmall,
          ),
          if (session?.baseUrl case final String address) ...[
            const SizedBox(height: Insets.xs),
            Text(address, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: Insets.sm),
          Text(
            signedIn
                ? 'Recovery, sleep health, debt, VO₂max and biological age are '
                      'worked out on this server. Signing out stops them and '
                      'leaves every measurement on this phone untouched.'
                : 'Your strap still syncs to this phone with no server at all. '
                      'Signing in adds the readings the server works out.',
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => context.go(Routes.serverSignIn),
              // The label names what is behind it. "Manage" would be a button
              // whose only documentation is the screen you have to open to read.
              child: Text(signedIn ? 'Sign out or change server' : 'Sign in to your server'),
            ),
          ),
        ],
      ),
    );
  }
}
