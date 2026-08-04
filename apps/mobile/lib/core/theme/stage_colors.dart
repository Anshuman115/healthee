/// The one sleep-stage palette. Two charts and a card draw from it.
///
/// ## Why not the legacy palette
///
/// `theme.dart`'s `HColors.sleepStage` gave each stage its own hue — deep amber,
/// core blue, REM purple, awake red. That is what most sleep apps do and it is
/// wrong under this design system: brief §2 rations colour to **judgement**
/// (`fav`/`unf` against the owner's own baseline, `alert` for illness alone), and
/// four hues across four stages spends the whole palette asserting that deep
/// sleep is good and awake is bad. Neither claim is the app's to make in a
/// picture of what the strap recorded.
///
/// So the stages are shades of the ONE accent, ordered deepest-to-lightest, with
/// awake drawn in [HealtheeColors.line] because it is the absence of sleep
/// rather than a fifth kind of it. The reading is carried by width, which is
/// what the measurement actually is.
///
/// Extracted here on its second use, per Standards §1 — `sleep_card.dart` had
/// the ladder inline and the hypnogram needed the same four values.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The stage names the strap and the server both use, deepest first.
///
/// `core` is the server's word for what the strap calls `light`; both map to the
/// same shade because they are the same stage under two vocabularies, and giving
/// them different colours would draw a distinction that does not exist.
const List<String> kSleepStages = <String>['deep', 'light', 'rem', 'awake'];

/// The colour for one stage name.
///
/// An unrecognised stage gets [HealtheeColors.line2] rather than a default
/// shade: the strap emits codes we do not recognise, and painting one as light
/// sleep would put a stage in the picture that nothing measured.
Color sleepStageColor(HealtheeColors colors, String stage) => switch (stage) {
  'deep' => colors.accent,
  'light' || 'core' => colors.accent.withValues(alpha: 0.55),
  'rem' => colors.accent.withValues(alpha: 0.30),
  'awake' => colors.line,
  _ => colors.line2,
};

/// The owner-facing name for one stage.
String sleepStageLabel(String stage) => switch (stage) {
  'deep' => 'Deep',
  'light' || 'core' => 'Light',
  'rem' => 'REM',
  'awake' => 'Awake',
  _ => 'Unrecognised',
};
