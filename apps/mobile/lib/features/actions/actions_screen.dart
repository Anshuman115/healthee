/// Actions — the v02 screen: what to try, what is running, and what changed.
///
/// ## The prototype's order, and it is the order
///
/// `screens-actions.js::H.screens.actions` is five things and this list is those
/// five things:
///
/// ```text
///   header                       date · "Small steps. / Your pace." · avatar
///   focus-card                   Today’s suggestion
///   section  What you’re working on   challenge card(s) + program row
///   section  Your daily check-in     journal strip
///   section  Look back, learn a little   outcomes · previous suggestions
///   footer
/// ```
///
/// `test/features/actions_order_test.dart` asserts it against that list rather
/// than against a scroll position, for the reason `_screen_data.dart` gives:
/// order is a decision, and scrolling until something appears asserts what
/// happened to be on screen when the drag stopped.
///
/// ## What is here that Today does not show
///
/// Today draws the top recommendation under `Suggested today`. This screen draws
/// the whole ranked set, each in the prototype's focus card and each naming the
/// reading that raised it. Adoption records **intent**, never completion —
/// `v02/suggestion_card.dart` holds that sentence and the reason for it.
///
/// ## A quiet day draws nothing rather than a heading over nothing
///
/// Every block is gated on what the payload carried. `EmptyState` survives in
/// exactly one place — a server that answered with no recommendations at all —
/// because that is a sentence about the day, not an absent section.
///
/// ## The set's own day, when it is not the day in the header
///
/// `read/today.py::_recommendations_for` reaches **two days back** for the newest
/// set at or before the day being served. The header eyebrow here names the day the
/// PAYLOAD is for, so a two-day-stale set was relabelled as today's — while the Today
/// card next door said "written for &lt;day&gt;" about the identical rows. One surface
/// fixed, one not, and the fix in the file next door: audit C5, the same class as A4
/// and the third instance of it.
///
/// The decision now lives in `shared/format/other_day.dart` and both screens call it,
/// so a fix cannot land on one of them again.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/features/actions/v02/suggestion_card.dart';
import 'package:healthee/features/actions/v02/working_on.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/format/other_day.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/journal_strip.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/past_day.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/screen_head.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's own h1 for this screen, its line break included.
const String kActionsTitle = 'Small steps.\nYour pace.';

/// What Actions cannot date. `screens.actions`'s own past-day heading.
const String kActionsPastTitle = 'No saved suggestion';

/// The three section headings, in the prototype's words and its order.
const String kWorkingOnHeading = 'What you’re working on';

/// The second.
const String kCheckInHeading = 'Your daily check-in';

/// The third.
const String kLookBackHeading = 'Look back, learn a little';

/// The Actions tab.
class ActionsScreen extends ConsumerWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const ActionsScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InstrumentScreen(
      now: now,
      sections: (data) => actionsSections(data, ActionsLinks.of(context)),
      onRefreshed: () => ref.invalidate(commitmentRepositoryProvider),
    );
  }
}

/// Where this screen can go. Passed in so the section list stays a pure
/// function of the payload and a test can build one with no router at all.
@immutable
class ActionsLinks {
  /// Every destination the screen offers.
  const ActionsLinks({
    this.onOpenProfile,
    this.onOpenJournal,
    this.onOpenOutcomes,
    this.onOpenHistory,
  });

  /// The set bound to a real router.
  factory ActionsLinks.of(BuildContext context) => ActionsLinks(
    onOpenProfile: () => unawaited(context.push(Routes.settings)),
    onOpenJournal: () => unawaited(context.push(Routes.journal)),
    onOpenOutcomes: () => unawaited(context.push(Routes.outcomes)),
    onOpenHistory: () => unawaited(context.push(Routes.recommendations)),
  );

  /// The avatar.
  final VoidCallback? onOpenProfile;

  /// The check-in strip.
  final VoidCallback? onOpenJournal;

  /// `What changed?`
  final VoidCallback? onOpenOutcomes;

  /// `Previous suggestions`.
  final VoidCallback? onOpenHistory;
}

/// Builds the ordered section list for one render of Actions.
List<PageSection> actionsSections(ScreenData data, ActionsLinks links) {
  final past = data.view.isPast;
  // Null on a past day. A suggestion is written overnight FOR the current day
  // and `/api/today` takes no other; the challenge and program a reader is on
  // are current state for the same reason. Showing either under an older date
  // would be dating today's advice to a day it was not given on.
  final snapshot = past ? null : data.snapshot;
  final recommendations = snapshot?.recommendations ?? const <Recommendation>[];
  return <PageSection>[
    PageSection(
      ScreenHead(
        eyebrow: past
            ? data.view.line
            : (snapshot == null
                  ? null
                  : '${prettyDate(snapshot.date)} · ${data.view.status}'),
        title: kActionsTitle,
        trailing: HTap(
          onTap: links.onOpenProfile,
          semanticLabel: 'Settings',
          child: const HAvatar('H'),
        ),
      ),
      gap: 0,
    ),
    if (past)
      const PageSection(
        PastDayNotice(title: kActionsPastTitle, body: kPastDayReason),
        gap: PageSpacing.block,
      ),
    if (!past) ...<PageSection>[
      if (data.serverFailure case final PageSection failure) failure,
      if (data.serverPending case final PageSection pending) pending,
    ],

    // ── the suggestions ────────────────────────────────────────────────────
    // The set's own day, said in words, whenever it is not the day the payload
    // answers for. Above the cards because it qualifies the whole set.
    if (recommendationsFromDay(recommendations, snapshot?.asOf?.day)
        case final String day)
      PageSection(
        PanelNote(writtenForDay(day)),
        gap: PageSpacing.panel,
      ),
    if (snapshot != null)
      if (recommendations.isEmpty)
        const PageSection(
          EmptyState(
            message: 'Nothing suggested for today',
            hint:
                'Actions are written overnight from the readings the server '
                'has, and only where a reading actually raised one. A quiet day '
                'is a day with nothing worth telling you to change.',
          ),
          gap: PageSpacing.block,
        )
      else
        for (var i = 0; i < recommendations.length; i++)
          PageSection(
            SuggestionCard(recommendation: recommendations[i], first: i == 0),
            gap: i == recommendations.length - 1
                ? PageSpacing.block
                : PageSpacing.panel,
          ),

    // ── what you’re working on ─────────────────────────────────────────────
    // Absent on a past day: a challenge's progress and a program's week are
    // both "as of now", and `screens.actions`'s own past-day view drops them.
    if (!past) ...<PageSection>[
      const PageSection(SectionHead(title: kWorkingOnHeading), gap: 0),
      const PageSection(WorkingOn(), gap: PageSpacing.block),
    ],

    // ── your daily check-in ────────────────────────────────────────────────
    const PageSection(SectionHead(title: kCheckInHeading), gap: 0),
    PageSection(
      JournalStrip(onOpen: links.onOpenJournal ?? () {}),
      gap: PageSpacing.block,
    ),

    // ── look back, learn a little ──────────────────────────────────────────
    const PageSection(SectionHead(title: kLookBackHeading), gap: 0),
    PageSection(
      RowCard(<Widget>[
        ListRow(
          icon: SolarIconsOutline.chartSquare,
          title: 'What changed?',
          subtitle: 'Review outcomes without jumping to conclusions',
          tone: Tone.movement,
          onTap: links.onOpenOutcomes,
        ),
        ListRow(
          icon: SolarIconsOutline.clockCircle,
          title: 'Previous suggestions',
          subtitle: 'Your intentions and action history',
          tone: Tone.fitness,
          onTap: links.onOpenHistory,
        ),
      ]),
      gap: 0,
    ),
    const PageSection(DataFooter(), gap: 0),
  ];
}
