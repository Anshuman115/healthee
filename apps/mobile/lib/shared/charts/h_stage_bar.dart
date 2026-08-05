/// [HStageBar] — one night as a stacked proportion bar, legible at 30 px.
///
/// ## Why the hypnogram is not drawn here
///
/// Today's grid cell gave the full four-lane [HHypnogram] 28 px of height. On the
/// owner's real nights that is **~7 px per lane** with a 62% band inside it, so
/// each span is a 4 px sliver on its own row, and a fragmented night — which is
/// most of this owner's nights — reads as scattered dots. Dots are not a chart.
/// Nothing was wrong with the drawing: the same hypnogram is perfectly legible at
/// full width on the Sleep tab, where it stays, because the shape of the night in
/// TIME is exactly what that screen is for.
///
/// What survives 30 px is **proportion**, not sequence. A stacked bar spends the
/// whole height on one row instead of a quarter of it on each of four, so the
/// smallest stage a real night carries is still several pixels tall, and the four
/// stages stay told apart by the same `stage_colors.dart` palette the hypnogram
/// uses — one definition of what deep sleep looks like, across three charts.
///
/// ## What it says, and what it deliberately does not
///
/// It says how the night divided: this much deep, this much light, this much REM,
/// this much awake. It does **not** say when, how fragmented, or how many
/// awakenings — and it must not be read as saying so, which is why the cell's
/// foot still names the minutes and the cell is a door to the tab that draws the
/// timeline.
///
/// **No judgement.** The stages are ordered deep → light → REM → awake because
/// that is the order the record is written in, not a ranking, and the bar has no
/// target line, no fill colour that varies with the night, and no "good" end. A
/// short night and a long one are both a full bar: the DURATION is the figure
/// above it, and drawing the proportion bar to length as well would say the same
/// number twice while making a fragmented short night look like a healthy one.
///
/// [HStackedSleep] was the other candidate and is a different chart: it stacks
/// SEVEN nights against a shared hour axis with gridlines and weekday labels,
/// which is a week's comparison and needs the 130 px it asks for.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';

/// One night's stage minutes, as widths in proportion.
class HStageBar extends StatelessWidget {
  /// [minutesByStage] is keyed by the names in [kSleepStages]; [progress] is
  /// 0–1 from `RevealOnce` and grows the bar from the left.
  const HStageBar(
    this.minutesByStage, {
    required this.progress,
    this.height = 10,
    super.key,
  });

  /// Minutes per stage. Absent or zero stages simply take no width.
  final Map<String, int> minutesByStage;

  /// How far the bar has grown, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  /// The stage minutes actually present, in record order.
  List<(String, int)> get _spans => <(String, int)>[
    for (final stage in kSleepStages)
      if ((minutesByStage[stage] ?? 0) > 0) (stage, minutesByStage[stage]!),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final spans = _spans;
    if (spans.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          // `StackFit.expand` and `CrossAxisAlignment.stretch` are both
          // load-bearing, and both for one reason: **a `ColoredBox` with no
          // child sizes to `constraints.smallest`**. A default `Stack` hands out
          // loose constraints and a default `Row` gives its children a loose
          // CROSS axis, so without either of these every segment lays out at
          // zero height and the bar renders as an empty grey track. It did, on a
          // real render — the widget tree was correct and the picture was blank,
          // which is why `grid_sleep_cell_test.dart` measures painted size and
          // not just flex. `h_meter.dart` is the same shape for the same reason.
          fit: StackFit.expand,
          children: [
            // The track. The reveal fills it left to right; the PROPORTIONS
            // never move, because a bar whose stages shift while it grows would
            // be animating a claim rather than a chart.
            ColoredBox(color: colors.line2),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // `flex` on integer minutes rather than fractional widths: the
                  // segments sum to the full width exactly, with no sub-pixel
                  // seam between two stages of the same colour.
                  for (final (stage, minutes) in spans)
                    Expanded(
                      flex: minutes,
                      child: ColoredBox(
                        color: sleepStageColor(hues, stage),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
