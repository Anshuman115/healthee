/// The one sleep-stage palette. Three charts and two cards draw from it.
///
/// ## What this file used to say, and why it changed
///
/// The previous revision drew all four stages as ONE hue — `accent` at 100%, 55%
/// and 30% alpha, with awake in `line` — and argued that four hues would spend the
/// whole palette asserting that deep sleep is good and awake is bad.
///
/// The premise was right and the conclusion was wrong. Three tints of indigo
/// stacked in a hypnogram 30–84 px tall are not separable by eye, and a hypnogram
/// whose bands cannot be told apart is a decoration where a reading should be.
/// The legacy screens this rebuild is matching draw four clearly distinct stage
/// colours for exactly that reason, and the argument against them was never
/// "distinct is wrong" — it was "distinct must not imply a verdict".
///
/// So the stages now wear the **identity tags** from `metric_hues.dart`, which are
/// built to carry no verdict: they are hue-disjoint from `fav`, `unf` and `alert`,
/// they sit at one lightness so none ranks above another, and they are constants
/// of a category rather than functions of a value. A reader cannot decode "deep is
/// the good one" from a violet band, because violet is also HRV and readiness and
/// says nothing about any of them.
///
/// Awake keeps [HealtheeColors.line]. It is the absence of sleep rather than a
/// fourth kind of it, and drawing it in a tag would put it on the same footing as
/// the three staged bands.
///
/// `core` is the server's word for what the strap calls `light`; both map to the
/// same colour because they are the same stage under two vocabularies, and giving
/// them different colours would draw a distinction that does not exist.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The stage names the strap and the server both use, deepest first.
const List<String> kSleepStages = <String>['deep', 'light', 'rem', 'awake'];

/// The colour for one stage name.
///
/// An unrecognised stage gets [HealtheeColors.line2] rather than a tag: the strap
/// emits codes we do not recognise, and painting one as light sleep would put a
/// stage in the picture that nothing measured.
Color sleepStageColor(HealtheeColors colors, MetricHues hues, String stage) =>
    switch (stage) {
      'deep' => hues.rest,
      'light' || 'core' => hues.body,
      'rem' => hues.heart,
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
