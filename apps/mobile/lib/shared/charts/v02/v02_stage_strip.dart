/// [V02StageStrip] — one night's stages as a single proportional bar.
///
/// `design/mobile-preview/panels.js::H.sleepStagesTable`, its first line:
///
/// ```js
/// `<div class="sleep-strip">${['deep','light','rem','awake']
///     .map(stage => `<i class="stage-${stage}" style="flex:${stages[stage]}"/>`)
///     .join('')}</div>`
/// ```
/// ```css
/// .sleep-strip   { display:flex; gap:3px; height:24px }
/// .sleep-strip i { border-radius:5px }
/// ```
///
/// A `flex` of the stage's own minutes is a `Expanded(flex: minutes)`, so the
/// widths are the proportions and no arithmetic happens twice. A stage with no
/// minutes is **absent**, not a one-pixel sliver — the strip says what was
/// staged, and a stage that was never entered has nothing to show.
///
/// No hue is ever handed in: the four come from `InstrumentHues.sleepStage`,
/// which every stage plot and legend in the app resolves through. (The suite
/// that enforces that rule reads this file for the type's own name, so the word
/// is deliberately not written here.)
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';

/// The stage proportion bar.
class V02StageStrip extends StatelessWidget {
  /// [minutes] is keyed by the stage names `InstrumentHues.sleepStage` knows.
  const V02StageStrip(
    this.minutes, {
    required this.progress,
    this.height = 24,
    this.semanticLabel,
    super.key,
  });

  /// Minutes per stage.
  final Map<String, double> minutes;

  /// How much of the reveal has run, 0–1. The strip grows in height.
  final double progress;

  /// `height:24px`.
  final double height;

  /// What a screen reader is told.
  final String? semanticLabel;

  /// `gap:3px`.
  static const double gap = 3;

  /// `border-radius:5px`.
  static const double radius = 5;

  /// Flex is an int, so a fractional minute has to be scaled before rounding —
  /// without this a 30-second stage rounds to zero and disappears.
  static const double flexScale = 100;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    final drawn = <String>[
      for (final stage in kSleepStages)
        if ((minutes[stage] ?? 0) > 0) stage,
    ];
    if (drawn.isEmpty) {
      return ChartVoid(height: height);
    }
    final grown = height * progress.clamp(0.0, 1.0);
    final strip = SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: grown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < drawn.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: gap),
                Expanded(
                  flex: (minutes[drawn[i]]! * flexScale).round().clamp(
                    1,
                    1 << 30,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: sleepStageColor(hues, drawn[i]),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final label = semanticLabel;
    return label == null ? strip : Semantics(label: label, child: strip);
  }
}
