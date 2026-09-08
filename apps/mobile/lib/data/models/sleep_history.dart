/// Seven nights of stage totals — what the stacked sleep chart is drawn from.
///
/// `sleep_history_7d[]`, oldest first. Each night carries the four stage minute
/// counts the strap summed plus its own device score.
///
/// Seven nights, not thirty, because that is what `/api/today` sends; the sleep
/// screen's longer windows come from `/api/sleep`. A chart that drew seven
/// nights under a "last month" label would be the same class of lie as drawing
/// sixty days and calling it ninety (brief §7.4).
library;

import 'package:meta/meta.dart';

/// One night's stage totals.
@immutable
class SleepNightSummary {
  /// A dated night.
  const SleepNightSummary({
    required this.date,
    required this.durationMin,
    required this.deepMin,
    required this.lightMin,
    required this.remMin,
    required this.awakeMin,
    required this.deviceScore,
  });

  /// Parses one entry of `sleep_history_7d`.
  ///
  /// Every stage field was `?? 0` with no honesty wrapper at all, which turned a
  /// night the strap never staged into a night of measured zeros — and this is
  /// the model the stacked chart paints, so those zeros were pixels. The server
  /// sends null for an unstaged night since migration `0018`; null is kept.
  factory SleepNightSummary.fromJson(Map<String, Object?> json) {
    int? minutes(String key) => (json[key] as num?)?.toInt();
    return SleepNightSummary(
      date: json['date']! as String,
      durationMin: minutes('duration_min'),
      deepMin: minutes('deep'),
      lightMin: minutes('light'),
      remMin: minutes('rem'),
      awakeMin: minutes('awake'),
      deviceScore: (json['score'] as num?)?.toInt(),
    );
  }

  /// Owner-local calendar date the night is filed under.
  final String date;

  /// Total sleep time, minutes. Null when the night was not measured.
  final int? durationMin;

  /// Deep-sleep minutes. Null when the strap staged nothing.
  final int? deepMin;

  /// Light-sleep minutes. Null when the strap staged nothing.
  final int? lightMin;

  /// REM minutes. Null when the strap staged nothing.
  final int? remMin;

  /// Awake-in-bed minutes. Null when the strap staged nothing.
  final int? awakeMin;

  /// Whether this night has a stage breakdown to draw at all.
  ///
  /// The chart's gate. A night with no breakdown is painted as a marked absence,
  /// never as four zero-height segments — those are indistinguishable from a
  /// night of literal zero sleep, which is the defect this field exists to make
  /// unrepresentable.
  bool get hasBreakdown =>
      deepMin != null || lightMin != null || remMin != null || awakeMin != null;

  /// **The strap's own score**, not Healthee's judgement.
  final int? deviceScore;

  /// Parses the whole array.
  static List<SleepNightSummary> listFrom(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map<String, Object?> && entry['date'] is String)
          SleepNightSummary.fromJson(entry),
    ];
  }

  /// The weekday initial for an axis label — `M`, `T`, `W`…
  ///
  /// Derived from the date string by Zeller's congruence rather than by parsing
  /// it into a `DateTime`: the date is a calendar day, and turning it into an
  /// instant to ask what weekday it is would answer in the device's zone.
  String get weekdayInitial {
    final year = int.parse(date.substring(0, 4));
    final month = int.parse(date.substring(5, 7));
    final day = int.parse(date.substring(8, 10));
    final shiftedMonth = month < 3 ? month + 12 : month;
    final shiftedYear = month < 3 ? year - 1 : year;
    final century = shiftedYear ~/ 100;
    final yearOfCentury = shiftedYear % 100;
    // Zeller: 0 = Saturday, 1 = Sunday, 2 = Monday, …
    final zeller =
        (day +
            (13 * (shiftedMonth + 1)) ~/ 5 +
            yearOfCentury +
            yearOfCentury ~/ 4 +
            century ~/ 4 +
            5 * century) %
        7;
    return const ['S', 'S', 'M', 'T', 'W', 'T', 'F'][zeller];
  }
}
