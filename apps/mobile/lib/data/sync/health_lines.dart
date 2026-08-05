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
///   destroyed   unsent measurements hit the one-year bound  loud, forever
/// ```
///
/// The first two are self-healing: the phone is holding the rows, nothing is
/// marked sent until the server acknowledges it, and the next sync — which is
/// now automatic — takes them. Raising those is how a health surface teaches the
/// owner to ignore it. The rest do not clear on their own, and the last one does
/// not clear at all.
///
/// ## "Nothing is lost" is said only where it is true
///
/// It is true of the push queue, and it is now true *structurally* rather than
/// by hope. `push_reader.dart` marks a row only after a 2xx, so a failed push
/// delays data and never destroys it — and since `horizon_prune.dart`, the
/// 60-day horizon no longer destroys it either: an unsent measurement is kept
/// past the horizon rather than pruned with it.
///
/// This docstring previously said the opposite, because it was: the prune
/// deleted by date alone, so the reassurance had to be withdrawn from the stuck
/// lines. The copy retreated because the code was wrong. The code is fixed, so
/// the copy can come back — and it comes back with the bound stated, because the
/// honest sentence is "kept for up to a year", not "kept".
///
/// It has never been true of the strap's own ring buffer, and still is not.
/// [kStrapHorizonWarning] is that risk, and it is a different one.
///
/// ## The one line that never goes away
///
/// If the one-year bound is ever actually reached, measurements were destroyed.
/// Nothing on this phone or any server can undo that, so there is no state in
/// which quieting the sentence would be honest, and it is deliberately not tied
/// to whether the queue currently looks healthy. It is reachable only after the
/// loud signed-out/faulted line has been on this screen for about 365 days.
library;

import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/local_store.dart';
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

/// One sentence for the data-health card — and, when it is loud, the four words
/// the connection indicator shows for the same fact.
///
/// ## Why a loud line cannot exist without a headline
///
/// The two surfaces are one voice at two lengths. `shared/connection/` collapses
/// to a dot when everything is well and expands when it is not, and what it
/// expands into is the [headline] of every loud line here; the card under it
/// carries the [text] with the remedy in full. The pair is not a restatement —
/// it is a title and its paragraph — and it is the reason the indicator may go
/// quiet at all.
///
/// So a loud line is built through [HealthLine.alarm], which **requires** the
/// headline and the id. A `loud: true` flag on the plain constructor would let a
/// new alarm ship with no short form, and the indicator would then have nothing
/// to draw for it — which is the collapsing indicator swallowing a real fault,
/// the exact failure this design is one bad commit away from.
/// `test/mutations.sh` deletes a headline on purpose to prove the compiler stops
/// it.
@immutable
class HealthLine {
  /// A line that reports progress and asks for nothing.
  const HealthLine.quiet(this.text) : loud = false, id = '', headline = null;

  /// A line the owner has to act on. [headline] is what the connection
  /// indicator shows; [text] is the full sentence on the card.
  const HealthLine.alarm({
    required this.id,
    required this.headline,
    required this.text,
  }) : loud = true;

  /// The sentence. Never empty.
  final String text;

  /// Whether this is something only the owner can clear.
  final bool loud;

  /// A stable name for the fault, for the indicator and for a log line. Empty on
  /// a quiet line, which nothing outside the card ever reads.
  final String id;

  /// The short form, for the chrome. Non-null exactly when [loud] is true.
  final String? headline;
}

/// What the card should say right now. Empty means say nothing at all.
///
/// Loud lines come first: a sentence somebody must act on, under two lines of
/// progress reporting, is a sentence that gets scrolled past.
///
/// [signedIn] is nullable and **null means not yet known** — the keystore read is
/// asynchronous, and announcing "not signed in" during it would flash the
/// invitation at an owner who already is.
List<HealthLine> dataHealthLines({
  required DateTime now,
  PushStamp? push,
  DateTime? lastStrapSync,
  DateTime? cachedAt,
  String? cachedDate,
  bool? signedIn,
}) {
  final lines = <HealthLine>[
    // First among the loud lines, and first for a reason: it is the only one
    // that reports something already irreversible.
    if (_destroyed(push) case final HealthLine line) line,
    if (signedIn == false) _signedOut,
    if (_strapGap(lastStrapSync, now) case final HealthLine line) line,
    if (_pushFault(push) case final HealthLine line) line,
    if (cachedAt case final DateTime received)
      HealthLine.quiet(_cacheLine(received, cachedDate, now)),
    if (_backlog(push) case final HealthLine line) line,
  ];
  // Two passes rather than a sort: `List.sort` is not documented as stable, and
  // the order WITHIN each group carries meaning — the fault sentence has to come
  // before the backlog sentence that refers to "the problem above".
  return [...lines.where((line) => line.loud), ...lines.where((line) => !line.loud)];
}

/// No token, so every `/api/*` call is a 401 and the derived half of Today goes
/// quiet.
///
/// It lives here rather than inline in the card because the connection indicator
/// needs the same fact in four words, and a sentence written in a widget is a
/// sentence the chrome cannot reach without copying it. The wording is unchanged
/// from the card's own.
const HealthLine _signedOut = HealthLine.alarm(
  id: 'signed_out',
  headline: 'Not signed in to a server',
  text:
      'This phone is not signed in to a Healthee server. Everything your strap '
      'measured is below and is still being recorded here; the readings the '
      'server works out — recovery, sleep health, debt, VO₂max, biological age '
      '— need a sign-in.',
);

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
    // Never synced is not this problem, and the connection indicator already
    // raises it in its own words (`data/sync/connection_health.dart`'s
    // `never_synced` alert). Two voices on one fact is how a card stops being
    // read.
    return null;
  }
  final gap = now.difference(lastStrapSync);
  if (gap <= kStrapHorizonWarning) {
    return null;
  }
  return HealthLine.alarm(
    id: 'strap_gap',
    headline: 'Your strap has not been read in days',
    text:
        'Your strap was last read ${ageLabel(lastStrapSync, now: now)}. '
        'The band only holds about a week or two of minute-by-minute readings '
        'before it writes over the oldest ones, so anything older than that may '
        'already be beyond recovery. Open this app near your strap and it will '
        'pull whatever the band still has.',
  );
}

/// Measurements this phone deleted before the server ever saw them.
///
/// Says what was lost, how much, through when, and what the owner could have
/// done — the three things `docs/ENGINEERING_STANDARDS.md` §1 means by a
/// background failure reaching its health surface, plus the one that makes it
/// actionable next time. It is deliberately not phrased as maintenance: this is
/// not "old data was cleaned up", it is health data that no longer exists
/// anywhere, because the strap cannot be re-read that far back.
HealthLine? _destroyed(PushStamp? push) {
  if (push?.loss case final loss?) {
    return HealthLine.alarm(
      id: 'destroyed',
      headline: 'Measurements were lost before they were sent',
      text:
          '${loss.rows} measurements recorded up to ${loss.throughDay} were '
          'deleted from this phone without ever reaching a server. They had '
          'been waiting $kUnsentSampleRetentionDays days, which is as long as '
          'this phone will hold unsent readings, and your strap cannot be read '
          'back that far — they are gone. Signing in to a server, or fixing the '
          'send error above, is what stops it happening to the rest.',
    );
  }
  return null;
}

/// A push that went wrong. Loud, because nothing on this phone will clear it.
HealthLine? _pushFault(PushStamp? push) {
  if (push?.failureReason case final String reason) {
    return HealthLine.alarm(
      id: 'push_fault',
      headline: 'Your data is not reaching the server',
      text: "The last attempt to send your data didn't finish: $reason",
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
    // Still not "they go out on the next sync" — the next sync fails the same
    // way. But the retention half of the sentence is now true rather than
    // withdrawn: an unsent row outlives the 60-day horizon, so the honest
    // statement is how long it outlives it by.
    return HealthLine.alarm(
      id: 'backlog_faulted',
      headline: 'Measurements are stuck on this phone',
      text:
          '$rows measurements are still on this phone. Nothing is marked sent '
          'until your server has it, and unsent readings are kept past the '
          '$localHorizonDays days this phone shows — for up to '
          '$kUnsentSampleRetentionDays days — so none of it has been thrown '
          'away. It will not reach the server until the problem above is fixed.',
    );
  }
  if (push.isSignedOut) {
    return HealthLine.alarm(
      id: 'backlog_signed_out',
      headline: 'Measurements are waiting for a sign-in',
      text:
          '$rows measurements are waiting here until this phone is signed in to '
          'a server. Nothing is lost while they wait: unsent readings are kept '
          'for up to $kUnsentSampleRetentionDays days, well past the '
          '$localHorizonDays days of history this phone shows.',
    );
  }
  if (push.isDraining) {
    // Quiet progress, not a fault: the push stopped at its own page cap with
    // every page accepted, and the rest goes out on the next sync — which no
    // longer needs anybody to ask for it.
    return HealthLine.quiet(
      '$rows measurements are still going out to your server.',
    );
  }
  return HealthLine.quiet(
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
