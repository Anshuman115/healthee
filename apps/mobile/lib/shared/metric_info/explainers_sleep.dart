/// The four sleep explainers.
///
/// This is the best-cited quarter of legacy's map, and the audit confirms it:
/// **Van Dongen 2003**, **NSF 2015** and the whole **Windred 2024** cluster
/// (n = 60,977, median SRI 81.0, HR 0.70, regularity beating duration) all check
/// out against the corpus to the figure. So the corrections here are narrower:
///
///   * **`sleep` attributed the 7–9 h band to Cappuccio 2010.** The note carries
///     a standing warning about exactly this: *"Do not quote a reference band
///     from this note. Cappuccio 2010 states none"* — the band is NSF 2015's
///     expert consensus, and the note records that this file's own kind of
///     mis-attribution was removed from the corpus in #88. The U-shape is
///     Cappuccio's; the numbers are not.
///   * **`sleep_health` claimed the four checks "track health better than any
///     single 0–100 sleep score".** That comparison has never been run. Worse,
///     `sleep_health_score_multidim` reports the composite losing to its own best
///     component — SRI alone outperforms the published composite effect sizes.
///     What IS Established is the part worth keeping: no validated composite
///     sleep score exists, which is why this is four checks and not a score.
///   * **Two of the four cutoffs are ours, not the literature's.** ≥85%
///     efficiency is clinical consensus whose own guideline gives a *range*
///     (">80% to 85%"), and **no published SRI threshold of 70 exists at all** —
///     it is derived from a quintile boundary. The card presented all four as
///     research cut-offs.
///   * **`sleep_debt` said missed sleep costs "focus and mood".** Van Dongen's
///     endpoints are cognitive and alertness measures, and `sleep_need_debt`
///     repeats that three times, including in its safety bounds. Mood is another
///     note's claim.
///   * **`sleep_consistency` told the owner to "skip long catch-up naps".**
///     Whether habitual napping is good or bad is graded **Contested** — genuinely
///     disputed, with reverse causation unresolved — and a Contested note does not
///     get to prescribe. Naps are excluded from our SRI by design, which is the
///     true and useful thing to say instead.
library;

import 'package:healthee/shared/metric_info/metric_info.dart';

/// Duration, the four checks, need and debt, and regularity.
const Map<String, MetricInfo> kSleepExplainers = <String, MetricInfo>{
  'sleep': MetricInfo(
    title: 'Sleep duration',
    what:
        'How long you actually slept last night (light + deep + REM, minus time '
        'awake). The total is the part a wrist device gets right; the split '
        'between stages on any one night is much rougher — deep sleep tends to be '
        'over-counted and REM is error-prone.',
    target:
        'Aim for 7–9 hours a night as an adult. That band is the National Sleep '
        'Foundation’s 2015 expert consensus for 18–64 — a recommendation, not a '
        'measured threshold.',
    why:
        'Pooled across prospective studies covering about 1.4 million people, both '
        'short and long sleep are linked to worse long-term health in a U-shape '
        '(Cappuccio 2010). That is a chronic, multi-week pattern — one short night '
        'means nothing here — and the long-sleep side is read as a possible marker '
        'of illness rather than a cause of it.',
    notes: <String>[
      'sleep_duration_mortality',
      'sleep_need_debt',
      'wearable_sleep_stage_validity',
    ],
  ),
  'sleep_health': MetricInfo(
    title: 'Sleep health (4 checks)',
    what:
        'Four qualities of a good night: enough hours, efficient sleep, a healthy '
        'bedtime, and night-to-night regularity. Each is a simple pass/fail, and '
        'they are never summed into a score.',
    target:
        'Aim for 4 / 4. Two of the four cut-offs come straight from the literature; '
        'the other two we chose — see below.',
    why:
        'No peer-reviewed composite 0–100 sleep score exists, and refusing to show '
        'one is the honest choice, so this is a count of checks passed and never a '
        'percentage. Each dimension has its own evidence behind it; the four '
        'together are a reasonable assembly by analogy with published multi-'
        'dimensional sleep-health work, not a directly validated instrument.',
    notes: <String>[
      'sleep_score_implementation_plan',
      'no_validated_sleep_score',
      'sleep_health_score_multidim',
      'sleep_regularity_index',
      'sleep_duration_mortality',
    ],
    uncited:
        'The four cut-offs are unequally sourced. 7–9 h is NSF 2015 consensus. '
        '≥85% efficiency is clinical consensus whose guideline actually gives a '
        'range of >80–85%, so picking 85 was ours. The 2–4 am timing band and '
        'SRI ≥ 70 are both ours — no published SRI threshold of 70 exists. Two '
        'further dimensions of the published framework, satisfaction and '
        'alertness, are self-reported and are simply missing here.',
  ),
  'sleep_debt': MetricInfo(
    title: 'Sleep need, performance & debt',
    what:
        'How much sleep you need versus what you got. "Sleep performance" is last '
        'night ÷ your need. The need is the midpoint of the age band recommended '
        'for you — 8 hours for adults 18–64 — so it is a recommendation, not a '
        'measurement of your body. A minority are genuine short or long sleepers.',
    target:
        'Aim for 100% of that 8-hour midpoint and keep the debt shrinking. Even an '
        'extra 30 min a night moves it the right way.',
    why:
        'Sleep restricted to 6 h a night for two weeks degraded cognitive '
        'performance to the level of two nights with no sleep at all — and the '
        'deficit kept accumulating with no plateau, while the people in it reported '
        'feeling only slightly sleepy (Van Dongen 2003). That is what makes debt '
        'worth tracking rather than trusting how you feel.',
    notes: <String>[
      'sleep_need_debt',
      'sleep_duration_mortality',
      'wearable_sleep_stage_validity',
    ],
    uncited:
        'The half-credit a long night earns back, and the 14-night window the debt '
        'is summed over, are modelling choices rather than validated constants. '
        'The evidence behind sleep debt is for alertness and thinking, not for '
        'mood and not for any direct health outcome.',
  ),
  'sleep_consistency': MetricInfo(
    title: 'Sleep consistency (SRI)',
    what:
        'How steady your sleep–wake timing is night to night, scored 0–100 (the '
        'Sleep Regularity Index). It rewards going to bed and waking at the same '
        'clock times; drifting timing — even with the same hours — lowers it. Ours '
        'is scored from night sleep only, so naps do not count either way.',
    target:
        'Keep both bedtime and wake time within about a 1-hour band every day, '
        'weekends included — that is roughly what the steadiest fifth of people do. '
        'A late bedtime (after midnight) is worth shifting toward 10–11 PM, though '
        'consistency matters more than the clock time itself, and for a night owl a '
        'fixed WAKE time plus morning light beats forcing an early bedtime.',
    why:
        'In 60,977 UK Biobank adults, sleep regularity predicted mortality more '
        'strongly than sleep duration did — adding duration to the model did not '
        'improve it — and the steadiest sleepers sat around 30% lower all-cause '
        'risk (Windred 2024). To improve: pick a fixed wake time, get bright light '
        'on waking, and shift lights-out a little earlier each week.',
    notes: <String>[
      'sleep_regularity_index',
      'sleep_consistency',
      'sleep_timing_chronotype',
      'morning_light_circadian',
    ],
    uncited:
        'SRI does not transport between scoring pipelines, and ours is a third one '
        '— it reads roughly 3–5 points above the published boundaries. So the '
        'population median of 81 belongs to that study’s software, not to this '
        'screen, and none of its risk figures can be converted into a number about '
        'you.',
  ),
};
