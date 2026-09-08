/// What `#route` shows, in the prototype's order — and what it refuses to show.
///
/// ```js
/// H.screens.route = () => `${H.header('Your recorded route.','31 July · saved workout',true)}
///   ${H.charts.route()}
///   <div class="card section"><div class="three">Distance · Duration · Avg. pace</div>
///     ${H.source('Phone GPS · 20 sample fixes')}</div>
///   ${H.section('Elevation along the way', card + line chart + gain/loss)}
///   ${H.notice('Not enough heart-rate coverage', …)}
///   ${H.link('Record another route','record','button secondary full')}
///   ${H.footer()}`;
/// ```
///
/// ## Every figure is the server's, and an absent one is absent
///
/// The summary's fields are all nullable on the wire: a track the server could
/// not compute a pace for sends none. Each stat is therefore built only when its
/// number arrived — `StatRow` lays out the two it was given rather than three
/// with a dash in the middle, because a dash there reads as a measurement that
/// came back empty rather than one that was never sent.
///
/// ## The VO₂max notice is the prototype's own withheld slot
///
/// The fixture route carries the sentence *"This route has one matched
/// heart-rate point. A fitness estimate is withheld until coverage is
/// sufficient."* — the design already treats a missing session VO₂max as a
/// **stated refusal with its reason**, which is what `Reading` does everywhere
/// else in this app. So a real track with no estimate keeps the notice, and one
/// with an estimate replaces it with the estimate **and the instrument that
/// produced it**: `derive/vo2max_tier.py` names its method on the wire, and a
/// number without its method is the flattery mode #108 shipped.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/gps/recorded_route.dart';
import 'package:healthee/data/gps/route_point.dart';
import 'package:healthee/features/gps/route_map.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/full_button.dart';
import 'package:healthee/shared/v02/labels.dart';
import 'package:healthee/shared/v02/notices.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surface_cards.dart';

/// `H.section('Elevation along the way', …)`.
const String kElevationHeading = 'Elevation along the way';

/// The prototype's own headline for a track that cannot carry a fitness number.
const String kNoFitnessTitle = 'Not enough heart-rate coverage';

/// Why. The count is the track's own, so the sentence is about this recording.
String noFitnessBody(int matched) =>
    'This route has ${matched == 1 ? 'one matched heart-rate point' : '$matched '
        'matched heart-rate points'}. A fitness estimate is withheld until '
    'coverage is sufficient.';

/// `Model fit r²` — a fit, said plainly for what a fit is and is not.
String fitNote(double r2) =>
    'Model fit r² ${r2.toStringAsFixed(2)}. Fit describes how well the line '
    'follows these points; it does not establish that the measurement is right.';

/// The whole body of `#route`, in order.
List<Widget> routeDetailSections(
  BuildContext context,
  RecordedRoute route,
  RevealRegistry reveals,
) {
  return <Widget>[
    RouteMap(points: route.points),
    const SectionGap(),
    PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatRow(_summaryStats(route)),
          SourceNote('Phone GPS · ${route.points.length} fixes'),
        ],
      ),
    ),
    ..._elevation(route, reveals),
    ..._fitness(route),
    const SectionGap(),
    Builder(
      builder: (context) => V02FullButton(
        label: 'Record another route',
        onPressed: () => unawaited(context.push(Routes.gps)),
      ),
    ),
    const DataFooter(),
  ];
}

/// `.three` — Distance, Duration, Avg. pace, and only the ones that arrived.
List<Stat> _summaryStats(RecordedRoute route) => <Stat>[
  if (route.distanceKm case final double km)
    Stat('Distance', km.toStringAsFixed(2), unit: 'km'),
  if (route.durationS case final int seconds)
    Stat('Duration', durationLabel(seconds ~/ 60)),
  if (route.avgPaceMinKm case final double pace)
    Stat('Avg. pace', pace.toStringAsFixed(2), unit: '/km'),
];

/// `Elevation along the way` — the profile, then gain and loss under it.
///
/// Drawn only when the track carries elevations at all. A phone that recorded
/// no altitude gets no section rather than a flat line at zero, which would be
/// a reading of "level ground" that nothing measured.
List<Widget> _elevation(RecordedRoute route, RevealRegistry reveals) {
  final List<double?> values = <double?>[
    for (final RoutePoint point in route.points) point.elevationM,
  ];
  if (values.nonNulls.length < 2) {
    return const <Widget>[];
  }
  return <Widget>[
    const SectionGap(),
    const SectionHead(title: kElevationHeading),
    PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RevealOnce(
            // The track, not a list index: a different route drawn into the
            // same slot must animate, and the same one scrolled past must not.
            id: 'route:${route.id}:elevation',
            registry: reveals,
            builder: (context, t) => V02LineChart(
              values,
              progress: t,
              unit: 'm',
              // The prototype's own edge captions for this chart.
              captions: const <String>['Start', 'Finish'],
              semanticLabel:
                  'Elevation along your recorded track, in metres, start to '
                  'finish.',
            ),
          ),
          const SizedBox(height: Insets.lg),
          StatRow(<Stat>[
            if (route.elevationGainM case final double gain)
              Stat('Elevation gain', gain.round().toString(), unit: 'm'),
            if (route.elevationLossM case final double loss)
              Stat('Elevation loss', loss.round().toString(), unit: 'm'),
          ]),
        ],
      ),
    ),
  ];
}

/// The session estimate, or the prototype's stated refusal in its place.
List<Widget> _fitness(RecordedRoute route) {
  final double? vo2max = route.vo2max;
  if (vo2max == null) {
    return <Widget>[
      const SectionGap(),
      HNotice(
        title: kNoFitnessTitle,
        body: noFitnessBody(
          route.points.where((RoutePoint point) => point.hr != null).length,
        ),
      ),
    ];
  }
  return <Widget>[
    const SectionGap(),
    const SectionHead(title: 'Fitness from this session'),
    PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatRow(<Stat>[
            Stat(
              'Session VO₂max',
              vo2max.toStringAsFixed(1),
              unit: 'ml/kg/min',
            ),
            if (route.avgHr case final double bpm)
              Stat('Average heart rate', bpm.round().toString(), unit: 'bpm'),
            if (route.maxHr case final double bpm)
              Stat('Maximum heart rate', bpm.round().toString(), unit: 'bpm'),
          ]),
          // The instrument, always. `vo2max_tier.py` names its method on the
          // wire precisely so a screen never has to guess which tier produced
          // a number, and a number with no method beside it is the shape the
          // #108 failure shipped in.
          SourceNote(
            route.vo2Method == null
                ? 'Method not named by the server for this session'
                : 'Method · ${route.vo2Method}',
          ),
          if (route.r2 case final double r2) PanelNote(fitNote(r2)),
        ],
      ),
    ),
  ];
}
