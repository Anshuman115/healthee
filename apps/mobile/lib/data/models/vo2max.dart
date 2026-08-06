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

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:meta/meta.dart';

/// The inputs behind a non-exercise estimate, as the row stored them.
@immutable
class Vo2maxInputs {
  /// Builds an input set. Every field is nullable — see [Vo2max.inputs].
  const Vo2maxInputs({
    required this.bmi,
    required this.restingHrMedian7d,
    required this.weeklyMvpaMin,
    required this.physicalActivityScore,
  });

  /// Parses `vo2max.inputs`.
  factory Vo2maxInputs.fromJson(Map<String, Object?> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    return Vo2maxInputs(
      bmi: number('bmi'),
      restingHrMedian7d: number('rhr_med_7d'),
      weeklyMvpaMin: number('weekly_mvpa_min'),
      physicalActivityScore: number('pa_score'),
    );
  }

  /// Body mass index at the time the row was written.
  final double? bmi;

  /// Seven-day median resting heart rate.
  final double? restingHrMedian7d;

  /// Moderate-to-vigorous minutes that week.
  final double? weeklyMvpaMin;

  /// Jurca's self-reported physical-activity score, 0–7.
  final double? physicalActivityScore;
}

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
    required this.ageYears,
    required this.sex,
    required this.inputs,
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
      ageYears: (json['age_years'] as num?)?.toInt(),
      sex: json['sex'] as String?,
      inputs: Vo2maxInputs.fromJson(
        json['inputs'] is Map<String, Object?>
            ? json['inputs']! as Map<String, Object?>
            : const <String, Object?>{},
      ),
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

  /// [methodCaveat] as the disclosure it is, so the cards carry it the same way
  /// every other caveat on the app is carried.
  ///
  /// It arrives outside the `caveats` array — it is a property of the instrument
  /// rather than of this reading — but it is the same kind of claim and the same
  /// length: the live one is 568 characters, and printing it as body prose is
  /// what made Today's Fitness section an essay. Both VO₂max cards render it
  /// through `CaveatNote` now, which puts it one tap away instead of on the card.
  ///
  /// **The method itself stays ON the card.** [[hr_reserve_vo2max]] Directive 4
  /// requires the instrument to be named wherever the number is — that is the
  /// short "Read by …" line, not this paragraph, and moving the paragraph does
  /// not touch it.
  Disclosure get methodDisclosure =>
      Disclosure(reason: 'vo2max_method_caveat', message: methodCaveat);

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

  /// The age the population median was looked up for. A fact about the reference
  /// group; legacy prints it beside [sex] in the module's header.
  final int? ageYears;

  /// `male` or `female`, as the profile holds it — again, the reference group.
  final String? sex;

  /// The four numbers Jurca's non-exercise model takes.
  ///
  /// Every one of them can be null, and on this server three of them usually
  /// are: `read/vo2max.py` maps `weekly_mvpa_min` to `None` outright (a
  /// documented WP7 gap), and `bmi` / `rhr_med_7d` / `pa_score` only exist on a
  /// row the Jurca tier wrote. A measured tier leaves all four empty.
  final Vo2maxInputs inputs;

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
