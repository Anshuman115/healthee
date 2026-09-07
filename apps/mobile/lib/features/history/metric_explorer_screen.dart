/// **The metric explorer** — every signal this app holds a history for, and
/// what each one last read.
///
/// `screens-explore.js::H.screens.metrics`, read top to bottom:
///
/// ```text
///   header (detail)        <date> · Latest      Your health signals.
///   <p class="small">      A reading is a starting point…
///   .metric-list.section   one tile per metric, two across
///   .card.flush.section    Sleep history · Fitness estimates
///   footer
/// ```
///
/// ## The list is the app's own table, not the prototype's
///
/// The prototype's explorer holds **25** entries. Twenty of them are the ids in
/// `data/history/history_metric.dart` — the metrics `/api/history` will answer
/// for — and five are not: heart rate, stress, sleep duration, sleep efficiency
/// and skin temperature. Those five have no daily series on this server, so a
/// tile for one would be a door onto an endpoint that refuses. They are listed
/// in the brief for this screen and they are deliberately absent from it; the
/// gap is a server capability, and it is visible in `HistoryMetric` rather than
/// papered over here.
///
/// So this screen lists **exactly `HistoryMetric.values`**, in that enum's
/// order. `metric_explorer_test.dart` asserts the two are the same list, which
/// is what makes a metric added to the table appear here without anyone
/// remembering to add it.
///
/// ## Why the tiles are the CURRENT day and say so
///
/// The prototype has a second version of this screen for a past day
/// (`history-screens.js::screens.metrics`), which prints one dated reading per
/// metric under the caption *"A dash means no measurement on that day"*. It can
/// do that because it holds every series in the page. This app would have to
/// ask `/api/history` twenty times to fill one screen.
///
/// The alternative — drawing today's figures under a past date — is
/// stale-as-current, the failure `today_sections.dart` refuses for the same
/// reason and this repo has swept three times. So the explorer is the latest
/// reading only, and its own header names the day those readings are from. The
/// per-metric screen is where a day is chosen, and it genuinely follows it.
///
/// ## Where the figures come from
///
/// `/api/today`'s `metrics[]` — the server's own per-metric cards, each already
/// a `Reading<double>` — then its `sparklines`, whose last point is the same
/// day's value for the series the cards do not cover. A metric in neither
/// renders the em dash the prototype renders, under a caption that says what a
/// dash means. Nothing is computed here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/metric_card.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/history/v02/metric_tile.dart';
import 'package:healthee/shared/format/date_labels.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/format/number_labels.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/detail_page.dart';
import 'package:healthee/shared/v02/list_rows.dart';
import 'package:healthee/shared/v02/surface_cards.dart' show SmallProse;

/// `H.screens.metrics`'s own opening line.
const String kExplorerCaption =
    'A reading is a starting point. Open one to see its history, context and '
    'source.';

/// What a tile with no figure means. The prototype's caption, made true for a
/// screen that is always showing the newest day it has.
const String kDashCaption =
    'A dash means this signal has no reading on the day above.';

/// The explorer: every metric with a history, and the way into each one.
class MetricExplorerScreen extends ConsumerWidget {
  /// Builds the screen.
  const MetricExplorerScreen({super.key});

  /// `.section { margin-top: 24px }`.
  static const double sectionGap = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = currentAccountValue(ref.watch(todaySnapshotProvider));
    final snapshot = view.value?.snapshot;
    return DetailPage(
      title: 'Your health signals.',
      eyebrow: snapshot == null
          ? null
          : '${prettyDate(snapshot.date)} · Latest',
      children: <Widget>[
        const SmallProse(kExplorerCaption),
        // Above the grid, where `history-screens.js::screens.metrics` puts its
        // own dash caption: a reader who meets the dash first has to guess.
        const SmallProse(kDashCaption),
        const SizedBox(height: sectionGap),
        MetricGrid(
          entries: explorerEntries(snapshot),
          onOpen: (metric) => unawaited(
            context.push(
              '${Routes.history}?metric=${Uri.encodeComponent(metric)}',
            ),
          ),
        ),
        const SizedBox(height: sectionGap),
        FlushCard(
          rows: <Widget>[
            V02ListRow(
              icon: Icons.bedtime_outlined,
              title: 'Sleep history',
              detail: 'Duration, stages and regularity',
              tone: Tone.sleep,
              onOpen: () => context.go(Routes.sleep),
            ),
            V02ListRow(
              icon: Icons.monitor_heart_outlined,
              title: 'Fitness estimates',
              detail: 'VO₂max and biological age',
              tone: Tone.fitness,
              onOpen: () => context.go(Routes.activity),
            ),
          ],
        ),
        const SizedBox(height: sectionGap),
        const DataFooter(),
      ],
    );
  }
}

/// One [MetricEntry] per [HistoryMetric], in the table's own order.
///
/// Exported so the test can assert the list against `HistoryMetric.values`
/// without pumping a screen: what is being checked is which metrics the app
/// offers, not where the tiles landed.
List<MetricEntry> explorerEntries(TodaySnapshot? snapshot) {
  final cards = <String, MetricCard>{
    for (final card in snapshot?.metrics ?? const <MetricCard>[])
      card.metric: card,
  };
  return <MetricEntry>[
    for (final metric in HistoryMetric.values)
      _entryFor(metric, cards[metric.id], snapshot),
  ];
}

MetricEntry _entryFor(
  HistoryMetric metric,
  MetricCard? card,
  TodaySnapshot? snapshot,
) {
  final reading = card?.reading;
  final value = reading?.valueOrNull ?? _sparklineValue(snapshot, metric.id);
  return MetricEntry(
    metric: metric.id,
    // The card's own label when the server sent one, so the explorer and the
    // card the owner came from cannot call one quantity two things.
    title: card?.label ?? metricTitle(metric.id),
    unit: card?.unit ?? metric.unit,
    // A withheld reading has no figure: the tile draws the refusal instead.
    value: reading is Withheld<double> || value == null
        ? null
        : decimalLabel(value),
    reading: reading,
  );
}

/// The newest point of the same-day sparkline, for a metric with no card.
double? _sparklineValue(TodaySnapshot? snapshot, String metric) {
  final series = snapshot?.sparklines[metric];
  return series == null || series.isEmpty ? null : series.last.value;
}
