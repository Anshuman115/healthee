---
id: wearable_spo2_validity
topic: Wrist optical SpO2 accuracy and limits
evidence_grade: 3
applies_to_metrics: [spo2]
applies_to_interventions: []
tags: [methodology, spo2, ppg, accuracy]
last_reviewed: 2026-05-11
---

## What it actually measures
Wrist SpO2 uses **two-wavelength optical sensing** (red + infrared LEDs) at the
skin to estimate the ratio of oxygenated to deoxygenated hemoglobin in capillary
blood. Clinical pulse oximeters use the same principle but typically at the
fingertip, where perfusion is higher and motion is lower.

## What we can trust
- **Population-average trend across multiple nights**: if your average nightly SpO2 drops over time, that's worth investigating.
- **Detecting clearly abnormal values**: sustained readings below ~90% are anomalous regardless of device precision.
- **Relative differences**: today's nightly SpO2 vs your own median.

## What we can't trust
- **Absolute values within ±2% precision.** FDA accuracy claims for consumer wrist SpO2 are commonly ±2–3% root-mean-square error vs arterial blood-gas reference.
- **Single low readings.** Motion, cold, dark skin pigmentation, poor sensor contact, and low perfusion all generate spurious low readings.
- **Sleep apnea diagnosis.** Wrist SpO2 cannot reliably detect or grade obstructive sleep apnea; it may surface a *suspicion* worth a clinical sleep study, nothing more.
- **Bias in dark skin pigmentation**: documented in the clinical pulse-oximeter literature; consumer wrist devices share this issue.

## Evidence strength
- Sjoding MW, Dickson RP, Iwashyna TJ, Gay SE, Valley TS. **"Racial bias in pulse oximetry measurement."** *New England Journal of Medicine* 2020;383(25):2477–2478. Documented overestimation of SpO2 in patients with darker skin pigmentation; broadly applicable to optical SpO2 devices.
- Pipek LZ, Nascimento RFV, Acencio MMP, Teixeira LR. **"Comparison of SpO2 and heart rate values on Apple Watch and conventional commercial oximeters devices in patients with lung disease."** *Scientific Reports* 2021;11:18901. Found modest agreement with clinical pulse oximetry for healthy ranges; degrades at lower SpO2.

## Caveats
- The Helio Strap has no published independent validation we're aware of. Inferences here come from PPG SpO2 literature on similar devices.
- Older consumer wrist SpO2 implementations (pre-2020) were less accurate than newer ones; newer firmware doesn't always carry independent validation.
- Most validation studies are in healthy populations at normal-range SpO2 (95–100%); accuracy at the *clinically interesting* range (<92%) is less well characterized for consumer devices.

## Operational use
- Surface SpO2 as a **trend over multiple nights**, not a single-reading alarm.
- A sustained drop in nightly SpO2 minimum below ~92% across several nights is worth flagging — and recommending a clinical evaluation, not making a diagnosis.
- Do **not** call out individual low-reading minutes (most are sensor artifacts).
- Cite this note when explaining what wearable SpO2 can and can't tell us.
