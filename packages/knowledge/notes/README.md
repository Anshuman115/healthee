# Healthee research base

Versioned evidence notes that ground every interpretation, correlation, and
recommendation in this project. The LLM grounding layer reads from this
directory at runtime and is **forced to cite a note** for any health claim.

If there is no note for a claim, the claim is not made.

## Layout

```
research/
├── README.md              ← this file
├── conventions.md         ← grading rules + frontmatter schema
├── sleep/                 ← evidence about sleep
├── activity/              ← evidence about steps, exercise, MVPA, fitness, mortality
├── meditation/            ← evidence about meditation, breathwork, yoga
├── hrv/                   ← evidence about heart-rate variability
├── intake/                ← evidence about alcohol, caffeine, food timing
├── metrics/               ← what we can/can't trust about each sensor signal
└── recs/                  ← framework + safety guardrails for the recommendations engine
```

## Evidence grade

Only `★★★` notes (strongest tier) ship by default — see `conventions.md`.

`★★` and `★` notes can be added but **must** be labeled accordingly; the LLM
must communicate the lower confidence when citing them.

## Adding a note

Drop a new `.md` file under the relevant subdirectory. It must include YAML
frontmatter (see `conventions.md` for the schema). Run nothing — the loader
reads the directory at runtime.
