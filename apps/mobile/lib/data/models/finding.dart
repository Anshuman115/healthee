/// A personal finding — the app's most personal claim, and its narrowest.
///
/// `top_findings[]`: a correlation the analytics layer discovered in **this one
/// owner's** data. "When your caffeine went up, your sleep score went down."
///
/// ## Single-subject and observational, and the label must say so
///
/// Brief §5.9 requires the framing and it is not decoration. These are found by
/// searching many metric pairs across one person's history; the q-value is the
/// multiple-comparison correction that keeps that search honest, and [nSamples]
/// is how many days it rests on. A finding rendered as "caffeine hurts your
/// sleep" would be a causal claim from an observational n-of-1 — the exact
/// over-reach the whole evidence-grading apparatus exists to prevent.
///
/// So [effectSize] carries its own metric name ([effectMetric], e.g. `rho`) and
/// the UI states the sample size and the correction beside the claim.
library;

import 'package:meta/meta.dart';

/// One discovered relationship in the owner's own data.
@immutable
class Finding {
  /// Built by [Finding.fromJson].
  const Finding({
    required this.kind,
    required this.metricA,
    required this.metricB,
    required this.eventKind,
    required this.description,
    required this.effectSize,
    required this.effectMetric,
    required this.qValue,
    required this.nSamples,
    required this.lagDays,
    required this.researchNoteIds,
    this.points = const <FindingPoint>[],
    this.pointsTruncated = false,
  });

  /// Parses one entry of `top_findings`.
  factory Finding.fromJson(Map<String, Object?> json) {
    return Finding(
      kind: json['kind'] as String?,
      metricA: json['metric_a'] as String?,
      metricB: json['metric_b'] as String?,
      eventKind: json['event_kind'] as String?,
      description: json['description_raw'] as String?,
      effectSize: (json['effect_size'] as num?)?.toDouble(),
      effectMetric: json['effect_metric'] as String?,
      qValue: (json['q_value'] as num?)?.toDouble(),
      nSamples: (json['n_samples'] as num?)?.toInt(),
      lagDays: (json['lag_days'] as num?)?.toInt(),
      researchNoteIds: [
        for (final entry in (json['research_note_ids'] as List? ?? const []))
          if (entry is String) entry,
      ],
      points: [
        for (final entry in (json['points'] as List? ?? const []))
          if (entry is Map<String, Object?>)
            if (FindingPoint.maybe(entry) case final FindingPoint point) point,
      ],
      pointsTruncated: json['points_truncated'] as bool? ?? false,
    );
  }

  /// What kind of search found it — `pairwise_lag`, `event`, …
  final String? kind;

  /// The first metric in the pair.
  final String? metricA;

  /// The second. Null on an event finding, which compares one metric across two
  /// groups of days rather than two metrics against each other.
  final String? metricB;

  /// What separated the two groups of days on an event finding — the server's
  /// own label for the event. Null on a pairwise one.
  final String? eventKind;

  /// The server's `description_raw` — a debug string, not a sentence.
  ///
  /// `analytics/correlations.py` builds it as
  /// `Spearman(hrv_sleep_avg, recovery_score) = +0.72 over 105 days (p=0.000)`,
  /// and `read/findings.py` ships it under a key that says `_raw` beside the
  /// structured fields it calls *"structured fields for a plain-English card"*.
  ///
  /// **Do not render it.** `findings_section.dart` composes the owner-facing
  /// sentence from the structured fields; this is kept because a log line is
  /// worth having when a finding looks wrong, and it is deliberately not on any
  /// surface. It reached the home screen verbatim once.
  final String? description;

  /// How strong the relationship is, in [effectMetric]'s units.
  final double? effectSize;

  /// WHICH statistic [effectSize] is — `rho`, `d`, … Without it a number
  /// between −1 and 1 could be read as three different things.
  final String? effectMetric;

  /// The multiple-comparison-corrected significance. Small is stronger.
  final double? qValue;

  /// How many days the finding rests on.
  final int? nSamples;

  /// The lag, in days, at which it was strongest. 0 is same-day.
  final int? lagDays;

  /// The notes that let this be shown at all.
  final List<String> researchNoteIds;

  /// The paired days the effect size was measured on, oldest first.
  ///
  /// Empty on an event finding, always: a Mann-Whitney effect compares two
  /// GROUPS, so it has no paired points and an x-axis for it would be a picture
  /// the statistic does not license. Empty too on a server that predates
  /// `docs/BACKEND_GAPS_FROM_UI.md` B1.
  final List<FindingPoint> points;

  /// Whether [points] is a PART of what the effect size was computed from.
  ///
  /// Set by the server when its payload cap bit or when the as-of-day bound
  /// dropped a day. It matters on screen because [nSamples] is the count behind
  /// the number: a chart showing fewer dots than the figure beside it, with
  /// nothing saying so, invites a check it cannot support.
  final bool pointsTruncated;

  /// Whether there is a real relationship to plot rather than a line of dots.
  ///
  /// Two points make a perfect line whatever the data is, which is a picture of
  /// arithmetic rather than of the owner. Guarded here rather than in the
  /// painter so every surface asks it the same way.
  bool get isPlottable => points.length >= minPlottablePoints;

  /// The fewest paired days worth drawing. Not a statistical threshold — the
  /// server's own `MIN_N` already governs whether a correlation exists at all
  /// — but the point below which a scatter stops being a shape.
  static const int minPlottablePoints = 5;
}

/// One paired day behind a finding: both values, and the day they were measured.
@immutable
class FindingPoint {
  /// Builds a point.
  const FindingPoint({required this.date, required this.a, required this.b});

  /// Parses one entry of `points[]`, or null when either half is missing.
  ///
  /// All-or-nothing on purpose: a pair with one value is not a point, and
  /// defaulting the absent half to zero would put a dot on the axis that no day
  /// produced. Dropping it is the only honest reading, and the server's
  /// `points_n` is what tells the screen how many survived.
  static FindingPoint? maybe(Map<String, Object?> json) {
    final a = (json['a'] as num?)?.toDouble();
    final b = (json['b'] as num?)?.toDouble();
    if (a == null || b == null) {
      return null;
    }
    return FindingPoint(date: json['date'] as String?, a: a, b: b);
  }

  /// The owner-local day, `YYYY-MM-DD`.
  final String? date;

  /// `metric_a`'s value on that day.
  final double a;

  /// `metric_b`'s value at the finding's lag from that day.
  final double b;
}
