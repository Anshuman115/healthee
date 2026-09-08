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

/// `vo2max.submax` — the fit behind a session-measured estimate.
///
/// **Not a second estimate.** `derive/vo2max_tier.py` writes ONE VO₂max, and
/// this block describes the session the graded tier read it off: how well the
/// heart-rate/workload line fitted, and the speed the fit was taken at. It is
/// parsed so the fitness screen can answer *"which instrument produced it?"*
/// with the fit's own numbers instead of restating the estimate.
@immutable
class Vo2maxSubmax {
  /// Builds the block. Prefer [Vo2maxSubmax.maybe].
  const Vo2maxSubmax({
    required this.lastMethod,
    required this.lastR2,
    required this.lastSpeedKmh,
    required this.asOfDate,
  });

  /// Parses `submax`, or null when it holds nothing worth drawing.
  static Vo2maxSubmax? maybe(Map<String, Object?> json) {
    final block = Vo2maxSubmax(
      lastMethod: json['last_method'] as String?,
      lastR2: (json['last_r2'] as num?)?.toDouble(),
      lastSpeedKmh: (json['last_speed_kmh'] as num?)?.toDouble(),
      asOfDate: json['as_of_date'] as String?,
    );
    return block.isEmpty ? null : block;
  }

  /// The instrument the last scoreable session was read with.
  final String? lastMethod;

  /// How well that session's heart-rate/workload line fitted, 0–1.
  final double? lastR2;

  /// The speed the fit was taken at.
  final double? lastSpeedKmh;

  /// The day that session was recorded.
  final String? asOfDate;

  /// Whether every field is absent — a block with nothing to say.
  bool get isEmpty =>
      lastMethod == null && lastR2 == null && lastSpeedKmh == null;
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
    required this.measuredAsOf,
    required this.medianForAge,
    required this.deltaFromMedian,
    required this.sessionCount,
    required this.trend90d,
    required this.researchNotes,
    required this.ageYears,
    required this.sex,
    required this.inputs,
    this.submax,
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
      measuredAsOf: json['measured_as_of'] as String?,
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
      submax: json['submax'] is Map<String, Object?>
          ? Vo2maxSubmax.maybe(json['submax']! as Map<String, Object?>)
          : null,
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

  /// The day the MEASUREMENT behind it was recorded, `YYYY-MM-DD`.
  ///
  /// A different fact from [asOfDate] and that is the whole reason it is here.
  /// `derive/vo2max_tier.py` lets a graded session or a reserve inversion speak
  /// for up to `MEASURED_VO2MAX_MAX_AGE_DAYS` = 14 days, and the freshness
  /// argument that permits it (`derive/freshness.py`) rests on the owner being
  /// told which day it was measured. This was on the wire and unparsed, so a card
  /// read "as of today" over a run recorded a fortnight ago — the stale-as-current
  /// lie reached through the client rather than the server, which is why the
  /// server's own guard could not catch it.
  ///
  /// Rendered only when it DIFFERS from [asOfDate]; see [measuredEarlier].
  final String? measuredAsOf;

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

  /// The measurement day when it is NOT the day the estimate is offered for.
  ///
  /// Null when the two agree, so a screen that prints this prints nothing on the
  /// ordinary day and names the gap on the day there is one.
  String? get measuredEarlier =>
      measuredAsOf != null && measuredAsOf != asOfDate ? measuredAsOf : null;

  /// The notes that license this number in front of the owner.
  final List<String> researchNotes;

  /// The age the population median was looked up for. A fact about the reference
  /// group; legacy prints it beside [sex] in the module's header.
  final int? ageYears;

  /// `male` or `female`, as the profile holds it — again, the reference group.
  final String? sex;

  /// The four numbers Jurca's non-exercise model takes.
  ///
  /// Every one of them can be null, and `bmi` / `rhr_med_7d` / `pa_score` exist
  /// only on a row the Jurca tier wrote.
  ///
  /// `weekly_mvpa_min` used to be null on EVERY row — `read/vo2max.py` mapped it
  /// to `None` outright, beside a note saying v2 does not store it in the VO₂max
  /// flags. That was true and it was not a reason: the number is computed twenty
  /// lines away for `/api/activity.mvpa.week_min`, and both surfaces read it from
  /// one place now (`docs/BACKEND_GAPS_FROM_UI.md` B3). It is null only when
  /// there is genuinely no MVPA row to sum — never `0`, which would read as a
  /// measured week of stillness.
  final Vo2maxInputs inputs;

  /// The fit behind a session-measured estimate, when there was a session.
  final Vo2maxSubmax? submax;

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
