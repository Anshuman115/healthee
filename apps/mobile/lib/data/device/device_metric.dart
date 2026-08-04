/// One metric stream as the strap reported it: latest value, when, how many.
///
/// ## Everything here is a measurement, and the list below is the boundary
///
/// [kDeviceStreams] is the complete set of metrics this app will show without a
/// server, and it is a whitelist rather than "whatever the store happens to
/// hold". That is the guard rail: a stream reaches the screen only by being
/// added here, which is a diff a reviewer sees, and the only thing that belongs
/// here is something a sensor produced.
///
/// Resting heart rate is in the list and is worth defending, because it is the
/// metric `vitals.dart` was deleted for. That file computed an RHR **on the
/// phone** — a rolling minimum over the heart-rate stream, which is a definition,
/// and a second one. This is not that: `resting_hr` (fetch type `0x3A`) is a
/// value the strap itself recorded and handed over, the same way it hands over a
/// heart-rate sample. Showing a number the device measured is not deriving one.
///
/// What is NOT here, and cannot be added here: recovery, sleep health, sleep
/// debt, VO₂max, biological age, baselines, anomalies, training load. The server
/// owns every one, and they reach the screen as a refusal — see
/// `data/models/today_snapshot.dart`.
library;

import 'package:healthee/data/honesty/reading.dart';
import 'package:meta/meta.dart';

/// A metric stream the strap records, with how to name it.
@immutable
class DeviceStream {
  /// A stream the app is willing to show from local data alone.
  const DeviceStream({
    required this.metric,
    required this.label,
    required this.unit,
    required this.decimals,
  });

  /// The wire name the samples are stored under — `hrv`, `spo2`, `resting_hr`.
  final String metric;

  /// The owner-facing name. Ours, because no server was asked; kept to the
  /// plainest wording rather than a branded one.
  final String label;

  /// Unit symbol, or null for a dimensionless index like stress.
  final String? unit;

  /// How many decimal places the value is worth showing. Skin temperature earns
  /// one; a heart rate in whole beats does not, and printing `54.0 bpm` implies
  /// a precision the sensor did not offer.
  final int decimals;
}

/// Every stream Today may show from the strap alone, in display order.
const List<DeviceStream> kDeviceStreams = [
  DeviceStream(
    metric: 'resting_hr',
    label: 'Resting heart rate',
    unit: 'bpm',
    decimals: 0,
  ),
  DeviceStream(metric: 'hrv', label: 'HRV', unit: 'ms', decimals: 0),
  DeviceStream(metric: 'spo2', label: 'Blood oxygen', unit: '%', decimals: 0),
  DeviceStream(
    metric: 'respiratory_rate',
    label: 'Breathing rate',
    unit: 'br/min',
    decimals: 0,
  ),
  DeviceStream(metric: 'stress', label: 'Stress index', unit: null, decimals: 0),
  DeviceStream(
    metric: 'temperature_c',
    label: 'Skin temperature',
    unit: '°C',
    decimals: 1,
  ),
  DeviceStream(
    metric: 'max_hr',
    label: 'Peak heart rate',
    unit: 'bpm',
    decimals: 0,
  ),
];

/// One stream's state on one day.
@immutable
class DeviceMetric {
  /// Built by [package:healthee/data/store/strap_reader].
  const DeviceMetric({
    required this.stream,
    required this.reading,
    required this.measuredAt,
    required this.sampleCount,
  });

  /// Which stream this is, and how to name it.
  final DeviceStream stream;

  /// The latest value the strap recorded that day.
  ///
  /// A [Reading] rather than a `double?` for the reason the type exists: a
  /// stream the strap did not write is a **withhold with a reason**, and the
  /// reason here is specific and useful — the sensor did not sample it, which is
  /// usually the strap being off the wrist. It is never a dash.
  final Reading<double> reading;

  /// When that latest value was recorded. Null when there is no value.
  ///
  /// Shown beside the number always, never on hover: a SpO₂ from 03:00 and one
  /// from four minutes ago are different claims, and the strap samples on its
  /// own schedule rather than continuously.
  final DateTime? measuredAt;

  /// How many samples the strap gave us for this stream that day. Zero when the
  /// reading is withheld — and shown, because "one sample" and "four hundred"
  /// are different confidences in the same displayed number.
  final int sampleCount;
}
