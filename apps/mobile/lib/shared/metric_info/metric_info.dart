/// The plain-language explainer behind a card's ⓘ — **legacy's `kMetricInfo`,
/// ported verbatim**.
///
/// `healthee-legacy/app/lib/ui/metric_info.dart`. Every card on legacy's screens
/// that carries an `infoKey` opens one of these, and four of them are on the
/// Sleep tab (`sleep`, `sleep_health`, `sleep_debt`, `sleep_consistency`). The
/// whole map is ported rather than the four, because the second screen to need it
/// would otherwise copy this file (Standards §1: second occurrence = extract, and
/// the first occurrence is the cheapest place to do it).
///
/// ## What is NOT claimed about this copy
///
/// These are legacy's own sentences and they cite primary literature in prose
/// ("Cappuccio 2010, 1.4M people"; "Windred 2024"). **They have not been
/// re-verified against `packages/knowledge` in this pass**, and they are not
/// wired to the corpus — no id, no grade, no manifest entry. That is a finding
/// reported with the port, not a fix made inside it: the brief is explicit that a
/// faithful port of something imperfect beats an unrequested change, and
/// rewriting research prose is the last thing to do silently.
library;

import 'package:meta/meta.dart';

/// What one metric is, what to aim for, and why it matters.
@immutable
class MetricInfo {
  /// Builds one explainer.
  const MetricInfo({
    required this.title,
    required this.what,
    required this.target,
    required this.why,
  });

  /// The layman name.
  final String title;

  /// What it is, in plain words.
  final String what;

  /// What to aim for — the optimal value or range.
  final String target;

  /// Why it matters, and the evidence behind it.
  final String why;
}

/// Keyed by the card identity legacy uses in `infoKey`.
const Map<String, MetricInfo> kMetricInfo = <String, MetricInfo>{
  'recovery_score': MetricInfo(
    title: 'Recovery & readiness',
    what:
        'A 0–100 estimate of how recovered you are, from overnight HRV and resting '
        'HR vs YOUR baseline, sleep vs your need, and breathing. Readiness starts at '
        "your morning recovery and drops as the day's training strain adds up.",
    target:
        'Higher is better; the trend matters far more than any single day. '
        "It's shown with a per-factor breakdown so you see exactly what moved it.",
    why:
        'HRV and resting HR are the best-validated recovery markers (Manresa-Rocamora '
        '2021; Aune 2017). No published formula COMBINES them into one number, so this '
        'is an honest evidence-weighted estimate — not a clinical score.',
  ),
  'stress': MetricInfo(
    title: 'Stress',
    what:
        'A 0–100 reading the strap derives from heart-rate variability through the '
        'day — lower is calmer, higher is more sympathetic (fight-or-flight) load.',
    target:
        'No single "good" number; watch YOUR pattern and what drives spikes. '
        'Recovery time after stress matters more than the peak.',
    why:
        'Chronically elevated stress load blunts recovery and HRV. It is a derived '
        'proxy, not a clinical measure — use it directionally.',
  ),
  'sleep': MetricInfo(
    title: 'Sleep duration',
    what: 'How long you actually slept last night (light + deep + REM, minus time awake).',
    target:
        'Aim for 7–9 hours a night (adults). Below ~6h or above ~9h both carry more risk.',
    why:
        'Both short and long sleep are linked to worse long-term health '
        '(Cappuccio 2010, 1.4M people).',
  ),
  'rhr_daily': MetricInfo(
    title: 'Resting heart rate',
    what:
        'How fast your heart beats at complete rest — a window into heart health '
        'and recovery.',
    target:
        'Lower is generally better. 50–65 bpm is healthy for most adults; fitter '
        'people sit lower.',
    why:
        'Every +10 bpm resting is linked to ~16% higher risk of early death '
        '(Aune 2017, 1.2M people).',
  ),
  'hrv': MetricInfo(
    title: 'Heart rate variability',
    what:
        'The tiny beat-to-beat changes in your heart rhythm. More variability = a '
        'more adaptable, recovered nervous system.',
    target:
        'Higher and steady is better — but HRV varies hugely between people, so '
        'compare to YOUR own baseline, not others.',
    why:
        'A drop below your normal can flag stress, illness, or poor recovery '
        '(Shaffer 2017).',
  ),
  'energy': MetricInfo(
    title: 'Energy — active calories',
    what:
        'Calories you burned through movement, on top of the ~1,760/day your body '
        'burns at rest just to stay alive (BMR).',
    target:
        'No fixed target — it simply reflects how active your day was. The weekly '
        'trend matters more than any single day.',
    why:
        'Estimated from activity type (the MET method), not heart rate — more '
        'accurate for ordinary days than wrist HR.',
  ),
  'resp': MetricInfo(
    title: 'Breathing rate',
    what: 'Breaths per minute, measured while you sleep.',
    target:
        '12–20 breaths/min is typical (lower in deep sleep). Watch for changes from '
        'YOUR baseline.',
    why: 'A sustained rise above your norm can be an early sign of illness or stress.',
  ),
  'spo2': MetricInfo(
    title: 'Blood oxygen (SpO₂)',
    what: 'The percentage of oxygen your blood is carrying overnight.',
    target:
        '95–100% is normal. Brief dips in sleep can be normal; consistently below '
        '90% is worth a doctor’s attention.',
    why:
        'Low overnight oxygen can be a sign of breathing problems such as sleep apnea.',
  ),
  'steps_total': MetricInfo(
    title: 'Steps',
    what: 'Total steps today — the simplest measure of daily movement.',
    target:
        'Around 7,000–8,000 a day captures most of the health benefit. More is fine; '
        'you don’t need 10,000.',
    why:
        'Risk of early death keeps falling up to ~7,500 steps/day, then plateaus '
        '(Paluch 2022).',
  ),
  'sleep_health': MetricInfo(
    title: 'Sleep health (4 checks)',
    what:
        'Four evidence-based qualities of a good night: enough hours, efficient '
        'sleep, a healthy bedtime, and night-to-night regularity. Each is a simple '
        'pass/fail.',
    target: 'Aim for 4 / 4. Each check uses a research cut-off (e.g. 7–9h, ≥85% efficient).',
    why:
        'These four together track health better than any single 0–100 “sleep score” '
        '— no such score is scientifically validated.',
  ),
  'sleep_debt': MetricInfo(
    title: 'Sleep need, performance & debt',
    what:
        'How much sleep your body needs versus what you got. “Sleep performance” is '
        'simply last night ÷ your need (e.g. 4h of 8h = 50%). Missed sleep adds up '
        'over time as “debt.”',
    target:
        'Aim for 100% performance (7–9h) and keep the debt shrinking. Even an extra '
        '30 min a night moves it the right way.',
    why:
        'Short sleep builds a debt with a real, accumulating cost to focus and mood '
        '(Van Dongen 2003); the 7–9h need comes from the NSF 2015 consensus.',
  ),
  'sleep_consistency': MetricInfo(
    title: 'Sleep consistency (SRI)',
    what:
        'How steady your sleep–wake timing is night to night, scored 0–100 (the '
        'Sleep Regularity Index). It rewards going to bed and waking at the same '
        'clock times; drifting timing — even with the same hours — lowers it.',
    target:
        'Keep both bedtime and wake time within about a 1-hour band every day, '
        'weekends included. Population median is 81; the steadiest 20% stay within '
        '~1 hour. A late bedtime (after midnight) is worth shifting toward 10–11 PM.',
    why:
        'In 60,977 UK Biobank adults, sleep regularity predicted mortality MORE '
        'strongly than sleep duration — the steadiest had ~30% lower all-cause risk '
        '(Windred 2024). To improve: pick a fixed wake time, get bright light on '
        'waking, set a lights-out target a little earlier each week, and skip long '
        'catch-up naps that fragment the rhythm.',
  ),
  'cardio_load': MetricInfo(
    title: 'Strain · cardio load',
    what:
        'How much cardiovascular work your heart did today. The 0–21 “strain” is '
        'your daily load placed on a personal scale — around 21 is one of your '
        'hardest days, 0 a rest day.',
    target:
        'No single “right” number — aim for consistency and gradual build-up. A '
        'strain well above your usual is a hard day; balance it with recovery and '
        'sleep.',
    why:
        'Built from Banister’s training-impulse method (1991) — minutes weighted by '
        'heart-rate reserve, HR-max from Tanaka 2001. The 0–21 scale is anchored to '
        'YOUR own min/max days, not a universal number, so compare it to yourself.',
  ),
  'vo2max': MetricInfo(
    title: 'VO₂max — cardio fitness',
    what:
        'How well your body uses oxygen during hard effort. It’s the single best '
        'number for overall fitness.',
    target:
        'Higher is better. The floor to aim for is the median for your age & sex '
        '(shown on the card); every small gain counts.',
    why:
        'One of the strongest predictors of a long life — low fitness beats smoking, '
        'diabetes & high blood pressure as a risk (Mandsager 2018, 122k adults).',
  ),
  'mvpa': MetricInfo(
    title: 'Active minutes (MVPA)',
    what:
        'Minutes spent moving briskly enough to raise your heart rate — '
        'moderate-to-vigorous activity.',
    target:
        'At least 150 min/week (~22 min/day); 300 is even better. Vigorous minutes '
        'count double.',
    why:
        '150 min/week lowers the risk of early death, heart disease and diabetes '
        '(WHO 2020).',
  ),
  'biological_age': MetricInfo(
    title: 'Biological age (estimate)',
    what:
        'A motivational estimate of how old your body “acts” based on your fitness '
        'and sleep — not your real age. Each metric’s mortality-risk is converted '
        'into years using the Gompertz law (death risk doubles ~every 8 years), the '
        'same math behind research aging-clocks like PhenoAge.',
    target:
        'Lower than your real age is the goal. The breakdown shows which habits add '
        'or remove years — fitness and sleep regularity are the biggest levers you '
        'control.',
    why:
        'Built from large meta-analyses (VO₂max, sleep duration & regularity, all '
        'UK-Biobank-scale) + the Gompertz conversion. Fitness is folded into one '
        'term so cardio isn’t double-counted. It’s a population trend, NOT a '
        'clinical or diagnostic age — and it leans on the VO₂max estimate, so treat '
        'it as motivation and the per-metric years as the actionable part.',
  ),
  'recovery': MetricInfo(
    title: 'Recovery signals',
    what:
        'A read on how recovered your body is, shown as individual markers (resting '
        'HR, HRV, sleep) versus your own baseline — not blended into one score.',
    target:
        'You want most markers favorable (in green). We show a simple tally, never '
        'an invented “readiness 78”.',
    why:
        'The science supports each marker on its own; no validated formula combines '
        'them into a single number, so we don’t fake one.',
  ),
};
