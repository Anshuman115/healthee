/// The day a screen is showing, beside the day it is being shown ON.
///
/// `components.js::H.header` prints one line for every date-aware screen:
///
/// ```js
/// `<time datetime="${H.viewDate()}">${H.dateLabel(H.viewDate(),true)}</time>
///   · ${H.isPast() ? 'Selected day' : 'Latest sample'}`
/// ```
///
/// Two words, and they are the whole honesty contract of this feature in the
/// header: **`Latest sample` promises the newest readings there are, and
/// `Selected day` promises nothing newer than that date.** A screen that
/// printed only the date would be making the first promise on a day that can
/// only keep the second.
///
/// ## Why a value rather than two `watch`es at fourteen call sites
///
/// `isPast` is one comparison and it is the same comparison every time, so
/// Standards section 1 makes it an extraction rather than a habit. It also
/// keeps the two dates *together*: a screen holding only the selected day
/// cannot tell whether it is the latest one, and the two most likely wrong
/// answers to that — comparing against `DateTime.now()`, or against the
/// payload's own date — are respectively the wall-clock bug `view_date.dart`
/// exists to prevent and a cached payload mistaken for a past day.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/store/view_date.dart';
import 'package:healthee/shared/format/date_labels.dart';

/// What the header says on the newest day there can be readings for.
const String kLatestSample = 'Latest sample';

/// What it says on any older one.
const String kSelectedDay = 'Selected day';

/// The day being read, and the wall-clock day it is judged against.
@immutable
class ViewDay {
  /// [day] is the selection; [latest] is the wall clock.
  const ViewDay({required this.day, required this.latest});

  /// The `YYYY-MM-DD` the screens are showing.
  final String day;

  /// The newest day there can be measurements for.
  final String latest;

  /// Whether the reader has stepped off the newest day.
  bool get isPast => day != latest;

  /// The header's own line — `29 July · Selected day`.
  ///
  /// `prettyDate`, not the prototype's `29 July`, for the reason
  /// `page_header.dart` already records: Today prints the day one way and two
  /// wordings for one date across two tabs is the drift `shared/format/` exists
  /// to stop.
  String get line => '${prettyDate(day)} · $status';

  /// The half of [line] that is not the date.
  String get status => isPast ? kSelectedDay : kLatestSample;
}

/// `29 July · Selected day` from a payload's own date, for a detail head.
///
/// A null date draws no line rather than a blank one — a loading or failed
/// screen has no day to report, and a middot on its own is not a date.
String? dayEyebrow(String? iso, String? status) => iso == null
    ? null
    : (status == null ? prettyDate(iso) : '${prettyDate(iso)} · $status');

/// The day [ref]'s screen is showing. Rebuilds when either end moves.
ViewDay watchViewDay(WidgetRef ref) => ViewDay(
  day: ref.watch(viewDateProvider),
  latest: ref.watch(todayProvider),
);
