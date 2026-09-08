/// Renders a named [ServerSignInFailure] — headline, remedy, and a retry when
/// one would help.
///
/// ## Three outcomes, three sentences — this is the whole point of the file
///
/// `data/api/signin_failure.dart` distinguishes **refused** (the server read the
/// token and said no), **unreachable** (nothing answered), and **answered
/// unexpectedly** (something answered, but not like our server). This card
/// prints whichever one happened, verbatim, and never collapses them:
/// *"Could not reach server"* shown for a wrong token is the exact failure that
/// once cost an evening.
///
/// The shape is chosen by [ServerSignInFailure.canRetry] rather than by the
/// caller: a retryable failure gets a **Try again**, and one that needs
/// different input gets **no button** — a token the server has already read and
/// rejected does not become right by pressing it.
///
/// ## Neither is tinted, and that is deliberate
///
/// `notices.dart` records the rule: `alert` is this product's one red and it
/// belongs to the illness flag. A sign-in failure is not a fact about the
/// owner's body, so it is a plain `.notice` — the same untinted treatment the
/// pre-v02 card used, in v02's geometry.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/notices.dart';
import 'package:healthee/shared/v02/settings_page.dart';

/// A sign-in failure, said plainly.
class SignInFailureCard extends StatelessWidget {
  /// [onRetry] is only used when [failure] says a retry is worth offering.
  const SignInFailureCard({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  /// What went wrong.
  final ServerSignInFailure failure;

  /// Runs the same check again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HNotice(title: failure.headline, body: failure.remedy),
        if (failure.canRetry) ...<Widget>[
          const SectionGap(),
          HButton(
            label: 'Try again',
            kind: HButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
