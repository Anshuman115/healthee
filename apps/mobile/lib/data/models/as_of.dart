/// Which day a payload answers for, and when that day's rows were computed.
///
/// `/api/today`, `/api/activity` and `/api/sleep` each carry an `as_of` block
/// (`docs/AS_OF_DAY.md` rules 5 and 6). It exists so the client cannot mislabel
/// the answer, and it is typed here rather than read as a map because a date is
/// exactly the field a screen must not be free to guess at.
///
/// ## Why [isToday] comes from the server
///
/// The two ways a phone could work this out for itself are both the bug the
/// server's `core/tenancy.py` was written against: comparing against
/// `DateTime.now()` uses the DEVICE's clock and zone, and comparing the payload's
/// date against the selection cannot tell a past day from a cached one. The
/// owner's calendar day belongs to their profile timezone, so the server is the
/// only thing that knows it — and the answer travels with the answer.
///
/// ## [derivedAt] is the receipt, not the date
///
/// A row for 29 July computed during a re-derive in September is still 29 July's
/// answer, and the reader is entitled to know when it was computed. Null is a
/// real answer — a day nothing was derived for has no computation to name — and
/// it is never filled in from a neighbouring day.
///
/// The wording that belongs with any of this is **as of** that date, never **on**
/// it. A past-day answer is the best account of that day from the rows filed
/// under it, using today's model; it is not a transcript of what the app said at
/// the time, because re-derives and science fixes mean the two can differ.
library;

import 'package:meta/meta.dart';

/// The day a payload answers for.
@immutable
class AsOf {
  /// Builds the block. Prefer [AsOf.maybe].
  const AsOf({required this.day, required this.isToday, this.derivedAt});

  /// Parses an `as_of` block, or null when the server sent none.
  ///
  /// Null rather than a fabricated "today": a payload with no `as_of` is an older
  /// server, and inventing one here would put this app's guess where the server's
  /// fact belongs. Every reader treats null as "not stated" and falls back to the
  /// behaviour it had before the block existed.
  static AsOf? maybe(Map<String, Object?> json) {
    final day = json['day'];
    final isToday = json['is_today'];
    if (day is! String || isToday is! bool) {
      return null;
    }
    return AsOf(
      day: day,
      isToday: isToday,
      derivedAt: json['derived_at'] as String?,
    );
  }

  /// The owner-local calendar date this payload answers for, `YYYY-MM-DD`.
  final String day;

  /// Whether [day] is the owner's current day, decided in their timezone.
  final bool isToday;

  /// When this day's derived rows were last computed, ISO-8601, or null.
  final String? derivedAt;
}
