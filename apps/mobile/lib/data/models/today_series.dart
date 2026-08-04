/// One hour of an intraday series — `today_hr_series` and `today_stress_series`.
///
/// `{hour, hour_iso, min, avg, max, n}`. The server aggregates the day into
/// hours before it sends it, which is a summary rather than a measurement, so
/// the model keeps all three of min/avg/max: an hour whose heart rate ran 62–148
/// is not the same hour as one that sat flat at 80, and only the average would
/// say they were.
///
/// [count] is how many samples the hour rests on. An hour built from four
/// readings and one built from sixty are different confidences in the same
/// average, and the strap samples on its own schedule.
library;

import 'package:meta/meta.dart';

/// One hour's summary of an intraday series.
@immutable
class HourPoint {
  /// An hour with its range.
  const HourPoint({
    required this.hour,
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.count,
  });

  /// Parses one entry of `today_hr_series` / `today_stress_series`.
  factory HourPoint.fromJson(Map<String, Object?> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    return HourPoint(
      hour: (json['hour']! as num).toInt(),
      average: number('avg') ?? 0,
      minimum: number('min'),
      maximum: number('max'),
      count: (json['n'] as num?)?.toInt(),
    );
  }

  /// Hour of the owner's local day, 0–23.
  final int hour;

  /// The hour's mean.
  final double average;

  /// Its lowest reading, when the payload carried one.
  final double? minimum;

  /// Its highest.
  final double? maximum;

  /// How many samples it rests on.
  final int? count;

  /// Parses a whole series, skipping anything that is not an hour.
  static List<HourPoint> listFrom(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map<String, Object?> && entry['hour'] is num)
          HourPoint.fromJson(entry),
    ];
  }

  /// `HH:00` for an axis label.
  String get label => '${hour.toString().padLeft(2, '0')}:00';
}
