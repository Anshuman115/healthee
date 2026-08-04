/// The VO₂max payload — the estimate, and which instrument produced it.
///
/// The mobile half of `read/vo2max.py`. Two of its rules are structural here
/// rather than advisory:
///
///   * **The instrument is not optional.** [[hr_reserve_vo2max]] Directive 4
///     requires that the method be stated wherever the number is, because "an
///     owner whose number comes from a run one week and a questionnaire the next
///     has to be able to see that, or a change of instrument reads as a change in
///     them". [method] and [methodCaveat] are therefore non-null on [Vo2max] —
///     you cannot construct this object without them, so no screen can render the
///     number and omit its instrument.
///   * **Withheld is not a zero.** The server nulls `estimate` and attaches a
///     `withheld` block; [Vo2max.maybe] returns null in exactly that case, and the
///     envelope turns it into a `Withheld<Vo2max>`. There is no `Vo2max` object
///     with a null estimate to accidentally render.
library;

import 'package:healthee/data/models/trend_point.dart';
import 'package:meta/meta.dart';

/// A reported VO₂max, with the instrument that read it and that instrument's error.
@immutable
class Vo2max {
  /// Builds an estimate. Prefer [Vo2max.maybe] via the honesty envelope.
  const Vo2max({
    required this.estimate,
    required this.method,
    required this.methodCaveat,
    required this.standardErrorMlKgMin,
    required this.standardErrorSource,
    required this.asOfDate,
    required this.medianForAge,
    required this.deltaFromMedian,
    required this.sessionCount,
    required this.trend90d,
    required this.researchNotes,
  });

  /// Parses the payload when it carries a current estimate; null when it does not.
  ///
  /// The null return is what the honesty envelope turns into a `Withheld`. Note
  /// that `method` is read only on this path: the server sets it to null in
  /// lockstep with `estimate`, "because naming the instrument behind a number we
  /// have just declined to report would describe something the owner is not being
  /// shown".
  static Vo2max? maybe(Map<String, Object?> json) {
    final estimate = (json['estimate'] as num?)?.toDouble();
    if (estimate == null) {
      return null;
    }
    return Vo2max(
      estimate: estimate,
      method: json['method']! as String,
      methodCaveat: json['method_caveat']! as String,
      standardErrorMlKgMin: (json['see_ml_kg_min'] as num?)?.toDouble(),
      standardErrorSource: json['see_source'] as String?,
      asOfDate: json['as_of_date'] as String?,
      medianForAge: (json['median_for_age'] as num?)?.toDouble(),
      deltaFromMedian: (json['delta_from_median'] as num?)?.toDouble(),
      sessionCount: (json['n_sessions'] as num?)?.toInt(),
      trend90d: TrendPoint.listFrom(json['trend_90d']),
      researchNotes: _strings(json['research_notes']),
    );
  }

  /// mL/kg/min.
  final double estimate;

  /// Which instrument produced it: `gps_graded`, `hr_reserve`, or
  /// `jurca_non_exercise`. Non-null by construction — see the library docstring.
  final String method;

  /// That instrument's limit, in the second person. Always rendered with the
  /// number; it is the honest half of the estimate.
  final String methodCaveat;

  /// The ± band, in the reporting instrument's own units of error.
  ///
  /// `docs/APP_DESIGN.md` §3.1 and §3.3 both say "always show the ± band", which
  /// is why this is on the model rather than looked up per screen.
  final double? standardErrorMlKgMin;

  /// WHICH kind of error the band is — a MAPE, a modelled SD, or an SEE. Without
  /// it a percentage error can be misread as a standard error of estimate.
  final String? standardErrorSource;

  /// The day this estimate is a claim about, `YYYY-MM-DD`.
  final String? asOfDate;

  /// The population median for the owner's age and sex — a fact about the
  /// reference group, not a claim about them.
  final double? medianForAge;

  /// Estimate minus [medianForAge]. Null when either is missing.
  final double? deltaFromMedian;

  /// How many recorded sessions are behind a measured estimate. 1 means the
  /// number is one session, not a settled level, and the caveat says so.
  final int? sessionCount;

  /// Up to 90 days of history. Kept even when the estimate is withheld — a trend
  /// that ends before today is honest as long as nothing claims it ends now.
  final List<TrendPoint> trend90d;

  /// The notes that license this number in front of the owner.
  final List<String> researchNotes;

  static List<String> _strings(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }
}
