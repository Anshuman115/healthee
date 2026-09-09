/// The two stage panels the Sleep screen opens with.
///
/// `design/mobile-preview/sleep-history-view.js`, in order:
///
/// ```js
/// H.panel('How your night unfolded','sleep',
///   `${night.stage_timeline.length ? H.charts.sleep()
///      : H.note('No stage timeline recorded for this night.')}${H.stageLegend()}`,
///   'sleep-history','moon')
/// H.panel('Every stage, accounted for','sleep', stageDetails(night), '', 'moon')
/// ```
///
/// where `stageDetails` is `H.sleepStagesTable()` when any stage has minutes and
/// `H.note('Stage durations were not recorded for this night.')` when none does.
///
/// ## The two panels are two different claims and stay apart
///
/// The timeline is *when* each stage happened; the table is *how much* of each
/// there was. The prototype's own note says they can disagree — the strap's
/// staged spans and its stage totals are separate fields on the wire — so
/// putting the totals under the timeline would read as the timeline's own
/// summary. `CHART_COVERAGE.md`: *"Supplied stage totals differ from the separate
/// duration/timeline estimates and that remains disclosed."*
///
/// ## An unstaged night keeps the chart's slot
///
/// A night with no spans draws `ChartVoid` at the timeline's height and says so
/// in words inside the panel. Collapsing the panel would have made a night the
/// strap did not stage look like a night that did not happen.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/sleep_type_scale.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';
import 'package:healthee/shared/charts/v02/v02_hypnogram.dart';
import 'package:healthee/shared/charts/v02/v02_stage_strip.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/colour_key.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// `H.note('No stage timeline recorded for this night.')`.
const String kNoTimelineNote = 'No stage timeline recorded for this night.';

/// `H.note('Stage durations were not recorded for this night.')`.
const String kNoStagesNote = 'Stage durations were not recorded for this night.';

/// The prototype's own caveat under the stage table.
const String kStageTotalsNote =
    'Proportions use the supplied stage total. Stage totals and time-asleep '
    'estimates can differ.';

/// The one thing the stage legend is there to say.
const String kStageColourMethod =
    'Each stage keeps the same colour throughout the app.';

/// `How your night unfolded` — the stage timeline and its legend.
class NightTimelinePanel extends StatelessWidget {
  /// [night] is the session being read.
  const NightTimelinePanel({
    required this.night,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'How your night unfolded';

  /// The plot's height, before the legend.
  static const double chartHeight = 165;

  /// The gap above the legend.
  static const double legendGap = 10;

  /// The night being read.
  final SleepNight night;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the sleep history.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    final staged = night.timeline.isNotEmpty;
    return Panel(
      tone: Tone.sleep,
      label: 'Sleep stages',
      head: PanelHead(
        title: title,
        icon: SolarIconsOutline.moonSleep,
        infoKey: 'sleep',
        detail: const MetricDetail(method: <String>[kStageColourMethod]),
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (staged)
            RevealOnce(
              id: 'sleep.hypnogram',
              registry: reveals,
              builder: (context, t) => V02Hypnogram(
                night.timeline,
                progress: t,
                height: chartHeight,
                startLabel: night.start == null ? null : clock(night.start!),
                endLabel: night.end == null ? null : clock(night.end!),
                semanticLabel: 'Sleep stages through the night',
              ),
            )
          else
            const ChartVoid(height: chartHeight),
          const SizedBox(height: legendGap),
          ColourKey(<ColourKeyEntry>[
            for (final stage in kSleepStages)
              ColourKeyEntry(
                sleepStageLabel(stage),
                colour: sleepStageColor(hues, stage),
              ),
          ]),
          if (!staged) const PanelNote(kNoTimelineNote),
        ],
      ),
    );
  }
}

/// `Every stage, accounted for` — the proportion bar, then the four totals.
class StageTablePanel extends StatelessWidget {
  /// [night] is the session being read.
  const StageTablePanel({
    required this.night,
    required this.reveals,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Every stage, accounted for';

  /// The gap between the strip and the table.
  static const double tableGap = 16;

  /// The night being read.
  final SleepNight night;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Minutes per stage, in the app's own stage names — empty with no breakdown.
  ///
  /// The empty map and a map of four zeros are the same picture on this panel and
  /// a different claim underneath, which is why [total] is read off `stages`
  /// being null rather than off these values summing to nothing.
  Map<String, double> get minutes => switch (night.stages) {
    final StageMinutes stages => <String, double>{
      'deep': stages.deep,
      'light': stages.light,
      'rem': stages.rem,
      'awake': stages.awake,
    },
    null => const <String, double>{},
  };

  @override
  Widget build(BuildContext context) {
    // Null stages -> no breakdown was recorded; zero total -> the strap staged the
    // night as nothing. Both draw `kNoStagesNote`, and neither draws a strip.
    final total = night.stages?.total ?? 0;
    return Panel(
      tone: Tone.sleep,
      label: 'Stage totals',
      head: const PanelHead(
        title: title,
        icon: SolarIconsOutline.moonSleep,
        infoKey: 'sleep',
      ),
      child: total <= 0
          ? const PanelNote(kNoStagesNote)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RevealOnce(
                  id: 'sleep.stage-strip',
                  registry: reveals,
                  builder: (context, t) => V02StageStrip(
                    minutes,
                    progress: t,
                    semanticLabel: 'Stage proportions for this night',
                  ),
                ),
                const SizedBox(height: tableGap),
                _StageTable(minutes: minutes, total: total),
                const PanelNote(kStageTotalsNote),
              ],
            ),
    );
  }
}

/// `.data-table` — Stage · Duration · Proportion.
class _StageTable extends StatelessWidget {
  const _StageTable({required this.minutes, required this.total});

  final Map<String, double> minutes;
  final double total;

  /// `.data-table th { padding-block:8px }`.
  static const double headPad = 8;

  /// `.data-table td { padding-block:12px }`.
  static const double cellPad = 12;

  /// `.data-table .swatch { width:7px; height:7px; border-radius:2px }`.
  static const double swatch = 7;

  /// `margin-right:6px`.
  static const double swatchGap = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: headPad),
          child: _Row(
            stage: Text(
              'Stage',
              style: SleepType.tableCell.copyWith(color: colors.ink2),
            ),
            duration: Text(
              'Duration',
              style: SleepType.tableCell.copyWith(color: colors.ink2),
            ),
            proportion: Text(
              'Proportion',
              textAlign: TextAlign.right,
              style: SleepType.tableCell.copyWith(color: colors.ink2),
            ),
          ),
        ),
        for (final stage in kSleepStages)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.line, width: hairline),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: cellPad),
              child: _Row(
                stage: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: swatch,
                      height: swatch,
                      decoration: BoxDecoration(
                        color: sleepStageColor(hues, stage),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: swatchGap),
                    Flexible(
                      child: Text(
                        sleepStageLabel(stage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SleepType.tableCell.copyWith(color: colors.ink),
                      ),
                    ),
                  ],
                ),
                duration: Text(
                  hoursMinutes(minutes[stage] ?? 0),
                  style: SleepType.tableCell.copyWith(color: colors.ink),
                ),
                proportion: Text(
                  '${(100 * (minutes[stage] ?? 0) / total).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: SleepType.tableCell.copyWith(color: colors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One table row's three columns. The last is right-aligned, as the CSS is.
class _Row extends StatelessWidget {
  const _Row({
    required this.stage,
    required this.duration,
    required this.proportion,
  });

  final Widget stage;
  final Widget duration;
  final Widget proportion;

  /// The two measured columns, sized so the stage name keeps the rest.
  static const double durationWidth = 74;
  static const double proportionWidth = 74;
  static const double gap = 8;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Expanded(child: stage),
      const SizedBox(width: gap),
      SizedBox(width: durationWidth, child: duration),
      const SizedBox(width: gap),
      SizedBox(width: proportionWidth, child: proportion),
    ],
  );
}
