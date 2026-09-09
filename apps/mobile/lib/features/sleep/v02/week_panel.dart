/// `Your week, stage by stage` — seven nights, stacked, and what they can't say.
///
/// `design/mobile-preview/sleep-history-view.js`:
///
/// ```js
/// H.panel('Your week, stage by stage','sleep',
///   `${stages(week)}${H.stageLegend()}
///    ${H.note(`${H.dateLabel(week[0].date)}–${H.dateLabel()} · stage totals `
///             + `can differ from time-asleep estimates.`)}`,
///   'sleep-history','moon')
/// ```
///
/// ## The chart is `HStackedSleep`, kept
///
/// It is the app's only stacked stage chart, it already resolves its four hues
/// through `InstrumentHues.sleepStage`, it takes no `Color`, and it takes its
/// reveal as a parameter. Today's `SleepWeekPanel` wraps the same painter for
/// the same reason: a second stacked painter would be a second opinion about
/// the same seven nights, and the two screens would start disagreeing about a
/// week they both draw.
///
/// ## The note is not decoration
///
/// The strap sends staged spans and stage totals as separate fields, and they
/// can disagree with the time-asleep figure at the top of this screen. The
/// prototype discloses that here and so does this.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/colour_key.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's own caveat, said inside the card it is about.
const String kWeekStageNote =
    'stage totals can differ from time-asleep estimates.';

/// The one thing the stage legend is there to say.
const String kWeekStageMethod =
    'Each stage keeps the same colour throughout the app.';

/// `Your week, stage by stage`.
class StageWeekPanel extends StatelessWidget {
  /// [nights] is oldest first and never padded to reach seven.
  const StageWeekPanel({
    required this.nights,
    required this.span,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Your week, stage by stage';

  /// The stack's height.
  static const double chartHeight = 130;

  /// The gap above the legend.
  static const double legendGap = 10;

  /// The week, oldest first.
  final List<SleepNightSummary> nights;

  /// `25 Jul–31 Jul` — the window the bars cover.
  final String span;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the sleep history.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    return Panel(
      tone: Tone.sleep,
      label: 'Sleep stages · seven nights',
      head: PanelHead(
        title: title,
        icon: SolarIconsOutline.moonSleep,
        infoKey: 'sleep',
        detail: const MetricDetail(method: <String>[kWeekStageMethod]),
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RevealOnce(
            id: 'sleep.stage-week',
            registry: reveals,
            builder: (context, t) =>
                HStackedSleep(nights, progress: t, height: chartHeight),
          ),
          const SizedBox(height: legendGap),
          ColourKey(<ColourKeyEntry>[
            for (final stage in kSleepStages)
              ColourKeyEntry(
                sleepStageLabel(stage),
                colour: sleepStageColor(hues, stage),
              ),
          ]),
          PanelNote(span.isEmpty ? kWeekStageNote : '$span · $kWeekStageNote'),
        ],
      ),
    );
  }
}
