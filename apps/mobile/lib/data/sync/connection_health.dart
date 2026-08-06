/// Is anything wrong with the link or the pipe — the one function that decides.
///
/// ## Two surfaces now, and the bargain that makes the quiet one honest
///
/// A full-width "Connected · Sync now" bar sat at the top of Today forever,
/// spending about a tenth of the screen to say *fine* on almost every day of the
/// app's life. It became a 7 px dot plus a strip that opened when something was
/// wrong. Both are gone (owner, 2026-08-05: *"remove that top device connection
/// and sync now that we have the sync visible as a progress ring around
/// profile"*), and the answer this function produces now goes to two places:
///
/// ```text
///   the ring round the avatar   busy · progress · a fault exists · a session is open
///   the data-health card        every fault, in words, with its remedy
/// ```
///
/// **A quiet healthy state is only honest if every unhealthy state is genuinely
/// loud**, and a ring cannot say *"your token was rotated"*. So the loudness and
/// the sentence are separated on purpose: this function is still the only thing
/// that may produce the quiet answer, and everything it classifies as loud lands
/// on the card as prose. [ConnectionHealth.linkAlerts] exists for exactly that
/// reason — the two link faults have no `HealthLine` behind them, so before the
/// strip's deletion they had no surface that could carry their remedy.
///
/// It is exhaustive over the sealed [StrapConnection] union and takes every other
/// fact that could be wrong as a required-or-explicitly-absent parameter. The
/// mutation this design is one commit away from is a new failure state that
/// nobody added a branch for, rendering as the calm ring; that is why the link
/// half is a `switch` with no default and the data half iterates
/// `dataHealthLines` rather than naming faults it knows about.
///
/// ## Why "busy" is not a kind of alert
///
/// A sync in progress is not a problem and must not read as one — and it must
/// not be hidden either. *"A spinner that vanishes is how 'did it work?' becomes
/// unanswerable."* It is a field, so both can be true at once (a sync running on
/// a phone that is signed out) and both are shown: the ring turns, and the card
/// still says what is wrong.
///
/// ## No copy is decided here
///
/// The link's own words come from `link_report.dart` and the data-side headlines
/// come from `health_lines.dart` — the same call the card makes, so a fault's
/// headline and its paragraph are a title and its body rather than two voices.
/// One function produces both, and `HealthLine.alarm` will not compile without
/// the short form.
library;

import 'package:healthee/ble/strap_progress.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/health_lines.dart';
import 'package:healthee/data/sync/link_report.dart';
import 'package:meta/meta.dart';

/// One thing that is wrong, named.
@immutable
class ConnectionAlert {
  /// [detail] is the remedy in full, when this alert owns it. Null when the
  /// data-health card's own `HealthLine` already carries the paragraph.
  const ConnectionAlert({required this.id, required this.headline, this.detail});

  /// A stable name for the fault — `link_failed`, `never_synced`, or a
  /// [HealthLine.id].
  final String id;

  /// The short form, for the strip.
  final String headline;

  /// The remedy, when this alert is the only surface that carries it.
  final String? detail;
}

/// Everything the connection surface needs to draw itself.
@immutable
class ConnectionHealth {
  /// Built by [connectionHealth].
  const ConnectionHealth({
    required this.report,
    required this.busy,
    required this.linkAlerts,
    required this.dataAlerts,
    this.progress,
  });

  /// The link's own words — the ring's spoken label, and the card's freshness
  /// line under a link fault.
  final LinkReport report;

  /// Whether work is in flight. Never hidden, never an alert.
  final bool busy;

  /// The fetch's own progress, when it has reported any.
  final StrapSyncProgress? progress;

  /// Faults of the RADIO, which nothing else on the screen speaks about.
  ///
  /// Kept apart from [dataAlerts] because their surfaces differ, not their
  /// severity. A data fault has a `HealthLine` whose paragraph the data-health
  /// card already prints; these two — an unreachable strap, and a phone that has
  /// never synced — have no line anywhere, so they carry their own
  /// [ConnectionAlert.detail] and the card prints them. **When the strip was
  /// deleted this was the half with nowhere to go**, and a fault with no surface
  /// is the one outcome this file exists to prevent.
  final List<ConnectionAlert> linkAlerts;

  /// Every loud `HealthLine`, as a headline. The card prints the full sentence.
  final List<ConnectionAlert> dataAlerts;

  /// Every unhealthy thing, in the order it should be read.
  ///
  /// The link first: it is the fault the owner can usually fix in ten seconds by
  /// walking back to their strap.
  List<ConnectionAlert> get alerts => <ConnectionAlert>[
    ...linkAlerts,
    ...dataAlerts,
  ];

  /// Whether the indicator may collapse to a dot.
  ///
  /// The ONE place the quiet answer is computed. Anything that wants to know
  /// whether the chrome may be silent asks this rather than re-deriving it, so a
  /// new state cannot be quiet in one widget and loud in another.
  bool get quiet => !busy && alerts.isEmpty;

  /// Whether an authenticated session is open right now.
  bool get live => report.live;
}

/// Classify the whole connection surface. Exhaustive by construction.
///
/// [signedIn] is nullable and null means **not yet known** — the keystore read is
/// asynchronous, and treating "unknown" as "signed out" would open the strip on
/// every cold start for one frame.
ConnectionHealth connectionHealth({
  required StrapConnection link,
  required DateTime now,
  PushStamp? push,
  bool? signedIn,
  DateTime? lastStrapSync,
  DateTime? cachedAt,
  String? cachedDate,
}) {
  // Everything the data-health card is loud about. Iterated rather than
  // enumerated, so a fault added there cannot be missing here — the failure mode
  // of a hand-written list is silence, which is the one outcome this surface may
  // not have.
  final dataAlerts = <ConnectionAlert>[
    for (final line in dataHealthLines(
      now: now,
      push: push,
      lastStrapSync: lastStrapSync,
      cachedAt: cachedAt,
      cachedDate: cachedDate,
      signedIn: signedIn,
    ))
      if (line.loud)
        ConnectionAlert(id: line.id, headline: line.headline!),
  ];
  return ConnectionHealth(
    report: linkReport(link, now: now),
    busy: link.isBusy,
    progress: switch (link) {
      Syncing(:final progress) => progress,
      _ => null,
    },
    linkAlerts: _linkAlert(link) ?? const <ConnectionAlert>[],
    dataAlerts: dataAlerts,
  );
}

/// The link's own faults, or null when the link is fine.
///
/// A `switch` over the sealed union with no default: a sixth [StrapConnection]
/// case is a compile error here rather than a state that quietly renders as the
/// calm ring.
List<ConnectionAlert>? _linkAlert(StrapConnection link) => switch (link) {
  // Working. Not an alert — `busy` carries it, and the ring turns.
  Scanning() || Connecting() || Authenticating() || Syncing() => null,
  // A session is open. Nothing is wrong.
  Connected() => null,
  ConnectionFailed(:final failure) => <ConnectionAlert>[
    ConnectionAlert(
      id: 'link_failed',
      headline: failure.headline,
      // This alert owns its remedy in full: nothing else on the screen says how
      // to fix a radio, so a headline alone would be a fault with no answer.
      detail: failure.remedy,
    ),
  ],
  // The resting state. Quiet after a healthy sync — the app let the link go on
  // purpose and reporting the socket would send somebody to check their
  // Bluetooth over nothing (`link_report.dart`). Loud when nothing has ever been
  // read, because then the screen has nothing behind it.
  Disconnected(:final lastCompleteSync) => lastCompleteSync == null
      ? const <ConnectionAlert>[
          ConnectionAlert(
            id: 'never_synced',
            headline: 'Nothing has been read from your strap yet',
            // Deliberately NOT the fresh-install empty state's sentence. That
            // card explains why the screen is empty; this line says what to do
            // about the link, which is the only thing this surface is about.
            detail: 'Pull down with the strap on your wrist and nearby.',
          ),
        ]
      : null,
};
