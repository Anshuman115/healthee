/// `Sleep history` — the prototype's `#sleep-history`, opened from Sleep and
/// from Insights.
///
/// `design/mobile-preview/sleep-history-view.js`, read top to bottom:
///
/// ```text
///   header                  Sleep history
///   Sleep duration          the month of nightly totals
///   Seven nights of stages  the stacked week, and its colour key
///   Open a night            every night in the window, as a button
///   footer
/// ```
///
/// ## The rows set the day, and what that does today
///
/// `H.actions['date-night']` calls `H.setViewDate(...)` and then navigates to
/// Sleep, which is what produces the prototype's `?date=…#sleep`. The app's
/// equivalent of `setViewDate` is `viewDateProvider`, and it is written here for
/// the same reason: the selection *follows the reader between screens*.
///
/// **The Sleep screen does not yet re-window on it.** `/api/sleep` answers with
/// its own newest-first list and `SleepWindows` slices from the front;
/// `docs/V02_CONNECTIVITY.md` section 3 names carrying the day in the route as a
/// separate structural piece, and it is not this screen's to build. So a row
/// lands on Sleep with the day selected, and Sleep still opens on its latest
/// night. That is recorded here rather than hidden, and it is the one thing on
/// this screen that is not yet the prototype's behaviour.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/data/store/view_date.dart';
import 'package:healthee/features/sleep/v02/history_panels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/detail_page.dart';
import 'package:healthee/shared/v02/list_rows.dart';
import 'package:healthee/shared/v02/section_head.dart';

/// The prototype's own title for this screen.
const String kSleepHistoryTitle = 'Sleep history';

/// How many nights the duration chart and the list cover.
const int kSleepHistoryDays = 30;

/// How many nights the stage chart covers.
const int kSleepHistoryWeek = 7;

/// The sleep-history screen.
class SleepHistoryScreen extends ConsumerStatefulWidget {
  /// Builds the screen.
  const SleepHistoryScreen({super.key});

  @override
  ConsumerState<SleepHistoryScreen> createState() => _SleepHistoryState();
}

class _SleepHistoryState extends ConsumerState<SleepHistoryScreen> {
  /// Outlives every panel, which is the whole reveal-once mechanism.
  final RevealRegistry _reveals = RevealRegistry();

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(sleepPageProvider)
        .when(
          skipLoadingOnRefresh: true,
          loading: () => const _Frame(
            children: <Widget>[LoadingState(label: 'Reading your nights')],
          ),
          error: (error, stackTrace) => _Frame(
            children: <Widget>[
              ErrorState(
                message: "Couldn't reach your server for your nights",
                detail:
                    'Your nights are safe. This is a connection problem, not '
                    'a gap in them.',
                onRetry: () => ref.invalidate(sleepPageProvider),
              ),
            ],
          ),
          data: (page) => SleepHistoryDetail(
            page: page,
            reveals: _reveals,
            onOpenNight: _openNight,
          ),
        );
  }

  /// Sets the day the reader is looking at, then opens Sleep.
  void _openNight(BuildContext context, String date) {
    ref.read(viewDateProvider.notifier).select(date);
    unawaited(context.push(Routes.sleep));
  }
}

/// The screen's body. Public so the screen tests can host it directly.
class SleepHistoryDetail extends StatelessWidget {
  /// Builds the detail for one render of `/api/sleep`.
  const SleepHistoryDetail({
    required this.page,
    required this.reveals,
    this.onOpenNight,
    super.key,
  });

  /// `.panel { margin-top: 12px }`.
  static const double panelGap = 12;

  /// `.section { margin-top: 24px }`.
  static const double blockGap = 24;

  /// `/api/sleep`.
  final SleepPage page;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens one night. Null draws the rows without chevrons.
  final void Function(BuildContext context, String date)? onOpenNight;

  /// The window the chart and the list cover, newest first.
  List<SleepNight> get window => page.nights.take(kSleepHistoryDays).toList();

  /// The stacked week, oldest first.
  List<SleepNightSummary> get week => <SleepNightSummary>[
    for (final night in page.nights.take(kSleepHistoryWeek).toList().reversed)
      SleepNightSummary(
        date: night.date,
        durationMin:
            night.tstMin.valueOrNull?.round() ?? night.stages.total.round(),
        deepMin: night.stages.deep.round(),
        lightMin: night.stages.light.round(),
        remMin: night.stages.rem.round(),
        awakeMin: night.stages.awake.round(),
        deviceScore: night.deviceScore.valueOrNull?.round(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final nights = window;
    if (nights.isEmpty) {
      return const _Frame(
        children: <Widget>[
          EmptyState(
            message: 'No sleep recorded yet',
            hint: 'Wear the strap overnight and sync, and this fills in.',
          ),
        ],
      );
    }
    return _Frame(
      children: <Widget>[
        // **No Details link.** The prototype points this panel at
        // `metric/sleep`; `history_metric.dart` offers no sleep-DURATION
        // series, so `?metric=sleep` matched nothing and `history_screen.dart`
        // fell back to HRV — a control that opened a different measurement
        // under the same word, silently. Sleep debt and sleep health exist and
        // are not duration, so neither is a substitute. The link comes back
        // with the metric.
        SleepDurationPanel(nights: nights, reveals: reveals),
        // One bar is not a week. The prototype draws seven; the payload decides.
        if (week.length >= 2) ...<Widget>[
          const SizedBox(height: panelGap),
          NightStagesPanel(nights: week, reveals: reveals),
        ],
        const SizedBox(height: blockGap),
        const SectionHead(title: 'Open a night'),
        FlushCard(
          rows: <Widget>[
            for (final night in nights)
              NightRow(
                night: night,
                onOpen: onOpenNight == null
                    ? null
                    : () => onOpenNight!(context, night.date),
              ),
          ],
        ),
        const SizedBox(height: blockGap),
        const DataFooter(),
      ],
    );
  }
}

/// The page every state of this screen is drawn in, so the head and the gutter
/// cannot differ between them.
class _Frame extends StatelessWidget {
  const _Frame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      DetailPage(title: kSleepHistoryTitle, children: children);
}
