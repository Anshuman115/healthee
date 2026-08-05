/// The owner-facing name for a research-note id. **Generated — do not hand-edit.**
///
/// Run `python3 tool/gen_note_names.py` from `apps/mobile` after any change to
/// `packages/knowledge`; `test/shared/note_names_test.dart` reads the manifest
/// out of the repo and fails when this file has drifted from it.
///
/// ## Why the app carries the corpus's names at all
///
/// A citation reaches the screen as an id — `/api/today` sends
/// `research_note_ids: ["mvpa_minutes_mortality"]` and nothing else — and an id
/// is an internal identifier. The chips rendered `recovery_readiness` under the
/// gauge and `cardio_load_trimp` on Activity, which is a log line where a source
/// should be.
///
/// The names here are the corpus's own `name` field, transcribed. Two other
/// designs were rejected:
///
///   * **Prettify the id** (`sleep_score_implementation_plan` → "Sleep score
///     implementation plan"). `metric_names.dart` already argues this one down
///     for metric ids: it invents an owner-facing name for something nobody
///     named, and it looks like a name, so nothing about it reads as a gap.
///   * **Have the server send the name.** This is the right long-term fix and it
///     is a wire change, so it belongs in a server PR with a contract snapshot.
///     Until then the app resolves offline, which it must do anyway — the
///     citations are on cached payloads and the phone is often on no network.
///
/// An id with no entry keeps its id (see [noteName]), which is the same stance
/// `metric_names.dart` takes and is now a corpus-ahead-of-app condition rather
/// than a routine one.
library;

/// The readable source name for [noteId], or null when this build has never
/// heard of it.
///
/// Null rather than a manufactured phrase: an app older than the corpus should
/// show the id and be visibly behind, not invent a title for a note it does not
/// have. `CitationRow` renders the id in that case and logs it.
String? noteName(String noteId) => kNoteNames[noteId];

/// Every note in the corpus, id → the corpus's own name.
const Map<String, String> kNoteNames = <String, String>{
  'aerobic_decoupling': 'Aerobic Decoupling & Cardiac Drift',
  'alcohol_sleep': 'Alcohol, sleep architecture, and overnight autonomics',
  'behavior_change_and_personalization': 'Behavior change & personalization (recs design basis)',
  'biological_age_estimate': 'Biological Age (estimate)',
  'cadence': 'Cadence (Step Rate)',
  'cadence_derived_speed': 'Cadence-derived speed as a workload input',
  'cadence_intensity': 'Step cadence as exercise-intensity proxy',
  'caffeine_alcohol_cutoff_plan': 'Personal caffeine/alcohol cutoff-time finder (plan)',
  'caffeine_sleep': 'Caffeine timing and sleep',
  'critical_speed': 'Critical Speed / Critical Power',
  'distance_from_steps': 'Deriving distance from step count',
  'energy_expenditure_derivation': 'Deriving daily energy expenditure (calories)',
  'environmental_stress': 'Heat & Altitude',
  'exercise_mortality': 'Minimum exercise dose and mortality',
  'fasting_metrics': 'Fasting (IF / TRE) and tracked metrics',
  'fitness_fatigue_form': 'Fitness / Fatigue / Form (CTL, ATL, TSB)',
  'fueling_and_hydration': 'Fueling & Hydration',
  'grade_adjusted_pace': 'Grade-Adjusted Pace (GAP)',
  'heart_rate_variability': 'Heart-Rate Variability (HRV)',
  'heart_rate_zones': 'Heart-Rate Training Zones',
  'hr_reserve_vo2max': 'VO₂max from heart-rate reserve (%HRR = %VO₂R)',
  'hydration_8x8_rule': 'The "8 glasses a day" rule',
  'hydration_everyday': 'Everyday hydration (non-exercise)',
  'illness_flag_plan': 'Illness / recovery early-warning flag',
  'individualization': 'Individualization — Training the Runner, Not the Population',
  'injury_prevention': 'Running Injury Prevention',
  'lactate_threshold': 'Lactate Threshold (LT1, LT2, LTHR)',
  'late_eating_sleep': 'Late eating and sleep',
  'llm_health_advice_safety': 'LLM health-advice safety guardrails',
  'load_currency': 'Load Currency — TRIMP vs TSS (why Healthee reasons over one unit)',
  'maximum_heart_rate': 'Maximum Heart Rate (HRmax)',
  'menstrual_cycle_and_training': 'Menstrual Cycle & Training',
  'mindfulness_anxiety_depression': 'Mindfulness meditation for anxiety, depression, and pain',
  'morning_light_circadian': 'Morning bright light & circadian entrainment',
  'mvpa_minutes_mortality': 'MVPA minutes and mortality (150-min target)',
  'mvpa_weekly_plan': 'MVPA derivation & weekly-target plan',
  'napping': 'Daytime napping',
  'napping_chronic_health': 'Is habitual napping healthy?',
  'no_validated_sleep_score': 'No validated composite sleep score',
  'non_exercise_vo2max': 'Non-exercise VO₂max estimate (Jurca 2005)',
  'pace_zones': 'Pace Zones & Threshold Pace',
  'periodization': 'Periodization & Tapering',
  'polarized_training': 'Polarized & Intensity-Distribution Training',
  'progressive_overload': 'Progressive Overload & Adaptation',
  'race_prediction': 'Race-Time Prediction',
  'recommendations_engine_plan': 'Daily AI recommendations engine (implementation plan)',
  'recovery_readiness': 'Daily Recovery / Readiness',
  'respiratory_rate_normal': 'Respiratory Rate (overnight)',
  'resting_heart_rate': 'Resting Heart Rate (RHR)',
  'running_economy': 'Running Economy',
  'running_form_metrics': 'Advanced Form Metrics & Running Power',
  'sauna_cv_benefits': 'Sauna bathing and cardiovascular mortality',
  'sedentary_mortality': 'Sedentary time and mortality',
  'skin_temp_signals': 'Skin Temperature (overnight)',
  'sleep_and_recovery': 'Sleep & Recovery',
  'sleep_consistency': 'Sleep timing consistency (day-to-day variability)',
  'sleep_duration_mortality': 'Sleep duration and all-cause mortality',
  'sleep_health_score_multidim': 'Multi-dimensional sleep-health composites (evidence review)',
  'sleep_need_debt': 'Sleep need & cumulative sleep debt',
  'sleep_regularity_index': 'Sleep Regularity Index (SRI)',
  'sleep_score_implementation_plan': '4-dimension sleep-health score (implementation plan)',
  'sleep_timing_chronotype': 'Sleep timing, chronotype & the CVD-lowering bedtime',
  'slow_breathing_hrv_acute': 'Slow-paced breathing and acute HRV',
  'specificity_and_recovery': 'Specificity & Recovery',
  'steps_mortality': 'Daily steps and mortality',
  'strength_adherence_plan': 'Weekly strength-minutes tally plan',
  'strength_training_for_runners': 'Strength Training for Runners',
  'strength_training_mortality': 'Strength training and mortality',
  'stride_length': 'Stride Length',
  'submaximal_vo2max': 'Submaximal HR-vs-pace VO₂max estimate',
  'training_load_acwr': 'Training Load & Acute:Chronic Workload Ratio (ACWR)',
  'training_stress_score': 'Training Stress Score (TSS) and Session Load Quantification',
  'vo2max': 'VO₂max (Maximal Oxygen Uptake)',
  'wearable_hr_validity': 'Wearable HR (PPG) — validity & limits',
  'wearable_sleep_stage_validity': 'Wearable sleep-stage scoring — validity & limits',
  'wearable_spo2_validity': 'Wearable SpO2 — validity & limits',
  'wearable_stress_validity': 'Wearable stress scores — validity & limits',
  'weight_bmi_body_composition': 'Body weight, BMI, and body composition',
};
