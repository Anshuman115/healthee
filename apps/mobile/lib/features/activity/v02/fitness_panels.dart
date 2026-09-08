/// The fitness screen's own panels: the estimate, its history, its instrument.
///
/// `design/mobile-preview/screens-fitness.js::H.screens.fitness`:
///
/// ```js
/// H.panel('Cardiorespiratory fitness','fitness', value + vo2 rail + three stats + note,'','activity')
/// H.panel('Your stored estimate history','fitness', line(trend_90d) + note,'metric/vo2')
/// H.panel('Which instrument produced it?','fitness',
///         h3 + badge + note(method_caveat) + two stats + evidence,'workout','location')
/// ```
///
/// ## The ± is an error MAGNITUDE and the prototype says so in as many words
///
/// *"Supplied error magnitude: ±2.95 ml/kg/min, derived from MAPE 6.85%. The
/// band is not a confidence interval."* `see_ml_kg_min` is a published model
/// error against lab CPET, not an interval computed for this owner, and the
/// sentence that says so is drawn from the payload's own two fields rather than
/// written out — a server that revises the figure revises the sentence.
///
/// ## The history now names the instrument that read each point
///
/// `trend_90d` used to carry a date and a value and **no method**, while
/// `vo2max_tier.py` writes that series from three different instruments — so a
/// step in it might be the owner or might be the ruler, and nothing on the wire
/// could tell them apart. The note said exactly that.
///
/// It carries `method` now (`docs/BACKEND_GAPS_FROM_UI.md` B2), so the caveat is
/// a legend: [StoredHistoryPanel.note] names what read the latest point and, when
/// the window crosses more than one instrument, says that a step in the line may
/// be that change. **The sentence still appears when the wire says nothing** —
/// an old server sending no method is not the same fact as a window read by one
/// instrument throughout, and collapsing the two would be the caveat quietly
/// disappearing rather than being answered.
///
/// The points are still joined with straight segments, because a spline between
/// two stored estimates would draw a fitness nobody estimated.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/shared/charts/v02/chart_curve.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/format/date_labels.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/instruments/vo2max_rail.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/surface_panels.dart';

/// Shown only when the wire named no instrument on any point of the window.
///
/// It was unconditional, and true, until the server started sending `method`
/// per point. It is kept for the server that does not: an unlabelled series is
/// still a series a method change could be hiding in.
const String kStoredHistoryNote =
    'Historical method metadata is not supplied, so a method change cannot be '
    'distinguished from a fitness change here.';

/// Shown when the window was read by more than one instrument.
///
/// The caveat's answer rather than its removal: the thing it warned about has
/// happened, and now the line can say so instead of warning that it could not.
const String kMixedMethodNote =
    'This window was read by more than one instrument, so a step in the line '
    'can be a change of method rather than a change of fitness.';

/// Shown when every point of the window names the SAME instrument.
///
/// The one case the old caveat was wrong about: nothing was mixed, and saying a
/// method change could be hiding here would be inventing a doubt.
const String kSingleMethodNote =
    'Every estimate in this window was read the same way, so its shape is a '
    'change in you rather than a change of instrument.';

/// `Cardiorespiratory fitness` — the estimate, its rail and its error magnitude.
class CardiorespiratoryPanel extends StatelessWidget {
  /// [vo2max] is the payload's block.
  const CardiorespiratoryPanel({
    required this.vo2max,
    required this.reveals,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Cardiorespiratory fitness';

  /// The estimate and everything the server said about how it was made.
  final Vo2max vo2max;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// `Supplied error magnitude: ±2.95 ml/kg/min, derived from Carrier 2023…`
  ///
  /// **The last sentence is load-bearing** and `test/mutations.sh` breaks it on
  /// purpose: an error magnitude silently read as a confidence interval is a
  /// reader mis-reading the uncertainty of the number above it.
  static String? errorNote(Vo2max vo2max) {
    final magnitude = vo2max.standardErrorMlKgMin;
    if (magnitude == null) {
      return null;
    }
    final source = vo2max.standardErrorSource;
    final derived = source == null ? '' : ', derived from $source';
    return 'Supplied error magnitude: ±${magnitude.toStringAsFixed(2)} '
        'ml/kg/min$derived. The band is not a confidence interval.';
  }

  /// `VO₂max estimate` over the day it was read, and the day it was MEASURED.
  ///
  /// The second date appears only when it differs from the first. `as_of_date` is
  /// the day the estimate is offered for; `measured_as_of` is the day the session
  /// behind it was recorded, and the tiered metric lets those be up to fourteen
  /// days apart. Drawing only the first read as "as of today" over a fortnight-old
  /// run — the stale-as-current lie, arriving through the client.
  static String context_(Vo2max vo2max) => <String>[
    'VO₂max estimate',
    if (vo2max.asOfDate case final String date) prettyDate(date),
    if (vo2max.measuredEarlier case final String day) 'Measured ${prettyDate(day)}',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final note = errorNote(vo2max);
    return Panel(
      tone: Tone.fitness,
      label: 'VO₂max · estimate',
      caveats: <Disclosure>[vo2max.methodDisclosure],
      head: PanelHead(
        title: title,
        icon: Icons.monitor_heart_outlined,
        infoKey: 'vo2max',
        detail: MetricDetail(
          notes: vo2max.researchNotes,
          source: vo2max.standardErrorSource,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            vo2max.estimate.toStringAsFixed(1),
            unit: 'ml/kg/min',
            context_: context_(vo2max),
          ),
          RevealOnce(
            id: 'fitness.vo2max-rail',
            registry: reveals,
            builder: (context, t) => Vo2maxRail(
              estimate: vo2max.estimate,
              medianForAge: vo2max.medianForAge,
              errorMagnitude: vo2max.standardErrorMlKgMin,
              progress: t,
            ),
          ),
          StatRow(<Stat>[
            if (vo2max.medianForAge case final double median)
              Stat('Age/sex median', median.toStringAsFixed(1)),
            if (vo2max.deltaFromMedian case final double delta)
              Stat(
                'vs reference',
                '${delta < 0 ? '−' : '+'}${delta.abs().toStringAsFixed(1)}',
              ),
            if (vo2max.sessionCount case final int sessions)
              Stat(sessions == 1 ? 'Session' : 'Sessions', '$sessions'),
          ]),
          if (note != null) PanelNote(note),
        ],
      ),
    );
  }
}

/// `Your stored estimate history` — every estimate the server has kept.
class StoredHistoryPanel extends StatelessWidget {
  /// [vo2max] supplies `trend_90d`; the panel draws nothing without two points.
  const StoredHistoryPanel({
    required this.vo2max,
    required this.reveals,
    this.onDetails,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Your stored estimate history';

  /// The plot's height, before its readout line.
  static const double chartHeight = 150;

  /// The gap above the chart.
  static const double chartGap = 8;

  /// The estimate and its stored series.
  final Vo2max vo2max;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens the VO₂max metric history.
  final VoidCallback? onDetails;

  /// The dates behind the series, oldest first.
  List<String> get dates => <String>[
    for (final point in vo2max.trend90d) shortDate(point.date),
  ];

  /// The note, with the latest point's instrument in front of it.
  ///
  /// Three endings, and they are three different facts about the window — see
  /// the library docstring for why the unlabelled one may not be folded into
  /// the single-instrument one.
  String get note {
    final latest =
        'The latest estimate was read by ${methodLabel(vo2max.method)}.';
    final methods = TrendPoint.methodsIn(vo2max.trend90d);
    final tail = switch (methods.length) {
      0 => kStoredHistoryNote,
      1 => kSingleMethodNote,
      _ => kMixedMethodNote,
    };
    return '$latest $tail';
  }

  @override
  Widget build(BuildContext context) => Panel(
    tone: Tone.fitness,
    label: 'VO₂max · stored estimates',
    head: PanelHead(
      title: title,
      icon: Icons.show_chart,
      infoKey: 'vo2max',
      actionLabel: onDetails == null ? null : 'Details',
      onAction: onDetails,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: chartGap),
        RevealOnce(
          id: 'fitness.vo2max-history',
          registry: reveals,
          builder: (context, t) => V02LineChart(
            <double?>[for (final point in vo2max.trend90d) point.value],
            progress: t,
            height: chartHeight,
            unit: 'ml/kg/min',
            digits: 1,
            // Stored daily estimates, not a continuous trace. See the library
            // docstring.
            curve: SeriesCurve.straight,
            captions: dates.isEmpty
                ? const <String>[]
                : <String>[dates.first, dates.last],
            sampleLabels: dates,
            semanticLabel: 'Stored VO₂max estimates, ml/kg/min',
          ),
        ),
        PanelNote(note),
      ],
    ),
  );
}

/// `Which instrument produced it?` — the fit behind a session-read estimate.
class InstrumentPanel extends StatelessWidget {
  /// [vo2max] must carry a `submax` block; the screen gates on it.
  const InstrumentPanel({
    required this.vo2max,
    required this.submax,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Which instrument produced it?';

  /// The gap above the statistics row.
  static const double statsGap = 14;

  /// The estimate this fit produced.
  final Vo2max vo2max;

  /// The fit's own numbers.
  final Vo2maxSubmax submax;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Panel(
      tone: Tone.fitness,
      label: 'VO₂max · instrument',
      head: PanelHead(
        title: title,
        icon: Icons.place_outlined,
        infoKey: 'vo2max',
        detail: MetricDetail(
          notes: vo2max.researchNotes,
          source: vo2max.standardErrorSource,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  methodLabel(submax.lastMethod ?? vo2max.method),
                  style: TypeScale.panelTitle.copyWith(color: colors.ink),
                ),
              ),
              const StatusBadge('Latest', accented: true),
            ],
          ),
          // The server's own paragraph about how this number was made, drawn in
          // full: this is the panel that exists to carry it.
          PanelNote(vo2max.methodCaveat),
          const SizedBox(height: statsGap),
          StatRow(<Stat>[
            if (submax.lastR2 case final double r2)
              Stat('Session fit · R²', r2.toStringAsFixed(2)),
            if (submax.lastSpeedKmh case final double speed)
              Stat('Last fitted speed', speed.toStringAsFixed(1), unit: 'km/h'),
          ]),
        ],
      ),
    );
  }
}
