/// `H.historyPanel` — one metric's reading on the chosen day, over its fortnight.
///
/// ```js
/// H.historyPanel = (key,limit=14) => {
///   const metric=H.metricDefinitions[key], points=H.historySeries(key,limit),
///         value=H.dayValue(key);
///   return H.panel(metric.title, metric.tone,
///     `${H.value(H.formatReading(value), metric.unit,
///        value===null ? 'No reading on this day' : H.dateLabel())}
///      ${H.historyChart(key,limit)}
///      ${H.note(points.length ? `${points.length} dated samples through …`
///                             : 'No dated samples before this day.')}`,
///     `metric/${key}`);
/// };
/// ```
///
/// Six past-day screens are built out of this one card, so it is one widget six
/// times (Standards section 1).
///
/// ## Two departures, both in the honesty layer
///
/// **The count is of readings, not of slots.** The prototype counts the array it
/// sliced, which includes the days with nothing in them — its own blood-oxygen
/// panel says *"14 dated samples through 24 Jul"* above a chart that drew
/// nothing, because all fourteen entries are `null`. Counting what was measured
/// is the same correction `history_panel.dart` already made for the metric
/// screen ("N observed samples"), and it is the difference between describing a
/// window and describing a measurement.
///
/// **A chart with fewer than two readings draws nothing and keeps its slot**
/// rather than swapping in a sentence. That is `chart_void.dart`'s rule for
/// every other chart in this app, and the note under it already says how many
/// readings there are — two sentences saying the same absence is how a screen
/// starts reading as broken.
///
/// ## The figure is a [Reading], and its absence carries no invented remedy
///
/// A day with no row is [Withheld] with a reason the app can actually stand
/// behind: nothing was recorded. `workout_readings.dart` set the precedent and
/// the rule with it — *"no remedy is invented"*. There is no action that
/// produces a measurement for a day that has already happened, so the sentence
/// does not offer one.
///
/// ## Nothing here takes a `Color`
///
/// The tone is the metric's identity (`metric_tone.dart`), it is declared on the
/// [Panel], and the icon, the chart ink and the action all resolve it from the
/// enclosing `ToneScope`.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/history/history_window.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/charts/v02/metric_series.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/format/date_labels.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/metric_tone.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// How many calendar days a dated panel's chart covers — `H.historyPanel`'s
/// `limit=14`, and the reason the batched read asks for a longer window than any
/// one panel draws.
const int kDatedPanelDays = 14;

/// The reason id for a day the strap recorded nothing on.
const String kNoReadingReason = 'no_reading_on_day';

/// One metric's dated card: the day's reading, its fortnight, and one sentence.
class DatedPanel extends StatelessWidget {
  /// [metric] is the server's canonical id — the key the name, the tone, the
  /// curve and the decimals are all read with, so they cannot disagree.
  const DatedPanel({
    required this.metric,
    required this.unit,
    required this.day,
    required this.window,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// `.chart` inside a full-width panel.
  static const double chartHeight = 140;

  /// The gap between the figure and the chart.
  static const double chartGap = 8;

  /// The canonical metric id.
  final String metric;

  /// Its unit, as `HistoryMetric` names it.
  final String unit;

  /// The day the reader has chosen. The window's last slot, and the date the
  /// panel's own sentences are about.
  final String day;

  /// The fortnight ending on [day], one slot per calendar day.
  final HistoryWindow window;

  /// Where "this chart has already been revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens this metric's own dated series. Null draws no action.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final tone = toneForMetric(metric);
    final decimals = decimalsFor(metric);
    final reading = readingOn(window, day);
    final title = metricTitle(metric);
    return Panel(
      tone: tone,
      label: title,
      head: PanelHead(
        title: title,
        icon: iconForTone(tone),
        infoKey: metric,
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            switch (reading) {
              Present<double>(:final value) ||
              Caveated<double>(:final value) => value.toStringAsFixed(decimals),
              Withheld<double>() || Excluded<double>() => '—',
            },
            unit: unit.isEmpty ? null : unit,
            context_: switch (reading) {
              Present<double>() || Caveated<double>() => shortDate(day),
              Withheld<double>(:final disclosure) => disclosure.message,
              Excluded<double>() => null,
            },
          ),
          const SizedBox(height: chartGap),
          RevealOnce(
            // The metric and the day it ends on. Stepping the date control is a
            // different chart and earns a fresh reveal; scrolling past this one
            // is the same chart and must not replay it.
            id: 'dated:$metric:$day',
            registry: reveals,
            builder: (context, t) => V02LineChart(
              window.values,
              progress: t,
              height: chartHeight,
              unit: unit,
              digits: decimals,
              // Straight for a total or an extremum, monotone only for a signal
              // sampled densely enough that the space between two readings is a
              // path rather than a boundary. `chart_curve.dart` argues it.
              curve: seriesCurveFor(metric),
              captions: window.captions,
              sampleLabels: window.sampleLabels,
              semanticLabel: window.isEmpty
                  ? null
                  : '$title, $unit. ${window.captions.join(' to ')}.',
            ),
          ),
          PanelNote(datedPanelNote(window, day)),
        ],
      ),
    );
  }
}

/// The reading on [day], as the honesty layer sees it.
///
/// Public because the wording of an absence is a claim, and a test that could
/// only reach it through a rendered widget would be testing the layout instead.
Reading<double> readingOn(HistoryWindow window, String day) {
  final value = window.on(day);
  if (value != null) {
    return Present<double>(value);
  }
  return const Withheld<double>(
    Disclosure(
      reason: kNoReadingReason,
      // No remedy, deliberately. The day is over; nothing the owner does now
      // puts a measurement into it, and an instruction that cannot work is
      // worse than an absence that admits itself.
      message: 'No reading on this day',
    ),
  );
}

/// `14 dated samples through 24 Jul.` — the sentence under the chart.
String datedPanelNote(HistoryWindow window, String day) {
  final count = window.observed.length;
  if (count == 0) {
    return 'No dated samples through ${shortDate(day)}.';
  }
  return '${groupedInt(count)} dated '
      '${count == 1 ? 'sample' : 'samples'} through ${shortDate(day)}.';
}
