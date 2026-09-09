/// `/api/activity.fitness_plan` — what to do about the VO₂max above it.
///
/// ## The server has shipped this on every request and nothing read it
///
/// `read/fitness_plan.py` builds the block, `read/activity.py` puts it on the
/// wire, and the app had **no reference to the key at all** — the server's own
/// comment says so: *"No client read this copy… the app has no model for this
/// block."* The legacy app rendered it as `Your VO₂max plan`; the rebuild
/// dropped it silently, which made this tab a set of readings with nothing to
/// act on.
///
/// ## The projection is a BOUNDED TYPICAL RESPONSE, not a forecast
///
/// [gain] is null unless the server has an age median to measure against, and
/// when it is null [withheld] says why in the owner's words. The bounds come
/// with it on every response — [gainFloor], [gainCap], [gainGapFraction] — and
/// they ship even on the withheld case, deliberately: *"a key that appears only
/// on the answered case is one a client learns to ignore"*.
///
/// So a surface drawing [projected12wk] **must** draw [caveats] with it. The
/// note this is cited to ([noteId], `vo2max`) has that as directive D5: never
/// bare. The panel keeps them together by construction — see
/// `fitness_plan_panel.dart`.
///
/// ## `trend_source` is a pointer and is deliberately not modelled
///
/// The block carries `trend_source` naming where the 90-day trend lives rather
/// than a second copy of it — 6,233 bytes of the endpoint's 22,401 used to be
/// exactly that duplicate. The app reads the trend from `vo2max.trend_90d`
/// already (`data/models/vo2max.dart`), so following the pointer here would
/// rebuild the duplication the server removed.
library;

import 'package:healthee/data/honesty/disclosure.dart';

/// One prescribed block of the week — a target, and what has been done of it.
class PlanBlock {
  /// [doneMin] is null when the week's minutes are not known, which is NOT the
  /// same as zero and must not be drawn as an empty bar at 0%.
  const PlanBlock({
    required this.name,
    required this.targetMin,
    required this.doneMin,
    required this.description,
  });

  /// `Zone 2 base` / `Hard · VILPA`.
  final String name;

  /// The weekly target, in minutes.
  final int targetMin;

  /// Minutes done this week, or null when unknown.
  final int? doneMin;

  /// The server's own sentence describing the block.
  final String? description;

  /// How much of [targetMin] is done, 0–1, or null when [doneMin] is.
  double? get fraction {
    final done = doneMin;
    if (done == null || targetMin <= 0) {
      return null;
    }
    return (done / targetMin).clamp(0.0, 1.0);
  }

  /// Whether the week's target is already met.
  bool get met => doneMin != null && doneMin! >= targetMin;
}

/// The projection and the week's prescription.
class FitnessPlan {
  /// Prefer [FitnessPlan.maybe] — it is null when the block is absent.
  const FitnessPlan({
    required this.current,
    required this.projected12wk,
    required this.gain,
    required this.medianForAge,
    required this.weeks,
    required this.caveats,
    required this.withheld,
    required this.blocks,
    required this.noteId,
  });

  /// Parses the block, or returns null when there is none to parse.
  static FitnessPlan? maybe(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final plan = raw['plan'];
    final week = plan is Map<String, Object?> ? plan : const <String, Object?>{};
    return FitnessPlan(
      current: (raw['current'] as num?)?.toDouble(),
      projected12wk: (raw['projected_12wk'] as num?)?.toDouble(),
      gain: (raw['gain'] as num?)?.toDouble(),
      medianForAge: (raw['median_for_age'] as num?)?.toDouble(),
      weeks: (raw['weeks'] as num?)?.toInt(),
      caveats: <String>[
        for (final entry in (raw['caveats'] as List? ?? const <Object?>[]))
          if (entry is String) entry,
      ],
      withheld: switch (raw['withheld']) {
        final Map<String, Object?> block => Disclosure.fromJson(block),
        _ => null,
      },
      blocks: <PlanBlock>[
        if (week['zone2_target_min'] case final num target)
          PlanBlock(
            name: 'Zone 2 base',
            targetMin: target.toInt(),
            doneMin: (week['zone2_done_min'] as num?)?.toInt(),
            description: week['zone2_desc'] as String?,
          ),
        if (week['vilpa_target_min'] case final num target)
          PlanBlock(
            // `VILPA` is the literature's word, not the owner's, so it is
            // introduced rather than used bare. The server's own description
            // says what the session is.
            name: 'Hard · short bursts',
            targetMin: target.toInt(),
            doneMin: (week['vilpa_done_min'] as num?)?.toInt(),
            description: week['vilpa_desc'] as String?,
          ),
      ],
      noteId: raw['note_id'] as String?,
    );
  }

  /// Today's estimate, as the plan saw it.
  final double? current;

  /// Where [weeks] of the plan typically lands it. Null when [withheld].
  final double? projected12wk;

  /// The typical gain over [weeks]. Null when there is no age median.
  final double? gain;

  /// The population median for this owner's age band.
  final double? medianForAge;

  /// How many weeks the projection covers.
  final int? weeks;

  /// The server's own qualification of the projection. **Drawn whenever
  /// [projected12wk] is.**
  final List<String> caveats;

  /// Why there is no projection, when there is none.
  final Disclosure? withheld;

  /// The week's prescribed blocks, in the server's order.
  final List<PlanBlock> blocks;

  /// The note the projection is cited to.
  final String? noteId;

  /// Whether there is a projection to draw.
  bool get hasProjection => projected12wk != null && gain != null;
}
