/// Paired. What is held, where it is held, and how to undo it.
///
/// The end of the flow is also the screen an owner returns to months later
/// asking "what does this app actually have of mine?" — so it answers that
/// rather than saying "Success!" and moving on. Whether the Zepp sign-in was
/// kept is stated either way, because "we did not store your password" is only
/// reassuring if the same screen would have admitted the opposite.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The paired state, with an unpair action.
class PairedSummary extends StatelessWidget {
  /// [zeppRemembered] drives the sentence about the account credential.
  const PairedSummary({
    required this.strap,
    required this.zeppRemembered,
    required this.onUnpair,
    required this.onDone,
    super.key,
  });

  /// The strap we hold credentials for.
  final PairedStrap strap;

  /// Whether a Zepp sign-in is also in the keystore.
  final bool zeppRemembered;

  /// Forgets everything about this pairing.
  final VoidCallback onUnpair;

  /// Leaves the pairing screen.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paired', style: text.titleMedium),
          const SizedBox(height: Insets.sm),
          Text(strap.mac, style: text.titleSmall),
          const SizedBox(height: Insets.lg),
          Text(
            PairingDisclosure.whatIsAlwaysStored,
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            zeppRemembered
                ? 'Your Zepp email and password are also in the keystore, '
                      'because you asked us to remember them. Unpairing removes '
                      'them too.'
                : 'Nothing about your Zepp account was kept — not the password, '
                      'not the session. Only the strap.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              FilledButton(onPressed: onDone, child: const Text('Done')),
              const SizedBox(width: Insets.md),
              OutlinedButton(onPressed: onUnpair, child: const Text('Unpair')),
            ],
          ),
        ],
      ),
    );
  }
}
