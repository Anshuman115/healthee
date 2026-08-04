/// The editorial opening: a greeting, and the server's own sentence about today.
///
/// **Ported from** `design_reference/project/hh/screen_today.jsx` — a 42 px
/// display greeting, then a one-line prose state ("You're *well recovered* —
/// deep sleep ran long and HRV climbed overnight."). It is the one place on the
/// legacy screen that speaks in sentences, and it is what stops the page reading
/// as a dashboard with nobody behind it.
///
/// ## Three things legacy had here that this cannot honestly have
///
/// **No name.** Legacy's greeting is "Good morning, *Maya*." with the name in
/// italic accent. Nothing in this app stores an owner name, so the line stops at
/// the greeting rather than inventing one.
///
/// **No serif.** Legacy sets this in Newsreader italic and that face is a real
/// part of its identity. It is not taken, for three reasons that all point the
/// same way. `docs/APP_DESIGN_BRIEF.md` §2 bans serif in the app, and the owner's
/// instruction was legacy's *structure* wearing the **new** theme — the type
/// system is the part that is explicitly new. The app vendors exactly one family
/// (`typography.dart`); a display serif is another ~60 KB in the binary against a
/// 2 s cold-start budget, for two words on one screen. And the alternative that
/// costs nothing — falling back to the platform serif — would render this line in
/// New York on iOS and Noto Serif on Android, which for the app's single most
/// prominent piece of type is worse than one face that is consistently ours.
/// What the serif was *doing* — making the opening sound like a person rather
/// than a readout — is got here from size, a light weight and tight tracking.
/// Changing the decision is one `fontFamily` on the [Text] below.
///
/// **No accent-coloured phrase.** Legacy tints a fragment of the sentence green
/// ("You're **well recovered** —"). Two ways to reproduce it were rejected:
/// highlighting a substring of a server sentence means pattern-matching prose the
/// server calibrated, and deriving a phrase from [RecoveryScore.band] would have
/// shipped an actual bug. The band is computed from the recovery number, but
/// **an illness flag overrides the guidance without changing the band** — the
/// contract snapshot is exactly that case, `band: "high"` beside guidance that
/// begins "An illness signal is active". A cheerful accent phrase beside a safety
/// message is the flattery this product exists not to do.
///
/// So [guidance] renders **verbatim** and undecorated, which is what
/// `recovery_card.dart` already required of it and for the same reason.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The greeting, and the day's sentence beneath it.
class GreetingBlock extends StatelessWidget {
  /// [guidance] is the server's line, rendered as it arrived.
  const GreetingBlock({this.guidance, this.now, super.key});

  /// `RecoveryScore.guidance` — deterministic, rule-based, and overridden by an
  /// active illness flag. Null when the server sent no recovery block at all, in
  /// which case the greeting stands alone rather than inventing a sentence.
  final String? guidance;

  /// The instant the greeting is chosen from.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greetingFor(now ?? DateTime.now()),
          style: text.displayLarge?.copyWith(
            fontSize: 34,
            // Lighter than the display default. The hero figures on this screen
            // are w600; the greeting is prose and must not compete with them.
            fontWeight: FontWeight.w400,
            height: 1.05,
          ),
        ),
        if (guidance case final String line) ...[
          const SizedBox(height: Insets.md),
          Text(
            line,
            style: text.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.45,
              color: colors.ink2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Legacy's "Good morning," by the clock.
///
/// The boundaries are 05:00 / 12:00 / 18:00. They are a greeting, not a claim
/// about the owner's body, which is why this is the one thing on Today the app
/// decides for itself.
String greetingFor(DateTime at) {
  if (at.hour < 5) {
    return 'Still up.';
  }
  if (at.hour < 12) {
    return 'Good morning.';
  }
  if (at.hour < 18) {
    return 'Good afternoon.';
  }
  return 'Good evening.';
}
