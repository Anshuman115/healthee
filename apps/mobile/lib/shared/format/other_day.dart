/// "These are from another day" — ONE decision, for every dated block on a screen.
///
/// Three surfaces have now needed the same fix and the fourth should not be a fourth
/// patch. `read/today.py` reaches **two days back** for the newest recommendation set,
/// and `read/health_metrics.py` treats an illness flag as active for **two days** after
/// the day it was raised. Both are correct server behaviour. What is not correct is a
/// screen drawing either under a heading that says "today" with nothing able to say
/// otherwise — the stale-as-current lie `docs/HOW_WE_VERIFY.md` section 3 records as
/// swept three times.
///
/// `ActionsSection` fixed it for the Today card. The v02 Actions screen and the illness
/// banner did not get it, so the identical two-day-stale set was relabelled as today's on
/// one surface while the other named the day. The decision lives here now, so a fix
/// cannot land on one surface again.
///
/// ## Why the comparison is against the SERVER's day
///
/// [otherDay] takes the day the payload answers for (`as_of.day`), never a device clock.
/// `data/models/as_of.dart` makes the same argument about `isToday`: a phone whose clock
/// has drifted, or one crossing midnight mid-render, would otherwise decide the question
/// the server has already answered.
///
/// A null on either side returns null. An undated block is one whose day we do not know,
/// which is a different statement from "it is this day's" — filling it in from the day
/// on screen is precisely the claim this file exists to stop.
library;

import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/shared/format/date_labels.dart';

/// The content's own day when it is NOT [viewedDay], else null.
///
/// Pure and static so the decision is testable without a widget tree.
String? otherDay(String? contentDay, String? viewedDay) {
  if (contentDay == null || viewedDay == null || contentDay == viewedDay) {
    return null;
  }
  return contentDay;
}

/// What a block of written-for-a-day content says when it is not this day's.
///
/// Public so a test can pin the wording rather than re-typing it.
String writtenForDay(String isoDay) =>
    'Written for ${shortDate(isoDay)} — nothing was written for this day.';

/// The recommendation set's own day when it is not the day on screen, else null.
///
/// All rows in a set share a date — `read/today.py::_recommendations_for` keeps only the
/// newest date it found — so the first row speaks for the set. It lives here rather than
/// on `ActionsSection` because the v02 Actions screen needs the identical answer about
/// the identical list, and asked it in two places it got two answers.
String? recommendationsFromDay(List<Recommendation> items, String? viewedDay) =>
    otherDay(items.isEmpty ? null : items.first.date, viewedDay);

/// What a MEASURED signal says when it was raised on another day.
///
/// Deliberately not [writtenForDay]. An illness flag is not advice authored for a day;
/// it is a reading taken on one, still inside the server's active window. Saying
/// "nothing was written for this day" about it would be a claim about a nightly job that
/// did not fail. What the owner needs is the date the signal is about, because the
/// server's own framing sentence is present-tense ("consider lighter activity today")
/// and reads as this morning's on the morning after next.
String raisedOnDay(String isoDay) => 'Raised on ${shortDate(isoDay)}, not on this day.';
