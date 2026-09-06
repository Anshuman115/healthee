# v02 — current-app data and chart coverage

Reviewed the actual Flutter composition and chart widgets, rather than relying
only on the older design brief. The brief's single-accent proposal was superseded
by the per-metric hues in `apps/mobile/lib/core/theme/instrument_hues.dart`.
The user's September 6 feedback explicitly requires colour-coded data and views.

## What the current app renders

Primary inventory sources:

- `apps/mobile/lib/features/today/today_sections.dart` — documented complete order.
- `apps/mobile/lib/features/today/today_body.dart` — actual Today instruments.
- `apps/mobile/lib/features/sleep/sleep_sections.dart` — night/week/fortnight views.
- `apps/mobile/lib/features/sleep/widgets/breakdown_card.dart` — durations/proportions.
- `apps/mobile/lib/features/sleep/widgets/sleep_trends_card.dart` — efficiency/SRI/HRV.
- `apps/mobile/lib/features/activity/activity_screen.dart` and its widgets.
- `apps/mobile/lib/features/today/widgets/bio_age_card.dart` — age contributions.
- `apps/mobile/lib/features/insights/widgets/trends_section.dart` — metric trends.
- `apps/mobile/lib/data/history/history_metric.dart` — the 20 historical metrics.
- `apps/mobile/lib/shared/charts/` — area, bars, stage stack, hypnogram, debt,
  timing, night trend, deviation, gauges, meters and sparklines.

| Current data/view | v02 HTML placement | Relationship made visible |
| --- | --- | --- |
| Recovery, remaining readiness, four factors | Today and Recovery | Overnight recovery is distinct from remaining capacity after activity |
| Personal baseline signal comparison | Recovery | Each metric against its own baseline |
| HRV and RHR histories | Today, Sleep, Insights, metric explorer | Overnight physiology alongside sleep |
| Intraday heart rate and stress | Today and Insights, linked chart | Shared hour selection, independent labelled scales; no causality claimed |
| Oxygen and breathing | Today, Sleep, metric explorer | Overnight measurements alongside the same sleep history |
| Skin temperature | Today, Sleep, metric explorer | Dated physiology with missing samples preserved |
| Amazfit sleep score | Sleep hero; Today context | Explicitly a device estimate, distinct from four dimensions |
| Stage timeline and stage split | Sleep | Colours persist between timeline, proportion bar and table |
| Stage durations and percentages | Sleep table | All four stage totals shown, including awake |
| Time asleep, in bed, bedtime and wake | Sleep hero and night selector | Distinguishes time asleep from opportunity to sleep |
| Need, performance, debt, nightly gap | Today and Sleep | Nightly shortfall versus the separate 14-night debt model |
| Duration, efficiency, SRI and midpoint | Today and Sleep | Independent dimensions with named reference values |
| Stacked seven-night sleep | Today, Sleep, sleep history | Duration and stage composition stay visible together |
| Bedtime/wake consistency | Sleep | Timings, SRI, onset and wake variation |
| Efficiency, SRI and HRV fortnight trends | Sleep and Insights | Longer context without replacing a night with a score |
| Naps and sleep findings | Sleep, journal and insight links | Daytime context around the night |
| Steps, distance, active/resting/total energy | Today and Activity | Movement amount and modelled energy remain distinct |
| Strain, TRIMP, acute/chronic load | Today, Activity, Recovery, Fitness | Recent effort versus habitual workload and remaining readiness |
| Moderate/vigorous minutes and strength | Today and Activity | Intensity equivalence explicit; strength shown separately |
| Logged caffeine, meditation, fasting | Today and Journal | Context beyond wearable measurements |
| Biological age, chronological age, delta, terms | Today hero and age detail | Actual arithmetic waterfall plus linked fitness/sleep contributors |
| Exclusions and caveats | Age detail | Excluded regularity is not drawn as zero contribution |
| VO₂max, method, reference, error, sessions | Today, Activity, Fitness | Latest instrument and uncertainty shown alongside the estimate |
| VO₂max history | Fitness and metric explorer | Historical instrument metadata absence is disclosed |
| 20 history metrics and statistics | 25-entry metric explorer | Original 20 plus HR, stress, sleep duration, efficiency, temperature |
| Workouts, HR zones, pace and load | Workout details | Existing detail flows retained, heart/load colour restored |
| GPS route, elevation and recording | Route/record flows | Existing HTML flows retained; no real GPS collected |
| Challenges, programs and outcomes | Actions and outcome flows | Intent, observation and causality remain separate |

## Visual system and sample integrity

Green identifies recovery/fitness, violet sleep, coral heart/load, amber
movement/energy, and blue breathing/oxygen. Stress uses its own warm tone.
Status still has words and context: a metric's colour alone is not a verdict.
Stage colours are separately mapped and shared across all stage plots/legends.
Dark is the default for this direction; light and system modes remain available.

The biological-age sample does reconcile: 36 − 1.7 + 0.0 = 34.3. The earlier
prototype's README incorrectly deferred that waterfall; v02 corrects this.
The model's sleep term translates 6.3 wearable hours to a self-report equivalent
of 7.0 hours. This is not the same reference as the 8-hour sleep-need model.

Measurements remain the bundled contract data. Repetitive samples are not
replaced with invented trends. The hypnogram has the three supplied segments;
no extra sleep cycles are fabricated. Supplied stage totals differ from the
separate duration/timeline estimates and that remains disclosed.

The VO₂max error illustration uses the supplied ±2.95 magnitude. It is labelled
as an error magnitude, not an individual confidence interval. The single latest
method is not assigned retroactively to the whole history. The correlation
summary has no paired raw values, so no scatter plot is invented.

Colour and data-rich chart coverage supersede the v01 monochrome reduction.
This remains a browser prototype. No Flutter installation or backend changes.

## Shared historical day selection

Today owns the only header date control. Its selected day is shared by the main
measurement screens and history views, which show a non-interactive date label. Historical series use explicit fixture dates, ending on the chosen
day. Sleep keeps its stage timeline, stage proportions, timing chart, physiological
trends and four independent checks, with missing recordings shown explicitly.
Archived biological-age/recovery/debt results are not present in the fixtures and
are withheld on older days. Session-specific pages keep their recorded date.
