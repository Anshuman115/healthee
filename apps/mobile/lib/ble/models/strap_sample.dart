/// One decoded reading off the strap.
///
/// **Ported verbatim** from the `StrapSample` class in
/// `~/projects/healthee-legacy/app/lib/ble/activity_parser.dart`; only its home
/// changed, because Standards §1 wants one public class per file and the parser
/// file has its own reason to change.
library;

import 'package:meta/meta.dart';

/// A single timestamped value for one metric.
///
/// [metric] is the wire name the server also uses: `hr`, `hrv`, `spo2`,
/// `spo2_sleep`, `temperature_c`, `stress`, `respiratory_rate`, `resting_hr`,
/// `max_hr`, `steps`, `sleep_session`, `manual_hr`, `stress_manual`.
@immutable
class StrapSample {
  /// A reading of [value] for [metric] at [date].
  const StrapSample(this.date, this.metric, this.value);

  /// When the strap recorded it. Local time for the round-relative types,
  /// device epoch for the types that embed a timestamp.
  final DateTime date;

  /// The metric's wire name.
  final String metric;

  /// The decoded value, in the metric's own unit.
  final double value;

  @override
  String toString() => '$metric=$value @${date.toIso8601String()}';
}
