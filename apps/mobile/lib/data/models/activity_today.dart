/// The activity block: cardio load, MVPA, and the week they are measured over.
///
/// Two payloads in one file because they are one section of one screen and
/// neither has a life without the other — Standards §1 allows a helper beside
/// the class it serves, and splitting these would be two files that always
/// change together.
///
/// **MVPA carries the WHO floor on the wire** (`week_target`, 150 min/week), so
/// the app never hard-codes it. That number is a public-health recommendation
/// with a citation behind it, and a copy in a widget is a copy that can be wrong
/// on the day the recommendation moves.
library;

import 'package:healthee/data/models/trend_point.dart';
import 'package:meta/meta.dart';

/// One day's moderate/vigorous minutes.
@immutable
class MvpaDay {
  /// A dated split.
  const MvpaDay({
    required this.date,
    required this.mvpaMin,
    required this.moderateMin,
    required this.vigorousMin,
  });

  /// Parses one entry of `mvpa.daily`.
  factory MvpaDay.fromJson(Map<String, Object?> json) {
    int minutes(String key) => (json[key] as num?)?.toInt() ?? 0;
    return MvpaDay(
      date: json['date']! as String,
      mvpaMin: minutes('mvpa_min'),
      moderateMin: minutes('moderate_min'),
      vigorousMin: minutes('vigorous_min'),
    );
  }

  /// Owner-local calendar date.
  final String date;

  /// Moderate-to-vigorous minutes on that day.
  final int mvpaMin;

  /// Of which moderate.
  final int moderateMin;

  /// Of which vigorous.
  final int vigorousMin;
}

/// Moderate-to-vigorous activity, today and across the week.
@immutable
class Mvpa {
  /// Built by [Mvpa.maybe].
  const Mvpa({
    required this.todayMin,
    required this.weekMin,
    required this.weekTarget,
    required this.weekModerateMin,
    required this.weekVigorousMin,
    required this.daily,
    required this.researchNotes,
  });

  /// Parses `mvpa`, or null when the week could not be established.
  static Mvpa? maybe(Map<String, Object?> json) {
    final week = (json['week_min'] as num?)?.toInt();
    if (week == null) {
      return null;
    }
    return Mvpa(
      todayMin: (json['today_min'] as num?)?.toInt() ?? 0,
      weekMin: week,
      // The WHO floor, from the wire.
      weekTarget: (json['week_target'] as num?)?.toInt() ?? 150,
      weekModerateMin: (json['week_moderate_min'] as num?)?.toInt() ?? 0,
      weekVigorousMin: (json['week_vigorous_min'] as num?)?.toInt() ?? 0,
      daily: [
        for (final entry in (json['daily'] as List? ?? const []))
          if (entry is Map<String, Object?>) MvpaDay.fromJson(entry),
      ],
      researchNotes: [
        for (final entry in (json['research_notes'] as List? ?? const []))
          if (entry is String) entry,
      ],
    );
  }

  /// Today's MVPA minutes.
  final int todayMin;

  /// This week's total so far.
  final int weekMin;

  /// The weekly floor, from the server. 150 min/week is WHO's.
  final int weekTarget;

  /// Of the week's total, moderate minutes.
  final int weekModerateMin;

  /// Of the week's total, vigorous minutes.
  final int weekVigorousMin;

  /// The per-day split, oldest first.
  final List<MvpaDay> daily;

  /// The notes licensing the target.
  final List<String> researchNotes;

  /// Progress against the floor, clamped to 1. Never above: a bar that overfills
  /// says nothing a number does not, and the interesting fact past 100% is the
  /// count, which is shown as a number.
  double get weekProgress =>
      weekTarget <= 0 ? 0 : (weekMin / weekTarget).clamp(0.0, 1.0);
}

/// Training load — today's, against the owner's own 30-day baseline.
@immutable
class CardioLoad {
  /// Built by [CardioLoad.maybe].
  const CardioLoad({
    required this.load,
    required this.baseline30d,
    required this.hrMinutes,
    required this.edwardsTl,
    required this.strain,
    required this.strainMax,
    required this.zoneMinutes,
    required this.trend30d,
    required this.asOfDate,
    required this.researchNotes,
  });

  /// Parses `cardio_load`, or null when today has no load figure.
  static CardioLoad? maybe(Map<String, Object?> json) {
    final load = (json['load'] as num?)?.toDouble();
    if (load == null) {
      return null;
    }
    return CardioLoad(
      load: load,
      baseline30d: (json['baseline_30d'] as num?)?.toDouble(),
      hrMinutes: (json['hr_minutes'] as num?)?.toInt(),
      edwardsTl: (json['edwards_tl'] as num?)?.toInt(),
      strain: (json['strain'] as num?)?.toDouble(),
      strainMax: (json['strain_max'] as num?)?.toDouble(),
      zoneMinutes: [
        for (final entry in (json['zone_minutes'] as List? ?? const []))
          if (entry is num) entry.toInt(),
      ],
      trend30d: TrendPoint.listFrom(json['trend_30d']),
      asOfDate: json['as_of_date'] as String?,
      researchNotes: [
        for (final entry in (json['research_notes'] as List? ?? const []))
          if (entry is String) entry,
      ],
    );
  }

  /// Today's load.
  final double load;

  /// The owner's own 30-day baseline — the comparison that makes [load] mean
  /// anything. A population figure would not.
  final double? baseline30d;

  /// Minutes of heart-rate data behind it. One minute and four hundred are
  /// different confidences in the same number.
  final int? hrMinutes;

  /// Edwards training load.
  final int? edwardsTl;

  /// Today's strain.
  final double? strain;

  /// The strain scale's own maximum, so a bar has a denominator it did not
  /// invent.
  final double? strainMax;

  /// Minutes in each heart-rate zone, zone 1 first.
  final List<int> zoneMinutes;

  /// Thirty days of load, oldest first.
  final List<TrendPoint> trend30d;

  /// The day this is a claim about.
  final String? asOfDate;

  /// The notes licensing the model.
  final List<String> researchNotes;

  /// Today against the owner's own normal, as a ratio. Null without a baseline.
  double? get versusBaseline =>
      (baseline30d == null || baseline30d == 0) ? null : load / baseline30d!;
}
