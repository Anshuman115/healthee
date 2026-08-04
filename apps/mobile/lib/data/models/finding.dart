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
    required this.description,
    required this.effectSize,
    required this.effectMetric,
    required this.qValue,
    required this.nSamples,
    required this.lagDays,
    required this.researchNoteIds,
  });

  /// Parses one entry of `top_findings`.
  factory Finding.fromJson(Map<String, Object?> json) {
    return Finding(
      kind: json['kind'] as String?,
      metricA: json['metric_a'] as String?,
      metricB: json['metric_b'] as String?,
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
    );
  }

  /// What kind of search found it — `pairwise_lag`, `event`, …
  final String? kind;

  /// The first metric in the pair.
  final String? metricA;

  /// The second.
  final String? metricB;

  /// The server's own short description, e.g. "Caffeine ↔ sleep".
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

  /// The direction, as a word, or null when there is no effect size.
  ///
  /// Deliberately "rose together" / "moved opposite" rather than "helps" or
  /// "hurts": the second pair are causal and this is a correlation.
  String? get directionLabel => switch (effectSize) {
    null => null,
    final double size when size >= 0 => 'moved together',
    _ => 'moved in opposite directions',
  };
}
