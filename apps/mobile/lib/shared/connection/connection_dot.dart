/// The quiet state: one dot, beside the date, and nothing else.
///
/// Seven pixels, in [HealtheeColors.accent] while an authenticated session is
/// open and [HealtheeColors.ink3] when the app has let the link go on purpose.
/// **There is no green**: "green means connected" is a convention that would cost
/// a colour this product reserves for a reading being better than the owner's own
/// normal (`apps/mobile/README.md`, "Colour is a claim").
///
/// It is only ever built when `ConnectionHealth.quiet` is true, and that is the
/// one place the quiet answer is computed — see `data/sync/connection_health.dart`
/// for why nothing may re-derive it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A live session's only mark.
class ConnectionDot extends StatelessWidget {
  /// [live] is true when an authenticated session is open right now.
  const ConnectionDot({required this.live, this.semanticLabel, super.key});

  /// Whether a session is open.
  final bool live;

  /// What a screen reader announces. A dot with no label is a decoration to
  /// anybody not looking at it, and this one carries the app's whole "is
  /// anything wrong" answer.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel ?? (live ? 'Connected to your strap' : 'Idle'),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: live ? colors.accent : colors.ink3,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    );
  }
}
