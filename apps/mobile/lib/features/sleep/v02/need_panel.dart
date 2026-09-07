/// `Sleep need & debt` — the shortfall, and what it is a shortfall against.
///
/// `design/mobile-preview/sleep-history-view.js`:
///
/// ```js
/// H.panel('Sleep need & debt','sleep',
///   `${H.value(debt,'min debt', need + ' need')}
///    <div class="three section">${H.stat('79','%','Sleep performance')}
///                               ${H.stat('1h 40m','','Nightly gap')}
///                               ${H.stat('14','','Modelled nights')}</div>
///    <div class="progress-track section"><i style="width:79.16%"></i></div>
///    ${H.charts.sleepGap()}
///    ${H.note('The 8h reference leaves a 1h 40m nightly gap. '
///             'Debt is a separate 14-night model.')}
///    ${H.evidence('sleep_need_debt')}`, '', 'moon')
/// ```
///
/// ## Three deliberate differences from the prototype's numbers
///
/// **`/api/sleep` sends no need and no debt.** The prototype's `120 min` and its
/// `14-night model` come from Today's `sleep_debt` block, which this endpoint
/// does not carry. Rather than restate a number from another screen — the way
/// two numbers start disagreeing — the figure here is the one this screen can
/// compute from the nights it was sent: the total shortfall against the 8-hour
/// reference across the measured nights of the last seven.
///
/// So the third statistic says **`Nights counted`**, not `Modelled nights`, and
/// carries the count this screen actually used. The note says the same thing in
/// words. A `14` here would have been a label borrowed from a model that is not
/// running behind it.
///
/// **The reference is `kSleepNeedMin`,** the app's one sleep-need constant, and
/// the note names it rather than leaving `79%` to look like a mark out of a
/// hundred.
///
/// ## The chart is `HDebtBars`, not a second one
///
/// `H.charts.sleepGap` draws each night's bar to what was slept and a dashed
/// ghost from there up to the reference. `HDebtBars` already draws exactly that,
/// takes no `Color`, takes its reveal as a parameter, and is the app's one
/// need-versus-actual chart. A second painter would be a second opinion about
/// the same seven nights.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/sleep_windows.dart';
import 'package:healthee/shared/charts/h_debt_bars.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/colour_key.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// `Sleep need & debt` — the seven-night shortfall against the 8-hour reference.
class SleepNeedPanel extends StatelessWidget {
  /// [night] is the latest session; [nights] the measured week, oldest first.
  const SleepNeedPanel({
    required this.night,
    required this.nights,
    required this.reveals,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Sleep need & debt';

  /// `H.charts.sleepGap()`'s height.
  static const double chartHeight = 130;

  /// The gap above the statistics row.
  static const double statsGap = 14;

  /// `.progress-track { margin-block:16px 8px }`.
  static const double trackTop = 16;
  static const double trackBottom = 8;

  /// The gap above the legend.
  static const double legendGap = 10;

  /// The latest night.
  final SleepNight night;

  /// The measured nights of the last seven, oldest first.
  final List<DebtNight> nights;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Total minutes short of the reference across [nights].
  double get shortfallMin => nights.fold<double>(
    0,
    (sum, night) =>
        sum + (kSleepNeedMin - night.totalMin).clamp(0.0, kSleepNeedMin),
  );

  /// Last night as a share of the reference, carrying its honesty state.
  Reading<double> get performance =>
      night.tstMin.map((minutes) => (100 * minutes / kSleepNeedMin).clamp(0, 100));

  /// Last night's own shortfall, or null when the night was not measured.
  double? get nightlyGapMin {
    final minutes = night.tstMin.valueOrNull;
    return minutes == null ? null : (kSleepNeedMin - minutes).clamp(0.0, kSleepNeedMin);
  }

  /// The note, naming the reference and the window it was applied over.
  String get note =>
      'Measured against a ${hoursMinutes(kSleepNeedMin)} reference, summed over '
      'the ${nights.length} measured '
      '${nights.length == 1 ? 'night' : 'nights'} of the last seven. This is '
      'not a modelled sleep debt.';

  @override
  Widget build(BuildContext context) {
    final percent = performance.valueOrNull;
    final gap = nightlyGapMin;
    return Panel(
      tone: Tone.sleep,
      label: 'Sleep need · debt',
      head: const PanelHead(
        title: title,
        icon: Icons.bedtime_outlined,
        infoKey: 'sleep_debt',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            hoursMinutes(shortfallMin),
            unit: 'debt',
            context_: '${hoursMinutes(kSleepNeedMin)} need',
          ),
          const SizedBox(height: statsGap),
          StatRow(<Stat>[
            if (percent != null)
              Stat('Sleep performance', '${percent.round()}', unit: '%'),
            if (gap != null) Stat('Nightly gap', hoursMinutes(gap)),
            Stat('Nights counted', '${nights.length}'),
          ]),
          if (percent != null) ...<Widget>[
            const SizedBox(height: trackTop),
            ProgressTrack(fraction: percent / 100),
            const SizedBox(height: trackBottom),
          ],
          // One bar is not a week. Below the floor the chart draws nothing and
          // keeps its slot, and the note below already says how many nights are
          // behind the figure.
          if (nights.length < SleepWindows.minimumNights)
            const ChartVoid(height: chartHeight)
          else
            RevealOnce(
              id: 'sleep.debt',
              registry: reveals,
              builder: (context, t) => SizedBox(
                height: chartHeight,
                child: HDebtBars(
                  totalsMin: <double>[for (final n in nights) n.totalMin],
                  labels: <String>[for (final n in nights) n.label],
                  needMin: kSleepNeedMin.round(),
                  progress: t,
                  height: chartHeight,
                ),
              ),
            ),
          const SizedBox(height: legendGap),
          ColourKey(<ColourKeyEntry>[
            ColourKeyEntry('Met ${hoursMinutes(kSleepNeedMin)}', tone: Tone.fitness),
            const ColourKeyEntry('Short', tone: Tone.heart),
          ]),
          PanelNote(note),
          if (night.tstMin case Withheld<double>(:final disclosure))
            PanelNote('Last night: ${disclosure.message}'),
        ],
      ),
    );
  }
}
