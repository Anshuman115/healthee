/// The recovery-and-vitals explainers: what the strap reads off your body while
/// you are still, and what we are willing to say about it.
///
/// Legacy's copy, corrected against `packages/knowledge` and cited. The four
/// heaviest corrections are here rather than in the other two files:
///
///   * **`stress`** described a number "derived from heart-rate variability"
///     showing "fight-or-flight load". `wearable_stress_validity` grades both
///     wrong at [Established]: consumer stress scores are *heart-rate-dominated,
///     not HRV-driven*, and cardiac signals *"index arousal intensity, not
///     emotional valence — they cannot tell 'stressed' from 'excited'"*. Its D2
///     is SAFETY-CRITICAL and says never to infer mood from it. The explainer was
///     doing exactly that, in the middle of the app.
///   * **`rhr_daily`** printed *"every +10 bpm resting is linked to ~16% higher
///     risk of early death"*. The corpus number is 17% (Aune 2017) or 9% (Zhang
///     2016) — 16% is neither — and `resting_heart_rate` D13 forbids the sentence
///     shape outright: *"Never present RHR as a death-risk or mortality
///     number."* That directive is the declared source of the live
///     `personal_death_risk_number` output rule, so a model saying this would
///     have been blocked and the hardcoded string was not.
///   * **`rhr_daily`** also called 50–65 bpm *"healthy for most adults"*. That is
///     the note's **trained-runner** row; its general-adult band is ~60–100, most
///     sitting 60–80. An owner at 72 was being told they were outside normal.
///   * **`spo2`** gave 95–100% as normal and 90% as the see-a-doctor line. The
///     note routes at **~92%**, calls even that *"a clinical convention, not a
///     wearable-validated cutoff"*, and records that the strap *"is not a cleared
///     oximeter and has no published validation, so its error is unquantified"*.
///     The dark-skin bias it grades [Established] — occult hypoxaemia behind a
///     reading of ≥92% — was missing entirely.
library;

import 'package:healthee/shared/metric_info/metric_info.dart';

/// Recovery, stress and the overnight vitals.
const Map<String, MetricInfo> kRecoveryExplainers = <String, MetricInfo>{
  'recovery_score': MetricInfo(
    title: 'Recovery & readiness',
    what:
        'A 0–100 estimate of how recovered you are, from overnight HRV and resting '
        'HR vs YOUR baseline, sleep vs your need, and breathing. Readiness starts at '
        "your morning recovery and drops as the day's training strain adds up.",
    target:
        'Higher is better; the trend matters far more than any single day. '
        "It's shown with a per-factor breakdown so you see exactly what moved it — "
        'and a green morning never clears mounting fatigue, poor mood or pain. '
        'Those are not in the number.',
    why:
        'Each input is well-evidenced on its own. What does NOT exist is a '
        'peer-reviewed formula that combines HRV, resting HR and sleep into one '
        'recovery number — every commercial one is a black box. So the weights '
        'here are assigned by evidence strength, published beside the number, and '
        'this is an honest estimate rather than a clinical score.',
    notes: <String>[
      'recovery_readiness',
      'heart_rate_variability',
      'resting_heart_rate',
      'respiratory_rate_normal',
      'sleep_need_debt',
    ],
    uncited:
        'The way readiness falls through the day is our own conservative model. '
        'There is no validated intraday “battery” formula to copy.',
  ),
  'recovery': MetricInfo(
    title: 'Recovery signals',
    what:
        'Your recovery markers shown one at a time — resting HR, HRV, sleep — each '
        'against your own baseline, so you can see which one moved rather than only '
        'that something did.',
    target:
        'Agreement is what carries weight: three markers pointing the same way is a '
        'stronger read than one. No single marker gets to say "go", and none of them '
        'overrides how you actually feel.',
    why:
        'The individual markers are well-evidenced; no validated formula combines '
        'them, so the breakdown is the honest form and the combined score above is '
        'shown only WITH it, never instead of it.',
    notes: <String>[
      'recovery_readiness',
      'resting_heart_rate',
      'heart_rate_variability',
      'sleep_and_recovery',
    ],
  ),
  'stress': MetricInfo(
    title: 'Stress',
    what:
        'A 0–100 number the strap computes with an algorithm it does not publish. It '
        'tracks physiological AROUSAL against your own baseline — and in practice it '
        'follows heart rate far more closely than HRV.',
    target:
        'No single "good" number, and no target we can defend. It cannot tell '
        'stressed from excited, or a hard walk from bad news, so read it as "how '
        'switched-on was my body", never as how you felt.',
    why:
        'Exercise, caffeine, standing up, a fever and a poor sensor contact all '
        'produce the same signature. No consumer stress score has been validated on '
        'our Huami/Zepp hardware, so we pass the strap’s number through and '
        'treat it as a personal trend only.',
    notes: <String>['wearable_stress_validity', 'heart_rate_variability'],
  ),
  'rhr_daily': MetricInfo(
    title: 'Resting heart rate',
    what:
        'How fast your heart beats at complete rest — a window into heart health '
        'and recovery. Measured optically at the wrist, which sits within a few bpm '
        'of an ECG when you are still.',
    target:
        'About 60–100 bpm is the textbook adult band, with most healthy adults '
        'around 60–80 and trained endurance athletes often 50–65. The useful signal '
        'is not the band — it is a sustained move away from YOUR own baseline.',
    why:
        'Across two meta-analyses of well over a million people, a higher resting '
        'heart rate tracks with worse long-term cardiovascular outcomes. That is a '
        'population association and a marker of fitness, not a prediction about you '
        '— so we show it as an autonomic marker and never as a risk figure. A '
        'multi-day rise above your normal is a real flag for fatigue, alcohol or '
        'oncoming illness.',
    notes: <String>['resting_heart_rate', 'wearable_hr_validity', 'alcohol_sleep'],
  ),
  'hrv': MetricInfo(
    title: 'Heart rate variability',
    what:
        'The tiny beat-to-beat changes in your heart rhythm, read overnight when '
        'you are still. It reflects the state of your autonomic nervous system.',
    target:
        'HRV varies hugely between people, so a number is only meaningful against '
        'YOUR own baseline — comparing yours to someone else’s says nothing. '
        'Higher is generally the better direction, but not always: some people show '
        'RAISED overnight HRV when they are overreached, so it cannot on its own '
        'tell good adaptation from bad.',
    why:
        'A drop of more than about a standard deviation below your rolling baseline '
        'lines up with an acute stressor the day before. Alcohol is the most '
        'reproducible suppressor there is — a heavy evening can take double-digit '
        'milliseconds off, which is usually the answer before illness is.',
    notes: <String>[
      'heart_rate_variability',
      'alcohol_sleep',
      'wearable_hr_validity',
      'recovery_readiness',
    ],
  ),
  'resp': MetricInfo(
    title: 'Breathing rate',
    what:
        'Breaths per minute over your sleep. The strap infers this from the pulse '
        'signal rather than measuring airflow, so it is an estimate — typically '
        'within a breath or two of a clinical instrument.',
    target:
        '12–20 breaths/min is the healthy resting range, and most adults sit around '
        '12–16 in deep sleep. Watch for a shift from YOUR baseline rather than the '
        'band.',
    why:
        'Overnight breathing rate is one of the cleanest, least noisy signals the '
        'strap produces: a rise of about 2 br/min sustained over two nights is a '
        'validated early flag for illness. It also rises with fever, stress and '
        'anxiety, so it says something changed, not what.',
    notes: <String>['respiratory_rate_normal', 'illness_flag_plan'],
  ),
  'spo2': MetricInfo(
    title: 'Blood oxygen (SpO₂)',
    what:
        'An optical estimate of how much oxygen your blood is carrying overnight. '
        'The strap is not a cleared oximeter and has no published validation, so '
        'how far out any single reading is, is genuinely unknown.',
    target:
        'Read the multi-night trend, never a single night and never one minute — '
        'most isolated dips are sensor artefacts. Optical sensors also '
        'OVERESTIMATE saturation on darker skin, which matters most at exactly the '
        'low values worth noticing.',
    why:
        'A nightly minimum that stays below about 92% across several nights is '
        'worth taking to a clinician. That is a threshold from clinical practice, '
        'not one validated on a wrist device — we could source none — so it is a '
        'reason to get checked, never a measurement of your oxygenation and never a '
        'sleep-apnea finding.',
    notes: <String>['wearable_spo2_validity'],
  ),
};
