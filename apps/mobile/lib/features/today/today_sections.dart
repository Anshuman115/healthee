/// The ordered sections of Today. Composition only — no widget is defined here.
///
/// **This is legacy's screen, in legacy's order.** Owner decision 2026-08-05:
/// *"not a single change in design, every section remains as is, every tab,
/// everything — only honesty wording as mentioned."* The order below is
/// `healthee-legacy/app/lib/ui/today_screen.dart:217–378` read top to bottom, and
/// the spacers between the sections are legacy's own `SizedBox`es, which is what
/// [_Sections.gap] exists to express.
///
/// ```text
///   greeting header           date · battery · avatar · "Good morning,"
///   Recovery — <summary>.
///   data health               silent when everything is fresh
///   illness banner            ADDED · silent when nothing is flagged
///   recovery card             the gauge, the guidance, four factors
///   recovery signals          the ladder
///   suggested actions         collapsed
///   ── grid ──                Resting HR · HRV
///   HRV · 14 days
///   Stress · today
///   Heart rate · 24h
///   Sleep ─────────────────
///   (stale-sleep banner)
///   readiness block           the device sleep score
///   ── grid ──                Sleep · Respiratory rate
///   Blood oxygen · 14 nights
///   Sleep need · debt
///   Sleep health · 4-dim
///   Sleep · 7 nights
///   Activity ──────────────
///   ── grid ──                Steps · Energy · active
///   Strain · cardio load
///   Active minutes · MVPA
///   Strength · this week      ADDED · silent when the block is absent
///   Today · logged            ADDED · silent when nothing was logged
///   Fitness ───────────────
///   Biological age · estimate
///   VO₂max · estimate
///   Insights ──────────────
///   patterns
/// ```
///
/// ## What is NOT here, and why
///
/// **`TodayFocus`** (legacy 230) surfaces active challenges from
/// `GET /api/challenges`. This app has no client for that endpoint; the widget
/// renders nothing when there are no active challenges, so the omission costs no
/// pixels on an owner with none. Reported.
///
/// **`_SleepTonightMini`** (legacy 303) mirrors the Sleep tab's "Tonight" focus
/// from `GET /api/sleep/consistency`. Same situation, same `SizedBox.shrink()`
/// when absent. Reported.
///
/// ## Three things the server sends that NO legacy file reads
///
/// The owner's second instruction: surface what the API returns and legacy never
/// showed. Each one is added in legacy's own visual language, and each renders
/// **nothing** when its field is null or empty.
///
///   * **The illness banner** (`illness_flag`). Legacy references it in zero
///     files — a strictly verbatim port would delete a safety surface. It stays,
///     and it stays **above everything a number can be read from**: brief §4.1
///     makes it deterministic and outranking, so nothing on this screen may be
///     read before it. Null today on the live account, and null draws nothing.
///   * **`Strength · this week`** (`strength`), under `Active minutes · MVPA`.
///     They are the two halves of one recommendation.
///   * **`Today · logged`** (`routine`), under it. Sessions, meditation and an
///     open fast — a log, not a judgement.
///
/// **`pai` is null on this account and `anomalies` is `[]` unconditionally**
/// (`read/today.py:83` sets it, and the real data is behind a separate
/// premium-gated `/api/notable`). Neither gets a section: a heading that can
/// never have content under it is dead code.
///
/// ## The one structural difference from legacy, and it is the brief's
///
/// Legacy gates each block on `is Map` and draws **nothing** when the server sent
/// none. Every such block is a [Reading] here, so an absent or refused block
/// renders as a `WithheldCard` carrying its reason. That is the product's whole
/// premise applied to the last hop — "not enough data" beats a silent gap — and
/// it is state rather than layout: the card sits where legacy's card sat.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/features/today/today_body.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';
import 'package:healthee/features/today/widgets/greeting_header.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/features/today/widgets/recovery_summary_line.dart';
import 'package:healthee/shared/charts/day_line_chart.dart';
import 'package:healthee/shared/device_health_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Everything Today needs that is not on [ScreenData].
@immutable
class TodayExtras {
  /// The push state, the session state, the classified connection, the strap's
  /// charge, and the two things the header can open.
  const TodayExtras({
    this.push,
    this.signedIn,
    this.health,
    this.batteryPercent,
    this.syncing = false,
    this.onSignIn,
    this.onOpenProfile,
    this.onAddLog,
  });

  /// What the app knows about its own pushing, for the data-health card.
  final PushStamp? push;

  /// Null while the keystore read is in flight — "not yet known", which the
  /// card stays silent about rather than guessing "signed out" for a frame.
  final bool? signedIn;

  /// The connection surface's one classification. Null draws no dot.
  final ConnectionHealth? health;

  /// Strap battery at the last sync, for the header.
  final int? batteryPercent;

  /// Whether a sync is in flight — the ring around the avatar.
  final bool syncing;

  /// Opens the sign-in screen.
  final VoidCallback? onSignIn;

  /// Opens settings. Legacy's avatar opened the profile screen.
  final VoidCallback? onOpenProfile;

  /// Opens the manual-entry log sheet, when there is one. See
  /// `greeting_header.dart`.
  final VoidCallback? onAddLog;
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
    GreetingHeader(
      date: snapshot?.date ?? data.day.date,
      now: now,
      batteryPercent: extras.batteryPercent ?? data.day.batteryPercent,
      health: extras.health,
      syncing: extras.syncing,
      onOpenProfile: extras.onOpenProfile,
      onAddLog: extras.onAddLog,
    ),
  );
  sections.add(
    RecoverySummaryLine(
      summary: snapshot?.recoverySignals.valueOrNull?.summary,
    ),
  );
  sections.add(_dataHealth(data, extras));
  // Above everything a number can be read from, and absent entirely when the
  // server flagged nothing. See the library docstring.
  if (snapshot?.illnessFlag case final flag?) {
    sections.add(IllnessBanner(flag: flag));
    sections.gap(16);
  }
  if (data.serverFailure case final PageSection failure) {
    sections.addSection(failure);
    sections.gap(10);
    _measuredOnly(sections, data);
  }
  if (data.serverPending case final PageSection pending) {
    sections.addSection(pending);
  }
  if (snapshot != null) {
    todayBody(sections, TodayFacts.of(snapshot, now), data);
  }
  return sections.build();
}

/// What this phone measured, when the server cannot be reached.
///
/// **Not a legacy section, and it appears in one state only.** Legacy's Today is
/// entirely server-backed — it has no local store, so a dead server leaves it
/// with a retry and nothing else. This app holds the strap's own readings on
/// disk, and `docs/APP_DESIGN_BRIEF.md` §7.4 requires that half to render with no
/// network at all: an app that shows zero measurements while sitting on a
/// database of them is broken, not careful.
///
/// So it draws **only** behind the failure card, in legacy's own two-up row, and
/// nothing on the healthy path moves by a pixel.
void _measuredOnly(SectionList sections, ScreenData data) {
  final day = data.day;
  sections.add(
    Builder(
      builder: (context) => MetricTileRow(
        left: MetricTile(
          label: 'Steps · from the strap',
          tag: context.hues.steps,
          reading: day.steps.map((count) => count.toDouble()),
          format: (value) => commaGrouped(value.round()),
          foot: 'SINCE-MIDNIGHT COUNTER',
          chart: const SizedBox.shrink(),
        ),
        right: MetricTile(
          label: 'Heart rate · from the strap',
          tag: context.hues.heart,
          reading: day.heartRate,
          format: (value) => value.round().toString(),
          unit: 'bpm',
          foot: 'LATEST READING',
          chart: RevealOnce(
            id: 'today.offline.heart-rate',
            registry: data.reveals,
            builder: (context, t) => DayLineChart(
              points: day.heartRateSeries,
              progress: t,
              color: context.hues.heart,
              height: MetricTile.chartHeight,
              showRange: false,
            ),
          ),
        ),
      ),
    ),
  );
  sections.gap(10);
  sections.add(DeviceHealthCard(day: day, now: data.now));
}

/// A phone that has synced nothing AND has heard nothing from the server.
List<PageSection> _freshInstall(ScreenData data, TodayExtras extras) {
  final now = data.now ?? DateTime.now();
  return <PageSection>[
    PageSection(
      GreetingHeader(
        date: data.day.date,
        now: now,
        batteryPercent: extras.batteryPercent ?? data.day.batteryPercent,
        health: extras.health,
        syncing: extras.syncing,
        onOpenProfile: extras.onOpenProfile,
        onAddLog: extras.onAddLog,
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
    push: extras.push,
    cachedAt: view != null && view.fromCache ? view.fetchedAt : null,
    cachedDate: view != null && view.describesAnotherDay(data.day.date)
        ? data.snapshot?.date
        : null,
    lastStrapSync: data.day.sync.lastCompleteSync,
    now: data.now,
    signedIn: extras.signedIn,
    onSignIn: extras.onSignIn,
    // Legacy's banner carries its own 16 px, so a healthy day leaves no gap.
    bottomGap: 16,
  );
}
