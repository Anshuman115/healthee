/// The sleep-stage vocabulary: the order stages stack in, and their labels.
///
/// **The colour itself lives on [InstrumentHues.sleepStage]** and nowhere else,
/// exactly as legacy put it on `HColors.sleepStage` — one mapping, used by the
/// hypnogram, the seven-night bars and every legend. This file is what is left
/// once the colour moved: the stacking order and the owner-facing names.
///
/// The previous revision of this file argued for a one-hue hypnogram (an accent
/// at three alphas), then for the five identity tags. Both are gone. Legacy draws
/// four clearly distinct stage colours and legacy is the specification.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';

/// The stage names the strap and the server both use, **deepest first** — the
/// order legacy stacks them in (`instrument_charts.dart:335`).
const List<String> kSleepStages = <String>['deep', 'light', 'rem', 'awake'];

/// The colour for one stage name. A thin alias for [InstrumentHues.sleepStage],
/// kept so call sites read `sleepStageColor(hues, stage)` at the point of use.
Color sleepStageColor(InstrumentHues hues, String stage) =>
    hues.sleepStage(stage);

/// The owner-facing name for one stage.
///
/// `core` is the server's word for what the strap calls `light`; one stage, two
/// vocabularies, one label.
String sleepStageLabel(String stage) => switch (stage) {
  'deep' => 'Deep',
  'light' || 'core' => 'Light',
  'rem' => 'REM',
  'awake' => 'Awake',
  _ => 'Unrecognised',
};
