/// One dated value — the shape every series on `/api/today` shares.
///
/// `vo2max.trend_90d`, every entry of `sparklines`, and `cardio_load.trend_30d`
/// are all `{"date": "2026-07-31", "value": 43.0}`. This started life inside
/// `vo2max.dart` and moved here on its second use, which is Standards §1's rule
/// rather than a preference: two identical parsers are two chances to disagree
/// about whether `value` may be null.
///
/// The date stays a **string**. It is an owner-local calendar date, not an
/// instant, and `DateTime.parse` would hand back something in the device's zone
/// that sorts and prints differently depending on where the phone is — the
/// confusion `local_store.dart` documents having shipped twice.
library;

import 'package:meta/meta.dart';

/// A value on a day.
@immutable
class TrendPoint {
  /// A dated value.
  const TrendPoint({required this.date, required this.value});

  /// Parses `{"date": "2026-07-31", "value": 43.0}`.
  factory TrendPoint.fromJson(Map<String, Object?> json) {
    return TrendPoint(
      date: json['date']! as String,
      value: (json['value']! as num).toDouble(),
    );
  }

  /// Owner-local calendar date, `YYYY-MM-DD`.
  final String date;

  /// The value on that date.
  final double value;

  /// Parses a whole series, skipping entries that are not a dated number.
  ///
  /// A malformed point is dropped rather than defaulted to zero: a zero would be
  /// drawn as a real measurement of nothing, which is the one thing a chart of
  /// health data must never invent.
  static List<TrendPoint> listFrom(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map<String, Object?> && entry['value'] is num)
          TrendPoint.fromJson(entry),
    ];
  }

  /// Just the values, in order — what a chart painter wants.
  static List<double> valuesOf(List<TrendPoint> points) =>
      [for (final point in points) point.value];

  @override
  bool operator ==(Object other) =>
      other is TrendPoint && other.date == date && other.value == value;

  @override
  int get hashCode => Object.hash(date, value);

  @override
  String toString() => '$date=$value';
}
