/// The way to the instrument view — baselines, and the strap's own streams.
///
/// Moved here from the pairing screen, which is where it was because the Today
/// avatar went there. It belongs with the app's other about-the-app surfaces:
/// `features/diagnostics/diagnostics_screen.dart` argues that these are the
/// numbers the owner wants when something looks wrong and never at 7am, and that
/// argument is only sound while there is a door.
///
/// The row says what is behind it in the owner's own words rather than the word
/// "Diagnostics" alone, which would be a control whose only documentation is the
/// screen you have to open to read it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Opens `/diagnostics`.
class DiagnosticsSetting extends StatelessWidget {
  /// The instruments row.
  const DiagnosticsSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Instruments', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Text(
            'Every baseline the app computes, and every stream this phone read '
            'off the strap — with each number saying how it was measured.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              // Pushed: back lands on Settings, which is where it was
              // opened from and the only thing that makes it findable.
              onPressed: () => unawaited(context.push(Routes.diagnostics)),
              child: const Text('Open diagnostics'),
            ),
          ),
        ],
      ),
    );
  }
}
