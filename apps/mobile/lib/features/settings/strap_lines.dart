/// What is known about the strap's last read, in the owner's own words.
///
/// Lifted out of the deleted `widgets/strap_setting.dart` unchanged, because the
/// sentences are the behaviour and the card around them was the presentation.
/// The two rules it encodes are the reason it is a function with its own tests
/// rather than three lines inside a `build`:
///
/// **`lastCompleteSync`, never `lastAttempt`.** `data/device/device_day.dart`
/// keeps both and they are not interchangeable: an attempt that failed halfway
/// leaves data unread, and reporting it as a sync is the stale-behind-a-healthy-
/// screen failure the data-health strip exists to prevent.
///
/// **The battery is dated by that same sync and says so.** A percentage with no
/// instant beside it is a claim about now, made from a reading that may be a day
/// old — the strap is not connected while this screen is open, so there is no
/// fresher number to be had and pretending otherwise is not available.
library;

import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/shared/format/time_labels.dart';

/// The two sentences. A list rather than one string so they stay separable: a
/// phone with a sync and no battery reading is an ordinary state, and a joined
/// sentence would need a branch per combination.
List<String> strapLines(DeviceDay? day, {required DateTime now}) {
  if (day == null) {
    return const <String>["Reading this phone's own store…"];
  }
  return <String>[
    switch (day.sync.lastCompleteSync) {
      final DateTime last => 'Last full sync ${ageLabel(last, now: now)}.',
      // Not "never synced" phrased as a fault: a phone that has just been paired
      // is in this state for a minute and nothing is wrong with it.
      _ => 'No sync has finished on this phone yet.',
    },
    switch (day.batteryPercent) {
      final int percent => 'Battery $percent% at that sync.',
      _ => 'The band has not reported its battery.',
    },
  ];
}
