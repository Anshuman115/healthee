/// The evidence grade for a research-note id. **Generated — do not hand-edit.**
///
/// Emitted by `python3 tool/gen_note_names.py` in the same pass as
/// `note_names.dart`, from the same read of `packages/knowledge/manifest.json`,
/// so the two cannot describe different corpus versions. A separate file only
/// because one file of both would clear 400 lines (Standards §1).
///
/// `test/shared/note_names_test.dart` reads the manifest out of the repo and
/// fails when this file has drifted from it.
library;

import 'package:healthee/shared/format/note_names.dart';

/// Every note in the corpus, id → the corpus's own `grade` field.
///
/// ## Why the app may hold grades at all, when `CitationRow` may not infer them
///
/// `CitationRow` never derives a grade from an id it was handed, and that rule
/// stands: a `research_notes` array arriving on a payload says which notes back
/// a sentence the SERVER composed, and the server is the only party that knows
/// what that sentence claims. Guessing a grade there would rebuild the
/// `evidence_grade`-vs-`grade` split that once published a `Myth` note as
/// `Established` (#83).
///
/// The explainers in `shared/metric_info/` are the opposite case. Their prose is
/// written **in this repo, against these notes**, by a person who read them —
/// the citation is authored, not received. So the grade is not inferred from the
/// id; it is looked up from the corpus's own field, and this table is a
/// transcription of that field exactly as [kNoteNames] is a transcription of
/// `name`. The generator emits both from the same manifest read, so they cannot
/// describe different corpus versions.
const Map<String, String> kNoteGrades = <String, String>{
  'aerobic_decoupling': 'Probable',
  'alcohol_sleep': 'Established',
  'behavior_change_and_personalization': 'Established',
  'biological_age_estimate': 'Probable',
  'cadence': 'Probable',
  'cadence_derived_speed': 'Probable',
  'cadence_intensity': 'Established',
  'caffeine_alcohol_cutoff_plan': 'Probable',
  'caffeine_sleep': 'Established',
  'critical_speed': 'Established',
  'distance_from_steps': 'Probable',
  'energy_expenditure_derivation': 'Probable',
  'environmental_stress': 'Established',
  'exercise_mortality': 'Established',
  'fasting_metrics': 'Probable',
  'fitness_fatigue_form': 'Probable',
  'fueling_and_hydration': 'Established',
  'grade_adjusted_pace': 'Probable',
  'heart_rate_variability': 'Probable',
  'heart_rate_zones': 'Probable',
  'hr_reserve_vo2max': 'Contested',
  'hydration_8x8_rule': 'Myth',
  'hydration_everyday': 'Probable',
  'illness_flag_plan': 'Probable',
  'individualization': 'Established',
  'injury_prevention': 'Probable',
  'lactate_threshold': 'Established',
  'late_eating_sleep': 'Contested',
  'llm_health_advice_safety': 'Probable',
  'load_currency': 'Probable',
  'maximum_heart_rate': 'Established',
  'menstrual_cycle_and_training': 'Contested',
  'mindfulness_anxiety_depression': 'Established',
  'morning_light_circadian': 'Established',
  'mvpa_minutes_mortality': 'Established',
  'mvpa_weekly_plan': 'Probable',
  'napping': 'Probable',
  'napping_chronic_health': 'Contested',
  'no_validated_sleep_score': 'Established',
  'non_exercise_vo2max': 'Probable',
  'pace_zones': 'Established',
  'periodization': 'Probable',
  'polarized_training': 'Probable',
  'progressive_overload': 'Probable',
  'race_prediction': 'Probable',
  'recommendations_engine_plan': 'Probable',
  'recovery_readiness': 'Probable',
  'respiratory_rate_normal': 'Established',
  'resting_heart_rate': 'Established',
  'running_economy': 'Established',
  'running_form_metrics': 'Contested',
  'sauna_cv_benefits': 'Established',
  'sedentary_mortality': 'Established',
  'skin_temp_signals': 'Probable',
  'sleep_and_recovery': 'Probable',
  'sleep_consistency': 'Established',
  'sleep_duration_mortality': 'Established',
  'sleep_health_score_multidim': 'Probable',
  'sleep_need_debt': 'Probable',
  'sleep_regularity_index': 'Established',
  'sleep_score_implementation_plan': 'Probable',
  'sleep_timing_chronotype': 'Probable',
  'slow_breathing_hrv_acute': 'Established',
  'specificity_and_recovery': 'Established',
  'steps_mortality': 'Established',
  'strength_adherence_plan': 'Probable',
  'strength_training_for_runners': 'Established',
  'strength_training_mortality': 'Established',
  'stride_length': 'Probable',
  'submaximal_vo2max': 'Probable',
  'training_load_acwr': 'Contested',
  'training_stress_score': 'Probable',
  'vo2max': 'Established',
  'wearable_hr_validity': 'Established',
  'wearable_sleep_stage_validity': 'Established',
  'wearable_spo2_validity': 'Established',
  'wearable_stress_validity': 'Probable',
  'weight_bmi_body_composition': 'Established',
};

/// Grade → numeric rank. **The server's `core/knowledge.py::GRADE_RANK`,
/// transcribed** — one scale, so "weakest" means the same thing on both sides of
/// the wire. `Contested` and `Emerging` share rank 1 and `Myth`/`Refuted` share
/// 0, which is the server's map and not a simplification made here.
const Map<String, int> kGradeRank = <String, int>{
  'Established': 3,
  'Probable': 2,
  'Emerging': 1,
  'Contested': 1,
  'Myth': 0,
  'Refuted': 0,
};

/// The grade a claim citing [noteIds] may honestly wear: **the weakest one**.
///
/// The same rule `jobs/recs.py::_provable_grade` applies server-side — "the
/// strictest (weakest) grade among the cited notes is the ceiling" — so a claim
/// resting on an `Established` note and a `Probable` one ships as `Probable`.
/// Averaging or taking the strongest would let one solid citation launder a weak
/// one, which is the whole failure mode.
///
/// An id this build cannot resolve returns null rather than a grade: an app
/// older than the corpus must be visibly behind, never confidently wrong. Same
/// for an empty list — a claim with no citations has no grade to show, and
/// `MetricInfo` says so in words instead.
String? weakestGrade(Iterable<String> noteIds) {
  String? weakest;
  var lowest = 1 << 30;
  for (final id in noteIds) {
    final grade = kNoteGrades[canonicalNoteId(id)];
    final rank = grade == null ? null : kGradeRank[grade];
    if (grade == null || rank == null) {
      return null;
    }
    if (rank < lowest) {
      lowest = rank;
      weakest = grade;
    }
  }
  return weakest;
}
