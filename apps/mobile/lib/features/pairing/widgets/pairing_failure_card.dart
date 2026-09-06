/// Renders a named [PairingFailure] — headline, remedy, and a retry when one
/// would help.
///
/// Two shapes, chosen by [PairingFailure.canRetry] rather than by the caller:
///
///  * retryable → a **Try again**, so a pairing failure offers a retry that
///    looks and behaves exactly like every other retry in the app;
///  * not retryable → the same banner with **no button**, because a wrong
///    password does not become right by pressing Try again. The remedy sentence
///    is the way forward, and it points somewhere real.
///
/// Neither is tinted. `notices.dart` records why: `alert` is this product's one
/// red and belongs to the illness flag, and none of these failures is a fact
/// about the owner's body.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/notices.dart';
import 'package:healthee/shared/v02/settings_page.dart';

/// A pairing failure, said plainly.
class PairingFailureCard extends StatelessWidget {
  /// [onRetry] is only used when [failure] says a retry is worth offering.
  const PairingFailureCard({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  /// What went wrong.
  final PairingFailure failure;

  /// Runs the same step again.
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
