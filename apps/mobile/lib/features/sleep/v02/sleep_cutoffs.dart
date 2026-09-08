/// The four published cutoffs, their labels, and how far outside them a night is.
///
/// The bounds come from `/api/sleep`'s own `cutoffs` block. The fallbacks are
/// the prototype's strings, and they are only reached when the server sent no
/// block at all — a cutoff this app invented would be a reference with no source.
///
/// ```js
/// // design/mobile-preview/screens-sleep.js::checks
/// ['Duration', …, '7–9 hours',
///   minutes < 420 ? `${420-minutes} minutes below the 7-hour lower reference.`
///  : minutes > 540 ? `${minutes-540} minutes above the 9-hour upper reference.`
///  : 'Within the duration reference.'],
/// ['Efficiency', …, 'At least 85%',
///   efficiency < 85 ? `${(85-efficiency).toFixed(1)} percentage points below the reference.`
///                   : 'Within the efficiency reference.'],
/// ['Regularity · SRI', …, '70 or above',
///   sri < 70 ? `${70-sri} points below the reference.`
///            : 'Your sleep rhythm is within the reference.'],
/// ['Timing', …, 'Midpoint 02:00–04:00',
///   inBand ? 'Your sleep midpoint is within the reference window.'
///          : 'Your sleep midpoint is outside the reference window.'],
/// ```
///
/// Every sentence is written in the reader's own units and against the number
/// printed beside it, so nothing here needs a second look at the payload to be
/// checked. The distance is arithmetic; the **verdict** is the server's, and
/// lives on `SleepNight.pointDuration` and its three siblings.
library;

import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/shared/format/iso_clock.dart';

/// The published bands, resolved once per render.
class SleepBands {
  /// [cutoffs] of null falls back to the prototype's own wording.
  const SleepBands(this.cutoffs);

  /// The payload's block, when it carried one.
  final SleepCutoffs? cutoffs;

  /// `duration_hours`, in minutes.
  double get durationLowMin => (cutoffs?.durationHours?.first ?? 7) * 60;

  /// The upper end of the same band.
  double get durationHighMin => (cutoffs?.durationHours?.last ?? 9) * 60;

  /// `efficiency_min`, as a percentage.
  ///
  /// The wire sends a fraction (`0.85`), which is why this multiplies. A server
  /// that ever sent `85` would be read as 8500%, so the conversion is asserted
  /// by `sleep_checks_test.dart` against the committed snapshot.
  double get efficiencyMinPct => (cutoffs?.efficiencyMin ?? 0.85) * 100;

  /// `sri_min`.
  double get sriMin => cutoffs?.sriMin ?? 70;

  /// `timing_hour_band`, the earlier end.
  double get timingLowHour => cutoffs?.timingHourBand?.first ?? 2;

  /// The later end.
  double get timingHighHour => cutoffs?.timingHourBand?.last ?? 4;

  /// `7–9 hours`.
  String get durationLabel =>
      '${_plain(durationLowMin / 60)}–${_plain(durationHighMin / 60)} hours';

  /// `At least 85%`.
  String get efficiencyLabel => 'At least ${_plain(efficiencyMinPct)}%';

  /// `70 or above`.
  String get sriLabel => '${_plain(sriMin)} or above';

  /// `Midpoint 02:00–04:00`.
  String get timingLabel =>
      'Midpoint ${_clock(timingLowHour)}–${_clock(timingHighHour)}';

  /// How far the night sits from the duration band, in minutes.
  String durationDetail(double? minutes) {
    if (minutes == null) {
      return 'No duration recorded.';
    }
    if (minutes < durationLowMin) {
      return '${(durationLowMin - minutes).round()} minutes below the '
          '${_plain(durationLowMin / 60)}-hour lower reference.';
    }
    if (minutes > durationHighMin) {
      return '${(minutes - durationHighMin).round()} minutes above the '
          '${_plain(durationHighMin / 60)}-hour upper reference.';
    }
    return 'Within the duration reference.';
  }

  /// How far below the efficiency floor, in percentage points.
  String efficiencyDetail(double? percent) {
    if (percent == null) {
      return 'No efficiency recorded.';
    }
    if (percent < efficiencyMinPct) {
      return '${(efficiencyMinPct - percent).toStringAsFixed(1)} percentage '
          'points below the reference.';
    }
    return 'Within the efficiency reference.';
  }

  /// How far below the regularity floor, in points.
  String sriDetail(double? sri) {
    if (sri == null) {
      return 'No regularity reading.';
    }
    if (sri < sriMin) {
      return '${(sriMin - sri).round()} points below the reference.';
    }
    return 'Your sleep rhythm is within the reference.';
  }

  /// Whether the midpoint fell inside the reference window.
  String timingDetail(String? midpointLocal) {
    final hour = midpointHour(midpointLocal);
    if (hour == null) {
      return 'No midpoint recorded.';
    }
    return hour >= timingLowHour && hour <= timingHighHour
        ? 'Your sleep midpoint is within the reference window.'
        : 'Your sleep midpoint is outside the reference window.';
  }

  /// `2026-07-31T02:45:00` → `2.75`, or null when there is no clock in it.
  ///
  /// The prototype reads characters 11–16 of the local midpoint and this reads
  /// the same two fields, through the app's one `clockOfIso`.
  static double? midpointHour(String? midpointLocal) {
    final clock = clockOfIso(midpointLocal);
    if (clock == null) {
      return null;
    }
    final hour = int.tryParse(clock.substring(0, 2));
    final minute = int.tryParse(clock.substring(3, 5));
    return hour == null || minute == null ? null : hour + minute / 60;
  }

  /// `9.0` → `9`, `2.5` → `2.5`.
  static String _plain(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  /// `2` → `02:00`, `4.5` → `04:30`.
  static String _clock(double hours) {
    final whole = hours.floor();
    final minutes = ((hours - whole) * 60).round();
    return '${whole.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
}
