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
///
/// ## The two controls are stacked, not in a `Row`
///
/// They used to be a `Row`, and the two labels are 110 px wider than a 420 px
/// phone at this card's padding — so it overflowed, which Flutter renders as a
/// striped bar over content that cannot be seen. It went unnoticed because
/// every widget suite pumped the default 800 px test window, which is wider
/// than any phone this app runs on.
///
/// v02's buttons are `.button.full`: full-width and stacked by design, so the
/// failure is no longer reachable at any width rather than merely avoided at
/// the ones somebody remembered to test. `test/features/settings_layout_test.dart`
/// pumps 320 · 360 · 390 · 414 anyway, because "not reachable" is a claim.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';

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

  /// `.stack { gap: 16px }` between the two controls.
  static const double stackGap = 16;

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
    final colors = context.colors;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Signed in',
            style: FormType.statLabel.copyWith(color: colors.ink2),
          ),
          Text(
            baseUrl,
            style: FormType.heading3.copyWith(color: colors.ink),
          ),
          const SizedBox(height: SectionGap.height),
          const SmallProse(
            'A token for this server is in this phone’s keystore, and it was '
            'checked against the server before it was saved.',
          ),
          const SizedBox(height: stackGap),
          const SmallProse(
            'Signing out deletes the token from this phone. Everything your '
            'strap measured stays here and keeps being recorded; the readings '
            'the server works out simply stop until you sign in again.',
          ),
          const SizedBox(height: SectionGap.height),
          // Secondary, not primary: v02 keeps the accent for the path forward,
          // and leaving is not it.
          HButton(
            label: 'Sign out',
            kind: HButtonKind.secondary,
            onPressed: enabled ? onSignOut : null,
          ),
          const SizedBox(height: stackGap),
          HButton(
            label: 'Use a different server',
            kind: HButtonKind.soft,
            onPressed: enabled ? onReplace : null,
          ),
        ],
      ),
    );
  }
}
