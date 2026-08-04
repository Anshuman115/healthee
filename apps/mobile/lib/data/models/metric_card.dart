/// One Today metric card: a value, its personal baseline, and its honesty state.
///
/// The comprehension unit `docs/APP_DESIGN.md` §3.1 describes — "value + delta
/// badge (z vs your normal) + median + interactive mini-chart". The rule the type
/// enforces is §0's first: **never a bare number**. [median30d] and [z] are the
/// personal comparison, and [reading] decides whether there is a number at all.
library;

import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:meta/meta.dart';

/// A single metric on the Today page.
@immutable
class MetricCard {
  /// Builds a card. Prefer [MetricCard.fromJson].
  const MetricCard({
    required this.metric,
    required this.label,
    required this.reading,
    required this.unit,
    required this.median30d,
    required this.z,
    required this.anomalous,
  });

  /// Parses one entry of the Today payload's `metrics` array.
  factory MetricCard.fromJson(Map<String, Object?> json) {
    return MetricCard(
      metric: json['metric']! as String,
      label: json['label']! as String,
      // The value and its honesty keys are siblings in this object, so the fold
      // happens through the shared envelope — a metric card and a VO₂max card
      // cannot end up disagreeing about what "withheld" means.
      reading: numericReadingFrom(json, 'value'),
      unit: json['unit'] as String?,
      median30d: (json['median_30d'] as num?)?.toDouble(),
      z: (json['z'] as num?)?.toDouble(),
      anomalous: json['anomalous'] as bool? ?? false,
    );
  }

  /// The canonical metric id, e.g. `rhr_daily`. Stable; use it for lookups.
  final String metric;

  /// The owner-facing name, e.g. "Resting HR". Server-supplied so the app never
  /// invents a second name for a metric (CLAUDE.md: one canonical definition).
  final String label;

  /// The value and what the server was willing to say about it.
  final Reading<double> reading;

  /// Unit symbol, or null for a dimensionless count like steps.
  final String? unit;

  /// The owner's own 30-day median. Null when there is no baseline yet — weight
  /// never has one, and a new owner has none for anything.
  final double? median30d;

  /// Standard scores from that baseline. Null whenever [median30d] is.
  final double? z;

  /// |z| >= 2. `docs/APP_DESIGN.md` §3.1: "a quiet flag, not alarm".
  final bool anomalous;

  /// Whether this card can show a personal comparison at all.
  ///
  /// The UI branches on this rather than on `z != null` scattered about, so
  /// "we have no baseline for you yet" reads the same on every card.
  bool get hasBaseline => median30d != null;
}
