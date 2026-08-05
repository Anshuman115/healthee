/// The ordered sections of Today. Composition only — no widget is defined here.
///
/// ## Today is an INDEX. This is the whole shape, and it is legacy's.
///
/// `design_reference/project/hh/screen_today.jsx` is 140 lines and shows exactly
/// this, in this order:
///
/// ```text
///   greeting header      eyebrow date · theme toggle · avatar
///   readiness block      tick gauge + sub-score meters
///   2-column grid        Sleep · Resting HR · HRV · Steps · Energy · Resp/SpO₂
///   heart rate · 24h     full width
///   stress               full width
///   "Suggested today"    section title with a See all → the actions tab
/// ```
///
/// **And every grid module is a door**: legacy's cells carry
/// `onClick={() => onOpen('sleep' | 'heart' | 'activity' | 'respiratory')}`.
/// Detail lives behind the index, not under it.
///
/// The revision this replaces had that opening and then kept going for twenty
/// more cards — sleep health, debt, the week, blood oxygen, steps, cardio load,
/// active minutes, workouts, biological age, VO₂max, findings, baselines, the
/// strap's own strip — about eight screens of scrolling. Every one of those is a
/// good card and none of them is a daily read. They have moved, and the module
/// that indexes each one now taps through to where it went:
///
/// ```text
///   Sleep        → Routes.sleep        last night · sleep health · debt · week · SpO₂
///   Resting HR   → Routes.sleep        the overnight instruments live with the night
///   HRV          → Routes.sleep
///   Steps        → Routes.activity     steps · cardio load · active minutes · workouts
///   Energy       → Routes.activity     · biological age · VO₂max
///   Resp / SpO₂  → Routes.sleep
///   findings     → Routes.coach        "In your own data"
///   baselines    → Routes.diagnostics  reachable from the pairing screen
///   from the strap → Routes.diagnostics
/// ```
///
/// **Baselines and "from the strap" are diagnostics, not a daily read.** They
/// answer "is the instrument working", which is a question the owner asks when
/// something looks wrong and never at 7am. `diagnostics_screen.dart` says so in
/// its own docstring, and it is where the two resting-heart-rate instruments are
/// named apart rather than left to disagree in silence.
///
/// ## What stays, and why it is above the instruments
///
/// The data-health strip and the illness banner are **safety surfaces**. The
/// strip is the reason a stale number cannot masquerade as today's, and the flag
/// is deterministic and outranks every judgement on the screen (brief §4.1). Both
/// sit above everything a number could be read from, and both render nothing at
/// all when there is nothing to say.
///
/// ## The bargain the grid strikes, and who holds the other half now
///
/// `grid_module.dart` explains why a 118 px cell shows a hole and the word
/// WITHHELD but never a refusal's reason or its remedy: the section owning that
/// metric renders the full `WithheldCard`. That section is no longer on this
/// screen — it is on the tab the cell taps through to. The bargain is unchanged
/// and its other half moved with the card; what would break it is a cell whose
/// destination does not exist, which is why `metric_grid.dart` takes its doors as
/// a required argument rather than reading a table it could outlive.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/features/today/widgets/daily_action_card.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';
import 'package:healthee/features/today/widgets/greeting_block.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/features/today/widgets/metric_grid.dart';
import 'package:healthee/features/today/widgets/recovery_card.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/features/today/widgets/today_header.dart';
import 'package:healthee/shared/device_health_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Where each grid module goes.
///
/// Named here because `today_sections.dart` is what decides Today's shape, and
/// "which door leads where" is part of that shape rather than a fact about any
/// one cell.
abstract final class TodayDoors {
  /// Sleep, HRV, resting heart rate, breathing and blood oxygen — every
  /// instrument the strap reads while the owner is still.
  static const String overnight = Routes.sleep;

  /// Steps and energy: what the owner did, and what it cost.
  static const String daytime = Routes.activity;
}

/// Everything Today needs that is not on [ScreenData].
@immutable
class TodayExtras {
  /// The push state, the session state, and the way to fix the second.
  const TodayExtras({this.push, this.signedIn, this.onSignIn, this.onOpen});

  /// What the app knows about its own pushing, for the data-health strip.
  final PushStamp? push;

  /// Null while the keystore read is in flight — "not yet known", which the
  /// strip stays silent about rather than guessing "signed out" for a frame.
  final bool? signedIn;

  /// Opens the sign-in screen.
  final VoidCallback? onSignIn;

  /// Opens a route. The grid's doors go through it, so a test can watch where a
  /// tap went without standing a router up.
  final void Function(String route)? onOpen;
}

/// Builds the ordered section list for one render of Today.
///
/// A plain function rather than a widget: it decides ORDER, and order is not a
/// thing that needs an element in the tree. Everything it returns is a widget
/// defined in its own file.
List<PageSection> todaySections(ScreenData data, TodayExtras extras) {
  final snapshot = data.snapshot;
  if (data.day.hasNothing && snapshot == null) {
    return _freshInstall(data, extras);
  }
  return <PageSection>[
    PageSection(TodayHeader(now: data.now), gap: Insets.lg),
    PageSection(
      GreetingBlock(
        guidance: snapshot?.recovery.valueOrNull?.guidance,
        now: data.now,
      ),
      gap: PageSpacing.section,
    ),

    // Above everything a number could be read from, and silent when all is well.
    PageSection(_dataHealth(data, extras)),
    if (snapshot?.illnessFlag case final flag?) PageSection(IllnessBanner(flag: flag)),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,

    // ── the readiness instrument ───────────────────────────────────────────
    if (snapshot != null)
      PageSection(
        ReadingView<RecoveryScore>(
          reading: snapshot.recovery,
          label: 'Recovery',
          builder: (context, score) =>
              RecoveryCard(score: score, reveals: data.reveals),
        ),
      ),

    // ── the index ──────────────────────────────────────────────────────────
    PageSection(
      MetricGrid(
        day: data.day,
        reveals: data.reveals,
        snapshot: snapshot,
        onOpen: extras.onOpen ?? _nowhere,
      ),
    ),
    PageSection(HeartRateCard(day: data.day, reveals: data.reveals, now: data.now)),
    if (snapshot != null)
      PageSection(
        StressCard(hours: snapshot.hourlyStress, reveals: data.reveals),
        gap: PageSpacing.section,
      ),

    // ── suggested today ────────────────────────────────────────────────────
    if (snapshot != null) ...[
      const PageSection(
        SectionHeading(
          'Suggested today',
          // No `See all` yet: Actions has no screen, and `app_tab_bar.dart`
          // draws its tab dimmed for the same reason. A link to a route that
          // does not exist is a link to a crash.
          subtitle: 'One action, and the reading behind it',
        ),
      ),
      PageSection(
        DailyActionCard(
          action: snapshot.action,
          recommendations: snapshot.recommendations,
        ),
      ),
    ],
  ];
}

/// A phone that has synced nothing AND has heard nothing from the server.
///
/// ONE honest empty card rather than twenty identical refusals — twenty of the
/// same sentence reads as breakage, and the true statement is simply that the
/// strap has not been read yet.
List<PageSection> _freshInstall(ScreenData data, TodayExtras extras) {
  return <PageSection>[
    PageSection(TodayHeader(now: data.now), gap: Insets.lg),
    // A fresh install is exactly where "not signed in" is worth saying, so the
    // strip leads here too. It still renders nothing when a session is held —
    // the sentence below is then the whole and true answer.
    PageSection(
      DataHealthSection(
        signedIn: extras.signedIn,
        onSignIn: extras.onSignIn,
        now: data.now,
      ),
    ),
    const PageSection(
      EmptyState(
        message: 'Nothing from your strap yet',
        hint:
            'Tap "Sync now" above with the strap on your wrist and nearby. '
            'Everything on this screen comes off the device or from the '
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
    // The strap's own last complete read, which is the one gap that can cost
    // measurements outright — the band overwrites, the push queue does not.
    // `health_lines.dart` owns the threshold and the wording.
    lastStrapSync: data.day.sync.lastCompleteSync,
    now: data.now,
    signedIn: extras.signedIn,
    onSignIn: extras.onSignIn,
  );
}

/// The door a cell gets when nobody wired one — a widget test pumping the
/// section list on its own. Never reached from the running app.
void _nowhere(String route) {}
