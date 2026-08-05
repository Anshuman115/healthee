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
///
/// ## One stage, one word
///
/// Legacy called the light stage **`Core`** in the breakdown and the hypnogram
/// lanes, **`light`** in the naps legend, and **`LIGHT`** on the seven-night
/// chip — three words for one stage, two of them on the same screen. Every
/// surface now asks [sleepStageLabel], which answers **`Light`**: the strap's own
/// word, and the one the server's `light` key already uses. This is wording, not
/// layout — no swatch, gap or row moves.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';

/// The stage names the strap and the server both use, **deepest first** — the
/// order legacy stacks them in (`instrument_charts.dart:335`).
const List<String> kSleepStages = <String>['deep', 'light', 'rem', 'awake'];

/// The stand-in stage for a code this app cannot name.
///
/// Not a stage the strap ever sends — it is what a chart resolves an unreadable
/// code to, so the band, its colour and its legend key all speak about the same
/// thing. See [InstrumentHues.sleepStage].
const String kUnrecognisedStage = 'unrecognised';

/// The colour for one stage name. A thin alias for [InstrumentHues.sleepStage],
/// kept so call sites read `sleepStageColor(hues, stage)` at the point of use.
Color sleepStageColor(InstrumentHues hues, String stage) =>
    hues.sleepStage(stage);

/// The owner-facing name for one stage.
///
/// `core` is the server's word for what the strap calls `light`; one stage, two
/// vocabularies, one label. Anything else is **named as unrecognised rather than
/// as a stage** — the label half of the rule `InstrumentHues.sleepStage` holds
/// for the colour.
String sleepStageLabel(String stage) => switch (stage) {
  'deep' => 'Deep',
  'light' || 'core' => 'Light',
  'rem' => 'REM',
  'awake' => 'Awake',
  _ => 'Unrecognised',
};

/// The legend keys for a chart that actually drew [drawn].
///
/// [kSleepStages], plus [kUnrecognisedStage] **only when [drawn] contains a code
/// this app cannot name**. A legend that always carried the fifth key would
/// announce a stage the chart did not paint, which is the empty-section failure
/// the honesty rules forbid; a legend that never carried it would leave a grey
/// band on screen with nothing to explain it.
List<String> legendStages(Iterable<String> drawn) => <String>[
  ...kSleepStages,
  if (drawn.any((stage) => !InstrumentHues.isRecognised(stage)))
    kUnrecognisedStage,
];
