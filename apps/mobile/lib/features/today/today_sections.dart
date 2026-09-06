/// The ordered sections of Today. Composition only — no widget is defined here.
///
/// **This is the v02 prototype's screen, in the prototype's order.** Owner
/// decision, 2026-09: *"we need every screen to be designed pixel perfect with
/// the same idea that i told."* The order below is `design/mobile-preview`'s
/// `screens-overview.js::H.screens.today` read top to bottom.
///
/// ```text
///   header                    date · Today · avatar with its sync ring
///   device strip              Helio Strap · charge · Data & sync
///   data health               silent when everything is fresh
///   illness banner            silent when nothing is flagged
///   ── the hero ──────────────
///   biological age            the halo, the figure, the ruler, two terms
///   summary tiles             recovery · sleep · movement
///   context bridge            what the estimate is, and is not
///   chapter nav               Your night · Your day · Longer view
///   ── Last night → today ────
///   recovery, explained       weights, colour key, four factor bars
///   overnight HRV | resting heart
///   sleep stages · seven nights
///   sleep health, beyond duration
///   context bridge            sleep's share of the recovery model
///   blood oxygen | sleep need & debt
///   ── Movement → recovery ───
///   heart rate & stress       one hour cursor, two labelled scales
///   steps & energy
///   context bridge            today's effort against remaining readiness
///   effort in context
///   active minutes | strength
///   ── Patterns → small changes ──
///   cardiorespiratory fitness
///   daily journal
///   suggested actions · insights
///   coach | actions           the two entry points
///   footer
/// ```
///
/// ## What survived the redesign unchanged, and why
///
/// The **data wiring**. Every figure is still a [Reading] off `TodayFacts`, every
/// block is still gated on what the payload carried, and every refusal still
/// renders as a refusal with its reason. The presentation is new; the honesty
/// layer under it is the same one, wired the same way.
///
/// The **illness banner** stays above everything a number can be read from —
/// brief §4.1 makes it deterministic and outranking, so nothing on this screen
/// may be read before it. It is null on this account today, and null draws
/// nothing.
///
/// **`pai` is null on this account and `anomalies` is `[]` unconditionally**
/// (`read/today.py:83`). Neither gets a section: a heading that can never have
/// content under it is dead code.
///
/// ## Two sections the prototype has that this screen does not
///
/// The prototype's `.date-controls` (previous / date / next) drives its
/// historical-day feature; this app reads one day and has no history route yet,
/// so the header prints the date rather than offering to change it. A control
/// that looks tappable and does nothing is worse than a missing one — the same
/// argument the pre-v02 header used for its own absent `+`.
///
/// The prototype's `.scenarioNotice` is its review-scenario switch. The live
/// equivalent is the data-health card, which says the same class of thing about
/// real data, so that is what sits in the slot.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/features/today/today_body.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/v02/today_chapters.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/shared/device_health_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// Everything Today needs that is not on [ScreenData].
@immutable
class TodayExtras {
  /// The push state, the session state, the classified connection, the strap's
  /// charge, the three things the header and the entry cards can open, and the
  /// chapter anchors the jump nav walks to.
  const TodayExtras({
    this.push,
    this.signedIn,
    this.health,
    this.batteryPercent,
    this.chapters,
    this.onSignIn,
    this.onOpenProfile,
    this.onOpenSync,
    this.onAddLog,
    this.onOpenCoach,
    this.onOpenActions,
  });

  /// What the app knows about its own pushing, for the data-health card.
  final PushStamp? push;

  /// Null while the keystore read is in flight — "not yet known", which the
  /// card stays silent about rather than guessing "signed out" for a frame.
  final bool? signedIn;

  /// The connection surface's one classification.
  ///
  /// Null draws no ring in the header, a neutral dot on the device strip and no
  /// link section on the data-health card. It carries `busy` and the fetch's
  /// progress, so nothing else has to.
  final ConnectionHealth? health;

  /// Strap battery at the last sync, for the device strip.
  final int? batteryPercent;

  /// Where the chapter nav jumps to. Null draws no nav rather than three dead
  /// buttons — see `today_chapters.dart`.
  final TodayChapters? chapters;

  /// Opens the sign-in screen.
  final VoidCallback? onSignIn;

  /// Opens settings. The avatar's destination.
  final VoidCallback? onOpenProfile;

  /// Opens the sync surface, from the device strip.
  final VoidCallback? onOpenSync;

  /// Opens the manual-entry log sheet, when there is one.
  final VoidCallback? onAddLog;

  /// Opens the coach.
  final VoidCallback? onOpenCoach;

  /// Opens the actions tab.
  final VoidCallback? onOpenActions;
}

/// Builds the ordered section list for one render of Today.
List<PageSection> todaySections(ScreenData data, TodayExtras extras) {
  final snapshot = data.snapshot;
  if (data.day.hasNothing && snapshot == null) {
    return _freshInstall(data, extras);
  }
  final now = data.now ?? DateTime.now();
  final sections = SectionList();
  sections.add(
    TodayHeader(
      date: snapshot?.date ?? data.day.date,
      now: now,
      health: extras.health,
      onOpenProfile: extras.onOpenProfile,
    ),
  );
  sections.add(
    DeviceStrip(
      health: extras.health,
      batteryPercent: extras.batteryPercent ?? data.day.batteryPercent,
      onOpenSync: extras.onOpenSync,
    ),
  );
  sections.add(_dataHealth(data, extras));
  // Above everything a number can be read from, and absent entirely when the
  // server flagged nothing. See the library docstring.
  if (snapshot?.illnessFlag case final flag?) {
    sections.add(IllnessBanner(flag: flag));
    sections.gap(PageSpacing.block);
  }
  if (data.serverFailure case final PageSection failure) {
    sections.addSection(failure);
    sections.gap(PageSpacing.panel);
    _measuredOnly(sections, data);
  }
  if (data.serverPending case final PageSection pending) {
    sections.addSection(pending);
  }
  if (snapshot != null) {
    todayBody(sections, TodayFacts.of(snapshot, now), data, extras);
  }
  return sections.build();
}

/// What this phone measured, when the server cannot be reached.
///
/// **Not a prototype section, and it appears in one state only.** This app holds
/// the strap's own readings on disk, and `docs/APP_DESIGN_BRIEF.md` §7.4 requires
/// that half to render with no network at all: an app that shows zero
/// measurements while sitting on a database of them is broken, not careful.
///
/// It draws only behind the failure card, in v02's own twin-panel row, and
/// nothing on the healthy path moves by a pixel.
void _measuredOnly(SectionList sections, ScreenData data) {
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

/// A phone that has synced nothing AND has heard nothing from the server.
List<PageSection> _freshInstall(ScreenData data, TodayExtras extras) {
  final now = data.now ?? DateTime.now();
  return <PageSection>[
    PageSection(
      TodayHeader(
        date: data.day.date,
        now: now,
        health: extras.health,
        onOpenProfile: extras.onOpenProfile,
      ),
      gap: 0,
    ),
    PageSection(
      DeviceStrip(
        health: extras.health,
        batteryPercent: extras.batteryPercent ?? data.day.batteryPercent,
        onOpenSync: extras.onOpenSync,
      ),
      gap: 0,
    ),
    PageSection(_dataHealth(data, extras), gap: 0),
    const PageSection(
      EmptyState(
        message: 'Nothing from your strap yet',
        hint:
            'Pull down on this screen with the strap on your wrist and nearby. '
            'Everything here comes off the device or from the '
            "server's reading of it; nothing is estimated in the meantime.",
      ),
    ),
    PageSection(DeviceHealthCard(day: data.day, now: data.now)),
    if (data.serverFailure case final PageSection failure) failure,
  ];
}

Widget _dataHealth(ScreenData data, TodayExtras extras) {
  final view = data.server.value;
  return DataHealthSection(
    health: data.snapshot?.dataHealth,
    // The radio's own faults have nowhere else to be said — see the card.
    connection: extras.health,
    push: extras.push,
    cachedAt: view != null && view.fromCache ? view.fetchedAt : null,
    cachedDate: view != null && view.describesAnotherDay(data.day.date)
        ? data.snapshot?.date
        : null,
    lastStrapSync: data.day.sync.lastCompleteSync,
    now: data.now,
    signedIn: extras.signedIn,
    onSignIn: extras.onSignIn,
    // The card carries its own bottom space, so a healthy day leaves no gap.
    bottomGap: 16,
  );
}
