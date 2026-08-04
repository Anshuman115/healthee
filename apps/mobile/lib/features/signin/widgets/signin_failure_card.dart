/// Renders a named [ServerSignInFailure] — headline, remedy, and a retry when
/// one would help.
///
/// The same two shapes `pairing_failure_card.dart` uses, chosen by
/// [ServerSignInFailure.canRetry] rather than by the caller: a retryable failure
/// gets the shared [ErrorState] so it looks like every other retry in the app,
/// and one that needs different input gets the card frame with **no button** —
/// a token the server has already read and rejected does not become right by
/// pressing Try again.
///
/// Neither is tinted. `docs/APP_DESIGN_BRIEF.md` §2 rations colour to judgement
/// about the owner's body, and a sign-in failure is not one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

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
    if (failure.canRetry) {
      return ErrorState(
        message: failure.headline,
        detail: failure.remedy,
        onRetry: onRetry,
      );
    }
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(failure.headline, style: text.titleSmall),
          const SizedBox(height: Insets.sm),
          Text(
            failure.remedy,
            style: text.bodySmall?.copyWith(color: context.colors.ink3),
          ),
        ],
      ),
    );
  }
}
