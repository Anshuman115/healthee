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
  const TrendPoint({required this.date, required this.value, this.method});

  /// Parses `{"date": "2026-07-31", "value": 43.0}`, and the instrument if sent.
  factory TrendPoint.fromJson(Map<String, Object?> json) {
    return TrendPoint(
      date: json['date']! as String,
      value: (json['value']! as num).toDouble(),
      method: json['method'] as String?,
    );
  }

  /// Owner-local calendar date, `YYYY-MM-DD`.
  final String date;

  /// The value on that date.
  final double value;

  /// Which instrument read this point, when the series carries one.
  ///
  /// `vo2max.trend_90d` and `vo2max.submax.trend` do
  /// (`docs/BACKEND_GAPS_FROM_UI.md` B2); the sparklines and the cardio-load
  /// trend do not, because each of those has exactly one instrument and a key
  /// repeating the same word on every point would be noise.
  ///
  /// It exists because a VO₂max series changes instrument between points BY
  /// DESIGN — `derive/vo2max_tier.py` picks a graded fit, a reserve inversion or
  /// Jurca depending on what the day had — so a step in the line can be a change
  /// of ruler rather than a change in the owner. Null means the server did not
  /// say, which is not the same as "one method throughout" and must not be
  /// rendered as it.
  final String? method;

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
  static List<double> valuesOf(List<TrendPoint> points) => [
    for (final point in points) point.value,
  ];

  /// How many distinct instruments read [points], ignoring the ones that did
  /// not say.
  ///
  /// More than one means the line crosses a change of ruler, which is the whole
  /// reason the key exists. Zero means the server named none — a caller must
  /// tell that apart from one, because "we were not told" and "one method
  /// throughout" are different claims.
  static Set<String> methodsIn(List<TrendPoint> points) => <String>{
    for (final point in points)
      if (point.method case final String method) method,
  };

  @override
  bool operator ==(Object other) =>
      other is TrendPoint &&
      other.date == date &&
      other.value == value &&
      other.method == method;

  @override
  int get hashCode => Object.hash(date, value, method);

  @override
  String toString() => '$date=$value';
}
