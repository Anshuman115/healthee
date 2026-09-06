/// The last value this phone actually held, **with the day it was true of**.
///
/// ## The one thing that makes this safe
///
/// The owner, on a hero the server refused: *"it should show the old one instead
/// of completely not showing"*. That is a reasonable thing to want and it is
/// also one step from the failure this whole product is built against — a stale
/// number read as today's. This repo has swept "stale-as-current" three times,
/// and `derive/vo2max_tier.py`'s 14-day horizon exists precisely because a held
/// measurement can end up **more wrong than the model it displaced**, and wrong
/// in the flattering direction.
///
/// So the distinction is drawn in the TYPE, not in the care taken at a call
/// site: there is no bare `double` here. A [LastKnown] cannot be constructed
/// without the day it belongs to, cannot be unwrapped to a number without
/// mentioning that day, and is deliberately NOT a [Reading] — so it cannot be
/// handed to any widget that draws a current value, cannot flow into a delta, a
/// trend, a ruler mark or a chart's latest point. A surface that wants to show
/// one has to say when it is from, because that is the only accessor there is.
///
/// ```text
///   showing a stale value AS TODAY'S      the bug. Not representable here.
///   showing it EXPLICITLY DATED           what this type is for.
/// ```
///
/// ## Where the value comes from
///
/// The 60-day local tier already holds one cached `/api/today` body **per
/// calendar day** (`store/local_store.dart` — `day` is the primary key, and it
/// is TEXT so it sorts chronologically). So the last day that carried a value is
/// a scan backwards through rows this phone already has. Nothing is derived,
/// nothing is carried forward from another metric, and a day whose payload has
/// no value is simply skipped — including today's own row, which is the refused
/// one that started the search.
library;

import 'package:meta/meta.dart';

/// A value that WAS true, and the calendar day it was true of.
@immutable
class LastKnown<T extends Object> {
  /// Both halves are required; that is the entire point of the type.
  const LastKnown({required this.value, required this.day});

  /// The value, exactly as the server sent it on [day].
  final T value;

  /// The owner-local calendar date it describes, `YYYY-MM-DD`.
  final String day;

  @override
  bool operator ==(Object other) =>
      other is LastKnown<T> && other.value == value && other.day == day;

  @override
  int get hashCode => Object.hash(LastKnown<T>, value, day);

  @override
  String toString() => 'LastKnown($value on $day)';
}

/// `2026-08-12` → `12 August 2026`, for a date a reader has to notice.
///
/// Spelled out rather than `12/08` because the whole job of this string is to be
/// unmissable: an ambiguous numeric date beside a large figure is exactly the
/// footnote a reader skips, and skipping it turns the figure back into a claim
/// about today. A string this app cannot parse is returned unchanged — an
/// unrecognised date shown verbatim is honest; a blank one is not.
String plainDay(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) {
    return iso;
  }
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) {
    return iso;
  }
  return '$day ${kMonthNames[month - 1]} ${parts[0]}';
}

/// Month names, in the app's one language.
const List<String> kMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
