/// Paired. What is held, where it is held, and how to undo it.
///
/// The end of the flow is also the screen an owner returns to months later
/// asking "what does this app actually have of mine?" — so it answers that
/// rather than saying "Success!" and moving on. Whether the Zepp sign-in was
/// kept is stated either way, because "we did not store your password" is only
/// reassuring if the same screen would have admitted the opposite.
///
/// The two controls are `.button.full` and stacked. They used to be a `Row`,
/// which is the shape that overflowed at phone width on the sign-in screen; a
/// full-width button cannot, at any width.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/stat_block.dart';
import 'package:healthee/shared/v02/surfaces.dart';

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

  /// `.stack { gap: 16px }`.
  static const double stackGap = 16;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PlainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StatBlock(label: 'Paired', value: strap.mac),
              const SizedBox(height: SectionGap.height),
              const SmallProse(PairingDisclosure.whatIsAlwaysStored),
              const SizedBox(height: stackGap),
              SmallProse(
                zeppRemembered
                    ? 'Your Zepp email and password are also in the keystore, '
                          'because you asked us to remember them. Unpairing '
                          'removes them too.'
                    : 'Nothing about your Zepp account was kept — not the '
                          'password, not the session. Only the strap.',
              ),
            ],
          ),
        ),
        const SectionGap(),
        HButton(label: 'Done', onPressed: onDone),
        const SizedBox(height: stackGap),
        HButton(
          label: 'Unpair',
          kind: HButtonKind.secondary,
          onPressed: onUnpair,
        ),
      ],
    );
  }
}
