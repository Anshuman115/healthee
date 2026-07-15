---
id: wearable_sleep_stage_validity
topic: Wrist/strap sleep stage scoring vs polysomnography
evidence_grade: 3
applies_to_metrics: [sleep_stage, sleep_light_min, sleep_deep_min, sleep_awake_min, sleep_score]
applies_to_interventions: []
tags: [methodology, sleep, sleep_staging, accuracy]
last_reviewed: 2026-05-11
---

## What it actually measures
Consumer wearables (including Huami / Zepp OS devices) estimate sleep stages
from **accelerometry + optical HR (PPG) + HRV**. They run proprietary
algorithms that approximate polysomnography (PSG) — the clinical gold
standard, which uses EEG, EOG, EMG, and respiratory signals.

This is a **fundamentally different measurement** than PSG. The proxies are
real (HRV does shift across stages, movement does drop), but they cannot
directly observe brain state.

## What we can trust
- **Total sleep time vs wake**: wearables agree well with PSG. Detection of "asleep" vs "awake" is the most reliable component.
- **Bedtime and wake time**: usually within minutes of PSG-determined values.
- **Within-individual trends** in stage proportions over weeks and months.
- **Direction of changes**: e.g., alcohol → less deep, illness → more wake — these directional effects do show up.

## What we can't trust
- **Single-night exact stage values.** Studies report ~60–70% epoch-level agreement with PSG for sleep stages, with Cohen's κ often 0.3–0.6 (fair-to-moderate agreement, not strong).
- **Deep sleep duration** specifically tends to be over-estimated by wrist wearables (consistent across multiple device families).
- **REM duration** is the most error-prone individual stage in most devices.
- **Sleep score** is a proprietary composite — its specific value carries less information than the underlying components.

## Evidence strength
- Chinoy ED, Cuellar JA, Huwa KE, et al. **"Performance of seven consumer sleep-tracking devices compared with polysomnography."** *Sleep* 2021;44(5):zsaa291. Compared 7 commercial wearables including Fitbit Versa, Garmin Forerunner, Withings, Apple Watch, etc., against PSG.
- Berryhill S, Morton CJ, Dean A, et al. **"Effect of wearables on sleep in healthy individuals: a randomized cross-over trial and validation study."** *Journal of Clinical Sleep Medicine* 2020;16(5):775–783.
- Robbins R et al. **"Estimated sleep duration before and during the COVID-19 pandemic in major metropolitan areas on different continents: observational study of smartphone app data."** *Journal of Medical Internet Research* 2020;22(2):e20546. (For context on what wearables measure well at population scale.)

## Caveats
- Helio Strap (specifically) has no published independent validation we're aware of. Estimates above are from devices with broadly similar sensor stacks.
- Cohen's κ varies considerably by population (e.g., poorer performance in older adults and people with sleep disorders).
- Algorithmic updates can change measured values without any change in physiology. Watch firmware version when comparing across long periods.

## Operational use
- Trust **total sleep time, bedtime, wake time, and asleep-vs-awake** classification.
- Use **stage breakdowns directionally**: "your deep sleep dropped 30% on alcohol nights" is fine; "you got exactly 44 minutes of deep sleep" is over-stated.
- Sleep score is useful as a personal trend, not as an absolute number with clinical meaning.
- Surface deep / REM changes as **personal-baseline deviations** rather than absolute health claims.
- Cite this note when explaining what wearable sleep staging can and can't tell us.
