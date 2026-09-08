/// **The day the reader is looking at**, which is not the same question as what
/// day it is.
///
/// `store_provider.dart`'s `today` answers the wall clock and is what a sync
/// files rows under. This one answers *what the owner has asked to see*, starts
/// equal to it, and moves when the date control moves. Two providers rather than
/// one writable `today` because the two answers must be allowed to disagree:
///
/// ```text
///   today       the wall clock    what a sync writes, what "latest" returns to
///   viewDate    the reader        what the screens read
/// ```
///
/// A single writable `today` would have made `SyncController` push a past day's
/// worth of samples under the day the owner happened to be browsing. That is not
/// a display bug; it is corrupted data on the server.
///
/// ## The bounds are the phone's own retention, not a guess
///
/// [earliestViewableDay] is [localHorizonDays] back, because that is exactly how
/// far the local tier keeps a day before `horizon_prune.dart` removes it. A
/// control that offered a day the store cannot answer for would be offering an
/// empty screen and calling it history. The forward bound is today: there are no
/// measurements from tomorrow, and a date control that could reach one would be
/// inviting a screen full of withholds.
///
/// ## What follows the selection, and what deliberately does not
///
/// `deviceDayProvider` follows it — the strap's own measurements are stored per
/// calendar day, so a past day is a real answer this phone can give with no
/// network at all.
///
/// **`todaySnapshotProvider` follows it too**, and that is the one `watch` that
/// makes the derived half date-aware: `/api/today` takes an optional
/// `day=YYYY-MM-DD` and answers from the rows filed under it
/// (`docs/AS_OF_DAY.md`), so stepping back re-requests rather than relabelling.
/// Serving today's judgements under yesterday's date would still be the
/// stale-as-current failure this repo has swept three times — the difference is
/// that we now ask for the right day instead of declining to ask.
///
/// What still does not follow it is the LLM half. A written analysis or a daily
/// action for a past day would have to be regenerated, which is a new claim
/// rather than a record, so those surfaces stay absent — and absent is what the
/// screens already drew for an un-warmed today.
library;

import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'view_date.g.dart';

/// The oldest day the control may reach from [today] — the retention horizon.
String earliestViewableDay(String today) {
  final anchor = DateTime.parse(today);
  return isoDay(
    DateTime.utc(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(const Duration(days: localHorizonDays)),
  );
}

/// [day] shifted by [days], as a calendar date. Negative moves backwards.
String shiftDay(String day, int days) {
  final anchor = DateTime.parse(day);
  return isoDay(
    DateTime.utc(
      anchor.year,
      anchor.month,
      anchor.day,
    ).add(Duration(days: days)),
  );
}

/// Whether [day] is inside the window the control may move within.
bool isViewableDay(String day, String today) =>
    day.compareTo(today) <= 0 && day.compareTo(earliestViewableDay(today)) >= 0;

/// The owner-local calendar date the screens are showing, `YYYY-MM-DD`.
///
/// `keepAlive` for the reason the selection exists at all: it **follows the
/// reader between screens**, which it cannot do if it is disposed the moment the
/// last screen watching it is rebuilt.
@Riverpod(keepAlive: true)
class ViewDate extends _$ViewDate {
  @override
  String build() => ref.watch(todayProvider);

  /// Shows [day], or does nothing when it is outside the window.
  ///
  /// Silently ignoring an out-of-range day rather than clamping it: a clamp
  /// would answer a request for a day this phone cannot speak about with a
  /// *different* day, and the screen would then be showing something nobody
  /// asked for under a date they did not choose.
  void select(String day) {
    if (isViewableDay(day, ref.read(todayProvider))) {
      state = day;
    }
  }

  /// The previous or next day, bounded by the window.
  void move(int days) => select(shiftDay(state, days));

  /// Back to the newest day there can be measurements for.
  void latest() => state = ref.read(todayProvider);
}
