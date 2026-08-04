/// Renders a named [PairingFailure] — headline, remedy, and a retry when one
/// would help.
///
/// Two shapes, chosen by [PairingFailure.canRetry] rather than by the caller:
///
///  * retryable → the shared [ErrorState], so a pairing failure offers a retry
///    that looks and behaves exactly like every other retry in the app;
///  * not retryable → the same card frame with **no button**, because a wrong
///    password does not become right by pressing Try again. The remedy sentence
///    is the way forward, and it points somewhere real.
///
/// Neither is tinted. `docs/APP_DESIGN_BRIEF.md` §2 rations colour to judgement
/// about the owner's body, and none of these failures is one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// A pairing failure, said plainly.
class PairingFailureCard extends StatelessWidget {
  /// [onRetry] is only used when [failure] says a retry is worth offering.
  const PairingFailureCard({required this.failure, required this.onRetry, super.key});

  /// What went wrong.
  final PairingFailure failure;

  /// Runs the same step again.
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
