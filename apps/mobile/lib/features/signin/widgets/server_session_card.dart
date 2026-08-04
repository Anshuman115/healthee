/// What is held: which server this phone is signed in to, and how to stop.
///
/// The counterpart of `features/pairing/widgets/paired_summary.dart`, and it
/// exists for the same reason: an app that already holds a credential should
/// show what it holds rather than a form that would silently overwrite it.
///
/// It names the server and does **not** show the token, revealed or otherwise.
/// A stored secret has no reason to be rendered — reading it back would put it
/// on a screen, in a screenshot and in the accessibility tree, and nothing here
/// needs it. Replacing it means signing out and signing in again, which is one
/// tap more and no ambiguity about what is stored.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The current session, with sign-out.
class ServerSessionCard extends StatelessWidget {
  /// [baseUrl] is the address the stored token was accepted by.
  const ServerSessionCard({
    required this.baseUrl,
    required this.onSignOut,
    required this.onReplace,
    required this.enabled,
    super.key,
  });

  /// The server this phone talks to.
  final String baseUrl;

  /// Clears the token from the keystore.
  final VoidCallback onSignOut;

  /// Opens the form again, to point at a different server.
  final VoidCallback onReplace;

  /// False while sign-out is in flight.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signed in', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Text(baseUrl, style: text.titleSmall),
          const SizedBox(height: Insets.sm),
          Text(
            'A token for this server is in this phone\'s keystore, and it was '
            'checked against the server before it was saved.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Signing out deletes the token from this phone. Everything your '
            'strap measured stays here and keeps being recorded; the readings '
            'the server works out simply stop until you sign in again.',
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              // Outlined, not filled: brief §2 keeps the accent for the primary
              // path, and leaving is not it.
              OutlinedButton(
                onPressed: enabled ? onSignOut : null,
                child: const Text('Sign out'),
              ),
              const SizedBox(width: Insets.sm),
              TextButton(
                onPressed: enabled ? onReplace : null,
                child: const Text('Use a different server'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
