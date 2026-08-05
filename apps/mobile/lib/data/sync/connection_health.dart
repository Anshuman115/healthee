/// Is anything wrong with the link or the pipe — the one function that decides.
///
/// ## What replaced the permanent strip, and the bargain that makes it honest
///
/// A full-width "Connected · Sync now" bar sat at the top of Today forever,
/// spending about a tenth of the screen to say *fine* on almost every day of the
/// app's life. It is now a **dot in the header row** when there is nothing to say
/// and a full-width strip when there is — the same rule the data-health card has
/// always followed, and the reason that card is worth reading when it speaks.
///
/// **A quiet healthy state is only honest if every unhealthy state is genuinely
/// loud.** So this function is the only thing that may produce the quiet answer,
/// it is exhaustive over the sealed [StrapConnection] union, and it takes every
/// other fact that could be wrong as a required-or-explicitly-absent parameter.
/// The mutation this design is one commit away from is a new failure state that
/// nobody added a branch for, rendering as the calm dot; that is why the link
/// half is a `switch` with no default and the data half iterates
/// `dataHealthLines` rather than naming faults it knows about.
///
/// ## The three shapes, and why "busy" is not a fourth kind of alert
///
/// ```text
///   busy      work in flight  →  the strip stays open, with its progress
///   alerts    something wrong →  the strip stays open, with every fault named
///   quiet     neither         →  a 7 px dot beside the date, and nothing else
/// ```
///
/// Busy is a field rather than an alert because a sync in progress is not a
/// problem and must not read as one — and it must not be hidden either. *"A
/// spinner that vanishes is how 'did it work?' becomes unanswerable."* The two
/// can be true at once (a sync running on a phone that is signed out), and both
/// are shown.
///
/// ## No copy is decided here
///
/// The link's own words come from `link_report.dart` and the data-side headlines
/// come from `health_lines.dart` — the same call the card makes, so the strip
/// shows the headline of a fault and the card underneath shows its paragraph.
/// They are a title and its body, not two voices: one function produces both, and
/// `HealthLine.alarm` will not compile without the short form.
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
  /// data-health card below carries the paragraph.
  const ConnectionAlert({
    required this.id,
    required this.headline,
    this.detail,
    this.statedInHeadline = false,
  });

  /// A stable name for the fault — `link_failed`, `never_synced`, or a
  /// [HealthLine.id].
  final String id;

  /// The short form, for the strip.
  final String headline;

  /// The remedy, when this alert is the only surface that carries it.
  final String? detail;

  /// True when the strip's own first line — `LinkReport.headline` — is already
  /// this alert's headline, so drawing it again would be the same sentence
  /// twice.
  ///
  /// A field rather than the strip comparing two strings: the equality is a fact
  /// about where the sentence CAME FROM, and a `==` would silently stop deduping
  /// the day either copy is reworded. It is set only where [headline] is read
  /// out of the same object `link_report.dart` reads it from.
  final bool statedInHeadline;
}

/// Everything the connection surface needs to draw itself.
@immutable
class ConnectionHealth {
  /// Built by [connectionHealth].
  const ConnectionHealth({
    required this.report,
    required this.busy,
    required this.alerts,
    this.progress,
  });

  /// The link's own words, for the strip's first line.
  final LinkReport report;

  /// Whether work is in flight. Never hidden, never an alert.
  final bool busy;

  /// The fetch's own progress, when it has reported any.
  final StrapSyncProgress? progress;

  /// Every unhealthy thing, in the order it should be read.
  final List<ConnectionAlert> alerts;

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
  final alerts = <ConnectionAlert>[
    // The link first: it is the fault the owner can usually fix in ten seconds
    // by walking back to their strap.
    ...?_linkAlert(link),
    // Then everything the data-health card is loud about. Iterated rather than
    // enumerated, so a fault added there cannot be missing here — the failure
    // mode of a hand-written list is silence, which is the one outcome this
    // surface may not have.
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
    alerts: alerts,
  );
}

/// The link's own faults, or null when the link is fine.
///
/// A `switch` over the sealed union with no default: a sixth [StrapConnection]
/// case is a compile error here rather than a state that quietly renders as the
/// calm dot.
List<ConnectionAlert>? _linkAlert(StrapConnection link) => switch (link) {
  // Working. Not an alert — `busy` carries it, and the strip stays open.
  Scanning() || Connecting() || Authenticating() || Syncing() => null,
  // A session is open. Nothing is wrong.
  Connected() => null,
  ConnectionFailed(:final failure) => <ConnectionAlert>[
    ConnectionAlert(
      id: 'link_failed',
      headline: failure.headline,
      // `linkReport` puts this same `failure.headline` on the strip's first
      // line. The alert still EXISTS — it is what makes the surface loud — and
      // only its second rendering is suppressed.
      statedInHeadline: true,
      // The strip owns this remedy in full: nothing else on the screen says how
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
