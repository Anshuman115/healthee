/// What the chrome says about the link — the ONE place any of those words live.
///
/// ## The rule
///
/// **`Connected` means an authenticated session is open right now.** Nothing
/// below can produce that word from anything except the [Connected] case, which
/// `connection_state.dart` explains cannot be constructed without a live
/// session's own authentication instant.
///
/// **When no session is open, report the useful fact instead of the socket.**
///
/// | situation | what this returns |
/// |---|---|
/// | session open | `Connected` |
/// | working | `Looking for your strap` · `Connecting` · `Authenticating` · `Syncing` |
/// | released after a healthy sync | `Synced 4 min ago` |
/// | strap unreachable | the named reason, plus how old the data is, plus the remedy |
/// | never synced | `Never synced — tap Sync now` |
///
/// "Not connected" after a healthy sync reads as a fault when nothing is wrong:
/// the app let the link go on purpose, and the owner's actual question is how
/// fresh their numbers are. The two failure modes this table is balanced
/// between are claiming a session that is not open, and alarming about a normal
/// resting state.
///
/// ## Why the copy is here and not on the states
///
/// Every resting line is a function of a stored instant AND the current time, so
/// putting it on the state object would mean either a `DateTime.now()` inside a
/// value class — untestable, and it would drift between two states rendered in
/// the same frame — or the same sentence written twice. This is a pure function
/// of (state, now), which a test can pin exactly. `time_labels.dart` does the
/// flooring, so a freshness label here can never round in the flattering
/// direction.
library;

import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:meta/meta.dart';

/// One line of chrome, and the two optional lines under it.
@immutable
class LinkReport {
  /// [headline] is never empty; the rest are shown only when present.
  const LinkReport({
    required this.headline,
    this.freshness,
    this.detail,
    this.live = false,
  });

  /// The sentence on the strip. Quiet, present tense, no exclamation.
  final String headline;

  /// How old the data is, when the headline is about something else.
  ///
  /// Only set on a failure: the resting states put freshness in the headline
  /// itself, because there it IS the news.
  final String? freshness;

  /// What the owner can do next. The failure's own remedy, in full.
  final String? detail;

  /// Whether an authenticated session is open, for the one mark that says so.
  final bool live;
}

/// What to show for [state], measured against [now].
///
/// Exhaustive over the sealed union, so a new connection state is a compile
/// error here rather than a case that silently renders as a grey dot.
LinkReport linkReport(StrapConnection state, {required DateTime now}) =>
    switch (state) {
      Scanning() => const LinkReport(headline: 'Looking for your strap'),
      Connecting() => const LinkReport(headline: 'Connecting'),
      Authenticating() => const LinkReport(headline: 'Authenticating'),
      // Live: a sync only ever runs over a session that authenticated, so the
      // mark is evidenced here for the same reason it is on `Connected`.
      Syncing(:final progress) => LinkReport(
        headline: progress == null ? 'Syncing' : 'Syncing — ${progress.label}',
        live: true,
      ),
      Connected() => const LinkReport(headline: 'Connected', live: true),
      Disconnected(:final lastCompleteSync) => LinkReport(
        headline: _atRest(lastCompleteSync, now),
      ),
      ConnectionFailed(:final failure, :final lastCompleteSync) => LinkReport(
        headline: failure.headline,
        freshness: _sinceLine(lastCompleteSync, now),
        detail: failure.remedy,
      ),
    };

/// The resting headline: what the owner actually wants to know.
String _atRest(DateTime? lastCompleteSync, DateTime now) =>
    lastCompleteSync == null
    ? 'Never synced — tap Sync now'
    : 'Synced ${ageLabel(lastCompleteSync, now: now)}';

/// The freshness line under a failure. Never omitted, because "we cannot reach
/// the strap" without "and your numbers are from 9 h ago" is half the news.
String _sinceLine(DateTime? lastCompleteSync, DateTime now) =>
    lastCompleteSync == null
    ? 'Nothing has ever been pulled from the strap.'
    : 'Last full sync ${ageLabel(lastCompleteSync, now: now)}.';
