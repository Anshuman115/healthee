/// What Today draws from this phone's own store — the half that needs no server.
///
/// Split out of `today_sections.dart` at the 400-line gate (Standards section
/// 1), and the seam is a real one: everything here is the MEASURED half, which
/// is stored per calendar day and readable with no network at all. It is drawn
/// in two situations that look alike and are not —
///
/// ```text
///   a past day          the server CANNOT answer for it     [pastDaySections]
///   the current day,
///   server unreachable  the server has not answered YET     [measuredOnlySections]
/// ```
///
/// — and the difference is exactly what each says in its own note. The first is
/// permanent and about the endpoint; the second is a connection problem and
/// carries the health card and a retry. Two functions rather than one with a
/// flag, because the two sentences must never be able to swap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/history/dated_history.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/device_health_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/v02/chapter.dart';
import 'package:healthee/shared/v02/dated_history.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/past_day.dart';

/// A day that is not today: what the strap measured, and nothing derived.
///
/// **The refusal is the point.** Every judgement on this screen — recovery,
/// sleep health, debt, VO₂max, biological age — comes from `/api/today`, which
/// takes no day and answers for the current one. There is no request that would
/// produce them for a past day, so the alternatives were to draw today's numbers
/// under a past date or to draw nothing derived. The first is stale-as-current;
/// this is the second, and it says so rather than leaving a short screen to be
/// read as a bad day.
///
/// The measured half is real: the local tier stores the strap's own readings per
/// calendar day, so this renders with no network at all — the same guarantee
/// `docs/APP_DESIGN_BRIEF.md` section 7.4 makes for the current day.
void pastDaySections(
  SectionList sections,
  ScreenData data, {
  void Function(String metric)? onOpenMetric,
}) {
  final day = data.day;
  // `history-screens.js::screens.today` opens on exactly this block, above the
  // dated panels, so the reader meets the absence before the readings rather
  // than hunting for the judgements underneath them.
  sections.add(
    const PastDayNotice(title: kPastDayAnalysisTitle, body: kPastDayNote),
  );
  sections.gap(PageSpacing.panel);
  sections.add(
    Panel(
      head: const PanelHead(
        title: 'From the strap',
        icon: Icons.watch_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatRow(<Stat>[
            if (day.steps.valueOrNull case final int steps)
              Stat('Steps', commaGrouped(steps)),
            if (day.heartRate.valueOrNull case final double bpm)
              Stat('Heart rate', bpm.round().toString(), unit: 'bpm'),
          ]),
          const PanelNote(kPastDayMeasuredNote),
        ],
      ),
    ),
  );
  if (data.history case final AsyncValue<DatedHistory> history) {
    pastDayChapters(sections, data, history, onOpenMetric: onOpenMetric);
  }
}

/// `screens.today`'s three dated chapters, in the prototype's order.
///
/// ```js
/// H.chapter('overnight','Overnight readings','sleep','moon')
///   panels(['sleep','hrv','rhr','spo2','breathing','temperature',
///           'efficiency','regularity'])
/// H.chapter('daytime','Movement & effort','movement','walk')
///   panels(['steps','energy','total-energy','distance','mvpa','load'])
/// missing('Heart rate & stress timeline', …)
/// H.chapter('longer-view','Fitness & context','fitness','activity')
///   panels(['vo2'])
/// ```
///
/// The headings are the prototype's own and they are what make a long run of
/// cards readable as three groups rather than fourteen unrelated charts. They
/// are plain [ChapterHeading]s here, not the tab's jump targets: the chapter nav
/// belongs to the current day's screen, and a nav over a different set of
/// chapters would be a control that means one thing on Monday and another on
/// Tuesday.
void pastDayChapters(
  SectionList sections,
  ScreenData data,
  AsyncValue<DatedHistory> history, {
  void Function(String metric)? onOpenMetric,
}) {
  void chapter(
    String title,
    IconData icon,
    Tone tone,
    List<HistoryMetric> metrics,
    List<String> unserved,
  ) {
    sections.gap(PageSpacing.block);
    sections.add(ChapterHeading(title: title, icon: icon, tone: tone));
    addDatedPanels(
      sections,
      history: history,
      metrics: metrics,
      day: data.view.day,
      reveals: data.reveals,
      onRetry: data.onRetryHistory,
      onOpenMetric: onOpenMetric,
    );
    if (unservedNotice(unserved) case final Widget notice) {
      sections.gap(PageSpacing.panel);
      sections.add(notice);
    }
  }

  chapter(
    'Overnight readings',
    Icons.bedtime_outlined,
    Tone.sleep,
    kNightDatedMetrics,
    kNightUnserved,
  );
  chapter(
    'Movement & effort',
    Icons.directions_walk,
    Tone.movement,
    kDayDatedMetrics,
    const <String>[],
  );
  // `missing('Heart rate & stress timeline', 'Hourly traces are included only
  // for the latest sample day.')` — and for the same structural reason as the
  // rest: `/api/today` carries the hourly traces and takes no day.
  sections.gap(PageSpacing.panel);
  sections.add(
    const PastDayNotice(title: kPastDayTracesTitle, body: kPastDayTracesNote),
  );
  chapter(
    'Fitness & context',
    Icons.monitor_heart_outlined,
    Tone.fitness,
    kLongerDatedMetrics,
    const <String>[],
  );
}

/// `H.chapter('overnight', …)`'s panels — `sleep` and the two the server keeps
/// no daily series for are in [kNightUnserved] instead.
const List<HistoryMetric> kNightDatedMetrics = <HistoryMetric>[
  HistoryMetric.hrv,
  HistoryMetric.restingHr,
  HistoryMetric.oxygen,
  HistoryMetric.breathing,
  HistoryMetric.sleepRegularity,
];

/// Three of the prototype's eight overnight panels have no dated daily series
/// on this server — `BACKEND_GAPS_FROM_UI.md` C3 checked both sides.
const List<String> kNightUnserved = <String>[
  kUnservedSleepDuration,
  kUnservedSleepEfficiency,
  kUnservedSkinTemperature,
];

/// `H.chapter('daytime', …)`'s panels. All six are served.
const List<HistoryMetric> kDayDatedMetrics = <HistoryMetric>[
  HistoryMetric.steps,
  HistoryMetric.activeEnergy,
  HistoryMetric.totalEnergy,
  HistoryMetric.distance,
  HistoryMetric.activeMinutes,
  HistoryMetric.cardioLoad,
];

/// `H.chapter('longer-view', …)`'s one panel.
const List<HistoryMetric> kLongerDatedMetrics = <HistoryMetric>[
  HistoryMetric.fitness,
];

/// `missing('Heart rate & stress timeline', …)` — the prototype's own heading.
const String kPastDayTracesTitle = 'Heart rate & stress timeline';

/// Why the hourly traces are not here. Structural, like every other refusal.
const String kPastDayTracesNote =
    'The hour-by-hour heart rate and stress traces arrive with the current '
    'day’s payload, which takes no date, so they are shown for the latest day '
    'only rather than replayed under an older one.';

/// `missing('Daily analysis', …)` — the prototype's own heading for the block.
const String kPastDayAnalysisTitle = 'Daily analysis';

/// Why a past day carries no judgements. One sentence, and it is about us.
const String kPastDayNote =
    'Recovery, sleep health, debt, VO₂max and biological age are worked out for '
    'the current day only, so nothing derived is shown here rather than today’s '
    'figures under an older date.';

/// What the panel beneath it IS, so a short screen is not read as a bad day.
const String kPastDayMeasuredNote =
    'Measured on this phone on the day you are viewing, and readable with no '
    'network at all.';

/// What this phone measured, when the server cannot be reached.
///
/// **Not a prototype section, and it appears in one state only.** This app holds
/// the strap's own readings on disk, and `docs/APP_DESIGN_BRIEF.md` §7.4 requires
/// that half to render with no network at all: an app that shows zero
/// measurements while sitting on a database of them is broken, not careful.
///
/// It draws only behind the failure card, in v02's own twin-panel row, and
/// nothing on the healthy path moves by a pixel.
void measuredOnlySections(SectionList sections, ScreenData data) {
  final day = data.day;
  sections.add(
    Panel(
      head: const PanelHead(
        title: 'From the strap',
        icon: Icons.watch_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatRow(<Stat>[
            if (day.steps.valueOrNull case final int steps)
              Stat('Steps', commaGrouped(steps)),
            if (day.heartRate.valueOrNull case final double bpm)
              Stat('Heart rate', bpm.round().toString(), unit: 'bpm'),
          ]),
          const PanelNote(
            'Measured on this phone, since midnight. The server has not been '
            'reached, so nothing here has been derived.',
          ),
        ],
      ),
    ),
  );
  sections.gap(PageSpacing.panel);
  sections.add(DeviceHealthCard(day: day, now: data.now));
}
