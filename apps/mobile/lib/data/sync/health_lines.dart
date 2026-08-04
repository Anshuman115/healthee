/// Every sentence the data-health card can say, as a pure function of facts.
///
/// The sibling of `link_report.dart`, and here for the same reason: each of
/// these lines is a function of a stored instant AND the current time, so a
/// widget is the one place they could not be tested against a pinned clock.
///
/// ## Loud and quiet are typography, never colour
///
/// `apps/mobile/README.md` is explicit: colour is a claim, only `fav`/`unf` say
/// anything about a reading, and `unf` "is not a warning colour and must never
/// be used as one". So [HealthLine.loud] does not mean red. It means the line
/// is stated first and in full ink, because there is something the owner has to
/// do; a quiet line reports progress in secondary ink and asks for nothing.
///
/// ## Which backlogs are loud, and why they are not the same backlog
///
/// ```text
///   draining    the push hit its own page cap mid-drain     quiet
///   waiting     rows arrived after the last push            quiet
///   signed out  no token, so nothing can be sent            loud
///   faulted     transport died, 401, server unreachable     loud
///   strap gap   the band has not been read in days          loud
/// ```
///
/// The first two are self-healing: the phone is holding the rows, nothing is
/// marked sent until the server acknowledges it, and the next sync — which is
/// now automatic — takes them. Raising those is how a health surface teaches the
/// owner to ignore it. The last three do not clear on their own.
///
/// ## "Nothing is lost" is said only where it is true
///
/// It is true of the push queue: `push_reader.dart` marks a row only after a
/// 2xx, so a failed push delays data and never destroys it. It is **not** true
/// of a queue left stuck past the 60-day horizon (`LocalStore.pruneBefore`
/// drops rows by date, not by whether they were sent), and it is not true of the
/// strap's own ring buffer at all. So the reassurance goes on the self-healing
/// lines and comes off the stuck ones, which say what is actually true instead.
library;

import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:meta/meta.dart';

/// How long the strap may go unread before the card says so.
///
/// **This number is an inference, not a specification.** One first-ever sync
/// against `kBackfillWindow` (30 days) returned ~101,518 measurements — about
/// nine days across the eight per-minute streams — so the band appears to hold
/// on the order of a week or two before it writes over the oldest readings. We
/// have never measured the true horizon and the firmware does not publish one.
///
/// Five days is therefore chosen with roughly four days of margin under the only
/// figure we have, and it warns while the owner can still act by doing the one
/// thing that fixes it: opening the app near the strap. If somebody later
/// measures the real retention, **this comment is what tells them what to
/// change** — raise it toward the measured horizon minus a safety margin, and
/// say what measured it.
const Duration kStrapHorizonWarning = Duration(days: 5);

/// One sentence for the data-health card.
@immutable
class HealthLine {
  /// [loud] marks a line the owner has to act on. See the library docstring.
  const HealthLine(this.text, {this.loud = false});

  /// The sentence. Never empty.
  final String text;

  /// Whether this is something only the owner can clear.
  final bool loud;
}

/// What the card should say right now. Empty means say nothing at all.
///
/// Loud lines come first: a sentence somebody must act on, under two lines of
/// progress reporting, is a sentence that gets scrolled past.
List<HealthLine> dataHealthLines({
  required DateTime now,
  PushStamp? push,
  DateTime? lastStrapSync,
  DateTime? cachedAt,
  String? cachedDate,
}) {
  final lines = <HealthLine>[
    if (_strapGap(lastStrapSync, now) case final HealthLine line) line,
    if (_pushFault(push) case final HealthLine line) line,
    if (cachedAt case final DateTime received)
      HealthLine(_cacheLine(received, cachedDate, now)),
    if (_backlog(push) case final HealthLine line) line,
  ];
  // Two passes rather than a sort: `List.sort` is not documented as stable, and
  // the order WITHIN each group carries meaning — the fault sentence has to come
  // before the backlog sentence that refers to "the problem above".
  return [...lines.where((line) => line.loud), ...lines.where((line) => !line.loud)];
}

/// The one data-loss risk in this design, named before it costs anything.
///
/// The push queue is durable; the strap's ring buffer is not. Foreground-only
/// syncing is the right trade precisely because the band outlasts any normal gap
/// between app opens — so the residual risk is the abnormal gap, and this is it.
///
/// It does **not** name a date. We do not know when the band overwrites, and
/// "you will lose data on Thursday" would be a precise claim built on one
/// observation. What is true is the gap, that the band holds a limited amount,
/// and what to do about it.
HealthLine? _strapGap(DateTime? lastStrapSync, DateTime now) {
  if (lastStrapSync == null) {
    // Never synced is not this problem, and the connection strip already says
    // "Never synced — tap Sync now" in its own words. Two voices on one fact is
    // how a card stops being read.
    return null;
  }
  final gap = now.difference(lastStrapSync);
  if (gap <= kStrapHorizonWarning) {
    return null;
  }
  return HealthLine(
    'Your strap was last read ${ageLabel(lastStrapSync, now: now)}. '
    'The band only holds about a week or two of minute-by-minute readings '
    'before it writes over the oldest ones, so anything older than that may '
    'already be beyond recovery. Open this app near your strap and it will '
    'pull whatever the band still has.',
    loud: true,
  );
}

/// A push that went wrong. Loud, because nothing on this phone will clear it.
HealthLine? _pushFault(PushStamp? push) {
  if (push?.failureReason case final String reason) {
    return HealthLine(
      "The last attempt to send your data didn't finish: $reason",
      loud: true,
    );
  }
  return null;
}

/// What the backlog is doing — four states, and only two of them are quiet.
HealthLine? _backlog(PushStamp? push) {
  final rows = push?.pendingRows ?? 0;
  if (push == null || rows == 0) {
    return null;
  }
  if (push.isFaulted) {
    // Deliberately not "nothing is lost; they go out on the next sync". Both
    // halves would be wrong here: the next sync will fail the same way, and a
    // queue left stuck past the 60-day horizon is pruned by date like any other
    // row. What IS true is that nothing has been marked sent.
    return HealthLine(
      '$rows measurements are still on this phone. Nothing is marked sent '
      'until your server has it, so none of it has been thrown away — but it '
      'will not reach the server until the problem above is fixed.',
      loud: true,
    );
  }
  if (push.isSignedOut) {
    return HealthLine(
      '$rows measurements are waiting here until this phone is signed in to a '
      'server. Nothing is lost while they wait.',
      loud: true,
    );
  }
  if (push.isDraining) {
    // Quiet progress, not a fault: the push stopped at its own page cap with
    // every page accepted, and the rest goes out on the next sync — which no
    // longer needs anybody to ask for it.
    return HealthLine('$rows measurements are still going out to your server.');
  }
  return HealthLine(
    '$rows measurements are waiting here to reach the server. Nothing is '
    'lost; they go out on the next sync.',
  );
}

/// The payload on screen came off disk. Quiet — it is provenance, not a fault.
String _cacheLine(DateTime received, String? cachedDate, DateTime now) =>
    cachedDate == null
    ? 'Showing the last snapshot the server sent, ${ageLabel(received, now: now)}.'
    : 'Showing the last snapshot the server sent — it describes $cachedDate, '
          '${ageLabel(received, now: now)}.';
